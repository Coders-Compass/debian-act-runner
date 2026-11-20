# Pinned versions for reproducibility
# Debian: https://hub.docker.com/_/debian (bookworm = Debian 12)
# Node.js LTS: https://nodejs.org (v24.x = current LTS)
# Docker CLI: Latest stable from official Docker repository
FROM debian:bookworm-20261027-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
ENV PATH="$AGENT_TOOLSDIRECTORY/node/current/bin:$PATH"

LABEL org.opencontainers.image.source="https://github.com/Coders-Compass/debian-act-runner"
LABEL org.opencontainers.image.description="Debian-based image for Forgejo/Gitea Actions runner (act based) with Node.js LTS and Docker CLI"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="hungrybluedev"

SHELL ["/bin/bash", "-c"]

# Install base dependencies + Python + Chromium for CI testing
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  wget \
  git \
  jq \
  openssh-client \
  build-essential \
  gnupg \
  lsb-release \
  xz-utils \
  zsh \
  shellcheck \
  # Python for testing frameworks
  python3 \
  python3-pip \
  python3-venv \
  # Chromium and dependencies for Puppeteer/Lighthouse/Pa11y
  chromium \
  libnspr4 \
  libnss3 \
  libatk1.0-0 \
  libatk-bridge2.0-0 \
  libcups2 \
  libdrm2 \
  libxkbcommon0 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxrandr2 \
  libgbm1 \
  libasound2 \
  libpango-1.0-0 \
  libcairo2 \
  libx11-xcb1 \
  && \
  # Configure SSH for GitHub
  mkdir -p /etc/ssh && \
  ssh-keyscan -t rsa github.com >> /etc/ssh/ssh_known_hosts && \
  ssh-keyscan -t rsa ssh.dev.azure.com >> /etc/ssh/ssh_known_hosts && \
  echo "SSH configuration complete"

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
  chmod a+r /etc/apt/keyrings/docker.asc && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
  echo "Docker CLI installed: $(docker --version)"

# Install CI lint tools from pinned release binaries (amd64 and arm64)
# Bump a version together with both of its sha256 lines; Dependabot does not track these.
# actionlint: https://github.com/rhysd/actionlint/releases
# shfmt: https://github.com/mvdan/sh/releases (bookworm apt ships 3.6.0)
# golangci-lint: https://github.com/golangci/golangci-lint/releases
ARG ACTIONLINT_VERSION=1.7.12
ARG ACTIONLINT_SHA256_AMD64=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ARG ACTIONLINT_SHA256_ARM64=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
ARG SHFMT_VERSION=3.14.1
ARG SHFMT_SHA256_AMD64=76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf
ARG SHFMT_SHA256_ARM64=5f2db09dae91fca848f7adbdd014632e921a383863a2ad7e0450ad3aba0c6489
ARG GOLANGCI_LINT_VERSION=2.15.0
ARG GOLANGCI_LINT_SHA256_AMD64=9b7fe6a6bf6334b98decf8d86b11415ea7889afdabdd1959fdce23af2a9ebcea
ARG GOLANGCI_LINT_SHA256_ARM64=b4d8f17068b35ee6060cc2f69a16fb48740d706fbba81661c318649c114a6998
RUN set -euo pipefail && \
  ARCH="$(dpkg --print-architecture)" && \
  case "$ARCH" in \
    amd64) AL_SHA="$ACTIONLINT_SHA256_AMD64" SF_SHA="$SHFMT_SHA256_AMD64" GL_SHA="$GOLANGCI_LINT_SHA256_AMD64" ;; \
    arm64) AL_SHA="$ACTIONLINT_SHA256_ARM64" SF_SHA="$SHFMT_SHA256_ARM64" GL_SHA="$GOLANGCI_LINT_SHA256_ARM64" ;; \
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
  esac && \
  cd /tmp; \
  curl -fsSLo actionlint.tar.gz "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${ARCH}.tar.gz" && \
  echo "${AL_SHA}  actionlint.tar.gz" | sha256sum -c - && \
  tar -xzf actionlint.tar.gz actionlint && \
  install -m 0755 actionlint /usr/local/bin/actionlint && \
  curl -fsSLo shfmt "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_${ARCH}" && \
  echo "${SF_SHA}  shfmt" | sha256sum -c - && \
  install -m 0755 shfmt /usr/local/bin/shfmt && \
  curl -fsSLo golangci-lint.tar.gz "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}.tar.gz" && \
  echo "${GL_SHA}  golangci-lint.tar.gz" | sha256sum -c - && \
  tar -xzf golangci-lint.tar.gz --strip-components=1 "golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}/golangci-lint" && \
  install -m 0755 golangci-lint /usr/local/bin/golangci-lint && \
  rm -f actionlint actionlint.tar.gz shfmt golangci-lint golangci-lint.tar.gz

