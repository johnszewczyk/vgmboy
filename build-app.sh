#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/module-cache"
APP_DIR="$BUILD_DIR/app/VGMBoy.app"
COCOASPICE_DIR="$SCRIPT_DIR/../CocoaSpice"
LIBVGM_BUILD="$COCOASPICE_DIR/.build/libvgm/bin/libvgm-player.a"

if [[ ! -f "$LIBVGM_BUILD" ]]; then
    echo "libvgm not built; building it from CocoaSpice's vendor copy..." >&2
    "$COCOASPICE_DIR/scripts/build-libvgm.sh"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$MODULE_CACHE" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"
export XDG_CACHE_HOME="$BUILD_DIR/cache"

swift build --package-path "$SCRIPT_DIR" --build-path "$BUILD_DIR" --disable-sandbox --configuration release --product VGMBoy
BIN_DIR="$BUILD_DIR/arm64-apple-macosx/release"
if [[ ! -x "$BIN_DIR/VGMBoy" ]]; then
    BIN_DIR="$(swift build --package-path "$SCRIPT_DIR" --build-path "$BUILD_DIR" --disable-sandbox --configuration release --show-bin-path)"
fi
[[ -x "$BIN_DIR/VGMBoy" ]] || { echo "Missing clean-built executable: $BIN_DIR/VGMBoy" >&2; exit 1; }

install -m 755 "$BIN_DIR/VGMBoy" "$APP_DIR/Contents/MacOS/VGMBoy"
install -m 644 "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

ICON_SOURCE=""
for candidate in "$SCRIPT_DIR/app-icon.png" "$SCRIPT_DIR/app-icon.jpg"; do
    if [[ -f "$candidate" ]]; then
        ICON_SOURCE="$candidate"
        break
    fi
done
if [[ -n "$ICON_SOURCE" ]]; then
    sips -s format png "$ICON_SOURCE" --out "$APP_DIR/Contents/Resources/app-icon.png" >/dev/null
fi
codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"