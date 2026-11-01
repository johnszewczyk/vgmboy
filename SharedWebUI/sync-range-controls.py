#!/usr/bin/env python3
"""Sync the canonical WebKit range-control assets into app resource bundles."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "SharedWebUI"
DESTINATIONS = (
    ROOT / "SB2/Sources/SB2/Resources",
    ROOT / "APPBOY/Sources/APPBOY/Resources/WebUI",
    ROOT / "VGMBoy/Sources/VGMBoyApp/Resources",
)
NAMES = ("range-controls.css", "range-controls.js")

parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true")
args = parser.parse_args()

for name in NAMES:
    source = SOURCE / name
    for destination_root in DESTINATIONS:
        destination = destination_root / name
        if args.check:
            if not destination.exists() or destination.read_bytes() != source.read_bytes():
                raise SystemExit(f"Shared WebKit control drift: {destination}")
        else:
            destination.write_bytes(source.read_bytes())

print("Shared WebKit range controls match all app bundles." if args.check else "Synced shared WebKit range controls to app bundles.")
