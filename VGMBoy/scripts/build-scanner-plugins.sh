#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_VENDOR_DIR="${VGMBoy_SHARED_VENDOR_DIR:-$ROOT_DIR/vendor}"
BUILD_DIR="$ROOT_DIR/.build/scanner-plugins"
VGMSTREAM_SOURCE="$SHARED_VENDOR_DIR/vgmstream"
VGMSTREAM_BUILD="$BUILD_DIR/vgmstream"
VGMSTREAM_OUTPUT="$BUILD_DIR/vgmstream-cli"
QSF_OUTPUT="$BUILD_DIR/vgmboy-qsf-inspect"
MDX_OUTPUT="$BUILD_DIR/vgmboy-mdx-inspect"
AMIGA_OUTPUT="$BUILD_DIR/vgmboy-amiga-inspect"
FFMPEG_OUTPUT="$BUILD_DIR/vgmboy-ffmpeg-inspect"
SCANNER_STAMP="$BUILD_DIR/scanner-inputs.sha256"

"$ROOT_DIR/scripts/build-dependencies.sh"

scanner_signature="$({
    shasum -a 256 \
        "$ROOT_DIR/scripts/build-scanner-plugins.sh" \
        "$ROOT_DIR/scripts/build-qsf-inspector.sh" \
        "$ROOT_DIR/Sources/VGMBoyQSFInspect/main.c" \
        "$ROOT_DIR/Sources/VGMBoyMDXInspect/main.swift" \
        "$ROOT_DIR/Sources/VGMBoyAmigaInspect/main.swift" \
        "$ROOT_DIR/Sources/VGMBoyFFmpegInspect/main.swift" \
        "$ROOT_DIR/Sources/VGMBoyKit/AmigaDecoder.swift" \
        "$ROOT_DIR/Sources/VGMBoyKit/FFmpegAudioDecoder.swift" \
        "$ROOT_DIR/Sources/VGMBoyKit/FFmpegInspector.swift" \
        "$ROOT_DIR/Sources/CFFmpeg/vgmboy_ffmpeg.c" \
        "$ROOT_DIR/Sources/CFFmpeg/include/vgmboy_ffmpeg.h" \
        "$ROOT_DIR/Sources/CUADE/vgmboy_uade.c" \
        "$ROOT_DIR/Sources/CUADE/include/vgmboy_uade.h" \
        "$ROOT_DIR/Sources/VGMBoyFormatCore/AmigaFormatManifest.swift" \
        "$ROOT_DIR/Package.swift" \
        "$ROOT_DIR/Sources/VGMBoyKit/MDXDecoder.swift" \
        "$ROOT_DIR/Sources/CMDX/mdx_bridge.c" \
        "$ROOT_DIR/vendor/mdxmini/src/"*.c \
        "$ROOT_DIR/vendor/mdxmini/src/"*.h \
        "$ROOT_DIR/.build/dependency-stamps/qsf.sha256" \
        "$ROOT_DIR/.build/dependency-stamps/vgmstream.sha256"
    printf '%s\n' "$VGMSTREAM_SOURCE"
    cmake --version | head -n 1
    "${CC:-cc}" --version | head -n 1
    pkg-config --modversion libavcodec vorbisfile ogg 2>/dev/null || true
} | shasum -a 256 | awk '{ print $1 }')"

if [[ -x "$VGMSTREAM_OUTPUT" && -x "$QSF_OUTPUT" && -x "$MDX_OUTPUT" && -x "$AMIGA_OUTPUT" && -x "$FFMPEG_OUTPUT" && -f "$SCANNER_STAMP" \
      && "$(<"$SCANNER_STAMP")" == "$scanner_signature" ]]; then
    echo "VGMBoy scanner plugins are current ($scanner_signature)"
    echo "vgmstream: $VGMSTREAM_OUTPUT"
    echo "qsf: $QSF_OUTPUT"
    echo "mdx: $MDX_OUTPUT"
    echo "amiga: $AMIGA_OUTPUT"
    echo "ffmpeg: $FFMPEG_OUTPUT"
    exit 0
fi

"$ROOT_DIR/scripts/build-qsf-inspector.sh" >/dev/null

swift build --disable-sandbox --package-path "$ROOT_DIR" --configuration release --product vgmboy-amiga-inspect >/dev/null
AMIGA_BUILT="$ROOT_DIR/.build/arm64-apple-macosx/release/vgmboy-amiga-inspect"
[[ -x "$AMIGA_BUILT" ]] || { echo "Missing built Amiga inspector: $AMIGA_BUILT" >&2; exit 1; }
cp -X "$AMIGA_BUILT" "$AMIGA_OUTPUT"
chmod 755 "$AMIGA_OUTPUT"

swift build --disable-sandbox --package-path "$ROOT_DIR" --configuration release --product vgmboy-mdx-inspect >/dev/null
MDX_BUILT="$ROOT_DIR/.build/arm64-apple-macosx/release/vgmboy-mdx-inspect"
[[ -x "$MDX_BUILT" ]] || { echo "Missing built MDX inspector: $MDX_BUILT" >&2; exit 1; }
cp -X "$MDX_BUILT" "$MDX_OUTPUT"
chmod 755 "$MDX_OUTPUT"

swift build --disable-sandbox --package-path "$ROOT_DIR" --configuration release --product vgmboy-ffmpeg-inspect >/dev/null
FFMPEG_BUILT="$ROOT_DIR/.build/arm64-apple-macosx/release/vgmboy-ffmpeg-inspect"
[[ -x "$FFMPEG_BUILT" ]] || { echo "Missing built FFmpeg inspector: $FFMPEG_BUILT" >&2; exit 1; }
cp -X "$FFMPEG_BUILT" "$FFMPEG_OUTPUT"
chmod 755 "$FFMPEG_OUTPUT"

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
echo "mdx: $MDX_OUTPUT"
echo "amiga: $AMIGA_OUTPUT"
echo "ffmpeg: $FFMPEG_OUTPUT"
echo "highly-complete: build through VGMBoy Package.swift product"
