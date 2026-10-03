#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$ROOT_DIR/build.sh"
exec open -n "$ROOT_DIR/.build/VGMManDocs.app"
