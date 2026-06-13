#!/usr/bin/env bash
# Apply and optionally prompt for code-server (and SSH) passwords.
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swift-devcontainer"
CODE_SERVER_CONFIG="${CODE_SERVER_CONFIG:-$HOME/.config/code-server/config.yaml}"
DEFAULT_CODE_SERVER_PASSWORD="changeme"

if [[ -t 1 ]]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  CYAN='\033[36m'
  RESET='\033[0m'
else
  BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

write_code_server_config() {
  local password="$1"
  export CODE_SERVER_CONFIG
  CODE_SERVER_PASSWORD_VALUE="$password" python3 - <<'PY'
import os
from pathlib import Path

password = os.environ["CODE_SERVER_PASSWORD_VALUE"]
escaped = password.replace("\\", "\\\\").replace('"', '\\"')
path = Path(os.environ["CODE_SERVER_CONFIG"])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(
    "\n".join(
        [
            "bind-addr: 0.0.0.0:8080",
            "auth: password",
            f'password: "{escaped}"',
            "cert: false",
            "",
        ]
    ),
    encoding="utf-8",
)
PY
}

read_code_server_password() {
  [[ -f "$CODE_SERVER_CONFIG" ]] || return 1
  export CODE_SERVER_CONFIG
  python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["CODE_SERVER_CONFIG"])
if not path.is_file():
    raise SystemExit(1)
match = re.search(r'^password:\s*"?(.+?)"?\s*$', path.read_text(encoding="utf-8"), re.M)
if not match:
    raise SystemExit(1)
print(match.group(1).strip())
PY
}

is_code_server_password_default() {
  local current=""
  current="$(read_code_server_password 2>/dev/null)" || return 0
  [[ "$current" == "$DEFAULT_CODE_SERVER_PASSWORD" ]]
}

is_code_server_password_configured() {
  if [[ -f "$STATE_DIR/passwords.configured" ]]; then
    return 0
  fi
  if [[ -n "${CODE_SERVER_PASSWORD:-}" ]]; then
    return 0
  fi
  ! is_code_server_password_default
}

apply_env_code_server_password() {
  if [[ -n "${CODE_SERVER_PASSWORD:-}" ]]; then
    write_code_server_config "$CODE_SERVER_PASSWORD"
    mkdir -p "$STATE_DIR"
    date -Iseconds > "$STATE_DIR/passwords.configured"
    return 0
  fi
  return 1
}

mark_passwords_configured() {
  mkdir -p "$STATE_DIR"
  date -Iseconds > "$STATE_DIR/passwords.configured"
}

prompt_code_server_password() {
  local required="${1:-false}"
  local password confirm

  cat <<EOF
${BOLD}code-server web password${RESET}
Used when you open the in-browser IDE at ${CYAN}http://localhost:8080${RESET}.
EOF

  while true; do
    printf 'New password (hidden, min 8 chars): '
    read -rs password
    echo
    if [[ -z "$password" ]]; then
      if [[ "$required" == "true" ]] && is_code_server_password_default; then
        printf '%sPlease choose a password — the default %s is not safe.%s\n' \
          "$YELLOW" "$DEFAULT_CODE_SERVER_PASSWORD" "$RESET"
        continue
      fi
      printf '%sKeeping current code-server password.%s\n' "$DIM" "$RESET"
      return 0
    fi
    if [[ ${#password} -lt 8 ]]; then
      printf '%sUse at least 8 characters.%s\n' "$YELLOW" "$RESET"
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

sshd_available() {
  command -v sshd >/dev/null 2>&1
}

prompt_ssh_password() {
  if ! sshd_available; then
    return 0
  fi

  cat <<EOF

${BOLD}SSH login password${RESET} (optional)
SSH is enabled in this container. Set a password for user ${BOLD}${USER}${RESET}
if you connect over SSH (port 2222 in many dev container setups).
EOF

  if ! ask_yes_no "Set SSH password for ${USER} now?" "n"; then
    printf '%sSkipped SSH password. Run %spasswd%s later if needed.%s\n' \
      "$DIM" "$CYAN" "$RESET" "$RESET"
    return 0
  fi

  if passwd; then
    printf '%s✓ SSH password set for %s.%s\n' "$GREEN" "$USER" "$RESET"
  else
    printf '%sCould not set SSH password.%s\n' "$YELLOW" "$RESET"
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local hint choice

  if [[ "$default" == "y" ]]; then
    hint="Y/n"
  else
    hint="y/N"
  fi

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
  elif is_code_server_password_default; then
    printf '%s✗ code-server still uses default password (%s)%s\n' \
      "$YELLOW" "$DEFAULT_CODE_SERVER_PASSWORD" "$RESET"
  else
    printf '%s✓ code-server password set (custom)%s\n' "$GREEN" "$RESET"
  fi

  if sshd_available; then
    printf '%s• SSH available — set with %spasswd%s if needed%s\n' \
      "$DIM" "$CYAN" "$RESET" "$RESET"
  fi
}

configure_passwords() {
  local mode="${1:-}"
  local required="false"

  if [[ "${2:-}" == "--required" ]]; then
    required="true"
  fi

  apply_env_code_server_password || true

  case "$mode" in
    --non-interactive)
      return 0
      ;;
    --interactive)
      if is_code_server_password_configured; then
        if [[ -n "${CODE_SERVER_PASSWORD:-}" ]]; then
          printf '%s✓ code-server password loaded from CODE_SERVER_PASSWORD.%s\n' "$GREEN" "$RESET"
        else
          printf '%s✓ code-server password already configured.%s\n' "$GREEN" "$RESET"
        fi
        if ask_yes_no "Change code-server password anyway?" "n"; then
          prompt_code_server_password "false"
        fi
      else
        printf '%sSet a code-server password (default %s is insecure).%s\n\n' \
          "$YELLOW" "$DEFAULT_CODE_SERVER_PASSWORD" "$RESET"
        prompt_code_server_password "$required"
        if is_code_server_password_default; then
          printf '%sWarning: still using the default password.%s\n' "$YELLOW" "$RESET"
          return 1
        fi
      fi
      prompt_ssh_password
      ;;
    --status)
      show_password_status
      ;;
    *)
      printf 'Usage: configure-passwords [--non-interactive|--interactive|--status]\n' >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  export CODE_SERVER_CONFIG
  mode="--non-interactive"
  required="false"
  for arg in "$@"; do
    case "$arg" in
      --non-interactive|--interactive|--status)
        mode="$arg"
        ;;
      --required)
        required="true"
        ;;
    esac
  done
  if [[ "$mode" == "--status" ]]; then
    configure_passwords --status
  else
    configure_passwords "$mode" "$required"
  fi
fi
