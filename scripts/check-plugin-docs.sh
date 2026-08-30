#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${VGMBoy_PLUGIN_MANIFEST:-$ROOT_DIR/Docs/plugin-versions.json}"
CATALOG="${VGMBoy_PLUGIN_CATALOG:-$ROOT_DIR/Docs/plugin-catalog.md}"

[[ -f "$MANIFEST" ]] || { echo "Missing plugin manifest: $MANIFEST" >&2; exit 1; }
[[ -f "$CATALOG" ]] || { echo "Missing plugin catalog: $CATALOG" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required to read the JSON manifest" >&2; exit 1; }

export MANIFEST CATALOG
python3 - <<'PY'
import json
import os
import sys

manifest_path = os.environ["MANIFEST"]
catalog_path = os.environ["CATALOG"]

with open(manifest_path, encoding="utf-8") as handle:
    manifest = json.load(handle)
with open(catalog_path, encoding="utf-8") as handle:
    catalog = handle.read()

missing = []
for plugin in manifest.get("plugins", []):
    for field in ("id", "current"):
        value = str(plugin.get(field, ""))
        if value and value not in catalog:
            missing.append(f"{plugin.get('id', '<unknown>')}:{field}={value}")

review_date = str(manifest.get("lastReviewed", ""))
if review_date and review_date not in catalog:
    missing.append(f"lastReviewed={review_date}")

if missing:
    print("Plugin documentation drift detected:", file=sys.stderr)
    for entry in missing:
        print(f"- {entry}", file=sys.stderr)
    sys.exit(1)

print(f"Plugin documentation is consistent: {len(manifest.get('plugins', []))} entries; reviewed {review_date}.")
PY
