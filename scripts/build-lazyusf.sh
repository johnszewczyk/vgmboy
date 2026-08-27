#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/vendor/lazyusf2"
BUILD_DIR="$ROOT_DIR/.build/lazyusf"
PATCH_FILE="$ROOT_DIR/patches/lazyusf2-render-safety.patch"

mkdir -p "$BUILD_DIR"

if ! rg -q "usf_set_render_timeout_ms" "$SOURCE_DIR/usf/usf.h"; then
  patch -l -p1 -d "$SOURCE_DIR" < "$PATCH_FILE" >/dev/null
fi

make -C "$SOURCE_DIR" liblazyusf.a \
  CC="${CC:-cc}" \
  AR="${AR:-ar}" \
  CFLAGS="-c -O2 -fPIC -I. -I$ROOT_DIR/vendor/psflib -Wno-return-type -Wno-pointer-to-int-cast -Wno-pointer-sign -Wno-shift-negative-value -Wno-macro-redefined" \
  OPTS="" \
  ROPTS="-DARCH_MIN_ARM_NEON" \
  >/dev/null

cc -c -O2 -fPIC -I"$ROOT_DIR/vendor/psflib" "$ROOT_DIR/vendor/psflib/psflib.c" -o "$BUILD_DIR/psflib.o"
ar rcs "$BUILD_DIR/libpsflib.a" "$BUILD_DIR/psflib.o"
cp "$SOURCE_DIR/liblazyusf.a" "$BUILD_DIR/liblazyusf.a"
