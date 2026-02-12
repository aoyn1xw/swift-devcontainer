FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install build dependencies + Swift runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl ca-certificates tar xz-utils \
  build-essential g++ pkg-config \
  cmake ninja-build \
  libssl-dev libminizip-dev liblzma-dev \
  libncurses-dev libpython3-dev libxml2-dev libz3-dev \
  libimobiledevice-dev libplist-dev libusbmuxd-dev \
  autoconf automake libtool \
  libusb-1.0-0-dev libreadline-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Swift via swiftly + build xtool & zsign (all in one layer)
RUN set -eux; \
  export DEBIAN_FRONTEND=noninteractive; \
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
  export PATH="${swiftly_home}/bin:$prefix/bin:$PATH"; \
  \
  # --- Swift toolchain --- \
  echo "=== Installing Swift ==="; \
  if [ -f "$swiftly_home/env.sh" ]; then . "$swiftly_home/env.sh"; fi; \
  "$prefix/bin/swiftly" install latest --use; \
  if [ -f "$swiftly_home/env.sh" ]; then . "$swiftly_home/env.sh"; fi; \
  swift --version; \
  \
  # --- Remove conflicting apt packages --- \
  echo "=== Removing conflicting system packages ==="; \
  apt-get remove -y libimobiledevice-dev libplist-dev libusbmuxd-dev || true; \
  \
  # --- Build libimobiledevice from source with pinned versions (CORRECT ORDER) --- \
  echo "=== Building libimobiledevice stack from source ==="; \
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
  export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"; \
  \
  # libplist (no dependencies) \
  git clone --depth 1 --branch 2.6.0 https://github.com/libimobiledevice/libplist.git; \
  cd libplist; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libplist; \
  \
  # libimobiledevice-glue (depends on libplist) - BUILD BEFORE libusbmuxd \
  git clone --depth 1 --branch 1.3.0 https://github.com/libimobiledevice/libimobiledevice-glue.git; \
  cd libimobiledevice-glue; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libimobiledevice-glue; \
  \
  # libusbmuxd (depends on libplist and libimobiledevice-glue) \
  git clone --depth 1 --branch 2.1.0 https://github.com/libimobiledevice/libusbmuxd.git; \
  cd libusbmuxd; \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libusbmuxd; \
  \
  # libimobiledevice (depends on all of the above) \
  git clone --depth 1 --branch 1.3.0 https://github.com/libimobiledevice/libimobiledevice.git; \
  cd libimobiledevice; \
  \
  # Patch utils.h to remove conflicting enum definitions \
  echo "=== Patching libimobiledevice to fix enum conflicts ==="; \
  sed -i '/^typedef enum {$/,/^} plist_format_t;$/d' common/utils.h; \
  \
  ./autogen.sh --prefix="$prefix" --without-cython; \
  make -j "$jobs"; \
  make install; \
  cd "$build"; rm -rf libimobiledevice; \
  \
  # Update ldconfig \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf; \
  ldconfig; \
  \
  # Verify installation \
  pkg-config --modversion libimobiledevice-1.0 || { echo "libimobiledevice pkg-config check failed"; exit 1; }; \
  \
  # --- xtool (iOS cross-compile) --- \
  echo "=== Building xtool ==="; \
  git clone --depth 1 --branch "1.16.1" https://github.com/xtool-org/xtool.git xtool; \
  cd xtool; \
  swift build -c release -j "$jobs" || { \
    echo "=== xtool build failed, diagnostics ==="; \
    pkg-config --modversion libimobiledevice-1.0 || echo "libimobiledevice not found via pkg-config"; \
    pkg-config --cflags libimobiledevice-1.0 || echo "Cannot get cflags"; \
    pkg-config --libs libimobiledevice-1.0 || echo "Cannot get libs"; \
    ls -la /usr/local/include/libimobiledevice/ || echo "libimobiledevice headers not found"; \
    ls -la /usr/local/lib/libimobiledevice* || echo "libimobiledevice libs not found"; \
    exit 1; \
  }; \
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
    echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"'; \
    echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"'; \
    echo '[ -f "$SWIFTLY_HOME_DIR/env.sh" ] && . "$SWIFTLY_HOME_DIR/env.sh"'; \
  } >> /etc/bash.bashrc; \
  \
  # --- verify installations --- \
  echo "=== Verifying installations ==="; \
  swiftly --version; \
  swift --version; \
  xtool --help | head -1 || true; \
  zsign --help | head -1 || true; \
  echo "DONE"
