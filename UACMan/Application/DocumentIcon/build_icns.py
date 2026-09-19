#!/usr/bin/env python3
"""Build UACMan's multi-resolution macOS document icon from its PNG artwork."""

from __future__ import annotations

import os
import struct
import subprocess
import tempfile
from pathlib import Path


ASSET_DIR = Path(__file__).resolve().parent
SOURCE = ASSET_DIR / "UACDocumentIcon.png"
OUTPUT = ASSET_DIR / "UACDocumentIcon.icns"
ICON_REPRESENTATIONS = (
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing icon artwork: {SOURCE}")

    chunks: list[bytes] = []
    with tempfile.TemporaryDirectory(prefix="uacman-icon-") as temporary:
        temporary_dir = Path(temporary)
        for chunk_name, size in ICON_REPRESENTATIONS:
            png_path = temporary_dir / f"{size}.png"
            subprocess.run(
                ["sips", "-z", str(size), str(size), str(SOURCE), "--out", str(png_path)],
                check=True,
                capture_output=True,
                text=True,
            )
            png = png_path.read_bytes()
            if not png.startswith(b"\x89PNG\r\n\x1a\n"):
                raise SystemExit(f"sips did not produce a PNG image at {size}px")
            width, height = struct.unpack(">II", png[16:24])
            if (width, height) != (size, size):
                raise SystemExit(f"Unexpected {size}px icon dimensions: {width}x{height}")
            chunks.append(
                chunk_name.encode("ascii")
                + struct.pack(">I", len(png) + 8)
                + png
            )

        payload = b"".join(chunks)
        icns = b"icns" + struct.pack(">I", len(payload) + 8) + payload
        temporary_output = temporary_dir / OUTPUT.name
        temporary_output.write_bytes(icns)
        os.replace(temporary_output, OUTPUT)

    print(f"Wrote {OUTPUT} ({OUTPUT.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
