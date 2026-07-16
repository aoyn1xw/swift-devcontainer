#!/usr/bin/env bash
# Fetch the latest (or specified) Xcode.xip using the xcodereleases.com API.
# Requires: curl, python3 (both pre-installed in this container).
set -euo pipefail

DEST_DIR="${XCODE_DOWNLOAD_DIR:-$HOME}"
API_URL="https://xcodereleases.com/data.json"

if [[ -t 1 ]]; then
  BOLD='\033[1m' GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[36m' DIM='\033[2m' RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' CYAN='' DIM='' RESET=''
fi

usage() {
  cat <<EOF
Usage: fetch-xcode [options]

Download an Xcode.xip from Apple's CDN using xcodereleases.com metadata.

Options:
  --list            List available stable releases and exit
  --version VER     Download a specific version (e.g. 16.3)
  --beta            Include beta/RC releases when picking latest
  --output DIR      Download destination (default: \$HOME)
  --no-verify       Skip SHA-1 verification after download
  -h, --help        Show this help

Examples:
  fetch-xcode                   # latest stable
  fetch-xcode --version 16.3   # specific version
  fetch-xcode --list            # see what's available
EOF
}

die() { printf '%sError: %s%s\n' "$YELLOW" "$1" "$RESET" >&2; exit 1; }

TARGET_VERSION=""
INCLUDE_BETA=false
VERIFY=true
LIST_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) LIST_MODE=true; shift ;;
    --version) TARGET_VERSION="$2"; shift 2 ;;
    --beta) INCLUDE_BETA=true; shift ;;
    --output) DEST_DIR="$2"; shift 2 ;;
    --no-verify) VERIFY=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

printf '%sFetching release data from xcodereleases.com...%s\n' "$DIM" "$RESET"
RELEASES_JSON="$(curl -fsSL "$API_URL")" || die "Failed to fetch release data"

# ponytail: python3 inline for JSON parsing — no jq dependency needed
RESULT="$(python3 - "$TARGET_VERSION" "$INCLUDE_BETA" "$LIST_MODE" <<'PYEOF'
import json, sys, os

data = json.loads(sys.stdin.read())
target_version = sys.argv[1] if len(sys.argv) > 1 else ""
include_beta = sys.argv[2] == "True" if len(sys.argv) > 2 else False
list_mode = sys.argv[3] == "true" if len(sys.argv) > 3 else False

def is_final(r):
    rel = r.get("version", {}).get("release", {})
    return rel.get("release") is True

def version_str(r):
    v = r.get("version", {})
    num = v.get("number", "?")
    rel = v.get("release", {})
    if rel.get("beta"):
        return f"{num} beta {rel['beta']}"
    if rel.get("rc"):
        return f"{num} RC {rel['rc']}"
    return num

def date_str(r):
    d = r.get("date", {})
    return f"{d.get('year', '?')}-{d.get('month', 0):02d}-{d.get('day', 0):02d}"

if list_mode:
    finals = [r for r in data if is_final(r)]
    finals.sort(key=lambda x: x.get("_versionOrder", 0), reverse=True)
    for r in finals[:20]:
        url = (r.get("links") or {}).get("download", {}).get("url", "")
        has_url = "✓" if url else "✗"
        print(f"  {version_str(r):12s}  {date_str(r)}  [{has_url} download]")
    sys.exit(0)

if include_beta:
    candidates = data
else:
    candidates = [r for r in data if is_final(r)]

if not candidates:
    print("ERROR:No releases found", file=sys.stderr)
    sys.exit(1)

if target_version:
    match = [r for r in candidates if r.get("version", {}).get("number") == target_version]
    if not match:
        print(f"ERROR:Version {target_version} not found", file=sys.stderr)
        sys.exit(1)
    chosen = match[0]
else:
    candidates.sort(key=lambda x: x.get("_versionOrder", 0), reverse=True)
    chosen = candidates[0]

links = chosen.get("links") or {}
download = links.get("download") or {}
url = download.get("url", "")
if not url:
    print(f"ERROR:No download URL for Xcode {version_str(chosen)}", file=sys.stderr)
    sys.exit(1)

