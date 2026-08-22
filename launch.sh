#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/build.sh"
exec open -n "$ROOT_DIR/.build/SPCBoy (WK).app"