# Install Node.js into the tool cache, where actions/setup-node finds it by the x64.complete marker
# The first version is `current` on PATH; the rest are the versions the Forgejo repos pin in .node-version.
# Bump by hand from https://nodejs.org/dist/index.json; Dependabot does not track these.
ARG NODE_VERSIONS="24.11.1 26.13.1 24.22.3 22.23.5"
RUN set -euo pipefail && \
  case "$(dpkg --print-architecture)" in amd64) NODE_ARCH=x64 ;; arm64) NODE_ARCH=arm64 ;; *) echo "Unsupported architecture" && exit 1 ;; esac && \
  cd /tmp; \
  for v in $NODE_VERSIONS; do \
    echo "Installing Node.js v$v ($NODE_ARCH)"; \
    tarball="node-v$v-linux-$NODE_ARCH.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/v$v/$tarball"; \
    curl -fsSL "https://nodejs.org/dist/v$v/SHASUMS256.txt" | grep " $tarball\$" | sha256sum -c -; \
    mkdir -p "$AGENT_TOOLSDIRECTORY/node/$v/$NODE_ARCH"; \
    tar -Jxf "$tarball" --strip-components=1 -C "$AGENT_TOOLSDIRECTORY/node/$v/$NODE_ARCH"; \
    touch "$AGENT_TOOLSDIRECTORY/node/$v/$NODE_ARCH.complete"; \
    rm "$tarball"; \
  done; \
  NODEPATH="$AGENT_TOOLSDIRECTORY/node/${NODE_VERSIONS%% *}/$NODE_ARCH" && \
  # Create 'current' symlink for easier PATH management
  ln -s "$NODEPATH" "$AGENT_TOOLSDIRECTORY/node/current" && \
  # Also create traditional symlinks
  ln -s "$NODEPATH/bin/node" /usr/local/bin/node && \
  ln -s "$NODEPATH/bin/npm" /usr/local/bin/npm && \
  ln -s "$NODEPATH/bin/npx" /usr/local/bin/npx && \
  ln -s "$NODEPATH/bin/corepack" /usr/local/bin/corepack && \
  echo "Node.js installed: $(node --version)" && \
  echo "npm installed: $(npm --version)"

# Cleanup
RUN apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Environment variables for Chromium (Puppeteer/Lighthouse/Pa11y)
ENV CHROME_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Verify installations
RUN echo "=== Installation Verification ===" && \
  echo "Debian version: $(cat /etc/debian_version)" && \
  echo "Node.js: $(node --version)" && \
  echo "npm: $(npm --version)" && \
  echo "Python: $(python3 --version)" && \
  echo "pip: $(pip3 --version)" && \
  echo "Chromium: $(chromium --version || echo 'installed')" && \
  echo "Docker CLI: $(docker --version)" && \
  echo "Git: $(git --version)" && \
  echo "jq: $(jq --version)" && \
  echo "zsh: $(zsh --version)" && \
  echo "shfmt: $(shfmt --version)" && \
  echo "shellcheck: $(shellcheck --version | head -2)" && \
  echo "actionlint: $(actionlint --version | head -1)" && \
  echo "golangci-lint: $(golangci-lint --version)"

WORKDIR /workspace