checksums = chosen.get("checksums") or {}
sha1 = checksums.get("sha1", "")

# Output as key=value for bash to eval
print(f"XCODE_VERSION={version_str(chosen)}")
print(f"XCODE_DATE={date_str(chosen)}")
print(f"XCODE_URL={url}")
print(f"XCODE_SHA1={sha1}")
PYEOF
)" <<< "$RELEASES_JSON"

if [[ "$LIST_MODE" == "true" ]]; then
  printf '\n%sAvailable Xcode releases (latest 20):%s\n' "$BOLD" "$RESET"
  echo "$RESULT"
  exit 0
fi

if echo "$RESULT" | grep -q '^ERROR:'; then
  die "$(echo "$RESULT" | sed 's/^ERROR://')"
fi

eval "$RESULT"

FILENAME="Xcode_${XCODE_VERSION// /_}.xip"
DEST_PATH="${DEST_DIR}/${FILENAME}"

printf '\n%s┌─────────────────────────────────────────┐%s\n' "$CYAN" "$RESET"
printf '%s│ Xcode %s (%s)%s\n' "$CYAN" "$XCODE_VERSION" "$XCODE_DATE" "$RESET"
printf '%s│ %s%s\n' "$DIM" "$XCODE_URL" "$RESET"
if [[ -n "$XCODE_SHA1" ]]; then
  printf '%s│ SHA-1: %s%s\n' "$DIM" "$XCODE_SHA1" "$RESET"
fi
printf '%s│ → %s%s\n' "$CYAN" "$DEST_PATH" "$RESET"
printf '%s└─────────────────────────────────────────┘%s\n\n' "$CYAN" "$RESET"

if [[ -f "$DEST_PATH" ]]; then
  printf '%s⚠ File already exists: %s%s\n' "$YELLOW" "$DEST_PATH" "$RESET"
  if [[ -t 0 ]]; then
    printf 'Re-download? [y/N]: '
    read -r choice
    [[ "${choice,,}" == "y" ]] || { printf 'Skipped.\n'; exit 0; }
  else
    die "File exists. Remove it or use a different --output directory."
  fi
fi

mkdir -p "$DEST_DIR"

printf '%sDownloading Xcode.xip (this will take a while — typically 7-12 GB)...%s\n' "$BOLD" "$RESET"
# ponytail: curl -L handles Apple CDN redirects, --progress-bar for human-friendly output
if [[ -t 1 ]]; then
  curl -L --progress-bar -o "$DEST_PATH" "$XCODE_URL"
else
  curl -L -o "$DEST_PATH" "$XCODE_URL"
fi

printf '\n%s✓ Download complete: %s%s\n' "$GREEN" "$DEST_PATH" "$RESET"

if [[ "$VERIFY" == "true" ]] && [[ -n "$XCODE_SHA1" ]]; then
  printf '%sVerifying SHA-1 checksum...%s\n' "$DIM" "$RESET"
  ACTUAL_SHA1="$(sha1sum "$DEST_PATH" | cut -d' ' -f1)"
  if [[ "$ACTUAL_SHA1" == "$XCODE_SHA1" ]]; then
    printf '%s✓ Checksum matches%s\n' "$GREEN" "$RESET"
  else
    printf '%s✗ Checksum mismatch!%s\n' "$YELLOW" "$RESET"
    printf '  Expected: %s\n  Got:      %s\n' "$XCODE_SHA1" "$ACTUAL_SHA1"
    printf '%sThe file may be corrupted. Re-download or use --no-verify if you trust the source.%s\n' "$YELLOW" "$RESET"
    exit 1
  fi
fi

printf '\n%sNext steps:%s\n' "$BOLD" "$RESET"
printf '  1. Run: %sxtool setup%s\n' "$CYAN" "$RESET"
printf '  2. When prompted for Xcode.xip, point to: %s%s%s\n' "$BOLD" "$DEST_PATH" "$RESET"
printf '  3. The SDK extraction takes ~10-20 min depending on disk speed\n'
