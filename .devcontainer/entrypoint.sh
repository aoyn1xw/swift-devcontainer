#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  exec "$@"
fi

export HOME="/home/vscode"
export USER="vscode"
export CODE_SERVER_CONFIG="${CODE_SERVER_CONFIG:-/home/vscode/.config/code-server/config.yaml}"

install -d -m 700 -o vscode -g vscode /home/vscode/.config/code-server
install -d -o vscode -g vscode /home/vscode/project

# Run as vscode so config.yaml / state files are not created root-owned
runuser -u vscode -- env CODE_SERVER_CONFIG="$CODE_SERVER_CONFIG" HOME="$HOME" \
  /usr/local/bin/configure-passwords --non-interactive

if [[ "${START_SSHD:-0}" == "1" ]]; then
  install -d -m 755 /run/sshd
  ssh-keygen -A >/dev/null 2>&1 || true
  /usr/sbin/sshd -t
  /usr/sbin/sshd
fi

echo "================================================"
echo "  Swift iOS Dev Environment"
echo "  code-server: http://0.0.0.0:8080"
if [[ "${START_SSHD:-0}" == "1" ]]; then
  echo "  SSH: port 22 (map host port as needed)"
fi
echo "================================================"

exec runuser -u vscode -- code-server --bind-addr 0.0.0.0:8080 --auth password
