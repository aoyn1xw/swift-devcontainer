#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_status() {
  local expected="$1"
  shift
  set +e
  "$@" >/tmp/swift-devcontainer-test.out 2>/tmp/swift-devcontainer-test.err
  local actual=$?
  set -e
  if [[ "$actual" -ne "$expected" ]]; then
    cat /tmp/swift-devcontainer-test.out /tmp/swift-devcontainer-test.err >&2 || true
    printf 'Expected exit %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

printf 'Testing shell syntax...\n'
for script in "$ROOT_DIR"/.devcontainer/*.sh; do
  bash -n "$script"
done

printf 'Testing onboarding selection counter...\n'
count_result="$(bash -c 'source "$1"; count_selected 1 1 1 0 1' bash "$ROOT_DIR/.devcontainer/onboard.sh")"
[[ "$count_result" == "4" ]]

printf 'Testing password failure when unset...\n'
assert_status 1 env HOME="$TMP_DIR/home" CODE_SERVER_CONFIG="$TMP_DIR/home/.config/code-server/config.yaml" \
  env -u CODE_SERVER_PASSWORD bash "$ROOT_DIR/.devcontainer/configure-passwords.sh" --non-interactive

printf 'Testing password validation and permissions...\n'
mkdir -p "$TMP_DIR/home/.config/code-server"
HOME="$TMP_DIR/home" CODE_SERVER_CONFIG="$TMP_DIR/home/.config/code-server/config.yaml" \
  CODE_SERVER_PASSWORD='safe-test-password' bash "$ROOT_DIR/.devcontainer/configure-passwords.sh" --non-interactive
[[ "$(stat -c '%a' "$TMP_DIR/home/.config/code-server/config.yaml")" == "600" ]]
[[ "$(grep '^password:' "$TMP_DIR/home/.config/code-server/config.yaml")" == 'password: "safe-test-password"' ]]

printf 'Testing known-default rejection...\n'
assert_status 1 env HOME="$TMP_DIR/home2" CODE_SERVER_CONFIG="$TMP_DIR/home2/config.yaml" \
  CODE_SERVER_PASSWORD='changeme' bash "$ROOT_DIR/.devcontainer/configure-passwords.sh" --non-interactive

printf 'Testing fetch-xcode list parsing with a fixture...\n'
cat > "$TMP_DIR/releases.json" <<'JSON'
[{"_versionOrder": 2, "version": {"number": "16.3", "release": {"release": true}}, "date": {"year": 2025, "month": 4, "day": 1}, "checksums": {"sha1": "0123456789012345678901234567890123456789"}, "links": {"download": {"url": "https://download.developer.apple.com/Developer_Tools/Xcode_16.3/Xcode_16.3.xip"}}}]
JSON
XCODE_RELEASES_API_URL="file://$TMP_DIR/releases.json" bash "$ROOT_DIR/.devcontainer/fetch-xcode.sh" --list | grep -F '16.3'

printf 'Testing entrypoint command passthrough...\n'
bash "$ROOT_DIR/.devcontainer/entrypoint.sh" true

printf 'All script tests passed.\n'
