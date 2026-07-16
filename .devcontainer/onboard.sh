#!/usr/bin/env bash
# Interactive first-run guide for the Swift iOS dev environment.
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swift-devcontainer"
MARKER_FILE="$STATE_DIR/onboarding.complete"
LOCK_FILE="$STATE_DIR/.onboard.lock"

# shellcheck source=/dev/null
if [[ -f /usr/local/bin/configure-passwords ]]; then
  source /usr/local/bin/configure-passwords
else
  is_code_server_password_configured() {
    [[ -n "${CODE_SERVER_PASSWORD:-}" ]] || [[ -f "$STATE_DIR/passwords.configured" ]]
  }
fi

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

usage() {
  cat <<'EOF'
Usage: onboard [options]

Walk through first-time setup for Swift, xtool, zsign, and Theos.

Options:
  --if-needed   Run only when onboarding is not complete (default for auto-start)
  --reset       Clear completion marker and run from the beginning
  --status      Show what is configured and exit
  -h, --help    Show this help
EOF
}

log_step() {
  printf '\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$CYAN" "$RESET"
  printf '%sStep %s/%s — %s%s\n' "$BOLD" "$1" "$TOTAL_STEPS" "$2" "$RESET"
  printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n' "$CYAN" "$RESET"
}

pause() {
  printf '%sPress Enter to continue...%s ' "$DIM" "$RESET"
  read -r _
}

run_checked() {
  local label="$1"
  shift
  printf '%s$ %s%s\n' "$DIM" "$*" "$RESET"
  if "$@"; then
    printf '%s✓ %s%s\n' "$GREEN" "$label" "$RESET"
    return 0
  fi
  printf '%s✗ %s failed%s\n' "$YELLOW" "$label" "$RESET"
  return 1
}

is_xtool_configured() {
  swift sdk list 2>/dev/null | grep -qw darwin
}

is_onboarding_complete() {
  [[ -f "$MARKER_FILE" ]] && is_xtool_configured && is_code_server_password_configured
}

mark_complete() {
  mkdir -p "$STATE_DIR"
  date -Iseconds > "$MARKER_FILE"
}

clear_marker() {
  rm -f "$MARKER_FILE"
}

show_status() {
  printf '%sSwift iOS Dev Environment — setup status%s\n\n' "$BOLD" "$RESET"

  if declare -F show_password_status >/dev/null 2>&1; then
    show_password_status
    echo
  fi

  if run_checked "Swift toolchain" swift --version; then true; else false; fi
  if run_checked "xtool CLI" xtool --help >/dev/null; then true; else false; fi
  if run_checked "zsign" zsign -h >/dev/null 2>&1; then true; else false; fi
  if [[ -d "${THEOS:-/opt/theos}" ]]; then
    printf '%s✓ Theos at %s%s\n' "$GREEN" "${THEOS:-/opt/theos}" "$RESET"
  else
    printf '%s✗ Theos not found%s\n' "$YELLOW" "$RESET"
  fi

  if is_xtool_configured; then
    printf '%s✓ iOS Swift SDK (darwin) installed%s\n' "$GREEN" "$RESET"
    swift sdk list 2>/dev/null | sed 's/^/    /'
  else
    printf '%s✗ iOS Swift SDK not configured yet — run %sonboard%s\n' "$YELLOW" "$CYAN" "$RESET"
  fi

  if is_onboarding_complete; then
    printf '\n%sOnboarding complete.%s\n' "$GREEN" "$RESET"
  else
    printf '\n%sOnboarding incomplete.%s Run %sonboard%s to continue.\n' "$YELLOW" "$RESET" "$CYAN" "$RESET"
  fi
}

with_lock() {
  mkdir -p "$STATE_DIR"
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    exit 0
  fi
  "$@"
}

step_welcome() {
  log_step 1 "Welcome"
  cat <<EOF
This environment lets you build and sign iOS apps on Linux — no Mac required.

You'll walk through:
  1. Set a secure ${BOLD}code-server${RESET} password (and optional SSH password)
  2. Verify the pre-installed toolchain (Swift, xtool, zsign, Theos)
  3. Run ${BOLD}xtool setup${RESET} (Apple login + Xcode.xip for the iOS SDK)
  4. Learn the usual next commands for building and deploying

${DIM}Tip: run ${RESET}onboard --status${DIM} anytime to check progress.${RESET}
EOF
  pause
}

step_configure_passwords() {
  log_step 2 "Configure passwords"
  cat <<EOF
${BOLD}code-server${RESET} protects the in-browser IDE on port ${BOLD}8080${RESET}.
You can also set ${BOLD}CODE_SERVER_PASSWORD${RESET} in a ${BOLD}.env${RESET} file before starting Docker Compose.

If SSH is enabled, you can optionally set a login password for user ${BOLD}${USER}${RESET}.
EOF

  if declare -F configure_passwords >/dev/null 2>&1; then
    if ! configure_passwords --interactive "true"; then
      printf '\n%sPassword setup incomplete.%s Run %sonboard%s again to continue.\n' \
        "$YELLOW" "$RESET" "$CYAN" "$RESET"
      exit 0
    fi
  else
    printf '%sconfigure-passwords is not installed in this environment.%s\n' "$YELLOW" "$RESET"
    exit 0
  fi

  pause
}

