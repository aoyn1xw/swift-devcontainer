FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
  git curl ca-certificates tar xz-utils \
  build-essential g++ pkg-config \
  cmake ninja-build \
  libssl-dev libminizip-dev \
  && rm -rf /var/lib/apt/lists/*

# Force rebuild from here - updated 2026-02-11
COPY install-tools.sh /usr/local/bin/install-tools.sh

RUN chmod +x /usr/local/bin/install-tools.sh \
 && /usr/local/bin/install-tools.sh
