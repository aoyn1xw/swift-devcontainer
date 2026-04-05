# ============================================================
# Stage 1: Builder — download & compile everything heavy
# ============================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"

# Build deps only needed at compile time
RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl ca-certificates tar xz-utils \
  build-essential pkg-config \
  libssl-dev libminizip-dev liblzma-dev \
  libplist-dev libzip-dev \
  libxml2-dev libz3-dev \
  libncurses-dev \
  && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Swift 6.2 (pinned)
# ------------------------------------------------------------
ARG SWIFT_VERSION=6.2
RUN set -eux; \
  ARCH="$(uname -m)"; \
  if [ "$ARCH" = "aarch64" ]; then \
    SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404-aarch64/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04-aarch64.tar.gz"; \
  else \
    SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"; \
  fi; \
  echo "Downloading Swift ${SWIFT_VERSION} from ${SWIFT_URL}"; \
  curl -fsSL "$SWIFT_URL" -o /tmp/swift.tar.gz; \
  mkdir -p /tmp/swift; \
  tar xzf /tmp/swift.tar.gz -C /tmp/swift --strip-components=1; \
  find /tmp/swift/usr -name "*.so" | xargs strip --strip-debug 2>/dev/null || true; \
  find /tmp/swift/usr -name "swift-*" -type f | xargs strip --strip-debug 2>/dev/null || true; \
  cp -r /tmp/swift/usr/* /usr/local/; \
  rm -rf /tmp/swift /tmp/swift.tar.gz; \
  swift --version

# ------------------------------------------------------------
# xtool binary only (no setup — done interactively at runtime)
# ------------------------------------------------------------
RUN set -eux; \
  curl -fsSL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
    -o /tmp/xtool.AppImage; \
  chmod +x /tmp/xtool.AppImage; \
  cd /tmp && APPIMAGE_EXTRACT_AND_RUN=1 ./xtool.AppImage --appimage-extract 2>&1 || true; \
  if [ ! -d /tmp/squashfs-root ]; then \
    echo "ERROR: AppImage extraction failed"; exit 1; \
  fi; \
  mkdir -p /opt/xtool; \
  cp -r /tmp/squashfs-root/* /opt/xtool/; \
  chmod +x /opt/xtool/AppRun; \
  rm -rf /tmp/xtool.AppImage /tmp/squashfs-root

# ------------------------------------------------------------
# minizip-ng (build from source)
# ------------------------------------------------------------
RUN set -eux; \
  apt-get update && apt-get install -y --no-install-recommends cmake zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*; \
  git clone --depth 1 https://github.com/zlib-ng/minizip-ng.git /tmp/minizip-ng; \
  cmake -S /tmp/minizip-ng -B /tmp/minizip-ng/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DMZ_FETCH_LIBS=OFF \
    -DMZ_OPENSSL=ON \
    -DMZ_PPMD=OFF \
    -DMZ_LZMA=OFF; \
  cmake --build /tmp/minizip-ng/build --parallel; \
  cmake --install /tmp/minizip-ng/build; \
  rm -rf /tmp/minizip-ng; \
  cp /usr/local/lib/pkgconfig/minizip.pc /usr/local/lib/pkgconfig/minizip-ng.pc; \
  sed -i 's/^Name: minizip/Name: minizip-ng/' /usr/local/lib/pkgconfig/minizip-ng.pc; \
  pkg-config --libs minizip-ng

# ------------------------------------------------------------
# zsign (build from source)
# ------------------------------------------------------------
RUN set -eux; \
  git clone --depth 1 https://github.com/zhlynn/zsign.git /tmp/zsign; \
  cd /tmp/zsign/build/linux; \
  sed -i 's/$(MINIZIP_LIB)/$(MINIZIP_LIB) -lz/' Makefile; \
  make clean && make; \
  strip ../../bin/zsign; \
  install -m 0755 ../../bin/zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign; \
  zsign --help | head -3

# ------------------------------------------------------------
# Theos (via official installer, run as non-root)
# ------------------------------------------------------------
ENV THEOS=/opt/theos
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /opt/theos \
  && chown vscode:vscode /opt/theos

RUN set -eux; \
  su vscode -c 'curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos | bash'

RUN test -d /opt/theos


# ============================================================
# Stage 2: Final image — only runtime deps + built artifacts
# ============================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"
ENV THEOS=/opt/theos
ENV THEOS_MAKE_PATH=/opt/theos/makefiles

# Runtime deps only
RUN apt-get update && apt-get install -y --no-install-recommends \
  # Swift runtime
  binutils libedit2 libxml2-dev libsqlite3-0 \
  libcurl4-openssl-dev tzdata \
  libssl3 libncurses6 \
  # zsign runtime
  libplist-dev libzip-dev libminizip-dev \
  # xtool / general
  libfuse2 libz3-dev \
  # iOS device
  usbmuxd libimobiledevice-utils \
  # Essentials
  git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean \
  && rm -rf /tmp/* /var/tmp/*

# Copy built artifacts from builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /opt/xtool /opt/xtool
COPY --from=builder /opt/theos /opt/theos

# Symlinks + permissions
RUN ln -sf /opt/xtool/AppRun /usr/local/bin/xtool \
  && chown -R vscode:vscode /opt/theos \
  && chown -R vscode:vscode /opt/xtool \
  && chmod -R 755 /opt/theos

# ------------------------------------------------------------
# code-server
# ------------------------------------------------------------
RUN curl -fsSL https://code-server.dev/install.sh | sh \
  && rm -rf /tmp/* ~/.cache

# Pre-install extensions
RUN code-server --install-extension sswg.swift-lang \
  && code-server --install-extension vadimcn.vscode-lldb \
  && rm -rf /tmp/*

# code-server config — password via env var at runtime
RUN mkdir -p /home/vscode/.config/code-server && \
  cat > /home/vscode/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: changeme
cert: false
EOF

# VS Code settings
RUN mkdir -p /home/vscode/.local/share/code-server/User && \
  cat > /home/vscode/.local/share/code-server/User/settings.json <<'EOF'
{
  "swift.path": "/usr/local/bin/swift",
  "lldb.library": "/usr/local/lib/swift/linux/liblldb.so",
  "editor.formatOnSave": true,
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "workbench.colorTheme": "Default Dark Modern",
  "terminal.integrated.defaultProfile.linux": "bash",
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000
}
EOF

# Entrypoint script — applies CODE_SERVER_PASSWORD env var at runtime
RUN cat > /usr/local/bin/entrypoint.sh <<'EOF'
#!/bin/bash
set -e

# Override password if env var is set
if [ -n "$CODE_SERVER_PASSWORD" ]; then
  sed -i "s/^password:.*/password: ${CODE_SERVER_PASSWORD}/" \
    /home/vscode/.config/code-server/config.yaml
fi

echo "================================================"
echo "  Swift iOS Dev Environment"
echo "  code-server running at http://0.0.0.0:8080"
echo ""
echo "  First time setup — run in the terminal:"
echo "    xtool setup"
echo "================================================"

exec code-server --bind-addr 0.0.0.0:8080
EOF
RUN chmod +x /usr/local/bin/entrypoint.sh

# Fix ownership
RUN chown -R vscode:vscode /home/vscode

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
RUN { \
    echo ''; \
    echo '# Swift and iOS toolchain'; \
    echo 'export PATH="/usr/local/bin:$PATH"'; \
    echo 'export THEOS=/opt/theos'; \
    echo 'export THEOS_MAKE_PATH=/opt/theos/makefiles'; \
  } >> /etc/bash.bashrc

# ------------------------------------------------------------
# Sanity check
# ------------------------------------------------------------
RUN swift --version && xtool --help && which zsign && test -d /opt/theos

EXPOSE 8080

USER vscode

CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password"]