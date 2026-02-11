#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

jobs="$(nproc)"
prefix="/usr/local"
build="/tmp/build"
swiftly_home="/usr/local/share/swiftly"

mkdir -p "$build"
cd "$build"

curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
tar zxf "swiftly-$(uname -m).tar.gz"

install -m 0755 swiftly "$prefix/bin/swiftly"

SWIFTLY_HOME_DIR="$swiftly_home" SWIFTLY_BIN_DIR="$prefix/bin" "$prefix/bin/swiftly" init --quiet-shell-followup

cat > /etc/profile.d/swiftly.sh <<EOF
if [ -f "$swiftly_home/env.sh" ]; then
  . "$swiftly_home/env.sh"
fi
EOF

. "$swiftly_home/env.sh"
swiftly install latest --use

# Also add to vscode user's bashrc for non-login shells
if [ -d "/home/vscode" ]; then
  echo 'source /usr/local/share/swiftly/env.sh' >> /home/vscode/.bashrc
fi

git clone --depth 1 --branch "v1.16.1" https://github.com/xtool-org/xtool.git xtool
cd xtool
swift build -c release -j "$jobs"
install -m 0755 .build/release/xtool "$prefix/bin/xtool"
cd "$build"
rm -rf xtool

git clone --depth 1 --branch "v0.7" https://github.com/zhlynn/zsign.git zsign
cd zsign/build/linux
make clean || true
make -j "$jobs"
install -m 0755 zsign "$prefix/bin/zsign"
cd "$build"
rm -rf zsign

rm -rf "$build"

echo "=== INSTALLED BINARIES ==="
ls -l /usr/local/bin | grep -E 'xtool|zsign|swift' || exit 1

