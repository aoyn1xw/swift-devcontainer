FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"

# ------------------------------------------------------------
# Base system + build dependencies
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
  # General
  git curl ca-certificates tar xz-utils \
  build-essential pkg-config \
  # Swift runtime (per swift.org)
  binutils libedit2 libxml2-dev libsqlite3-0 libz3-dev \
  libcurl4-openssl-dev tzdata \
  # SSL / compression
  libssl-dev libminizip-dev liblzma-dev \
  # ncurses (Swift REPL + lldb)
  libncurses6 libncurses-dev \
  # iOS device communication
  usbmuxd libimobiledevice-utils \
  # AppImage extraction
  libfuse2 \
  # zsign build deps
  libplist-dev libzip-dev \
  && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Swift (latest stable, multi-arch aware)
# ------------------------------------------------------------
RUN set -eux; \
  ARCH="$(uname -m)"; \
  # Fetch the latest release version number from swift.org
  SWIFT_VERSION="$(curl -fsSL https://www.swift.org/install/linux/tarball | grep -oP 'swift-\K[0-9]+\.[0-9]+\.[0-9]+(?=-RELEASE)' | sort -V | tail -1)"; \
  echo "Installing Swift ${SWIFT_VERSION}"; \
  if [ "$ARCH" = "aarch64" ]; then \
    SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404-aarch64/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04-aarch64.tar.gz"; \
  else \
    SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"; \
  fi; \
  curl -fsSL "$SWIFT_URL" -o /tmp/swift.tar.gz; \
  mkdir -p /tmp/swift; \
  tar xzf /tmp/swift.tar.gz -C /tmp/swift --strip-components=1; \
  cp -r /tmp/swift/usr/* /usr/local/; \
  rm -rf /tmp/swift /tmp/swift.tar.gz; \
  swift --version

# ------------------------------------------------------------
# xtool (extract AppImage, no FUSE required)
# ------------------------------------------------------------
RUN set -eux; \
  curl -fsSL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
    -o /tmp/xtool.AppImage; \
  chmod +x /tmp/xtool.AppImage; \
  cd /tmp && APPIMAGE_EXTRACT_AND_RUN=1 ./xtool.AppImage --appimage-extract 2>&1 || true; \
  if [ ! -d /tmp/squashfs-root ]; then \
    echo "ERROR: AppImage extraction failed — squashfs-root not found"; \
    ls /tmp; \
    exit 1; \
  fi; \
  mkdir -p /opt/xtool; \
  cp -r /tmp/squashfs-root/* /opt/xtool/; \
  chmod +x /opt/xtool/AppRun; \
  ln -sf /opt/xtool/AppRun /usr/local/bin/xtool; \
  rm -rf /tmp/xtool.AppImage /tmp/squashfs-root; \
  xtool --help

# ------------------------------------------------------------
# zsign (build from source)
# ------------------------------------------------------------
RUN set -eux; \
  git clone --depth 1 https://github.com/zhlynn/zsign.git /tmp/zsign; \
  cd /tmp/zsign/build/linux; \
  make; \
  install -m 0755 ../../bin/zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign

# ------------------------------------------------------------
# Theos
# ------------------------------------------------------------
ENV THEOS=/opt/theos
ENV THEOS_MAKE_PATH=/opt/theos/makefiles

RUN set -eux; \
  git clone --recursive --shallow-submodules \
    https://github.com/theos/theos.git /opt/theos; \
  chown -R vscode:vscode /opt/theos; \
  chmod -R 755 /opt/theos

# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------
RUN { \
    echo ''; \
    echo '# Swift and iOS toolchain environment'; \
    echo 'export PATH="/usr/local/bin:$PATH"'; \
    echo 'export THEOS=/opt/theos'; \
    echo 'export THEOS_MAKE_PATH=/opt/theos/makefiles'; \
  } >> /etc/bash.bashrc

# ------------------------------------------------------------
# Final sanity check
# ------------------------------------------------------------
RUN swift --version && xtool --help && which zsign && test -d /opt/theos

USER vscode
