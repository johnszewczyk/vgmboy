#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$ROOT/.build/site"

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT/assets"
cp "$ROOT/index.html" "$OUTPUT/index.html"
cp "$ROOT/assets/ModernDOS8x16.ttf" "$OUTPUT/assets/ModernDOS8x16.ttf"
cp "$ROOT/assets/CC0-1.0.txt" "$OUTPUT/assets/CC0-1.0.txt"

printf 'Built LineBoy static site: %s\n' "$OUTPUT"
