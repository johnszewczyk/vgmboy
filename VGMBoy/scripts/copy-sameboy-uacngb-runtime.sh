#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VGMBoy_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DESTINATION="${1:?Usage: $0 /path/to/app/Contents/Resources}"
SOURCE="$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/sameboy-uacngb-host"

if [[ ! -x "$SOURCE" || ! -f "$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/SameBoy-LICENSE.txt" ]]; then
    echo "SameBoy UACNGB runtime not staged; packaged apps will report it unavailable for .ngbd playback." >&2
    exit 0
fi

mkdir -p "$DESTINATION/sameboy-uacngb"
install -m 755 "$SOURCE" "$DESTINATION/sameboy-uacngb/sameboy-uacngb-host"
install -m 644 "$VGMBoy_DIR/.build/dependencies/sameboy-uacngb/SameBoy-LICENSE.txt" "$DESTINATION/sameboy-uacngb/SameBoy-LICENSE.txt"
echo "Bundled SameBoy UACNGB runtime in $DESTINATION/sameboy-uacngb"
