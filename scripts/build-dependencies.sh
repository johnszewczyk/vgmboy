#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_BUILD_ROOT="$ROOT_DIR/.build"
DEPENDENCY_ROOT="$ROOT_DIR/.build/dependencies"

[[ -f "$ROOT_DIR/Package.swift" ]] || {
    echo "Missing VGMBoy package: $ROOT_DIR" >&2
    exit 1
}

mkdir -p "$DEPENDENCY_ROOT"

copy_dependency() {
    local name="$1"
    local source="$2"
    local destination="$DEPENDENCY_ROOT/$name"
    [[ -e "$source" ]] || { echo "Missing built dependency: $source" >&2; exit 1; }
    rm -rf "$destination"
    mkdir -p "$destination"
    ditto "$source" "$destination"
}

if [[ ! -f "$SOURCE_BUILD_ROOT/libvgm/bin/libvgm-player.a" ]]; then
    "$ROOT_DIR/scripts/build-libvgm.sh"
fi
if [[ ! -f "$SOURCE_BUILD_ROOT/mgba/libmgba.a" ]]; then
    "$ROOT_DIR/scripts/build-mgba.sh"
fi
if [[ ! -f "$SOURCE_BUILD_ROOT/2sf/lib2sf.a" ]]; then
    "$ROOT_DIR/scripts/build-2sf.sh"
fi
if [[ ! -f "$SOURCE_BUILD_ROOT/lazyusf/liblazyusf.a" || ! -f "$SOURCE_BUILD_ROOT/lazyusf/libpsflib.a" ]]; then
    "$ROOT_DIR/scripts/build-lazyusf.sh"
fi
if [[ ! -f "$SOURCE_BUILD_ROOT/play-psf/libcocoaspice_play_psf.a" ]]; then
    "$ROOT_DIR/scripts/build-play-psf.sh"
fi
"$ROOT_DIR/scripts/build-vgmstream.sh"

copy_dependency libvgm "$SOURCE_BUILD_ROOT/libvgm"
copy_dependency mgba "$SOURCE_BUILD_ROOT/mgba"
copy_dependency 2sf "$SOURCE_BUILD_ROOT/2sf"
copy_dependency lazyusf "$SOURCE_BUILD_ROOT/lazyusf"
copy_dependency play-psf "$SOURCE_BUILD_ROOT/play-psf"
copy_dependency vgmstream "$SOURCE_BUILD_ROOT/vgmstream"

echo "VGMBoy dependencies ready: $DEPENDENCY_ROOT"
