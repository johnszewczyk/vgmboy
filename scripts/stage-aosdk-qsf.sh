#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/vendor/aosdk"
PATCH_FILE="$ROOT_DIR/patches/aosdk-qsf-lifecycle.patch"
DESTINATION="${1:?destination directory is required}"

rm -rf "$DESTINATION"
mkdir -p "$(dirname "$DESTINATION")"
ditto "$SOURCE_DIR/" "$DESTINATION/"

# The vendor checkout is an upstream gitlink. Apply VGMBoy's compatibility
# patch only to the disposable build copy so the checkout remains inspectable
# and the build does not depend on hidden working-tree edits.
rm -rf "$DESTINATION/.git" "$DESTINATION/obj"
find "$DESTINATION" -type f -name .DS_Store -delete
patch --batch --forward --directory "$DESTINATION" --strip=1 < "$PATCH_FILE" >/dev/null
