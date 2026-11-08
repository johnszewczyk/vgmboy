#!/usr/bin/env python3
"""Split the old SBO virtual hosts out of MathBook's combined Nginx file."""

from __future__ import annotations

import os
import re
import stat
import sys
import tempfile
from pathlib import Path


ADMIN_SERVER = re.compile(r"(?m)^\s*server_name\s+admin\.pre-calc\.com\s*;")
LEGACY_LIMIT_ZONE = re.compile(r"(?m)^\s*limit_req_zone\s+\$binary_remote_addr\s+zone=private_admin_auth:.*\n?")
SERVER_OPEN = re.compile(r"(?m)^server\s*\{")


def server_blocks(source: str) -> list[tuple[int, int, str]]:
    blocks = []
    for match in SERVER_OPEN.finditer(source):
        opening = source.find("{", match.start(), match.end())
        depth = 0
        closing = None
        for index in range(opening, len(source)):
            char = source[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    closing = index + 1
                    break
        if closing is None:
            raise ValueError("Unclosed Nginx server block.")
        blocks.append((match.start(), closing, source[match.start():closing]))
    return blocks


def migrate(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    blocks = server_blocks(original)
    admin_blocks = [(start, end) for start, end, block in blocks if ADMIN_SERVER.search(block)]
    if not admin_blocks:
        return False
    if len(admin_blocks) != 2 or len(blocks) < 4:
        raise ValueError("Unexpected legacy Nginx layout; no files were changed.")

    updated = original
    for start, end in reversed(admin_blocks):
        updated = updated[:start] + updated[end:]
    updated = LEGACY_LIMIT_ZONE.sub("", updated)
    if ADMIN_SERVER.search(updated) or "private_admin_auth" in updated:
        raise ValueError("Legacy SBO Nginx rules remain; no files were changed.")
    if "server_name pre-calc.com www.pre-calc.com _;" not in updated:
        raise ValueError("The Pre-Calc virtual host was not preserved; no files were changed.")

    metadata = path.stat()
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        os.chown(temporary, metadata.st_uid, metadata.st_gid)
        os.chmod(temporary, stat.S_IMODE(metadata.st_mode))
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
    return True


if __name__ == "__main__":
    try:
        changed = migrate(Path(sys.argv[1]))
    except (IndexError, OSError, ValueError) as error:
        raise SystemExit(f"Nginx ownership migration failed: {error}")
    print("Removed legacy SBO rules from MathBook Nginx config." if changed else "No legacy SBO rules found.")
