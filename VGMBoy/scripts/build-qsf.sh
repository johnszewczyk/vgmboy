#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT_DIR/.build/qsf"
CC_BIN="${CC:-clang}"

mkdir -p "$BUILD"
rm -f "$BUILD"/*.o "$BUILD/libvgmboy_qsf.a"
AO="$BUILD/aosdk-source"
"$ROOT_DIR/scripts/stage-aosdk-qsf.sh" "$AO"

CFLAGS=(
    -O2
    -DNDEBUG
    -DLSB_FIRST=1
    -DHAVE_STDINT_H
    -DPATH_MAX=2048
    -I"$AO"
    -I"$AO/eng_qsf"
    -I"$AO/eng_ssf"
)

sources=(
    "$AO/eng_qsf/eng_qsf.c"
    "$AO/eng_qsf/kabuki.c"
    "$AO/eng_qsf/qsound.c"
    "$AO/eng_qsf/z80.c"
    "$AO/eng_qsf/z80dasm.c"
    "$AO/corlett.c"
    "$AO/utils.c"
)

for source in "${sources[@]}"; do
    "$CC_BIN" "${CFLAGS[@]}" -c "$source" -o "$BUILD/$(basename "$source" .c).o"
done

libtool -static -o "$BUILD/libvgmboy_qsf.a" "$BUILD"/*.o
echo "Built $BUILD/libvgmboy_qsf.a"
