#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$ROOT/.build/site"
SWIFT_BUILD="$ROOT/.build/swift"
APP="$ROOT/.build/LineBoy.app"
MODULE_CACHE="$ROOT/.build/module-cache"
RESOURCE_BUNDLE_NAME="LineBoy_LineBoy.bundle"

mkdir -p "$OUTPUT" "$MODULE_CACHE" "$ROOT/.build/cache"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT/assets"
cp "$ROOT/index.html" "$OUTPUT/index.html"
cp "$ROOT/assets/ModernDOS8x16.ttf" "$OUTPUT/assets/ModernDOS8x16.ttf"
cp "$ROOT/assets/CC0-1.0.txt" "$OUTPUT/assets/CC0-1.0.txt"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"
export XDG_CACHE_HOME="$ROOT/.build/cache"
SDK_26="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
if [[ -n "${LINEBOY_SDKROOT:-}" ]]; then
  export SDKROOT="$LINEBOY_SDKROOT"
elif [[ -d "$SDK_26" ]]; then
  export SDKROOT="$SDK_26"
fi

swift build --package-path "$ROOT" --build-path "$SWIFT_BUILD" --disable-sandbox --manifest-cache local --cache-path "$ROOT/.build/cache/swiftpm" -debug-info-format none --configuration release --product LineBoy
BIN_DIR="$(swift build --package-path "$ROOT" --build-path "$SWIFT_BUILD" --disable-sandbox --manifest-cache local --cache-path "$ROOT/.build/cache/swiftpm" -debug-info-format none --configuration release --show-bin-path)"
EXECUTABLE="$BIN_DIR/LineBoy"
RESOURCE_BUNDLE="$BIN_DIR/$RESOURCE_BUNDLE_NAME"
[[ -x "$EXECUTABLE" ]] || { echo "Missing built executable: $EXECUTABLE" >&2; exit 1; }
[[ -d "$RESOURCE_BUNDLE" ]] || { echo "Missing WebKit resources: $RESOURCE_BUNDLE" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXECUTABLE" "$APP/Contents/MacOS/LineBoy"
cp "$ROOT/app-info.plist" "$APP/Contents/Info.plist"
ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/$RESOURCE_BUNDLE_NAME"
chmod +x "$APP/Contents/MacOS/LineBoy"
codesign --force --deep --sign - --identifier com.john.lineboy "$APP"

printf 'Built LineBoy native app: %s\n' "$APP"
printf 'Built LineBoy browser fallback: %s\n' "$OUTPUT"
