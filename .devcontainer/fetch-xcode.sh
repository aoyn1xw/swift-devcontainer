#!/usr/bin/env bash
# Fetch an Xcode.xip using xcodereleases.com metadata.
set -euo pipefail

DEST_DIR="${XCODE_DOWNLOAD_DIR:-$HOME}"
API_URL="${XCODE_RELEASES_API_URL:-https://xcodereleases.com/data.json}"

if [[ -t 1 ]]; then
  BOLD='\033[1m' GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[36m' DIM='\033[2m' RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' CYAN='' DIM='' RESET=''
fi

usage() {
  cat <<'EOF'
Usage: fetch-xcode [options]

Download an Xcode.xip from Apple's CDN using xcodereleases.com metadata.

Options:
  --list            List available stable releases and exit
  --version VER     Download a specific version (e.g. 16.3)
  --beta            Include beta/RC releases when picking latest
  --output DIR      Download destination (default: $HOME)
  --no-verify       Skip checksum verification (not recommended)
  -h, --help        Show this help
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
    --version)
      [[ $# -ge 2 && -n "$2" ]] || die "--version requires a value"
      TARGET_VERSION="$2"
      shift 2
      ;;
    --beta) INCLUDE_BETA=true; shift ;;
    --output)
      [[ $# -ge 2 && -n "$2" ]] || die "--output requires a directory"
      DEST_DIR="$2"
      shift 2
      ;;
    --no-verify) VERIFY=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

METADATA_FILE="$TMP_DIR/releases.json"
SELECTION_FILE="$TMP_DIR/selection.tsv"
printf '%sFetching release data from xcodereleases.com...%s\n' "$DIM" "$RESET"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  --output "$METADATA_FILE" "$API_URL" || die "Failed to fetch release data"

if [[ "$LIST_MODE" == "true" ]]; then
  python3 - "$METADATA_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

def is_final(release):
    return bool((release.get("version") or {}).get("release", {}).get("release"))

def version_str(release):
    version = release.get("version") or {}
    number = version.get("number", "?")
    rel = version.get("release") or {}
    if rel.get("beta"):
        return f"{number} beta {rel['beta']}"
    if rel.get("rc"):
        return f"{number} RC {rel['rc']}"
    return str(number)

def date_str(release):
    date = release.get("date") or {}
    return f"{date.get('year', '?')}-{date.get('month', 0):02d}-{date.get('day', 0):02d}"

for release in sorted((r for r in data if is_final(r)), key=lambda r: r.get("_versionOrder", 0), reverse=True)[:20]:
    url = ((release.get("links") or {}).get("download") or {}).get("url", "")
    marker = "✓" if url else "✗"
    print(f"  {version_str(release):16s}  {date_str(release)}  [{marker} download]")
PY
  exit 0
fi

python3 - "$METADATA_FILE" "$TARGET_VERSION" "$INCLUDE_BETA" > "$SELECTION_FILE" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
target_version = sys.argv[2]
include_beta = sys.argv[3].lower() == "true"

def is_final(release):
    return bool((release.get("version") or {}).get("release", {}).get("release"))

def version_str(release):
    version = release.get("version") or {}
    number = str(version.get("number", "?"))
    rel = version.get("release") or {}
    if rel.get("beta"):
        return f"{number} beta {rel['beta']}"
    if rel.get("rc"):
        return f"{number} RC {rel['rc']}"
    return number

def date_str(release):
    date = release.get("date") or {}
    return f"{date.get('year', '?')}-{date.get('month', 0):02d}-{date.get('day', 0):02d}"

candidates = data if include_beta else [r for r in data if is_final(r)]
if not candidates:
    raise SystemExit("No releases found")

if target_version:
    matches = [r for r in candidates if str((r.get("version") or {}).get("number", "")) == target_version]
    if not matches:
        raise SystemExit(f"Version {target_version} not found")
    chosen = matches[0]
else:
    chosen = sorted(candidates, key=lambda r: r.get("_versionOrder", 0), reverse=True)[0]

version = version_str(chosen)
url = ((chosen.get("links") or {}).get("download") or {}).get("url", "")
sha1 = ((chosen.get("checksums") or {}).get("sha1") or "").lower()
if not url:
    raise SystemExit(f"No download URL for Xcode {version}")
if not re.fullmatch(r"https://download\.developer\.apple\.com/[A-Za-z0-9_./%-]+", url):
    raise SystemExit("Download URL is not an Apple Developer CDN URL")
if not re.fullmatch(r"[0-9a-f]{40}", sha1):
    raise SystemExit(f"No valid SHA-1 checksum for Xcode {version}")

print("\t".join((version, date_str(chosen), url, sha1)))
PY

IFS=$'\t' read -r XCODE_VERSION XCODE_DATE XCODE_URL XCODE_SHA1 < "$SELECTION_FILE"
FILENAME="Xcode_${XCODE_VERSION// /_}.xip"
DEST_PATH="${DEST_DIR}/${FILENAME}"

printf '\n%s┌─────────────────────────────────────────┐%s\n' "$CYAN" "$RESET"
printf '%s│ Xcode %s (%s)%s\n' "$CYAN" "$XCODE_VERSION" "$XCODE_DATE" "$RESET"
printf '%s│ %s%s\n' "$DIM" "$XCODE_URL" "$RESET"
printf '%s│ SHA-1: %s%s\n' "$DIM" "$XCODE_SHA1" "$RESET"
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
TEMP_DOWNLOAD="$TMP_DIR/$FILENAME"
printf '%sDownloading Xcode.xip (this will take a while — typically 7-12 GB)...%s\n' "$BOLD" "$RESET"
if [[ -t 1 ]]; then
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors --progress-bar \
    --output "$TEMP_DOWNLOAD" "$XCODE_URL"
else
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    --output "$TEMP_DOWNLOAD" "$XCODE_URL"
fi

if [[ "$VERIFY" == "true" ]]; then
  printf '%sVerifying SHA-1 checksum...%s\n' "$DIM" "$RESET"
  ACTUAL_SHA1="$(sha1sum "$TEMP_DOWNLOAD" | cut -d' ' -f1)"
  [[ "$ACTUAL_SHA1" == "$XCODE_SHA1" ]] || die "Checksum mismatch (expected $XCODE_SHA1, got $ACTUAL_SHA1)"
  printf '%s✓ Checksum matches%s\n' "$GREEN" "$RESET"
else
  printf '%sWarning: checksum verification skipped by request.%s\n' "$YELLOW" "$RESET"
fi

mv -- "$TEMP_DOWNLOAD" "$DEST_PATH"
printf '\n%s✓ Download complete: %s%s\n' "$GREEN" "$DEST_PATH" "$RESET"
printf '\n%sNext steps:%s\n' "$BOLD" "$RESET"
printf '  1. Run: %sxtool setup%s\n' "$CYAN" "$RESET"
printf '  2. When prompted for Xcode.xip, point to: %s%s%s\n' "$BOLD" "$DEST_PATH" "$RESET"
printf '  3. The SDK extraction takes ~10-20 min depending on disk speed\n'
