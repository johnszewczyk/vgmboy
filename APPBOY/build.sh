#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

TARGET_MODE="device"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_MODE="${2:-device}"
      shift 2
      ;;
    --simulator)
      TARGET_MODE="simulator"
      shift
      ;;
    --all)
      TARGET_MODE="all"
      shift
      ;;
    *)
      echo "Usage: $0 [--target device|simulator|all]" >&2
      exit 2
      ;;
  esac
done

BUILD_DIR="${APPBOY_BUILD_DIR:-$ROOT_DIR/.build}"
BUNDLE_IDENTIFIER="${APPBOY_BUNDLE_IDENTIFIER:-com.john.spcboy.appboy}"
DEPLOYMENT_TARGET="${APPBOY_IOS_DEPLOYMENT_TARGET:-17.0}"
DEVELOPMENT_SIGNING_IDENTITY="${APPBOY_SIGNING_IDENTITY:-${SPCBOY_SIGNING_IDENTITY:-}}"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p "$BUILD_DIR"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export XDG_CACHE_HOME="$BUILD_DIR/cache"

resolve_signing_identity() {
  local requested="$1"
  if [[ -n "$requested" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$requested"; then
    echo "$requested"
  else
    echo "-"
  fi
}

generate_icons() {
  local app_dir="$1"
  local src_icon="$ROOT_DIR/app-icon.png"
  [[ -f "$src_icon" ]] || { echo "Missing canonical icon: $src_icon" >&2; exit 1; }
  cp "$src_icon" "$app_dir/app-icon.png"
  sips -z 120 120 "$src_icon" --out "$app_dir/AppIcon60x60@2x.png" >/dev/null
  sips -z 180 180 "$src_icon" --out "$app_dir/AppIcon60x60@3x.png" >/dev/null
  sips -z 152 152 "$src_icon" --out "$app_dir/AppIcon76x76@2x~ipad.png" >/dev/null
}

stamp_plist() {
  local plist_path="$1"
  local platform_name="$2"
  local supported_platform="$3"
  local sdk_name="$4"

  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$plist_path"
  /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $DEPLOYMENT_TARGET" "$plist_path"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleSupportedPlatforms" "$plist_path" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms:0 string $supported_platform" "$plist_path"
  /usr/libexec/PlistBuddy -c "Delete :DTPlatformName" "$plist_path" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :DTPlatformName string $platform_name" "$plist_path"
  /usr/libexec/PlistBuddy -c "Delete :DTSDKName" "$plist_path" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :DTSDKName string $sdk_name" "$plist_path"
}

build_variant() {
  local variant="$1"
  local sdk_type triple supported_platform app_dir sdk_path sdk_ver

  if [[ "$variant" == "device" ]]; then
    sdk_type="iphoneos"
    triple="arm64-apple-ios${DEPLOYMENT_TARGET}"
    supported_platform="iPhoneOS"
    app_dir="${APPBOY_APP_DIR:-$BUILD_DIR/APPBOY.app}"
  else
    sdk_type="iphonesimulator"
    triple="arm64-apple-ios${DEPLOYMENT_TARGET}-simulator"
    supported_platform="iPhoneSimulator"
    app_dir="$BUILD_DIR/APPBOY-Simulator.app"
  fi

  sdk_path="$(xcrun --sdk "$sdk_type" --show-sdk-path)"
  sdk_ver="$(xcrun --sdk "$sdk_type" --show-sdk-version)"

  local swift_args=(
    --build-path "$BUILD_DIR/spm-$variant"
    --configuration release
    --disable-sandbox
    --manifest-cache local
    --cache-path "$BUILD_DIR/swift-cache"
    --sdk "$sdk_path"
    --triple "$triple"
  )

  echo "Compiling APPBOY ($variant: $triple against $sdk_type$sdk_ver)..."
  swift build "${swift_args[@]}" --product APPBOY

  local bin_dir
  bin_dir="$(swift build "${swift_args[@]}" --show-bin-path)"
  local executable="$bin_dir/APPBOY"
  local resource_bundle="$bin_dir/APPBOY_APPBOY.bundle"

  [[ -x "$executable" ]] || { echo "Missing built executable: $executable" >&2; exit 1; }

  rm -rf "$app_dir"
  mkdir -p "$app_dir"
  cp "$executable" "$app_dir/APPBOY"
  chmod +x "$app_dir/APPBOY"
  printf 'APPL????' > "$app_dir/PkgInfo"

  cp "$ROOT_DIR/app-info.plist" "$app_dir/Info.plist"
  stamp_plist "$app_dir/Info.plist" "$sdk_type" "$supported_platform" "${sdk_type}${sdk_ver}"
  plutil -convert binary1 "$app_dir/Info.plist"

  generate_icons "$app_dir"

  if [[ -d "$resource_bundle" ]]; then
    ditto "$resource_bundle" "$app_dir/APPBOY_APPBOY.bundle"
  fi
  ditto "$ROOT_DIR/Sources/APPBOY/Resources/WebUI" "$app_dir/WebUI"

  local sign_id="-"
  if [[ "$variant" == "device" ]]; then
    sign_id="$(resolve_signing_identity "$DEVELOPMENT_SIGNING_IDENTITY")"
  fi
  codesign --force --deep --sign "$sign_id" --timestamp=none "$app_dir"

  echo "Built $app_dir"

  if [[ "$variant" == "device" ]]; then
    local ipa_path="${APPBOY_IPA_PATH:-$BUILD_DIR/APPBOY.ipa}"
    local staging_dir="$BUILD_DIR/ipa-staging"
    rm -rf "$staging_dir" "$ipa_path"
    mkdir -p "$staging_dir/Payload"
    ditto --norsrc "$app_dir" "$staging_dir/Payload/APPBOY.app"
    (
      cd "$staging_dir"
      ditto --norsrc -c -k --keepParent "Payload" "$ipa_path"
    )
    rm -rf "$staging_dir"
    echo "Packaged sideload archive: $ipa_path"
  fi
}

case "$TARGET_MODE" in
  device)
    build_variant device
    ;;
  simulator)
    build_variant simulator
    ;;
  all)
    build_variant device
    build_variant simulator
    ;;
  *)
    echo "Unsupported --target '$TARGET_MODE' (expected device, simulator, or all)." >&2
    exit 2
    ;;
esac
