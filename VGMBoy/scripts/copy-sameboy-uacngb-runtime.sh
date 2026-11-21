#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VGMBoy_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DESTINATION="${1:?Usage: $0 /path/to/app/Contents/Resources}"
SOURCE="$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/sameboy-uacngb-host"
BOOT_ROM="$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/dmg_boot.bin"
BOOT_ROM_SHA256_FILE="$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/dmg_boot.bin.sha256"

if [[ ! -x "$SOURCE" || ! -f "$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/SameBoy-LICENSE.txt" || ! -f "$BOOT_ROM" || ! -f "$BOOT_ROM_SHA256_FILE" ]]; then
    echo "SameBoy UACNGB runtime not staged; packaged apps will report it unavailable for .ngbd playback." >&2
    exit 0
fi

EXPECTED_BOOT_ROM_SHA256="6f64da4cecd7e54e2f928eb3e3ba7810a7a567d0d247cc71737d1771e073a916"
ACTUAL_BOOT_ROM_SHA256="$(shasum -a 256 "$BOOT_ROM" | awk '{print $1}')"
[[ "$ACTUAL_BOOT_ROM_SHA256" == "$EXPECTED_BOOT_ROM_SHA256" ]] || {
    echo "SameBoy DMG boot ROM hash mismatch: expected $EXPECTED_BOOT_ROM_SHA256, found $ACTUAL_BOOT_ROM_SHA256" >&2
    exit 1
}

mkdir -p "$DESTINATION/sameboy-uacngb"
install -m 755 "$SOURCE" "$DESTINATION/sameboy-uacngb/sameboy-uacngb-host"
install -m 644 "$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/SameBoy-LICENSE.txt" "$DESTINATION/sameboy-uacngb/SameBoy-LICENSE.txt"
install -m 644 "$BOOT_ROM" "$DESTINATION/sameboy-uacngb/dmg_boot.bin"
install -m 644 "$BOOT_ROM_SHA256_FILE" "$DESTINATION/sameboy-uacngb/dmg_boot.bin.sha256"
echo "Bundled SameBoy UACNGB runtime in $DESTINATION/sameboy-uacngb"
