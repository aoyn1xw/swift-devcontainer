FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"

# ------------------------------------------------------------
# Base system + build dependencies + FUSE for AppImage
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
# Swift 6.2
# ------------------------------------------------------------
RUN set -eux; \
  SWIFT_URL="https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz"; \
  curl -fsSL "$SWIFT_URL" -o /tmp/swift.tar.gz; \
  mkdir -p /tmp/swift; \
  tar xzf /tmp/swift.tar.gz -C /tmp/swift --strip-components=1; \
  cp -r /tmp/swift/usr/* /usr/local/; \
  rm -rf /tmp/swift /tmp/swift.tar.gz; \
  swift --version

# ------------------------------------------------------------
# xtool (extract AppImage and copy ALL contents)
# ------------------------------------------------------------
RUN set -eux; \
  curl -fsSL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o /tmp/xtool.AppImage; \
  chmod +x /tmp/xtool.AppImage; \
  cd /tmp; \
  ./xtool.AppImage --appimage-extract 2>&1 || true; \
  if [ ! -d /tmp/squashfs-root ]; then \
    echo "ERROR: AppImage extraction failed!"; \
    exit 1; \
  fi; \
  mkdir -p /opt/xtool; \
  cp -r /tmp/squashfs-root/* /opt/xtool/; \
  ln -s /opt/xtool/AppRun /usr/local/bin/xtool; \
  chmod +x /opt/xtool/AppRun; \
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
# Theos
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
