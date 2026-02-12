FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20
ENV PATH="/usr/local/bin:$PATH"

# ------------------------------------------------------------
# Base system + Node.js + build deps
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl ca-certificates tar xz-utils \
  build-essential g++ pkg-config \
  cmake ninja-build \
  autoconf automake libtool \
  libssl-dev libminizip-dev liblzma-dev \
  libncurses-dev libpython3-dev libxml2-dev libz3-dev \
  libusb-1.0-0-dev libreadline-dev \
  usbmuxd libimobiledevice-utils \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS and TypeScript with type definitions
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g typescript @types/node @types/mocha @types/jest && \
    node -v && npm -v && tsc -v

# ------------------------------------------------------------
# Swift 6.2 (official release)
# ------------------------------------------------------------
RUN set -eux; \
  SWIFT_URL="https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz"; \
  curl -fsSL "$SWIFT_URL" -o swift.tar.gz; \
  mkdir -p /tmp/swift; \
  tar xzf swift.tar.gz -C /tmp/swift --strip-components=1; \
  cp -r /tmp/swift/usr/* /usr/local/; \
  rm -rf swift.tar.gz /tmp/swift; \
  swift --version

# ------------------------------------------------------------
# xtool (using AppImage from GitHub releases)
# ------------------------------------------------------------
RUN set -eux; \
  curl -fsSL \
    "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
    -o /usr/local/bin/xtool; \
  chmod +x /usr/local/bin/xtool; \
  xtool --help

# ------------------------------------------------------------
# zsign (build from source using official instructions)
# ------------------------------------------------------------
RUN set -eux; \
  git clone https://github.com/zhlynn/zsign.git /tmp/zsign; \
  cd /tmp/zsign/build/linux; \
  make clean && make; \
  install -m 0755 zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign; \
  zsign

# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------
RUN set -eux; \
  { \
    echo ''; \
    echo '# Swift and tools environment'; \
    echo 'export PATH="/usr/local/bin:$PATH"'; \
  } >> /etc/bash.bashrc

# ------------------------------------------------------------
# Final sanity check
# ------------------------------------------------------------
RUN node -v && npm -v && tsc -v && swift --version && xtool --help && zsign
