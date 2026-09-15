#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
SWIFTPM_DIR="$BUILD_DIR/swiftpm"
APP_DIR="$BUILD_DIR/UACMan.app"
MODULE_CACHE="$BUILD_DIR/module-cache"
BUILD_ONLY=0

if [[ "${1:-}" == "--build-only" ]]; then
  BUILD_ONLY=1
  shift
fi

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

swift build \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$SWIFTPM_DIR" \
  -c release \
  --product UACManApp \
  --disable-sandbox \
  -Xswiftc -module-cache-path \
  -Xswiftc "$MODULE_CACHE"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$SWIFTPM_DIR/release/UACManApp" "$APP_DIR/Contents/MacOS/UACManApp"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/PkgInfo" "$APP_DIR/Contents/PkgInfo"
if [[ "$BUILD_ONLY" == "1" ]]; then
  exit 0
fi
open -n "$APP_DIR" --args "$@"
