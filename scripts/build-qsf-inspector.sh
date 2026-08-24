#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AO="$ROOT_DIR/vendor/aosdk"
OUT="$ROOT_DIR/.build/scanner-plugins/vgmboy-qsf-inspect"
BUILD="$ROOT_DIR/.build/qsf-inspect"
mkdir -p "$BUILD" "$(dirname "$OUT")"

cc=${CC:-clang}
cflags=(-O2 -DNDEBUG -DLSB_FIRST=1 -DHAVE_STDINT_H -DPATH_MAX=2048
  -I"$AO" -I"$AO/eng_qsf" -I"$AO/eng_ssf" -I"$AO/eng_dsf")
sources=(
  "$ROOT_DIR/Sources/VGMBoyQSFInspect/main.c"
  "$AO/eng_qsf/eng_qsf.c" "$AO/eng_qsf/kabuki.c" "$AO/eng_qsf/qsound.c"
  "$AO/eng_qsf/z80.c" "$AO/eng_qsf/z80dasm.c"
  "$AO/corlett.c" "$AO/utils.c"
  "$AO/zlib/adler32.c" "$AO/zlib/compress.c" "$AO/zlib/crc32.c"
  "$AO/zlib/deflate.c" "$AO/zlib/gzio.c" "$AO/zlib/infback.c"
  "$AO/zlib/inffast.c" "$AO/zlib/inflate.c" "$AO/zlib/inftrees.c"
  "$AO/zlib/trees.c" "$AO/zlib/uncompr.c" "$AO/zlib/zutil.c"
)
objects=()
for source in "${sources[@]}"; do
  object="$BUILD/$(basename "$source" .c).o"
  "$cc" "${cflags[@]}" -c "$source" -o "$object"
  objects+=("$object")
done
"$cc" -o "$OUT" "${objects[@]}" -lm
chmod 755 "$OUT"
echo "$OUT"
