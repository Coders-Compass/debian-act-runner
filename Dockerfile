FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
ENV PATH="$AGENT_TOOLSDIRECTORY/node/current/bin:$PATH"

LABEL org.opencontainers.image.source="https://github.com/Coders-Compass/debian-act-runner"
LABEL org.opencontainers.image.description="Debian-based image for Forgejo/Gitea Actions runner (act based) with Node.js LTS and Docker CLI"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="hungrybluedev"

SHELL ["/bin/bash", "-c"]

# Install base dependencies
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

# Install Node.js LTS
RUN mkdir -p "$AGENT_TOOLSDIRECTORY/node" && \
  NODE_VERSION=$(curl -s https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version') && \
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

# Verify installations
RUN echo "=== Installation Verification ===" && \
  echo "Debian version: $(cat /etc/debian_version)" && \
  echo "Node.js: $(node --version)" && \
  echo "npm: $(npm --version)" && \
  echo "Docker CLI: $(docker --version)" && \
  echo "Git: $(git --version)" && \
  echo "jq: $(jq --version)"

WORKDIR /workspace