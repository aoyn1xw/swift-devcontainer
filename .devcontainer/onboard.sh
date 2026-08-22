#!/usr/bin/env bash
# Interactive first-run setup for the Swift iOS dev environment.
# Lets users pick what to configure and skip what they don't need.
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swift-devcontainer"
MARKER_FILE="$STATE_DIR/onboarding.complete"
LOCK_FILE="$STATE_DIR/.onboard.lock"
CHOICES_FILE="$STATE_DIR/onboard.choices"

# shellcheck source=/dev/null
if [[ -f /usr/local/bin/configure-passwords ]]; then
  source /usr/local/bin/configure-passwords
else
  is_code_server_password_configured() {
    [[ -n "${CODE_SERVER_PASSWORD:-}" ]] || [[ -f "$STATE_DIR/passwords.configured" ]]
  }
fi

# --- Colors ---
if [[ -t 1 ]]; then
  BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'
  GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[36m' RED='\033[31m'
  BG_CYAN='\033[46m\033[30m' BG_GREEN='\033[42m\033[30m'
else
  BOLD='' DIM='' RESET='' GREEN='' YELLOW='' CYAN='' RED='' BG_CYAN='' BG_GREEN=''
fi

# --- Helpers ---
usage() {
  cat <<'EOF'
Usage: onboard [options]

Interactive setup for Swift iOS dev environment.

Options:
  --if-needed   Run only when onboarding is not complete
  --reset       Clear all choices and start fresh
  --status      Show what is configured and exit
  --quick       Non-interactive: configure passwords + verify tools only
  -h, --help    Show this help

Components you can configure:
  - Security: code-server password, SSH password
  - Toolchain: Swift, xtool, zsign, Theos verification
  - iOS SDK: xtool setup with Apple account + Xcode.xip
  - Xcode: download Xcode.xip via fetch-xcode
EOF
}

banner() {
  printf '\n'
  printf '%s%s ╭─────────────────────────────────────────────────╮ %s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s │   Swift iOS Dev Environment                     │ %s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s │   Build & sign iOS apps on Linux — no Mac needed│ %s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s ╰─────────────────────────────────────────────────╯ %s\n' "$BOLD" "$CYAN" "$RESET"
  printf '\n'
}

divider() {
  printf '%s──────────────────────────────────────────────────────%s\n' "$DIM" "$RESET"
}

section() {
  printf '\n%s%s %s %s\n' "$BG_CYAN" "$BOLD" " $1 " "$RESET"
  printf '\n'
}

success() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
info()    { printf '  %s→%s %s\n' "$CYAN" "$RESET" "$1"; }
fail()    { printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; }

pause() {
  printf '\n%s  Press Enter to continue...%s ' "$DIM" "$RESET"
  read -r _
}

ask_yes_no() {
  local prompt="$1" default="${2:-y}" hint choice
  [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
  while true; do
    printf '  %s [%s]: ' "$prompt" "$hint"
    read -r choice
    choice="${choice:-$default}"
    case "${choice,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf '  Please answer y or n.\n' ;;
    esac
  done
}

# Multi-select menu: pick from numbered options
# Usage: pick_components "prompt" options[@] defaults[@] -> sets PICKED array
pick_components() {
  local prompt="$1"
  local -n opts=$2
  local -n defs=$3
  local -a selected=("${defs[@]}")
  local count=${#opts[@]}

  printf '  %s%s%s\n\n' "$BOLD" "$prompt" "$RESET"

  while true; do
    for i in "${!opts[@]}"; do
      local mark=" "
      [[ "${selected[$i]}" == "1" ]] && mark="${GREEN}*${RESET}"
      printf '    %s[%s]%s %s%d%s) %s\n' "$DIM" "$mark" "$RESET" "$BOLD" $((i+1)) "$RESET" "${opts[$i]}"
    done
    printf '\n'
    printf '  %sToggle with number, %sA%s=all, %sN%s=none, %sEnter%s=confirm:%s ' \
      "$DIM" "$BOLD" "$DIM" "$BOLD" "$DIM" "$BOLD" "$DIM" "$RESET"
    read -r input

    case "${input,,}" in
      "") break ;;
      a|all) for i in "${!selected[@]}"; do selected[$i]=1; done ;;
      n|none) for i in "${!selected[@]}"; do selected[$i]=0; done ;;
      *)
        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= count )); then
          local idx=$((input - 1))
          [[ "${selected[$idx]}" == "1" ]] && selected[$idx]=0 || selected[$idx]=1
        fi
        ;;
    esac
    # Clear menu for redraw
    for (( j=0; j<count+3; j++ )); do printf '\033[A\033[2K'; done
  done

  PICKED=("${selected[@]}")
}

