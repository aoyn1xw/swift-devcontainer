FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20

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
  && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g typescript && \
    node -v && npm -v && tsc -v

# ------------------------------------------------------------
# Swift via swiftly
# ------------------------------------------------------------
RUN set -eux; \
  prefix="/usr/local"; \
  swiftly_home="/usr/local/share/swiftly"; \
  curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"; \
  tar zxf "swiftly-$(uname -m).tar.gz"; \
  install -m 0755 swiftly "$prefix/bin/swiftly"; \
  rm swiftly swiftly-*.tar.gz; \
  SWIFTLY_HOME_DIR="$swiftly_home" SWIFTLY_BIN_DIR="$prefix/bin" \
    "$prefix/bin/swiftly" init --quiet-shell-followup; \
  . "$swiftly_home/env.sh"; \
  "$prefix/bin/swiftly" install latest --use; \
  swift --version

# ------------------------------------------------------------
# Remove distro libimobiledevice stack completely
# ------------------------------------------------------------
RUN set -eux; \
  apt-get purge -y \
    libimobiledevice-dev \
    libplist-dev \
    libusbmuxd-dev || true; \
  rm -rf \
    /usr/include/libimobiledevice \
    /usr/include/plist \
    /usr/include/usbmuxd \
    /usr/lib/x86_64-linux-gnu/libimobiledevice* \
    /usr/lib/x86_64-linux-gnu/libplist* \
    /usr/lib/x86_64-linux-gnu/libusbmuxd*

# ------------------------------------------------------------
# Build libimobiledevice stack from source (with compatible versions)
# ------------------------------------------------------------
RUN set -eux; \
  jobs="$(nproc)"; \
  prefix="/usr/local"; \
  build="/tmp/build"; \
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"; \
  export LD_LIBRARY_PATH="/usr/local/lib"; \
  mkdir -p "$build"; \
  cd "$build"; \
  \
  git clone --depth 1 --branch 2.6.0 https://github.com/libimobiledevice/libplist.git; \
  cd libplist; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libplist; \
  \
  git clone --depth 1 --branch 1.3.0 https://github.com/libimobiledevice/libimobiledevice-glue.git; \
  cd libimobiledevice-glue; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libimobiledevice-glue; \
  \
  git clone --depth 1 --branch 2.1.0 https://github.com/libimobiledevice/libusbmuxd.git; \
  cd libusbmuxd; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libusbmuxd; \
  \
  git clone --depth 1 https://github.com/libimobiledevice/libimobiledevice.git; \
  cd libimobiledevice; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libimobiledevice; \
  \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf; \
  ldconfig; \
  pkg-config --modversion libimobiledevice-1.0; \
  rm -rf "$build"

# ------------------------------------------------------------
# xtool
# ------------------------------------------------------------
RUN set -eux; \
  . /usr/local/share/swiftly/env.sh; \
  git clone --depth 1 --branch 1.16.1 https://github.com/xtool-org/xtool.git /tmp/xtool; \
  cd /tmp/xtool; \
  swift build -c release -j "$(nproc)"; \
  install -m 0755 .build/release/xtool /usr/local/bin/xtool; \
  rm -rf /tmp/xtool

# ------------------------------------------------------------
# zsign
# ------------------------------------------------------------
RUN set -eux; \
  git clone --depth 1 --branch v0.7 https://github.com/zhlynn/zsign.git /tmp/zsign; \
  cd /tmp/zsign/build/linux; \
  make -j "$(nproc)"; \
  install -m 0755 zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign

# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------
RUN set -eux; \
  { \
    echo ''; \
    echo '# Swift'; \
    echo 'export SWIFTLY_HOME_DIR="/usr/local/share/swiftly"'; \
    echo 'export PATH="$SWIFTLY_HOME_DIR/bin:/usr/local/bin:$PATH"'; \
    echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"'; \
    echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"'; \
    echo '[ -f "$SWIFTLY_HOME_DIR/env.sh" ] && . "$SWIFTLY_HOME_DIR/env.sh"'; \
  } >> /etc/bash.bashrc

# ------------------------------------------------------------
# Final sanity check
# ------------------------------------------------------------
RUN node -v && npm -v && tsc -v && swift --version && xtool --help | head -1 && zsign --help | head -1
