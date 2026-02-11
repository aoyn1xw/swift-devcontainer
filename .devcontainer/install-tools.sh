#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

jobs="$(nproc)"
prefix="/usr/local"
build="/tmp/build"
swiftly_home="/usr/local/share/swiftly"

mkdir -p "$build"
cd "$build"

# Install swiftly
echo "=== Installing swiftly ==="
curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
tar zxf "swiftly-$(uname -m).tar.gz"
install -m 0755 swiftly "$prefix/bin/swiftly"

# Initialize swiftly
echo "=== Initializing swiftly ==="
SWIFTLY_HOME_DIR="$swiftly_home" SWIFTLY_BIN_DIR="$prefix/bin" "$prefix/bin/swiftly" init --quiet-shell-followup

# Set up PATH for Swift (swiftly puts Swift in ~/.local/bin or swiftly home)
export PATH="$swiftly_home/bin:$prefix/bin:$PATH"

# Install Swift
echo "=== Installing Swift ==="
"$prefix/bin/swiftly" install latest --use

# Add Swift to system-wide PATH
cat >> /etc/bash.bashrc <<'EOF'

# Swift environment (swiftly)
export SWIFTLY_HOME_DIR="/usr/local/share/swiftly"
export PATH="$SWIFTLY_HOME_DIR/bin:/usr/local/bin:$PATH"
if [ -f "$SWIFTLY_HOME_DIR/env.sh" ]; then
  . "$SWIFTLY_HOME_DIR/env.sh"
fi
EOF

cat > /etc/profile.d/swiftly.sh <<'EOF'
export SWIFTLY_HOME_DIR="/usr/local/share/swiftly"
export PATH="$SWIFTLY_HOME_DIR/bin:/usr/local/bin:$PATH"
if [ -f "$SWIFTLY_HOME_DIR/env.sh" ]; then
  . "$SWIFTLY_HOME_DIR/env.sh"
fi
EOF

# Source the environment for current shell
if [ -f "$swiftly_home/env.sh" ]; then
  . "$swiftly_home/env.sh"
fi

# Verify Swift is available
echo "=== Verifying Swift installation ==="
which swift || echo "WARNING: swift not found in PATH"
swift --version || echo "WARNING: swift command failed"

# Verify Swift is available
echo "=== Verifying Swift installation ==="
which swift || echo "WARNING: swift not found in PATH"
swift --version || echo "WARNING: swift command failed"

# Build and install xtool
echo "=== Building xtool ==="
git clone --depth 1 --branch "v1.16.1" https://github.com/xtool-org/xtool.git xtool
cd xtool
swift build -c release -j "$jobs"
install -m 0755 .build/release/xtool "$prefix/bin/xtool"
cd "$build"
rm -rf xtool

# Build and install zsign
echo "=== Building zsign ==="
git clone --depth 1 --branch "v0.7" https://github.com/zhlynn/zsign.git zsign
cd zsign/build/linux
make clean || true
make -j "$jobs"
install -m 0755 zsign "$prefix/bin/zsign"
cd "$build"
rm -rf zsign

# Cleanup
rm -rf "$build"

echo "=== INSTALLATION COMPLETE ==="
echo "Installed binaries:"
ls -lh /usr/local/bin/{swift,xtool,zsign,swiftly} 2>/dev/null || echo "Some binaries may not be installed"

