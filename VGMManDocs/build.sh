#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/VGMManDocs.app"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export XDG_CACHE_HOME="$BUILD_DIR/cache"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

swift build --disable-sandbox --build-path "$BUILD_DIR" --configuration release --product VGMManDocs

BIN_DIR="$(swift build --disable-sandbox --build-path "$BUILD_DIR" --configuration release --show-bin-path)"
EXECUTABLE="$BIN_DIR/VGMManDocs"
RESOURCE_BUNDLE="$BIN_DIR/VGMManDocs_VGMManDocs.bundle"
[[ -x "$EXECUTABLE" ]] || { echo "Missing built executable: $EXECUTABLE" >&2; exit 1; }
[[ -d "$RESOURCE_BUNDLE" ]] || { echo "Missing WebKit resources: $RESOURCE_BUNDLE" >&2; exit 1; }

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/VGMManDocs"
cp "$ROOT_DIR/app-info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
ditto "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/VGMManDocs_VGMManDocs.bundle"
chmod +x "$APP_DIR/Contents/MacOS/VGMManDocs"
codesign --force --deep --sign - --identifier org.vgmman.VGMManDocs "$APP_DIR"

echo "Built $APP_DIR"
