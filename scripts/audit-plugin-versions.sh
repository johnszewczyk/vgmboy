#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${VGMBoy_PLUGIN_MANIFEST:-$ROOT_DIR/Docs/plugin-versions.json}"
OFFLINE=0
JSON_OUTPUT=0
STRICT=0

for argument in "$@"; do
    case "$argument" in
        --offline) OFFLINE=1 ;;
        --json) JSON_OUTPUT=1 ;;
        --strict) STRICT=1 ;;
        -h|--help)
            echo "Usage: $0 [--offline] [--json] [--strict]"
            echo "Audit pinned VGMBoy decoder milestones without changing source or builds."
            echo "--strict returns nonzero when a review or source problem is found."
            exit 0
            ;;
        *) echo "Unknown option: $argument" >&2; exit 64 ;;
    esac
done

[[ -f "$MANIFEST" ]] || { echo "Missing plugin manifest: $MANIFEST" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required to read the JSON manifest" >&2; exit 1; }

export ROOT_DIR MANIFEST OFFLINE JSON_OUTPUT STRICT
python3 - <<'PY'
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

root = os.environ["ROOT_DIR"]
manifest_path = os.environ["MANIFEST"]
offline = os.environ["OFFLINE"] == "1"
json_output = os.environ["JSON_OUTPUT"] == "1"

with open(manifest_path, encoding="utf-8") as handle:
    manifest = json.load(handle)

def version_key(value):
    parts = []
    for part in value.lstrip("vV").replace("-", ".").split("."):
        digits = "".join(character for character in part if character.isdigit())
        parts.append((0, int(digits)) if digits else (1, part.lower()))
    return tuple(parts)

def latest_tag(remote):
    if not remote or offline:
        return None
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--tags", "--refs", remote],
            check=True, capture_output=True, text=True, timeout=20,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    tags = []
    for line in result.stdout.splitlines():
        fields = line.split("\t", 1)
        if len(fields) != 2:
            continue
        ref = fields[1]
        if ref.startswith("refs/tags/"):
            tags.append(ref.removeprefix("refs/tags/"))
    versioned = [tag for tag in tags if any(character.isdigit() for character in tag)]
    return max(versioned, key=version_key) if versioned else (sorted(tags)[-1] if tags else None)

def homebrew_version(formula):
    if not formula:
        return None
    try:
        result = subprocess.run(
            ["brew", "list", "--versions", formula],
            check=False, capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    fields = result.stdout.strip().split()
    return fields[1] if len(fields) > 1 else None

def homebrew_latest(formula):
    if not formula or offline:
        return None
    try:
        result = subprocess.run(
            ["brew", "info", "--json=v2", "--formula", formula],
            check=False, capture_output=True, text=True, timeout=20,
        )
        data = json.loads(result.stdout)
        formulae = data.get("formulae", [])
        return formulae[0].get("versions", {}).get("stable") if formulae else None
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return None

rows = []
for plugin in manifest["plugins"]:
    source = plugin.get("source", "")
    source_exists = not source or os.path.exists(os.path.join(root, source))
    result = {
        "id": plugin["id"],
        "name": plugin["name"],
        "kind": plugin["kind"],
        "current": plugin["current"],
        "upstream": plugin.get("upstream", ""),
        "sourcePresent": source_exists,
        "latestTag": None,
        "installed": None,
        "latestFormula": None,
        "status": "OK",
        "note": "",
    }
    if not source_exists:
        result["status"] = "MISSING-SOURCE"
        result["note"] = source
    elif plugin["kind"] == "snapshot" or plugin.get("milestoneCheck") == "manual":
        result["status"] = "MANUAL-REVIEW"
        result["note"] = "upstream revision or release baseline is not machine-pinned"
    elif plugin["kind"] == "homebrew":
        installed = homebrew_version(plugin.get("formula"))
        latest = homebrew_latest(plugin.get("formula"))
        result["installed"] = installed
        result["latestFormula"] = latest
        if installed is None:
            result["status"] = "NOT-INSTALLED"
            result["note"] = plugin.get("formula", "")
        elif latest and version_key(latest) > version_key(installed):
            result["status"] = "REVIEW"
            result["note"] = "newer Homebrew formula version is available"
        elif version_key(installed) != version_key(plugin["current"]):
            result["status"] = "REVIEW"
            result["note"] = "installed version differs from manifest"
    else:
        latest = latest_tag(plugin.get("upstream", ""))
        result["latestTag"] = latest
        if offline:
            result["status"] = "OFFLINE"
            result["note"] = "remote milestone lookup skipped"
        elif latest is None:
            result["status"] = "REVIEW"
            result["note"] = "no readable upstream tag"
        elif any(character.isdigit() for character in plugin["current"]):
            result["status"] = "REVIEW"
            result["note"] = "compare pinned commit with the latest milestone tag"
    rows.append(result)

if json_output:
    print(json.dumps({"manifest": manifest_path, "rows": rows}, indent=2, sort_keys=True))
else:
    print(f"Plugin milestone audit: {manifest_path}")
    print(f"Last reviewed: {manifest['lastReviewed']} • interval: {manifest['reviewIntervalDays']} days")
    for row in rows:
        details = []
        if row["installed"]:
            details.append(f"installed={row['installed']}")
        if row["latestTag"]:
            details.append(f"latest-tag={row['latestTag']}")
        if row["latestFormula"]:
            details.append(f"latest-formula={row['latestFormula']}")
        if row["note"]:
            details.append(row["note"])
        suffix = f" — {'; '.join(details)}" if details else ""
        print(f"[{row['status']}] {row['name']} ({row['id']}) current={row['current']}{suffix}")

review_statuses = {"MISSING-SOURCE", "MANUAL-REVIEW", "REVIEW"}
strict = os.environ["STRICT"] == "1"
sys.exit(1 if strict and any(row["status"] in review_statuses for row in rows) else 0)
PY
