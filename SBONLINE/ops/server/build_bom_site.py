#!/usr/bin/env python3
"""Stage the canonical BOM V4 site for the private-admin release bundle."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


DERIVED_FILES = (
    "Sources/Derived/BoM/bom-data.js",
    "Sources/Derived/BoM/trim-catalog.js",
    "Sources/Derived/BoM/trim-index.js",
    "Sources/Derived/KJV/kjv-data.js",
    "Sources/Derived/Variants/world-english-bible-protestant/webp-data.js",
    "Sources/Derived/Variants/berean-standard-bible/bsb-data.js",
    "Sources/Derived/Analysis/plagiarism-data.js",
    "Sources/Derived/Analysis/plagiarism-index.js",
    "Sources/Derived/Analysis/language-index.js",
    "Sources/Derived/Analysis/facsimile-matches.js",
    "Sources/Derived/Reader/lds-doctrine-and-covenants.js",
    "Sources/Derived/Reader/lds-pearl-of-great-price.js",
    "Sources/Derived/Reports/report-catalog.js",
    "Sources/Derived/BoM/reader-match-index.js",
    "Sources/Derived/BoM/search-index.js",
    "Sources/Derived/BoM/reader-index.js",
    "Sources/Derived/BoM/location-index.js",
    "Sources/Derived/BoM/Summaries/modern-summary-index.js",
    "Sources/Derived/BoM/Summaries/narrative-retelling-index.js",
    "Sources/Derived/BoM/Summaries/official-summary-index.js",
)


def copy_file(source_root: Path, output_root: Path, relative: str) -> None:
    source = source_root / relative
    if not source.is_file():
        raise SystemExit(f"Required BOM site asset is missing: {source}")
    destination = output_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def copy_tree(source: Path, destination: Path) -> None:
    if not source.is_dir():
        raise SystemExit(f"Required BOM site directory is missing: {source}")
    shutil.copytree(source, destination, dirs_exist_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bom_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()

    bom_root = args.bom_root.resolve()
    output_root = args.output_root.resolve()
    if not (bom_root / "Sites/V4/reader.html").is_file():
        raise SystemExit(f"Not a BOM project checkout: {bom_root}")
    if output_root == bom_root or output_root.is_relative_to(bom_root):
        raise SystemExit("The staging directory must be outside the BOM checkout.")
    if output_root.exists() and any(output_root.iterdir()):
        raise SystemExit(f"The staging directory must be new or empty: {output_root}")
    output_root.mkdir(parents=True, exist_ok=True)

    copy_tree(bom_root / "Sites/V4", output_root / "Sites/V4")
    copy_tree(bom_root / "Shared", output_root / "Shared")
    copy_file(bom_root, output_root, "Sites/reader-preferences.js")
    copy_file(bom_root, output_root, "Sites/Analysis/themes-data.js")
    for relative in DERIVED_FILES:
        copy_file(bom_root, output_root, relative)
    copy_tree(
        bom_root / "Sources/Derived/BoM/Chapters",
        output_root / "Sources/Derived/BoM/Chapters",
    )
    copy_tree(
        bom_root / "Sources/Original/Reports",
        output_root / "Sources/Original/Reports",
    )
    copy_tree(
        bom_root / "Sources/Original/Project-Gutenberg/Book-of-Mormon-17/Summaries/Abridged",
        output_root / "Sources/Original/Project-Gutenberg/Book-of-Mormon-17/Summaries/Abridged",
    )

    notes_directory = output_root / "Sites/V4/Notes"
    build_notes = bom_root / "WKWebView/build_notes_bundle.py"
    notes_api = bom_root / "WKWebView/notes-embedded-api.js"
    if not build_notes.is_file() or not notes_api.is_file():
        raise SystemExit("The BOM Notes bundle builder or read-only API is missing.")
    subprocess.run(
        [sys.executable, str(build_notes), str(bom_root), str(notes_directory / "notes-data.js")],
        check=True,
    )
    shutil.copy2(notes_api, notes_directory / "notes-embedded-api.js")

    notes_page = output_root / "Sites/V4/notes.html"
    html = notes_page.read_text(encoding="utf-8")
    notes_script = '<script src="notes.js?v=4" defer></script>'
    if html.count(notes_script) != 1:
        raise SystemExit("Could not locate the canonical V4 Notes script insertion point.")
    html = html.replace(
        notes_script,
        '  <script src="Notes/notes-data.js" defer></script>\n'
        '  <script src="Notes/notes-embedded-api.js" defer></script>\n'
        f"  {notes_script}",
        1,
    )
    edit_button = '<button class="edit-source-button" id="edit-source" type="button" disabled>Edit Markdown</button>'
    if html.count(edit_button) != 1:
        raise SystemExit("Could not locate the canonical Notes edit control.")
    html = html.replace(edit_button, edit_button.replace(" type=", " hidden type="), 1)
    edit_copy = "Browse, read, and edit the local Markdown research files."
    if html.count(edit_copy) != 1:
        raise SystemExit("Could not locate the canonical Notes introduction copy.")
    html = html.replace(edit_copy, "Browse and read the bundled Markdown research files.", 1)
    notes_page.write_text(html, encoding="utf-8")

    try:
        revision = subprocess.run(
            ["git", "-C", str(bom_root), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        revision = "unknown"
    manifest = {
        "site": "BOM V4",
        "sourceRevision": revision,
        "entry": "Sites/V4/reader.html",
        "notes": "bundled read-only snapshot",
    }
    (output_root / "build-info.json").write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )

    total_bytes = sum(path.stat().st_size for path in output_root.rglob("*") if path.is_file())
    print(f"Staged BOM V4 from {revision}: {total_bytes / (1024 * 1024):.1f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
