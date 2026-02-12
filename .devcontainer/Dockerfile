FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"

# ------------------------------------------------------------
# Base system + build deps + FUSE for AppImage
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl ca-certificates tar xz-utils \
  build-essential g++ pkg-config \
  libssl-dev libminizip-dev liblzma-dev \
  libncurses6 libncurses-dev \
  usbmuxd libimobiledevice-utils \
  fuse libfuse2 \
  bash sudo \
  && rm -rf /var/lib/apt/lists/*

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
# xtool (extract AppImage to avoid FUSE runtime dependency)
# ------------------------------------------------------------
RUN set -eux; \
  curl -fsSL \
    "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
    -o /tmp/xtool.AppImage; \
  chmod +x /tmp/xtool.AppImage; \
  cd /tmp && ./xtool.AppImage --appimage-extract; \
  mv squashfs-root/AppRun /usr/local/bin/xtool; \
  rm -rf /tmp/xtool.AppImage /tmp/squashfs-root; \
  xtool --help

# ------------------------------------------------------------
# zsign (build from source)
# ------------------------------------------------------------
RUN set -eux; \
  git clone https://github.com/zhlynn/zsign.git /tmp/zsign; \
  cd /tmp/zsign/build/linux; \
  make clean && make; \
  install -m 0755 zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign; \
  zsign

# ------------------------------------------------------------
# Theos (cross-platform build system for iOS/macOS/Linux/Windows)
# ------------------------------------------------------------
RUN set -eux; \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# ------------------------------------------------------------
# Environment setup
# ------------------------------------------------------------
RUN set -eux; \
  { \
    echo ''; \
    echo '# Swift and tools environment'; \
    echo 'export PATH="/usr/local/bin:$PATH"'; \
    echo 'export THEOS=/opt/theos'; \
  } >> /etc/bash.bashrc

# ------------------------------------------------------------
# Final sanity check
# ------------------------------------------------------------
RUN swift --version && xtool --help && zsign && test -d /opt/theos
