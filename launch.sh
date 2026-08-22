#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

swift package clean
swift build -c release
exec "$ROOT_DIR/.build/arm64-apple-macosx/release/SPCBoyWK"
