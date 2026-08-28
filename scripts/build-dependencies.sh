#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_BUILD_ROOT="$ROOT_DIR/.build"
DEPENDENCY_ROOT="$ROOT_DIR/.build/dependencies"
STAMP_ROOT="$ROOT_DIR/.build/dependency-stamps"

[[ -f "$ROOT_DIR/Package.swift" ]] || {
    echo "Missing VGMBoy package: $ROOT_DIR" >&2
    exit 1
}

mkdir -p "$DEPENDENCY_ROOT" "$STAMP_ROOT"

dependency_signature() {
    local source_relative="$1"
    shift
    {
        local input
        for input in "$@"; do
            shasum -a 256 "$ROOT_DIR/$input"
        done
        if [[ -d "$ROOT_DIR/$source_relative/.git" ]]; then
            git -C "$ROOT_DIR/$source_relative" rev-parse HEAD
            git -C "$ROOT_DIR/$source_relative" diff --binary HEAD
        else
            git -C "$ROOT_DIR" rev-parse "HEAD:$source_relative" 2>/dev/null || true
            git -C "$ROOT_DIR" diff --binary HEAD -- "$source_relative"
            # A checked-out gitlink has no diff visible from the parent
            # repository. Hash its working tree too, so local compatibility
            # changes cannot be hidden behind a stale dependency product.
            if [[ -d "$ROOT_DIR/$source_relative" ]]; then
                find "$ROOT_DIR/$source_relative" -type f -print0 \
                    | sort -z \
                    | xargs -0 shasum -a 256
            fi
        fi
        cmake --version 2>/dev/null | head -n 1 || true
        "${CC:-cc}" --version 2>/dev/null | head -n 1 || true
    } | shasum -a 256 | awk '{ print $1 }'
}

ensure_dependency() {
    local name="$1"
    local source_relative="$2"
    local output_relative="$3"
    local build_script="$4"
    shift 4
    local signature
    signature="$(dependency_signature "$source_relative" "scripts/$build_script" "$@")"
    local stamp="$STAMP_ROOT/$name.sha256"
    if [[ -f "$ROOT_DIR/$output_relative" && -f "$stamp" && "$(<"$stamp")" == "$signature" ]]; then
        echo "Reusing $name dependency product ($signature)"
        return
    fi
    "$ROOT_DIR/scripts/$build_script"
    [[ -f "$ROOT_DIR/$output_relative" ]] || {
        echo "Missing $name dependency product: $ROOT_DIR/$output_relative" >&2
        exit 1
    }
    # A build script may apply a tracked compatibility patch to a gitlink
    # source tree. Record the post-build source state, not the pre-patch one,
    # so the next invocation can reuse the product deterministically.
    signature="$(dependency_signature "$source_relative" "scripts/$build_script" "$@")"
    printf '%s\n' "$signature" > "$stamp"
}

copy_dependency() {
    local name="$1"
    local source="$2"
    local destination="$DEPENDENCY_ROOT/$name"
    local source_stamp="$STAMP_ROOT/$name.sha256"
    local destination_stamp="$destination/.vgmboy-inputs.sha256"
    [[ -e "$source" ]] || { echo "Missing built dependency: $source" >&2; exit 1; }
    if [[ -f "$source_stamp" && -f "$destination_stamp" ]] && cmp -s "$source_stamp" "$destination_stamp"; then
        echo "Reusing packaged $name dependency"
        return
    fi
    rm -rf "$destination"
    mkdir -p "$destination"
    ditto "$source" "$destination"
    install -m 644 "$source_stamp" "$destination_stamp"
}

ensure_dependency libvgm vendor/libvgm .build/libvgm/bin/libvgm-player.a build-libvgm.sh
ensure_dependency mgba vendor/mgba .build/mgba/libmgba.a build-mgba.sh
ensure_dependency 2sf vendor/2sf2wav .build/2sf/lib2sf.a build-2sf.sh
ensure_dependency lazyusf vendor/lazyusf2 .build/lazyusf/liblazyusf.a build-lazyusf.sh patches/lazyusf2-render-safety.patch
[[ -f "$SOURCE_BUILD_ROOT/lazyusf/libpsflib.a" ]] || "$ROOT_DIR/scripts/build-lazyusf.sh"
ensure_dependency play-psf vendor/play .build/play-psf/libcocoaspice_play_psf.a build-play-psf.sh patches/play-psfcore-only.patch
ensure_dependency qsf vendor/aosdk .build/qsf/libvgmboy_qsf.a build-qsf.sh
ensure_dependency vgmstream vendor/vgmstream .build/vgmstream/src/libvgmstream.a build-vgmstream.sh patches/vgmstream-cocoaspice.patch
ensure_dependency psgplay vendor/psgplay .build/psgplay/libpsgplay.a build-psgplay.sh

copy_dependency libvgm "$SOURCE_BUILD_ROOT/libvgm"
copy_dependency mgba "$SOURCE_BUILD_ROOT/mgba"
copy_dependency 2sf "$SOURCE_BUILD_ROOT/2sf"
copy_dependency lazyusf "$SOURCE_BUILD_ROOT/lazyusf"
copy_dependency play-psf "$SOURCE_BUILD_ROOT/play-psf"
copy_dependency qsf "$SOURCE_BUILD_ROOT/qsf"
copy_dependency vgmstream "$SOURCE_BUILD_ROOT/vgmstream"
copy_dependency psgplay "$SOURCE_BUILD_ROOT/psgplay"

echo "VGMBoy dependencies ready: $DEPENDENCY_ROOT"
