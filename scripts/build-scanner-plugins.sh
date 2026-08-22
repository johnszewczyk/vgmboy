#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_VENDOR_DIR="${VGMBoy_SHARED_VENDOR_DIR:-$ROOT_DIR/vendor}"
BUILD_DIR="$ROOT_DIR/.build/scanner-plugins"
VGMSTREAM_SOURCE="$SHARED_VENDOR_DIR/vgmstream"
VGMSTREAM_BUILD="$BUILD_DIR/vgmstream"
VGMSTREAM_OUTPUT="$BUILD_DIR/vgmstream-cli"

[[ -d "$VGMSTREAM_SOURCE" ]] || { echo "Missing shared vgmstream source: $VGMSTREAM_SOURCE" >&2; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "Missing cmake" >&2; exit 1; }

"$ROOT_DIR/scripts/build-dependencies.sh"

cmake -S "$VGMSTREAM_SOURCE" -B "$VGMSTREAM_BUILD" \
    -DBUILD_CLI=ON \
    -DBUILD_AUDACIOUS=OFF \
    -DBUILD_STATIC=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/opt/homebrew \
    -DCMAKE_EXE_LINKER_FLAGS="-L/opt/homebrew/opt/ffmpeg/lib -L/opt/homebrew/opt/libvorbis/lib -L/opt/homebrew/opt/libogg/lib" \
    -DUSE_FFMPEG=ON \
    -DUSE_MPEG=OFF \
    -DUSE_VORBIS=ON \
    -DVORBISFILE_ROOT=/opt/homebrew/opt/libvorbis \
    -DVORBIS_ROOT=/opt/homebrew/opt/libvorbis \
    -DOGG_ROOT=/opt/homebrew/opt/libogg \
    -DUSE_G7221=ON \
    -DUSE_G719=OFF \
    -DUSE_ATRAC9=OFF \
    -DUSE_CELT=OFF \
    -DUSE_SPEEX=OFF
cmake --build "$VGMSTREAM_BUILD" --target vgmstream_cli --parallel "${VGMBoy_BUILD_JOBS:-4}"

VGMSTREAM_BUILT="$VGMSTREAM_BUILD/cli/vgmstream-cli"
[[ -x "$VGMSTREAM_BUILT" ]] || { echo "Missing built vgmstream CLI: $VGMSTREAM_BUILT" >&2; exit 1; }
cp -X "$VGMSTREAM_BUILT" "$VGMSTREAM_OUTPUT"
chmod 755 "$VGMSTREAM_OUTPUT"

echo "Built VGMBoy scanner plugins"
echo "vgmstream: $VGMSTREAM_OUTPUT"
echo "highly-complete: build through VGMBoy Package.swift product"
