FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install build dependencies + Swift runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl ca-certificates tar xz-utils \
  build-essential g++ pkg-config \
  cmake ninja-build \
  libssl-dev libminizip-dev \
  libncurses-dev libpython3-dev libxml2-dev libz3-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Swift via swiftly + build xtool & zsign (all in one layer)
RUN set -eux; \
  export DEBIAN_FRONTEND=noninteractive; \
  apt-get update && apt-get install -y --no-install-recommends \
    libncurses-dev libpython3-dev libxml2-dev libz3-dev \
  && rm -rf /var/lib/apt/lists/*; \
  jobs="$(nproc)"; \
  prefix="/usr/local"; \
  swiftly_home="/usr/local/share/swiftly"; \
  build="/tmp/build"; \
  mkdir -p "$build"; \
  cd "$build"; \
  \
  # --- swiftly --- \
  echo "=== Installing swiftly ==="; \
  curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"; \
  tar zxf "swiftly-$(uname -m).tar.gz"; \
  install -m 0755 swiftly "$prefix/bin/swiftly"; \
  SWIFTLY_HOME_DIR="$swiftly_home" SWIFTLY_BIN_DIR="$prefix/bin" \
    "$prefix/bin/swiftly" init --quiet-shell-followup; \
  export PATH="$swiftly_home/bin:$prefix/bin:$PATH"; \
  \
  # --- Swift toolchain --- \
  echo "=== Installing Swift ==="; \
  if [ -f "$swiftly_home/env.sh" ]; then . "$swiftly_home/env.sh"; fi; \
  "$prefix/bin/swiftly" install latest --use; \
  if [ -f "$swiftly_home/env.sh" ]; then . "$swiftly_home/env.sh"; fi; \
  swift --version; \
  \
  # --- xtool (iOS cross-compile) --- \
  echo "=== Building xtool ==="; \
  git clone --depth 1 --branch "1.16.1" https://github.com/xtool-org/xtool.git xtool; \
  cd xtool; \
  swift build -c release -j "$jobs"; \
  install -m 0755 .build/release/xtool "$prefix/bin/xtool"; \
  cd "$build"; rm -rf xtool; \
  \
  # --- zsign (code signing) --- \
  echo "=== Building zsign ==="; \
  git clone --depth 1 --branch "v0.7" https://github.com/zhlynn/zsign.git zsign; \
  cd zsign/build/linux; \
  make clean || true; \
  make -j "$jobs"; \
  install -m 0755 zsign "$prefix/bin/zsign"; \
  cd "$build"; rm -rf zsign; \
  \
  # --- cleanup --- \
  rm -rf "$build"; \
  \
  # --- shell environment for Swift --- \
  { echo ''; \
    echo '# Swift environment'; \
    echo 'export SWIFTLY_HOME_DIR="/usr/local/share/swiftly"'; \
    echo 'export PATH="$SWIFTLY_HOME_DIR/bin:/usr/local/bin:$PATH"'; \
    echo '[ -f "$SWIFTLY_HOME_DIR/env.sh" ] && . "$SWIFTLY_HOME_DIR/env.sh"'; \
  } >> /etc/bash.bashrc; \
  cp /etc/bash.bashrc /etc/profile.d/swiftly.sh || true; \
  { echo ''; \
    echo 'export SWIFTLY_HOME_DIR="/usr/local/share/swiftly"'; \
    echo 'export PATH="$SWIFTLY_HOME_DIR/bin:/usr/local/bin:$PATH"'; \
    echo '[ -f "$SWIFTLY_HOME_DIR/env.sh" ] && . "$SWIFTLY_HOME_DIR/env.sh"'; \
  } > /etc/profile.d/swiftly.sh; \
  \
  # --- verify --- \
  echo "=== Installed tools ==="; \
  swift --version; \
  xtool --help | head -1 || true; \
  zsign --help | head -1 || true; \
  echo "DONE"
