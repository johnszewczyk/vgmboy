#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/build.sh"
exec open -n "${SB2_APP_DIR:-${SB2_BUILD_DIR:-$ROOT_DIR/.build}/SPCBoy SB2.app}"
