# Pinned versions for reproducibility
# Debian: https://hub.docker.com/_/debian (bookworm = Debian 12)
# Node.js LTS: https://nodejs.org (v24.x = current LTS)
# Docker CLI: Latest stable from official Docker repository
FROM debian:bookworm-20251229-slim

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
  shfmt \
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

# Install Node.js LTS (pinned version)
RUN mkdir -p "$AGENT_TOOLSDIRECTORY/node" && \
  NODE_VERSION="v24.11.1" && \
  echo "Installing Node.js $NODE_VERSION" && \
  NODEPATH="$AGENT_TOOLSDIRECTORY/node/${NODE_VERSION:1}/x64" && \
  mkdir -p "$NODEPATH" && \
  wget -q "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.xz" && \
  tar -Jxf "node-$NODE_VERSION-linux-x64.tar.xz" --strip-components=1 -C "$NODEPATH" && \
  rm "node-$NODE_VERSION-linux-x64.tar.xz" && \
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
  echo "shellcheck: $(shellcheck --version | head -2)"

WORKDIR /workspace