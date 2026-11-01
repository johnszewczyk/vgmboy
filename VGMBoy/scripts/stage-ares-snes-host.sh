#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_HOST="${1:-${VGMBoyAresSNESHostPath:-}}"
if [[ -z "$SOURCE_HOST" ]]; then
    echo "Usage: $0 /path/to/ares-agent-host (with adjacent Database/ directory)" >&2
    exit 2
fi
[[ -x "$SOURCE_HOST" ]] || { echo "ares-agent-host is not executable: $SOURCE_HOST" >&2; exit 1; }
SOURCE_DIR="$(cd "$(dirname "$SOURCE_HOST")" && pwd)"
[[ -f "$SOURCE_DIR/Database/Super Famicom.bml" && -f "$SOURCE_DIR/Database/Super Famicom Boards.bml" ]] || {
    echo "Missing pinned ares Super Famicom database resources beside the host." >&2
    exit 1
}

DESTINATION="$ROOT_DIR/.build/dependencies/ares-snes"
rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"
install -m 755 "$SOURCE_HOST" "$DESTINATION/ares-agent-host"
ditto "$SOURCE_DIR/Database" "$DESTINATION/Database"
echo "Staged ares SNES runtime: $DESTINATION"
