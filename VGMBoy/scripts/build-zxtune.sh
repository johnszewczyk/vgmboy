#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="${VGMBoy_ZXTUNE_SOURCE:-$ROOT_DIR/vendor/zxtune}"
OUTPUT_DIR="$ROOT_DIR/.build/zxtune"
JOBS="${VGMBoy_BUILD_JOBS:-4}"

[[ -f "$ROOT_DIR/Package.swift" ]] || {
    echo "Missing VGMBoy package: $ROOT_DIR" >&2
    exit 1
}
[[ -f "$SOURCE_DIR/src/core/plugins/players/Makefile" ]] || {
    echo "Missing ZXTune source checkout: $SOURCE_DIR" >&2
    exit 1
}

if ! rg -q "Subdata\.use_count\(\)" "$SOURCE_DIR/src/core/plugins/archives/raw_supp.cpp"; then
    if [[ -d "$SOURCE_DIR/.git" ]]; then
        git -C "$SOURCE_DIR" apply "$ROOT_DIR/patches/zxtune-modern-libcxx.patch"
    else
        echo "ZXTune source is missing the tracked modern-libcxx compatibility patch: $SOURCE_DIR" >&2
        exit 1
    fi
fi

MAKE_ARGS=(
    platform=darwin
    system.zlib=1
    "cxx_flags=-idirafter/opt/homebrew/include -DFMT_CONSTEVAL="
)

# Build only the AY-family dependency graph. ZXTune's full desktop player
# also builds unrelated archive and legacy-player backends; the VGMBoy bridge
# registers the AY-family plugins directly and therefore keeps those optional
# dependencies out of the shipped decoder.
for component in \
    3rdparty/lhasa \
    3rdparty/lzma \
    3rdparty/z80ex \
    src/analysis \
    src/async \
    src/binary \
    src/binary/compression \
    src/binary/format \
    src/core \
    src/debug \
    src/devices/aym \
    src/devices/aym/dumper \
    src/devices/z80 \
    src/formats/chiptune \
    src/formats/multitrack \
    src/module/conversion \
    src/module/players \
    src/module/properties \
    src/parameters \
    src/platform \
    src/platform/version \
    src/sound \
    src/strings \
    src/tools \
    src/l10n/stub \
    src/core/plugins/players; do
    make "${MAKE_ARGS[@]}" -C "$SOURCE_DIR/$component" -j"$JOBS"
done

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
ditto "$SOURCE_DIR/lib" "$OUTPUT_DIR/lib"
cp "$SOURCE_DIR/obj/darwin/release/core/scan_result.cpp.o" "$OUTPUT_DIR/scan_result.cpp.o"
ZXTUNE_LIB_DIR="$OUTPUT_DIR/lib/darwin/release"
"${CXX:-clang++}" \
    -std=c++20 \
    -O2 \
    -idirafter/opt/homebrew/include \
    -DFMT_CONSTEVAL= \
    -I"$ROOT_DIR/Sources/CZXTune/include" \
    -I"$SOURCE_DIR" \
    -I"$SOURCE_DIR/include" \
    -I"$SOURCE_DIR/src" \
    -I"$SOURCE_DIR/3rdparty/fmt/include" \
    "$ROOT_DIR/Sources/CZXTune/vgmboy_zxtune.cpp" \
    "$ROOT_DIR/Sources/CZXTune/zxtune_inspect.cpp" \
    "$OUTPUT_DIR/scan_result.cpp.o" \
    -L"$ZXTUNE_LIB_DIR" \
    -lcore_plugins_players \
    -lmodule_players \
    -lmodule_properties \
    -lmodule_conversion \
    -lformats_chiptune \
    -lformats_multitrack \
    -ldevices_aym \
    -ldevices_aym_dumper \
    -lsound \
    -lbinary_format \
    -lbinary \
    -lbinary_compression \
    -lanalysis \
    -lparameters \
    -lstrings \
    -ltools \
    -ldebug \
    -lplatform \
    -lasync \
    -ll10n_stub \
    -llhasa \
    -lz80ex \
    -lz \
    -o "$OUTPUT_DIR/vgmboy-zxtune-inspect"
chmod 755 "$OUTPUT_DIR/vgmboy-zxtune-inspect"
printf '%s\n' "$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || printf 'vendored-source')" > "$OUTPUT_DIR/source-revision"

[[ -f "$OUTPUT_DIR/lib/darwin/release/libcore_plugins_players.a" ]] || {
    echo "Missing ZXTune AY player library." >&2
    exit 1
}
[[ -f "$OUTPUT_DIR/lib/darwin/release/libformats_chiptune.a" ]] || {
    echo "Missing ZXTune chiptune format library." >&2
    exit 1
}

echo "ZXTune AY-family dependencies ready: $OUTPUT_DIR"
