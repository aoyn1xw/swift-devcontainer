#!/usr/bin/env bash
# Install Theos on first run. Called from onboard or manually.
set -euo pipefail

THEOS="${THEOS:-/opt/theos}"

if [[ -t 1 ]]; then
  GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[36m' DIM='\033[2m' RESET='\033[0m'
else
  GREEN='' YELLOW='' CYAN='' DIM='' RESET=''
fi

if [[ -d "$THEOS/makefiles" ]]; then
  printf '%s✓ Theos already installed at %s%s\n' "$GREEN" "$THEOS" "$RESET"
  exit 0
fi

printf '%sInstalling Theos to %s...%s\n' "$CYAN" "$THEOS" "$RESET"
printf '%sThis downloads the toolchain + SDKs (~400MB). May take a few minutes.%s\n\n' "$DIM" "$RESET"

THEOS_INSTALLER_COMMIT="${THEOS_INSTALLER_COMMIT:-5280bd038207e14f8bd76f5417aa2fe641c03228}"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  "https://raw.githubusercontent.com/theos/theos/${THEOS_INSTALLER_COMMIT}/bin/install-theos" \
  | bash

if [[ -d "$THEOS/makefiles" ]]; then
  printf '\n%s✓ Theos installed successfully%s\n' "$GREEN" "$RESET"
else
  printf '\n%s✗ Theos installation failed. Try again later or check network.%s\n' "$YELLOW" "$RESET"
  exit 1
fi
