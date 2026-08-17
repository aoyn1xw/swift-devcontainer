# ============================================================
# Stage 1: Builder — compile zsign + minizip-ng + extract xtool
# ============================================================
FROM swift:6.3.3-noble AS builder

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build deps (cached layer)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git \
    build-essential pkg-config cmake \
    libssl-dev libminizip-dev liblzma-dev zlib1g-dev \
    libplist-dev libzip-dev \
    && true

# xtool — extract AppImage
ARG XTOOL_VERSION=1.17.0
ARG MINIZIP_NG_COMMIT=dc8531deb704715fa57268d5e144f9eed7c8af66
ARG ZSIGN_COMMIT=e803f870dc686e6161d00d9b22c425b8acdfacee
ARG CODE_SERVER_VERSION=4.133.0
RUN set -eux; \
  if [ "$XTOOL_VERSION" = "latest" ]; then \
    XTOOL_URL="https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage"; \
  else \
    XTOOL_URL="https://github.com/xtool-org/xtool/releases/download/${XTOOL_VERSION}/xtool-$(uname -m).AppImage"; \
  fi; \
  curl -fsSL "$XTOOL_URL" -o /tmp/xtool.AppImage; \
  chmod +x /tmp/xtool.AppImage; \
  cd /tmp && APPIMAGE_EXTRACT_AND_RUN=1 ./xtool.AppImage --appimage-extract 2>&1 || true; \
  test -d /tmp/squashfs-root || { echo "AppImage extraction failed"; exit 1; }; \
  mkdir -p /opt/xtool; \
  cp -r /tmp/squashfs-root/* /opt/xtool/; \
  chmod +x /opt/xtool/AppRun; \
  rm -rf /tmp/xtool.AppImage /tmp/squashfs-root

# minizip-ng (needed by zsign)
RUN set -eux; \
  git clone https://github.com/zlib-ng/minizip-ng.git /tmp/minizip-ng; \
  git -C /tmp/minizip-ng checkout --detach "$MINIZIP_NG_COMMIT"; \
  cmake -S /tmp/minizip-ng -B /tmp/minizip-ng/build \
    -DCMAKE_BUILD_TYPE=Release -DMZ_FETCH_LIBS=OFF \
    -DMZ_OPENSSL=ON -DMZ_PPMD=OFF -DMZ_LZMA=OFF; \
  cmake --build /tmp/minizip-ng/build --parallel; \
  cmake --install /tmp/minizip-ng/build; \
  rm -rf /tmp/minizip-ng; \
  cp /usr/local/lib/pkgconfig/minizip.pc /usr/local/lib/pkgconfig/minizip-ng.pc; \
  sed -i 's/^Name: minizip/Name: minizip-ng/' /usr/local/lib/pkgconfig/minizip-ng.pc

# zsign
RUN set -eux; \
  git clone https://github.com/zhlynn/zsign.git /tmp/zsign; \
  git -C /tmp/zsign checkout --detach "$ZSIGN_COMMIT"; \
  cd /tmp/zsign/build/linux; \
  sed -i 's/$(MINIZIP_LIB)/$(MINIZIP_LIB) -lz/' Makefile; \
  make clean && make; \
  strip ../../bin/zsign; \
  install -m 0755 ../../bin/zsign /usr/local/bin/zsign; \
  rm -rf /tmp/zsign

# Strip Swift debug symbols to save ~500MB
RUN find /usr/lib/swift -name "*.so" -exec strip --strip-debug {} \; 2>/dev/null || true; \
    find /usr/bin -name "swift*" -type f -exec strip --strip-debug {} \; 2>/dev/null || true


# ============================================================
# Stage 2: Final image — runtime only
# ============================================================
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:$PATH"
ENV THEOS=/opt/theos
ENV THEOS_MAKE_PATH=/opt/theos/makefiles

# Runtime deps — use runtime libs, not -dev packages where possible
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    # Swift runtime
    binutils libedit2 libxml2 libsqlite3-0 \
    libcurl4t64 tzdata libssl3 libncurses6 \
    # zsign runtime
    libplist-dev libzip-dev libminizip-dev \
    # xtool
    libfuse2 libz3-dev \
    # iOS device
    usbmuxd libimobiledevice-utils \
    # Essentials
    git curl ca-certificates python3-minimal \
    # SSH (Cursor Remote-SSH)
    openssh-server \
    && mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && rm -rf /tmp/* /var/tmp/*

# Copy Swift toolchain from official image (already compiled + optimized)
COPY --from=builder /usr/lib/swift /usr/lib/swift
COPY --from=builder /usr/libexec/swift /usr/libexec/swift
COPY --from=builder /usr/bin/swift* /usr/bin/
COPY --from=builder /usr/bin/sourcekit-lsp /usr/bin/
COPY --from=builder /usr/share/swift /usr/share/swift

# Copy our built tools
COPY --from=builder /usr/local/bin/zsign /usr/local/bin/zsign
COPY --from=builder /usr/local/lib/libminizip* /usr/local/lib/
COPY --from=builder /opt/xtool /opt/xtool

# Theos — just create the directory; installed at first onboard
# ponytail: moved out of build to avoid flaky GH API + saves ~500MB
RUN mkdir -p /opt/theos && chown vscode:vscode /opt/theos

# Onboarding + scripts
COPY .devcontainer/onboard.sh /usr/local/bin/onboard
COPY .devcontainer/configure-passwords.sh /usr/local/bin/configure-passwords
COPY .devcontainer/fetch-xcode.sh /usr/local/bin/fetch-xcode
COPY .devcontainer/install-theos.sh /usr/local/bin/install-theos
COPY .devcontainer/profile-onboard.sh /etc/profile.d/99-swift-dev-onboard.sh
RUN sed -i 's/\r$//' /usr/local/bin/onboard /usr/local/bin/configure-passwords \
    /usr/local/bin/fetch-xcode /usr/local/bin/install-theos \
    /etc/profile.d/99-swift-dev-onboard.sh \
  && chmod +x /usr/local/bin/onboard /usr/local/bin/configure-passwords \
    /usr/local/bin/fetch-xcode /usr/local/bin/install-theos

# Symlinks + permissions
RUN ln -sf /opt/xtool/AppRun /usr/local/bin/xtool \
  && chown -R vscode:vscode /opt/xtool \
  && ldconfig

# code-server (single layer)
RUN curl --fail --silent --show-error --location --retry 3 --retry-all-errors https://code-server.dev/install.sh \
    | VERSION="$CODE_SERVER_VERSION" sh \
  && code-server --install-extension sswg.swift-lang \
  && code-server --install-extension vadimcn.vscode-lldb \
  && rm -rf /tmp/* /root/.cache

# Config files and user-owned workspace defaults
RUN install -d -m 700 -o vscode -g vscode /home/vscode/.config/code-server \
  && install -d -o vscode -g vscode /home/vscode/.local/share/code-server/User \
  && printf '{\n  "swift.path": "/usr/bin/swift",\n  "editor.formatOnSave": true,\n  "editor.fontSize": 14,\n  "editor.tabSize": 2,\n  "workbench.colorTheme": "Default Dark Modern",\n  "terminal.integrated.defaultProfile.linux": "bash",\n  "files.autoSave": "afterDelay",\n  "files.autoSaveDelay": 1000\n}\n' \
     > /home/vscode/.local/share/code-server/User/settings.json \
  && chown -R vscode:vscode /home/vscode/.local/share/code-server \
  && chmod 600 /home/vscode/.local/share/code-server/User/settings.json

COPY .devcontainer/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
  && chmod +x /usr/local/bin/entrypoint.sh

# Environment
RUN printf '\nexport PATH="/usr/local/bin:$PATH"\nexport THEOS=/opt/theos\nexport THEOS_MAKE_PATH=/opt/theos/makefiles\n' >> /etc/bash.bashrc

# Sanity check
RUN swift --version && xtool --help && which zsign

EXPOSE 8080 22
USER root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
