#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build_jobs="${COCOASPICE_BUILD_JOBS:-4}"
patch="$root/patches/vgmstream-cocoaspice.patch"
source_dir="$root/vendor/vgmstream"
build_dir="$root/.build/vgmstream"
library="$build_dir/src/libvgmstream.a"
stamp="$build_dir/cocoaspice-inputs.sha256"
export PKG_CONFIG_PATH="/opt/homebrew/opt/ffmpeg/lib/pkgconfig:/opt/homebrew/opt/libvorbis/lib/pkgconfig:/opt/homebrew/opt/libogg/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

if [[ -e "$source_dir/.git" ]]; then
  if git -C "$source_dir" apply --check "$patch" >/dev/null 2>&1; then
    git -C "$source_dir" apply "$patch"
  elif ! git -C "$source_dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "vgmstream source does not match the VGMBoy compatibility patch" >&2
    exit 1
  fi
else
  # Apply forward-only. Plain patch can auto-reverse a matching hunk, which
  # made repeated frontend builds toggle this compatibility change.
  if patch --dry-run --forward -p1 -d "$source_dir" < "$patch" >/dev/null 2>&1; then
    patch --forward -p1 -d "$source_dir" < "$patch" >/dev/null
  elif ! patch --dry-run --reverse -p1 -d "$source_dir" < "$patch" >/dev/null 2>&1; then
    echo "vgmstream source does not match the VGMBoy compatibility patch" >&2
    exit 1
  fi
fi

input_signature() {
  {
    printf '%s\n' 'CocoaSpice vgmstream build inputs v2'
    printf '%s\n' 'BUILD_CLI=OFF BUILD_STATIC=ON BUILD_SHARED_LIBS=OFF USE_FFMPEG=ON USE_MPEG=OFF USE_VORBIS=ON USE_G7221=ON USE_G719=OFF USE_ATRAC9=OFF USE_CELT=OFF USE_SPEEX=OFF'
    shasum -a 256 "$0" "$patch"
    # The fetched FFmpeg checkout is a large, immutable build input. Hashing
    # every one of its files on every frontend launch made a valid dependency
    # cache look hung for minutes. Its revision is controlled by vgmstream's
    # dependency declaration; force a rebuild with COCOASPICE_REBUILD_VGMSTREAM=1
    # when that vendored checkout is intentionally changed.
    find "$source_dir" \
      -type f \
      -not -path '*/.git/*' \
      -not -path "$source_dir/dependencies/ffmpeg/*" |
      sort |
      xargs shasum -a 256
    cmake --version | head -n 1
    cc --version | head -n 1
    pkg-config --modversion libavcodec vorbis ogg
  } | shasum -a 256 | awk '{ print $1 }'
}

signature="$(input_signature)"
if [[ "${COCOASPICE_REBUILD_VGMSTREAM:-0}" != "1" && -f "$library" && -f "$stamp" && "$(<"$stamp")" == "$signature" ]]; then
  echo "vgmstream native build is current."
  exit 0
fi

cmake -S "$source_dir" -B "$build_dir" \
  -DBUILD_CLI=OFF \
  -DBUILD_STATIC=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_PREFIX_PATH=/opt/homebrew \
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
cmake --build "$build_dir" --target libvgmstream --parallel "$build_jobs"
printf '%s\n' "$signature" > "$stamp"
