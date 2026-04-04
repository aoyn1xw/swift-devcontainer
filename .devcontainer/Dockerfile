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
# Swift (pinned — avoids scraping failures)
# ------------------------------------------------------------
ARG SWIFT_VERSION=6.0.3
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
# xtool
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
# zsign (build from source, only keep the binary)
# ------------------------------------------------------------
RUN set -eux; \
  git clone --depth 1 https://github.com/zhlynn/zsign.git /tmp/zsign; \
  cd /tmp/zsign/build/linux; \
  make; \
  strip ../../bin/zsign; \
  install -m 0755 ../../bin/zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign

# ------------------------------------------------------------
# Theos (shallow clone, no .git history)
# ------------------------------------------------------------
RUN set -eux; \
  git clone --recursive --shallow-submodules --depth 1 \
    https://github.com/theos/theos.git /opt/theos; \
  # Remove docs, examples, and git metadata to save space
  find /opt/theos -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true; \
  find /opt/theos -name "*.md" -delete 2>/dev/null || true; \
  find /opt/theos -name "CHANGELOG*" -delete 2>/dev/null || true; \
  find /opt/theos -name "LICENSE*" -delete 2>/dev/null || true


# ============================================================
# Stage 2: Final image — only runtime deps + built artifacts
# ============================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"
ENV THEOS=/opt/theos
ENV THEOS_MAKE_PATH=/opt/theos/makefiles
ENV CODE_SERVER_PASSWORD=changeme

# Runtime deps only — no build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
  # Swift runtime
  binutils libedit2 libxml2-dev libsqlite3-0 \
  libcurl4-openssl-dev tzdata \
  libssl3 libncurses6 \
  # zsign runtime (Ubuntu 24.04 noble)
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

# Symlinks
RUN ln -sf /opt/xtool/AppRun /usr/local/bin/xtool \
  && chown -R vscode:vscode /opt/theos \
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

# code-server config
RUN mkdir -p /home/vscode/.config/code-server && \
  cat > /home/vscode/.config/code-server/config.yaml <<'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: changeme
cert: false
EOF

# VS Code settings (Swift path, formatter, etc.)
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

CMD ["code-server", "--bind-addr", "0.0.0.0:8080"]