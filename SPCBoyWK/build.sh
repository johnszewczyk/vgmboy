#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/SPCBoy (WK).app"
BUNDLE_IDENTIFIER="com.john.spcboy.wk"
DEVELOPMENT_SIGNING_IDENTITY="${SPCBOY_SIGNING_IDENTITY:-${COCOASPICE_SIGNING_IDENTITY:-1D46142A0CE920B12207A97C60E9DD3C389E4144}}"

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
cp "$ROOT_DIR/app-icon.png" "$APP_DIR/Contents/Resources/app-icon.png"
ditto "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/SPCBoyWK_SPCBoyWK.bundle"
chmod +x "$APP_DIR/Contents/MacOS/SPCBoyWK"
SIGNING_IDENTITY="-"
if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$DEVELOPMENT_SIGNING_IDENTITY"; then
  SIGNING_IDENTITY="$DEVELOPMENT_SIGNING_IDENTITY"
else
  echo "Warning: stable signing identity unavailable; using ad-hoc signing." >&2
fi
codesign --force --deep --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" "$APP_DIR"

echo "Built $APP_DIR"
