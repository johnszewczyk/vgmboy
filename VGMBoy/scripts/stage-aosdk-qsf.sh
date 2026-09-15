#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/vendor/aosdk"
PATCH_FILE="$ROOT_DIR/patches/aosdk-qsf-lifecycle.patch"
DESTINATION="${1:?destination directory is required}"

rm -rf "$DESTINATION"
mkdir -p "$(dirname "$DESTINATION")"
ditto "$SOURCE_DIR/" "$DESTINATION/"

# The vendor source is a flattened upstream snapshot. Apply VGMBoy's
# compatibility patch only to the disposable build copy so the checked-in
# snapshot remains inspectable and the build has no hidden source edits.
rm -rf "$DESTINATION/.git" "$DESTINATION/obj"
find "$DESTINATION" -type f -name .DS_Store -delete
patch --batch --forward --directory "$DESTINATION" --strip=1 < "$PATCH_FILE" >/dev/null
