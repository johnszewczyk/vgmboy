#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/SPCBoy (WK).app"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export XDG_CACHE_HOME="$BUILD_DIR/cache"

swift build --build-path "$BUILD_DIR" --configuration release --product SPCBoyWK

BIN_DIR="$(swift build --build-path "$BUILD_DIR" --configuration release --show-bin-path)"
EXECUTABLE="$BIN_DIR/SPCBoyWK"
RESOURCE_BUNDLE="$BIN_DIR/SPCBoyWK_SPCBoyWK.bundle"
[[ -x "$EXECUTABLE" ]] || { echo "Missing built executable: $EXECUTABLE" >&2; exit 1; }
[[ -d "$RESOURCE_BUNDLE" ]] || { echo "Missing WebKit resources: $RESOURCE_BUNDLE" >&2; exit 1; }

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/SPCBoyWK"
cp "$ROOT_DIR/app-info.plist" "$APP_DIR/Contents/Info.plist"
ditto "$RESOURCE_BUNDLE" "$APP_DIR/SPCBoyWK_SPCBoyWK.bundle"
chmod +x "$APP_DIR/Contents/MacOS/SPCBoyWK"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built $APP_DIR"