# --- State ---
save_choices() {
  mkdir -p "$STATE_DIR"
  printf '%s\n' "${PICKED[@]}" > "$CHOICES_FILE"
}

load_choices() {
  PICKED=()
  if [[ -f "$CHOICES_FILE" ]]; then
    while IFS= read -r line; do PICKED+=("$line"); done < "$CHOICES_FILE"
  fi
}

is_xtool_configured() {
  swift sdk list 2>/dev/null | grep -qw darwin
}

is_onboarding_complete() {
  [[ -f "$MARKER_FILE" ]] || return 1
  is_code_server_password_configured || return 1
  swift --version >/dev/null 2>&1 || return 1
  xtool --help >/dev/null 2>&1 || return 1
  zsign -h >/dev/null 2>&1
}

count_selected() {
  local total=0 p
  for p in "$@"; do
    if (( p )); then
      (( total += 1 ))
    fi
  done
  printf '%s\n' "$total"
}

mark_complete() {
  mkdir -p "$STATE_DIR"
  date -Iseconds > "$MARKER_FILE"
}

clear_state() {
  rm -f "$MARKER_FILE" "$CHOICES_FILE"
}

# --- Steps ---
step_security() {
  section "Security Setup"

  if declare -F configure_passwords >/dev/null 2>&1; then
    if ! configure_passwords --interactive --required; then
      warn "Password setup incomplete. Run ${CYAN}onboard${RESET} again to continue."
      return 1
    fi
  else
    warn "configure-passwords not available in this environment."
  fi
}

step_verify_toolchain() {
  section "Toolchain Verification"

  local all_ok=true

  if swift --version >/dev/null 2>&1; then
    success "Swift $(swift --version 2>&1 | head -1 | grep -oP '[\d.]+')"
  else
    fail "Swift not found"; all_ok=false
  fi

  if xtool --help >/dev/null 2>&1; then
    success "xtool installed"
  else
    fail "xtool not found"; all_ok=false
  fi

  if command -v zsign >/dev/null 2>&1; then
    success "zsign available"
  else
    fail "zsign not found"; all_ok=false
  fi

  if [[ -d "${THEOS:-/opt/theos}/makefiles" ]]; then
    success "Theos at ${THEOS:-/opt/theos}"
  else
    warn "Theos not installed (run ${CYAN}install-theos${RESET})"
  fi

  if [[ "$all_ok" == true ]]; then
    success "All core tools ready"
    return 0
  fi
  warn "Some tools missing"
  return 1
}

step_install_theos() {
  section "Install Theos"

  if [[ -d "${THEOS:-/opt/theos}/makefiles" ]]; then
    success "Theos already installed"
    return 0
  fi

  info "Theos lets you build iOS tweaks and apps."
  info "Downloads ~400MB (toolchain + SDKs)."
  printf '\n'

  if ! ask_yes_no "Install Theos now?" "y"; then
    info "Skipped. Run ${CYAN}install-theos${RESET} later."
    return 0
  fi

  install-theos
}

