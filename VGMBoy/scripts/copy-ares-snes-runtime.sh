#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VGMBoy_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DESTINATION="${1:?Usage: $0 /path/to/app/Contents/Resources}"
SOURCE="$VGMBoy_DIR/.build/dependencies/ares-snes"

if [[ ! -x "$SOURCE/ares-agent-host" || ! -d "$SOURCE/Database" ]]; then
    echo "ares SNES runtime not staged; packaged apps will report it unavailable for .snesstate playback." >&2
    exit 0
fi

mkdir -p "$DESTINATION"
ditto "$SOURCE" "$DESTINATION/ares-snes"
echo "Bundled ares SNES runtime in $DESTINATION/ares-snes"
