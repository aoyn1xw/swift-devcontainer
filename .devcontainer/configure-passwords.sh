#!/usr/bin/env bash
# Apply and optionally prompt for code-server (and SSH) passwords.
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swift-devcontainer"
CODE_SERVER_CONFIG="${CODE_SERVER_CONFIG:-$HOME/.config/code-server/config.yaml}"
DEFAULT_CODE_SERVER_PASSWORD="CHANGE_ME_SET_CODE_SERVER_PASSWORD_ENV"
MIN_PASSWORD_LENGTH=8

if [[ -t 1 ]]; then
  BOLD='\033[1m' DIM='\033[2m' GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[36m' RESET='\033[0m'
else
  BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

password_is_valid() {
  local password="$1"
  [[ ${#password} -ge "$MIN_PASSWORD_LENGTH" ]] || return 1
  [[ "$password" != "$DEFAULT_CODE_SERVER_PASSWORD" ]] || return 1
  [[ "$password" != "changeme" ]] || return 1
}

write_code_server_config() {
  local password="$1"
  password_is_valid "$password" || return 1
  export CODE_SERVER_CONFIG
  CODE_SERVER_PASSWORD_VALUE="$password" python3 - <<'PY'
import os
import tempfile
from pathlib import Path

password = os.environ["CODE_SERVER_PASSWORD_VALUE"]
escaped = password.replace("\\", "\\\\").replace('"', '\\"')
path = Path(os.environ["CODE_SERVER_CONFIG"])
path.parent.mkdir(parents=True, exist_ok=True)
os.chmod(path.parent, 0o700)
fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
try:
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("\n".join([
            "bind-addr: 0.0.0.0:8080",
            "auth: password",
            f'password: "{escaped}"',
            "cert: false",
            "",
        ]))
    os.replace(temp_name, path)
    os.chmod(path, 0o600)
except BaseException:
    try:
        os.unlink(temp_name)
    except FileNotFoundError:
        pass
    raise
PY
}

read_code_server_password() {
  [[ -f "$CODE_SERVER_CONFIG" ]] || return 1
  export CODE_SERVER_CONFIG
  python3 - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["CODE_SERVER_CONFIG"])
for line in path.read_text(encoding="utf-8").splitlines():
    if line.startswith("password:"):
        value = line.split(":", 1)[1].strip()
        if value.startswith('"'):
            print(json.loads(value))
        else:
            print(value)
        break
else:
    raise SystemExit(1)
PY
}

is_code_server_password_configured() {
  if [[ -n "${CODE_SERVER_PASSWORD:-}" ]] && password_is_valid "$CODE_SERVER_PASSWORD"; then
    return 0
  fi
  local current=""
  current="$(read_code_server_password 2>/dev/null)" || return 1
  password_is_valid "$current"
}

mark_passwords_configured() {
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  date -Iseconds > "$STATE_DIR/passwords.configured"
  chmod 600 "$STATE_DIR/passwords.configured"
}

apply_env_code_server_password() {
  local password="${CODE_SERVER_PASSWORD:-}"
  [[ -n "$password" ]] || {
    printf '%sCODE_SERVER_PASSWORD is required and must be at least %d characters.%s\n' "$YELLOW" "$MIN_PASSWORD_LENGTH" "$RESET" >&2
    return 1
  }
  password_is_valid "$password" || {
    printf '%sCODE_SERVER_PASSWORD must be at least %d characters and cannot be a known default.%s\n' "$YELLOW" "$MIN_PASSWORD_LENGTH" "$RESET" >&2
    return 1
  }
  write_code_server_config "$password"
  mark_passwords_configured
}

prompt_code_server_password() {
  local required="${1:-false}"
  local password confirm

  cat <<EOF
${BOLD}code-server web password${RESET}
Used when you open the in-browser IDE at ${CYAN}http://localhost:8080${RESET}.
EOF

  while true; do
    printf 'New password (hidden, min %d chars): ' "$MIN_PASSWORD_LENGTH"
    read -rs password
    echo
    if [[ -z "$password" ]]; then
      if [[ "$required" == "true" ]] && ! is_code_server_password_configured; then
        printf '%sPlease choose a password — the default is not safe.%s\n' "$YELLOW" "$RESET"
        continue
      fi
      printf '%sKeeping current code-server password.%s\n' "$DIM" "$RESET"
      return 0
    fi
    if ! password_is_valid "$password"; then
      printf '%sUse at least %d characters and do not use a known default.%s\n' "$YELLOW" "$MIN_PASSWORD_LENGTH" "$RESET"
      continue
    fi
    printf 'Confirm password: '
    read -rs confirm
    echo
    if [[ "$password" != "$confirm" ]]; then
      printf '%sPasswords do not match. Try again.%s\n' "$YELLOW" "$RESET"
      continue
    fi
    write_code_server_config "$password"
    mark_passwords_configured
    printf '%s✓ code-server password updated.%s\n' "$GREEN" "$RESET"
    printf '%sRestart code-server if it is already running (e.g. docker compose restart).%s\n' "$DIM" "$RESET"
    return 0
  done
}

sshd_available() { command -v sshd >/dev/null 2>&1; }

prompt_ssh_password() {
  sshd_available || return 0
  cat <<EOF

${BOLD}SSH login password${RESET} (optional)
SSH is enabled in this container. Set a password for user ${BOLD}${USER}${RESET}
if you connect over SSH (port 2222 in many dev container setups).
EOF
  if ! ask_yes_no "Set SSH password for ${USER} now?" "n"; then
    printf '%sSkipped SSH password. Run %spasswd%s later if needed.%s\n' "$DIM" "$CYAN" "$RESET" "$RESET"
    return 0
  fi
  if passwd; then
    printf '%s✓ SSH password set for %s.%s\n' "$GREEN" "$USER" "$RESET"
  else
    printf '%sCould not set SSH password.%s\n' "$YELLOW" "$RESET"
  fi
}

ask_yes_no() {
  local prompt="$1" default="${2:-y}" hint choice
  if [[ "$default" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
  while true; do
    printf '%s [%s]: ' "$prompt" "$hint"
    read -r choice
    choice="${choice:-$default}"
    case "${choice,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf 'Please answer y or n.\n' ;;
    esac
  done
}

show_password_status() {
  if is_code_server_password_configured; then
    printf '%s✓ code-server password configured%s\n' "$GREEN" "$RESET"
  else
    printf '%s✗ code-server password is not configured%s\n' "$YELLOW" "$RESET"
  fi
  if sshd_available; then
    printf '%s• SSH available — set with %spasswd%s if needed%s\n' "$DIM" "$CYAN" "$RESET" "$RESET"
  fi
}

configure_passwords() {
  local mode="${1:-}"
  local required="false"
  [[ "${2:-}" == "--required" ]] && required="true"

  case "$mode" in
    --non-interactive)
      apply_env_code_server_password
      ;;
    --interactive)
      if [[ -n "${CODE_SERVER_PASSWORD:-}" ]]; then
        apply_env_code_server_password
        printf '%s✓ code-server password loaded from CODE_SERVER_PASSWORD.%s\n' "$GREEN" "$RESET"
      elif is_code_server_password_configured; then
        printf '%s✓ code-server password already configured.%s\n' "$GREEN" "$RESET"
        if ask_yes_no "Change code-server password anyway?" "n"; then
          prompt_code_server_password "$required"
        fi
      else
        printf '%sSet a code-server password (a known default is not safe).%s\n\n' "$YELLOW" "$RESET"
        prompt_code_server_password "$required"
      fi
      prompt_ssh_password
      ;;
    --status)
      show_password_status
      ;;
    *)
      printf 'Usage: configure-passwords [--non-interactive|--interactive|--status] [--required]\n' >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  mode="--non-interactive"
  required="false"
  for arg in "$@"; do
    case "$arg" in
      --non-interactive|--interactive|--status) mode="$arg" ;;
      --required) required="--required" ;;
      *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
    esac
  done
  configure_passwords "$mode" "$required"
fi