step_fetch_xcode() {
  section "Download Xcode.xip"

  info "Xcode.xip is needed for the iOS SDK (~7-12 GB download)."
  printf '\n'

  local xip_path=""
  xip_path="$(find "$HOME" -maxdepth 2 -name 'Xcode*.xip' 2>/dev/null | head -1)"

  if [[ -n "$xip_path" ]]; then
    success "Found existing: ${xip_path}"
    if ! ask_yes_no "Download a new one anyway?" "n"; then
      return 0
    fi
  fi

  info "Options:"
  printf '    %s1%s) Auto-download latest stable (fetch-xcode)\n' "$BOLD" "$RESET"
  printf '    %s2%s) Pick a specific version\n' "$BOLD" "$RESET"
  printf '    %s3%s) Skip — I already have one / will get it later\n' "$BOLD" "$RESET"
  printf '\n'
  printf '  Choice [1/2/3]: '
  read -r choice

  case "$choice" in
    1) fetch-xcode ;;
    2)
      fetch-xcode --list
      printf '\n  Version number (e.g. 16.3): '
      read -r ver
      [[ -n "$ver" ]] && fetch-xcode --version "$ver"
      ;;
    3) info "Skipped. Run ${CYAN}fetch-xcode${RESET} when ready." ;;
    *) info "Skipped." ;;
  esac
}

step_xtool_setup() {
  section "iOS SDK Setup (xtool)"

  if is_xtool_configured; then
    success "iOS SDK already installed:"
    swift sdk list 2>/dev/null | sed 's/^/    /'
    return 0
  fi

  info "xtool setup will:"
  printf '    • Sign in with your Apple Developer account\n'
  printf '    • Point to your Xcode.xip file\n'
  printf '    • Extract and install the iOS Swift SDK\n'
  printf '\n'

  if ! ask_yes_no "Run xtool setup now?" "y"; then
    info "Skipped. Run ${CYAN}xtool setup${RESET} when ready."
    return 0
  fi

  printf '\n'
  info "Starting xtool setup — follow the prompts..."
  printf '\n'
  xtool setup

  if is_xtool_configured; then
    printf '\n'
    success "iOS SDK installed!"
    swift sdk list 2>/dev/null | sed 's/^/    /'
  else
    warn "Setup didn't complete. Run ${CYAN}onboard${RESET} again when ready."
  fi
}

step_next_steps() {
  section "Quick Reference"

  cat <<EOF
  ${BOLD}Create a new iOS app:${RESET}
    ${CYAN}xtool new MyApp && cd MyApp && xtool dev${RESET}

  ${BOLD}Build Swift for iOS:${RESET}
    ${CYAN}swift build --swift-sdk arm64-apple-ios${RESET}

  ${BOLD}Sign an IPA:${RESET}
    ${CYAN}zsign -k cert.p12 -p pass -m profile.mobileprovision -o out.ipa in.ipa${RESET}

  ${BOLD}Create a Theos tweak:${RESET}
    ${CYAN}\$THEOS/bin/nic.pl${RESET}

  ${BOLD}Check status anytime:${RESET}
    ${CYAN}onboard --status${RESET}

EOF
}

step_finish() {
  mark_complete
  divider
  printf '\n  %s%s Setup complete! %s\n\n' "$BG_GREEN" "$BOLD" "$RESET"
  printf '  Re-run:  %sonboard --reset%s\n' "$CYAN" "$RESET"
  printf '  Status:  %sonboard --status%s\n' "$CYAN" "$RESET"
  printf '  Skip:    %sexport SKIP_ONBOARDING=1%s\n\n' "$CYAN" "$RESET"
}

# --- Status ---
show_status() {
  banner
  printf '  %sSetup Status%s\n\n' "$BOLD" "$RESET"

  if declare -F show_password_status >/dev/null 2>&1; then
    show_password_status | sed 's/^/  /'
    echo
  fi

  if swift --version >/dev/null 2>&1; then
    success "Swift $(swift --version 2>&1 | head -1 | grep -oP '[\d.]+')"
  else fail "Swift"; fi

  if xtool --help >/dev/null 2>&1; then success "xtool"; else fail "xtool"; fi
  if command -v zsign >/dev/null 2>&1; then success "zsign"; else fail "zsign"; fi
  if [[ -d "${THEOS:-/opt/theos}/makefiles" ]]; then success "Theos"; else warn "Theos not installed (run ${CYAN}install-theos${RESET})"; fi

  echo
  if is_xtool_configured; then
    success "iOS SDK installed"
    swift sdk list 2>/dev/null | sed 's/^/      /'
  else
    warn "iOS SDK not configured — run ${CYAN}onboard${RESET}"
  fi

  echo
  if is_onboarding_complete; then
    printf '  %s%s Onboarding complete %s\n\n' "$BG_GREEN" "$BOLD" "$RESET"
  else
    printf '  %sOnboarding incomplete.%s Run %sonboard%s to continue.\n\n' "$YELLOW" "$RESET" "$CYAN" "$RESET"
  fi
}

