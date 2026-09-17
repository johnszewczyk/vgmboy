#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

killall ViewBoy 2>/dev/null || true
"$ROOT_DIR/build.sh"
exec open -n "$ROOT_DIR/.build/ViewBoy.app"
