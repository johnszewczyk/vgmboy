#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_VENDOR_DIR="${VGMBoy_SHARED_VENDOR_DIR:-$ROOT_DIR/vendor}"
BUILD_DIR="$ROOT_DIR/.build/scanner-plugins"
VGMSTREAM_SOURCE="$SHARED_VENDOR_DIR/vgmstream"
VGMSTREAM_BUILD="$BUILD_DIR/vgmstream"
VGMSTREAM_OUTPUT="$BUILD_DIR/vgmstream-cli"
QSF_OUTPUT="$BUILD_DIR/vgmboy-qsf-inspect"
SCANNER_STAMP="$BUILD_DIR/scanner-inputs.sha256"

"$ROOT_DIR/scripts/build-dependencies.sh"

scanner_signature="$({
    shasum -a 256 \
        "$ROOT_DIR/scripts/build-scanner-plugins.sh" \
        "$ROOT_DIR/scripts/build-qsf-inspector.sh" \
        "$ROOT_DIR/Sources/VGMBoyQSFInspect/main.c" \
        "$ROOT_DIR/.build/dependency-stamps/qsf.sha256" \
        "$ROOT_DIR/.build/dependency-stamps/vgmstream.sha256"
    printf '%s\n' "$VGMSTREAM_SOURCE"
    cmake --version | head -n 1
    "${CC:-cc}" --version | head -n 1
    pkg-config --modversion libavcodec vorbisfile ogg 2>/dev/null || true
} | shasum -a 256 | awk '{ print $1 }')"

if [[ -x "$VGMSTREAM_OUTPUT" && -x "$QSF_OUTPUT" && -f "$SCANNER_STAMP" \
      && "$(<"$SCANNER_STAMP")" == "$scanner_signature" ]]; then
    echo "VGMBoy scanner plugins are current ($scanner_signature)"
    echo "vgmstream: $VGMSTREAM_OUTPUT"
    echo "qsf: $QSF_OUTPUT"
    exit 0
fi

"$ROOT_DIR/scripts/build-qsf-inspector.sh" >/dev/null

[[ -d "$VGMSTREAM_SOURCE" ]] || { echo "Missing shared vgmstream source: $VGMSTREAM_SOURCE" >&2; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "Missing cmake" >&2; exit 1; }

# CMake caches the absolute source directory. Older frontend builds used a
# CocoaSpice-owned checkout at this same build path; CMake refuses to reuse
# that cache for VGMBoy and ScanSong then appears to fail before packaging.
# Recreate only the derived scanner build directory when its source identity
# is stale. The shared source garden remains untouched.
if [[ -f "$VGMSTREAM_BUILD/CMakeCache.txt" ]]; then
    configured_source="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$VGMSTREAM_BUILD/CMakeCache.txt" | head -n 1)"
    if [[ -n "$configured_source" && "$configured_source" != "$VGMSTREAM_SOURCE" ]]; then
        echo "Replacing stale scanner CMake cache for $configured_source"
        rm -rf "$VGMSTREAM_BUILD"
    fi
fi

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
printf '%s\n' "$scanner_signature" > "$SCANNER_STAMP"

echo "Built VGMBoy scanner plugins"
echo "vgmstream: $VGMSTREAM_OUTPUT"
echo "qsf: $QSF_OUTPUT"
echo "highly-complete: build through VGMBoy Package.swift product"
