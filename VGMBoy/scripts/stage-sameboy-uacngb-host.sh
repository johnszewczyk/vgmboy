#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_HOST="${1:-${VGMBoySameBoyUACNGBHostPath:-}}"
if [[ -z "$SOURCE_HOST" ]]; then
    echo "Usage: $0 /path/to/sameboy-uacngb-host" >&2
    exit 2
fi
[[ -x "$SOURCE_HOST" ]] || { echo "SameBoy UACNGB host is not executable: $SOURCE_HOST" >&2; exit 1; }
SOURCE_DIR="$(cd "$(dirname "$SOURCE_HOST")" && pwd)"
[[ -f "$SOURCE_DIR/SameBoy-LICENSE.txt" ]] || { echo "Missing SameBoy license beside the host: $SOURCE_DIR/SameBoy-LICENSE.txt" >&2; exit 1; }
BOOT_ROM="$SOURCE_DIR/dmg_boot.bin"
EXPECTED_BOOT_ROM_SHA256="6f64da4cecd7e54e2f928eb3e3ba7810a7a567d0d247cc71737d1771e073a916"
[[ -f "$BOOT_ROM" ]] || { echo "Missing pinned SameBoy DMG boot ROM beside the host: $BOOT_ROM" >&2; exit 1; }
ACTUAL_BOOT_ROM_SHA256="$(shasum -a 256 "$BOOT_ROM" | awk '{print $1}')"
[[ "$ACTUAL_BOOT_ROM_SHA256" == "$EXPECTED_BOOT_ROM_SHA256" ]] || {
    echo "SameBoy DMG boot ROM hash mismatch: expected $EXPECTED_BOOT_ROM_SHA256, found $ACTUAL_BOOT_ROM_SHA256" >&2
    exit 1
}

DESTINATION="$ROOT_DIR/.build/dependencies/sameboy-uacngb"
mkdir -p "$DESTINATION"
install -m 755 "$SOURCE_HOST" "$DESTINATION/sameboy-uacngb-host"
install -m 644 "$SOURCE_DIR/SameBoy-LICENSE.txt" "$DESTINATION/SameBoy-LICENSE.txt"
install -m 644 "$BOOT_ROM" "$DESTINATION/dmg_boot.bin"
printf '%s  %s\n' "$EXPECTED_BOOT_ROM_SHA256" "dmg_boot.bin" > "$DESTINATION/dmg_boot.bin.sha256"
echo "Staged SameBoy UACNGB runtime: $DESTINATION/sameboy-uacngb-host"