step_verify_toolchain() {
  log_step 3 "Verify pre-installed tools"
  printf 'These were baked into the image at build time:\n\n'

  run_checked "Swift" swift --version || true
  echo
  run_checked "xtool" xtool --help >/dev/null || true
  echo
  run_checked "zsign" zsign -h >/dev/null 2>&1 || true
  echo
  if [[ -d "${THEOS:-/opt/theos}" ]]; then
    printf '%s✓ Theos at %s%s\n' "$GREEN" "${THEOS:-/opt/theos}" "$RESET"
    ls "${THEOS:-/opt/theos}" | head -5 | sed 's/^/    /'
  fi

  pause
}

step_xtool_prerequisites() {
  log_step 4 "Prepare for xtool setup"
  cat <<EOF
${BOLD}xtool setup${RESET} is interactive and needs two things from you:

  ${BOLD}1. Apple Developer account${RESET}
     Free or paid — used only to talk to Apple's services.

  ${BOLD}2. Xcode.xip${RESET}
     Use the built-in downloader (fetches latest automatically):
       ${CYAN}fetch-xcode${RESET}

     Or download manually from Apple:
       https://developer.apple.com/download/all/

     Run ${CYAN}fetch-xcode --list${RESET} to see available versions.

${YELLOW}The SDK extraction can take several minutes and uses a lot of disk space.${RESET}
EOF
  pause
}

step_xtool_setup() {
  log_step 5 "Run xtool setup"
  cat <<EOF
${BOLD}xtool setup${RESET} will:
  • Authenticate with your Apple Developer account
  • Ask for the path to your ${BOLD}Xcode.xip${RESET} file
  • Extract and install the iOS Swift SDK (shows up as ${BOLD}darwin${RESET})

If you are not ready yet, you can skip and run ${BOLD}onboard${RESET} again later.
EOF

  if is_xtool_configured; then
    printf '\n%s✓ iOS SDK already configured:%s\n' "$GREEN" "$RESET"
    swift sdk list 2>/dev/null | sed 's/^/    /'
    pause
    return 0
  fi

  if ask_yes_no "Run xtool setup now?" "y"; then
    echo
    printf '%sStarting xtool setup (follow the prompts)...%s\n\n' "$CYAN" "$RESET"
    xtool setup
    echo
    if is_xtool_configured; then
      printf '%s✓ iOS SDK installed:%s\n' "$GREEN" "$RESET"
      swift sdk list 2>/dev/null | sed 's/^/    /'
    else
      printf '%sSetup did not finish yet.%s Run %sonboard%s again when you have your Xcode.xip ready.\n' \
        "$YELLOW" "$RESET" "$CYAN" "$RESET"
      exit 0
    fi
  else
    printf '\n%sSkipped.%s Run %sonboard%s when you are ready.\n' "$YELLOW" "$RESET" "$CYAN" "$RESET"
    exit 0
  fi

  pause
}

step_next_steps() {
  log_step 6 "You're ready — common next commands"
  cat <<EOF
${BOLD}Create a new iOS app project${RESET}
  xtool new MyApp
  cd MyApp
  xtool dev

${BOLD}Build an existing Swift package for iOS${RESET}
  swift build --swift-sdk arm64-apple-ios

${BOLD}Sign an IPA${RESET}
  zsign -k cert.p12 -p password -m profile.mobileprovision -o signed.ipa unsigned.ipa

${BOLD}Theos tweak / app${RESET}
  \$THEOS/bin/nic.pl

${BOLD}Connect a physical device (Linux host)${RESET}
  usbmuxd should already be available in this image.
  Plug in your device, then: xtool devices

${DIM}Docs: https://xtool.sh/documentation/xtooldocs/installation-linux${RESET}
EOF
  pause
}

step_finish() {
  log_step 7 "All set"
  mark_complete
  cat <<EOF
${GREEN}Onboarding complete.${RESET}

  • Check status anytime: ${BOLD}onboard --status${RESET}
  • Re-run the guide:      ${BOLD}onboard --reset${RESET}
  • Skip auto-start:       ${BOLD}export SKIP_ONBOARDING=1${RESET}

Happy building.
EOF
}

run_onboarding() {
  TOTAL_STEPS=7
  step_welcome
  step_configure_passwords
  step_verify_toolchain
  step_xtool_prerequisites
  step_xtool_setup
  step_next_steps
  step_finish
}

main() {
  local mode="run"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --if-needed)
        mode="if-needed"
        shift
        ;;
      --reset)
        mode="reset"
        shift
        ;;
      --status)
        show_status
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  case "$mode" in
    if-needed)
      if [[ "${SKIP_ONBOARDING:-}" == "1" ]]; then
        exit 0
      fi
      if is_onboarding_complete; then
        exit 0
      fi
      if [[ ! -t 0 ]]; then
        cat <<EOF

${BOLD}Swift iOS Dev Environment — first-time setup${RESET}

Open a terminal and run: ${CYAN}onboard${RESET}

You'll set a code-server password, then complete xtool setup with your Apple account and Xcode.xip.
Status: ${CYAN}onboard --status${RESET}

EOF
        exit 0
      fi
      with_lock run_onboarding
      ;;
    reset)
      clear_marker
      with_lock run_onboarding
      ;;
    run)
      with_lock run_onboarding
      ;;
  esac
}

main "$@"
