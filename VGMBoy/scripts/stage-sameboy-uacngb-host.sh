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

DESTINATION="$ROOT_DIR/.build/dependencies/sameboy-uacngb"
mkdir -p "$DESTINATION"
install -m 755 "$SOURCE_HOST" "$DESTINATION/sameboy-uacngb-host"
install -m 644 "$SOURCE_DIR/SameBoy-LICENSE.txt" "$DESTINATION/SameBoy-LICENSE.txt"
echo "Staged SameBoy UACNGB runtime: $DESTINATION/sameboy-uacngb-host"
