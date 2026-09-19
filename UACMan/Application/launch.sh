#!/usr/bin/env bash
set -euo pipefail

APPLICATION_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$APPLICATION_DIR/.." && pwd)"
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

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$SWIFTPM_DIR/release/UACManApp" "$APP_DIR/Contents/MacOS/UACManApp"
cp "$APPLICATION_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$APPLICATION_DIR/Resources/PkgInfo" "$APP_DIR/Contents/PkgInfo"
cp "$APPLICATION_DIR/DocumentIcon/UACDocumentIcon.icns" "$APP_DIR/Contents/Resources/UACDocumentIcon.icns"
RESOURCE_BUNDLE="$SWIFTPM_DIR/release/UACMan_UACManApp.bundle"
[[ -d "$RESOURCE_BUNDLE" ]] || { echo "Missing WKWebView workspace resources: $RESOURCE_BUNDLE" >&2; exit 1; }
ditto "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/UACMan_UACManApp.bundle"
codesign --force --deep --sign - --identifier org.vgmman.UACMan "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
if [[ "$BUILD_ONLY" == "1" ]]; then
  exit 0
fi
open -n "$APP_DIR" --args "$@"
