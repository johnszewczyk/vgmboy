#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/vendor/psgplay"
BUILD_DIR="$ROOT_DIR/.build/psgplay"

[[ -f "$SOURCE_DIR/Makefile" ]] || {
  echo "Missing vendored psgplay source at $SOURCE_DIR" >&2
  exit 1
}
[[ -f "$SOURCE_DIR/lib/cf2149/module/cf2149.c" ]] || {
  echo "psgplay submodules are not initialized; run git submodule update --init --recursive" >&2
  exit 1
}

mkdir -p "$BUILD_DIR"
make -C "$SOURCE_DIR" lib/psgplay/libpsgplay.a CC="${CC:-cc}"
cp "$SOURCE_DIR/lib/psgplay/libpsgplay.a" "$BUILD_DIR/libpsgplay.a"
echo "Built $BUILD_DIR/libpsgplay.a"