# --- Main flow ---
run_onboarding() {
  banner

  info "Welcome! Let's configure your environment."
  printf '  %sYou can skip anything and come back later with %sonboard%s\n\n' "$DIM" "$CYAN" "$RESET"
  divider

  # Component selection
  local components=("Security (code-server & SSH passwords)"
                    "Verify toolchain (Swift, xtool, zsign)"
                    "Install Theos (iOS tweak toolkit, ~400MB)"
                    "Download Xcode.xip"
                    "iOS SDK setup (xtool setup — needs Apple account)"
                    "Show quick-reference commands")
  local defaults=(1 1 1 1 1 1)

  pick_components "What would you like to set up?" components defaults
  save_choices

  local step=0 total=0
  total="$(count_selected "${PICKED[@]}")"

  if (( total == 0 )); then
    info "Nothing selected. Run ${CYAN}onboard${RESET} anytime to configure."
    return 0
  fi

  # Run selected steps
  if [[ "${PICKED[0]}" == "1" ]]; then
    (( step += 1 ))
    step_security || return 1
  fi

  if [[ "${PICKED[1]}" == "1" ]]; then
    (( step += 1 ))
    step_verify_toolchain || return 1
  fi

  if [[ "${PICKED[2]}" == "1" ]]; then
    (( step += 1 ))
    step_install_theos
  fi

  if [[ "${PICKED[3]}" == "1" ]]; then
    (( step += 1 ))
    step_fetch_xcode
  fi

  if [[ "${PICKED[4]}" == "1" ]]; then
    (( step += 1 ))
    step_xtool_setup
  fi

  if [[ "${PICKED[5]}" == "1" ]]; then
    (( step += 1 ))
    step_next_steps
  fi

  if ! is_code_server_password_configured; then
    warn "A valid code-server password is required before setup can complete."
    return 1
  fi
  step_finish
}

run_quick() {
  banner
  info "Quick setup: passwords + toolchain verification"
  divider

  step_security || return 1
  step_verify_toolchain || return 1
  if ! is_code_server_password_configured; then
    warn "A valid code-server password is required before quick setup can complete."
    return 1
  fi
  mark_complete
  printf '\n  %sDone.%s Run %sonboard%s for full interactive setup.\n\n' "$GREEN" "$RESET" "$CYAN" "$RESET"
}

with_lock() {
  mkdir -p "$STATE_DIR"
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    exit 0
  fi
  "$@"
}

main() {
  local mode="run"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --if-needed) mode="if-needed"; shift ;;
      --reset)     mode="reset"; shift ;;
      --status)    show_status; exit 0 ;;
      --quick)     mode="quick"; shift ;;
      -h|--help)   usage; exit 0 ;;
      *)           printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
  done

  case "$mode" in
    if-needed)
      [[ "${SKIP_ONBOARDING:-}" == "1" ]] && exit 0
      is_onboarding_complete && exit 0
      if [[ ! -t 0 ]]; then
        cat <<EOF

${BOLD}Swift iOS Dev Environment — first-time setup${RESET}

Open a terminal and run: ${CYAN}onboard${RESET}

Pick which components to configure — passwords, toolchain, iOS SDK, etc.
Status: ${CYAN}onboard --status${RESET}

EOF
        exit 0
      fi
      with_lock run_onboarding
      ;;
    reset)
      clear_state
      with_lock run_onboarding
      ;;
    quick)
      with_lock run_quick
      ;;
    run)
      with_lock run_onboarding
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
