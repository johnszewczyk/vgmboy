#!/usr/bin/env python3
"""UAC pack, inspect, unpack, and source-archive conversion tools.

Native metadata import is delegated to UACManMetadataCLI/MetaManCore; this
module never implements a native format parser.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime
import errno
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
import unicodedata
from urllib.parse import urlsplit
import zlib
from pathlib import Path, PurePosixPath
from typing import BinaryIO

UACMAN_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent / "vendor" / "python"))

try:
    import blake3
except ImportError as error:  # pragma: no cover - environment diagnostic
    raise SystemExit(f"UACMan's vendored BLAKE3 module is unavailable: {error}") from error

UAC_SKIPPABLE_MAGIC = 0x184D2A55
UAC_METADATA_MAGIC = b"UACM"
UAC_METADATA_HEADER_SIZE = 40
UAC_MANIFEST_ZSTD_MAGIC = b"ZJ01"
UAC_COMPRESSED_MANIFEST_PREFIX_SIZE = 8
UAC_MAX_MANIFEST_SIZE = 16 * 1024 * 1024
UACMAN_VERSION = "0.2.0"
ZSTD_FRAME_MAGIC = b"\x28\xb5\x2f\xfd"
ZSTD_SEEK_TABLE_MAGIC = 0x184D2A5E
ZSTD_SEEK_TABLE_FOOTER_MAGIC = 0x8F92EAB1
ZSTD_MAX_FRAME_SIZE = 64 * 1024 * 1024
SEEKABLE_PROFILE = re.compile(r"^uac-zstd-seekable-level-(0|[1-9]|1[0-9]|2[0-2])-frame-([1-9][0-9]{0,9})-v1$")
OFFICIAL_SET_URLS = {
    ("JoshW", "Nintendo SNES"): "https://spc.joshw.info/",
    ("JoshW", "Sega Genesis"): "https://smd.joshw.info/",
    ("SNESMusicOrg", "Nintendo SNES"): "https://www.snesmusic.org/v2/",
    ("SNESMusicOrg", "Nintendo Super Game Boy"): "https://www.snesmusic.org/v2/",
    ("SNESMusicOrg", "Nintendo Super Game Boy (in joshw)"): "https://www.snesmusic.org/v2/",
    ("ZopharsDomain", "Game Boy"): "https://www.zophar.net/music/gameboy-gbs",
    ("GBS Penultimate", "Game Boy"): "https://snesmusic.org/hoot/gbs/",
    ("GBS Penultimate", "."): "https://snesmusic.org/hoot/gbs/",
    ("Project2612", "Sega Genesis"): "https://vgmrips.net/packs/system/sega/mega-drive",
    ("Project2612", "Sega 32X"): "https://vgmrips.net/packs/system/sega/32x",
    ("Project2612", "Sega CD"): "https://vgmrips.net/packs/system/sega/sega-cd",
    ("Project2612", "Mixed"): "https://vgmrips.net/packs/systems",
}
ARCHIVED_SOURCE_URLS = {"Project2612": "https://project2612.org/list.php"}
SOURCE_ARCHIVE_URLS = {
    "Project2612": "https://web.archive.org/web/20240809092444/https://project2612.org/list.php",
}
PLAYABLE_EXTENSIONS = {
    ".spc", ".vgm", ".vgz", ".nsf", ".nsfe", ".gbs", ".hes", ".kss",
    ".sid", ".s98", ".mdx", ".usf", ".gsf", ".snsf", ".wsr", ".sap",
    ".ay", ".ym", ".xgm", ".psf", ".minipsf", ".2sf", ".minigsf",
    ".aif", ".aiff", ".ape", ".flac", ".m4a", ".mp3", ".ogg", ".wav",
}


class UACError(Exception):
    pass


class HashingReader:
    def __init__(self, file: BinaryIO):
        self.file = file
        self.hasher = blake3.blake3()
        self.byte_count = 0
        self.crc32 = 0

    def read(self, size: int = -1) -> bytes:
        data = self.file.read(size)
        self.hasher.update(data)
        self.byte_count += len(data)
        self.crc32 = zlib.crc32(data, self.crc32)
        return data


def b3_file_from_offset(path: Path, offset: int = 0) -> str:
    hasher = blake3.blake3()
    with path.open("rb") as handle:
        handle.seek(offset)
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def safe_relative_path(value: str) -> bool:
    if not value or value.startswith("/") or "\\" in value or "\0" in value:
        return False
    parts = value.split("/")
    return all(part not in ("", ".", "..") for part in parts)


def safe_component(value: str) -> bool:
    return bool(value) and safe_relative_path(value) and "/" not in value


def match_unicode_member_paths(
    path_records: dict,
    expected_paths: set[str],
    context: str,
    *,
    allow_partial: bool = False,
) -> dict[str, object]:
    """Match filesystem paths to MetaMan paths despite canonical Unicode normalization."""
    expected_by_key: dict[str, str] = {}
    for expected in expected_paths:
        key = unicodedata.normalize("NFC", expected)
        previous = expected_by_key.get(key)
        if previous is not None and previous != expected:
            raise UACError(f"{context} input paths collide after Unicode normalization: {previous} and {expected}.")
        expected_by_key[key] = expected

    matched: dict[str, object] = {}
    unexpected: list[str] = []
    for reported_path, value in path_records.items():
        if not isinstance(reported_path, str):
            raise UACError(f"{context} returned a non-string member path.")
        expected = expected_by_key.get(unicodedata.normalize("NFC", reported_path))
        if expected is None:
            unexpected.append(reported_path)
            continue
        if expected in matched:
            raise UACError(f"{context} returned duplicate paths after Unicode normalization: {reported_path}.")
        matched[expected] = value

    missing = expected_paths - set(matched)
    if unexpected or (missing and not allow_partial):
        raise UACError(
            f"{context} path coverage mismatch after Unicode normalization "
            f"(missing={sorted(missing)[:5]}, unexpected={sorted(unexpected)[:5]})."
        )
    return matched


def original_member_path(relative_path: str, member_path_map: dict[str, str] | None) -> str:
    if not member_path_map:
        return relative_path
    return member_path_map.get(unicodedata.normalize("NFC", relative_path), relative_path)


def require_string(record: dict, field: str, owner: str) -> str:
    value = record.get(field)
    if not isinstance(value, str) or not value.strip():
        raise UACError(f"{owner} requires a non-empty '{field}' string.")
    return value


def normalize_recipe(recipe: dict) -> dict:
    """Fill Codable-required empty fields and reject malformed known records."""
    game = recipe["game"]
    if not isinstance(game, dict):
        raise UACError("Recipe 'game' must be an object.")
    for field in ("id", "title", "console"):
        require_string(game, field, "Recipe game")
    game.setdefault("canonicalIDs", [])
    game.setdefault("metadata", {})
    game.setdefault("extensions", {})
    if not isinstance(game["canonicalIDs"], list) or not all(isinstance(x, str) for x in game["canonicalIDs"]):
        raise UACError("Game canonicalIDs must be an array of strings.")
    if not isinstance(game["metadata"], dict) or not isinstance(game["extensions"], dict):
        raise UACError("Game metadata and extensions must be JSON objects.")

    if not isinstance(recipe["variants"], list) or not recipe["variants"]:
        raise UACError("Recipe 'variants' must be a non-empty array.")
    variant_ids = set()
    for variant in recipe["variants"]:
        if not isinstance(variant, dict):
            raise UACError("Every variant must be an object.")
        for field in ("id", "label", "kind"):
            require_string(variant, field, "Variant")
        variant_id = variant["id"]
        if not safe_component(variant_id) or variant_id in variant_ids:
            raise UACError(f"Variant id must be a unique safe path component: {variant_id}")
        variant_ids.add(variant_id)
        variant.setdefault("canonicalReleaseIDs", [])
        variant.setdefault("metadata", {})
        variant.setdefault("extensions", {})
        if not isinstance(variant["canonicalReleaseIDs"], list) or not all(
            isinstance(x, str) for x in variant["canonicalReleaseIDs"]
        ):
            raise UACError(f"Variant canonicalReleaseIDs must be an array of strings: {variant_id}")
        if not isinstance(variant["metadata"], dict) or not isinstance(variant["extensions"], dict):
            raise UACError(f"Variant metadata and extensions must be JSON objects: {variant_id}")

    for source in recipe["sources"]:
        if not isinstance(source, dict):
            raise UACError("Every source must be an object.")
        for field in ("id", "collection", "setName", "sourceName", "observedAt"):
            require_string(source, field, "Source")
        source.setdefault("metadata", {})
        source.setdefault("extensions", {})
        if not isinstance(source["metadata"], dict) or not isinstance(source["extensions"], dict):
            raise UACError(f"Source metadata and extensions must be JSON objects: {source['id']}")
        source_hash = source.get("packageBlake3")
        if source_hash is not None and (not isinstance(source_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", source_hash)):
            raise UACError(f"Source packageBlake3 must be a lowercase BLAKE3 digest: {source['id']}")
        if source.get("sourceURL") is not None and not isinstance(source["sourceURL"], str):
            raise UACError(f"Source sourceURL must be a string: {source['id']}")

    source_ids = {source["id"] for source in recipe["sources"]}
    if len(source_ids) != len(recipe["sources"]):
        raise UACError("Every source needs a unique non-empty id.")
    transformation_ids = set()
    for transformation in recipe["transformations"]:
        if not isinstance(transformation, dict):
            raise UACError("Every transformation must be an object.")
        for field in ("id", "operation", "tool", "toolVersion", "appliedAt"):
            require_string(transformation, field, "Transformation")
        transformation_id = transformation["id"]
        if not safe_component(transformation_id) or transformation_id in transformation_ids:
            raise UACError(f"Transformation id must be a unique safe path component: {transformation_id}")
        if transformation.get("operation") == "package":
            raise UACError("The package transformation is generated from member/source links by uacman.")
        transformation_ids.add(transformation_id)
        if not isinstance(transformation.get("inputs"), list) or not transformation["inputs"]:
            raise UACError(f"Transformation requires a non-empty inputs array: {transformation['id']}")
        transformation.setdefault("outputs", [])
        transformation.setdefault("details", {})
        if not isinstance(transformation["outputs"], list) or not isinstance(transformation["details"], dict):
            raise UACError(f"Transformation outputs/details are malformed: {transformation['id']}")
        for item in transformation["inputs"]:
            if not isinstance(item, dict):
                raise UACError(f"Transformation input must be an object: {transformation_id}")
            for field in ("sourceID", "sourcePath", "blake3"):
                require_string(item, field, f"Transformation {transformation_id} input")
            if item["sourceID"] not in source_ids or not safe_relative_path(item["sourcePath"]):
                raise UACError(f"Transformation input has an unknown source or unsafe path: {transformation_id}")
            if not re.fullmatch(r"[0-9a-f]{64}", item["blake3"]):
                raise UACError(f"Transformation input has an invalid BLAKE3 digest: {transformation_id}")
            stream_hash = item.get("streamBlake3")
            if stream_hash is not None and (not isinstance(stream_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", stream_hash)):
                raise UACError(f"Transformation input has an invalid stream BLAKE3 digest: {transformation_id}")
        for item in transformation["outputs"]:
            if not isinstance(item, dict):
                raise UACError(f"Transformation output must be an object: {transformation_id}")
            for field in ("memberPath", "blake3"):
                require_string(item, field, f"Transformation {transformation_id} output")
            if not safe_relative_path(item["memberPath"]) or not re.fullmatch(r"[0-9a-f]{64}", item["blake3"]):
                raise UACError(f"Transformation output has an unsafe path or invalid BLAKE3 digest: {transformation_id}")

    playlist_ids = set()
    for playlist in recipe["playlists"]:
        if not isinstance(playlist, dict):
            raise UACError("Every playlist must be an object.")
        playlist_id = require_string(playlist, "id", "Playlist")
        if not safe_component(playlist_id) or playlist_id in playlist_ids:
            raise UACError(f"Playlist id must be a unique safe path component: {playlist_id}")
        playlist_ids.add(playlist_id)
        if not isinstance(playlist.get("entries"), list):
            raise UACError(f"Playlist requires an entries array: {playlist_id}")
        playlist.setdefault("metadata", {})
        playlist.setdefault("extensions", {})
        if not isinstance(playlist["metadata"], dict) or not isinstance(playlist["extensions"], dict):
            raise UACError(f"Playlist metadata and extensions must be JSON objects: {playlist['id']}")
        for entry in playlist["entries"]:
            if not isinstance(entry, dict):
                raise UACError(f"Playlist entries must be objects: {playlist_id}")
            require_string(entry, "targetMemberPath", f"Playlist {playlist_id} entry")
            entry.setdefault("entryKind", "file")
            entry.setdefault("extraFields", {})
            entry.setdefault("extensions", {})
            if not isinstance(entry["extraFields"], dict) or not isinstance(entry["extensions"], dict):
                raise UACError(f"Playlist entry extraFields/extensions must be JSON objects: {playlist_id}")
            if not isinstance(entry["entryKind"], str) or not entry["entryKind"].strip():
                raise UACError(f"Playlist entryKind must be a non-empty string: {playlist_id}")
            if entry["entryKind"] == "subsong":
                track_index = entry.get("trackIndex")
                if (
                    not isinstance(track_index, str)
                    or not re.fullmatch(r"0|[1-9][0-9]*", track_index)
                    or len(track_index) > 19
                    or (len(track_index) == 19 and track_index > str(2**63 - 1))
                ):
                    raise UACError(
                        f"Subsong playlist entries require a nonnegative decimal trackIndex: {playlist_id}"
                    )
    return recipe


def source_set_metadata(sources: object) -> dict | None:
    """Return one conservative, collection-level set projection from source records."""
    if not isinstance(sources, list) or not sources:
        return None

    # Redump packages can also cite the derived extraction and legacy metadata
    # crosswalk. Those records document transformations/associations; the
    # disc-archive record remains the authoritative collection source.
    redump_sources = [
        source for source in sources
        if isinstance(source, dict) and source.get("id") == "redump-disc-archive"
    ]
    if redump_sources:
        projections: set[tuple[str, str, str]] = set()
        for source in redump_sources:
            collection_title = source.get("collection")
            set_name = source.get("setName")
            source_url = source.get("sourceURL")
            if not isinstance(collection_title, str) or not collection_title.startswith("Redump - "):
                return None
            if not isinstance(set_name, str) or not set_name.strip():
                return None
            if not isinstance(source_url, str):
                return None
            parsed = urlsplit(source_url)
            path_parts = [part for part in parsed.path.split("/") if part]
            if (
                parsed.scheme != "https"
                or parsed.netloc.lower() not in {"archive.org", "www.archive.org"}
                or len(path_parts) < 3
                or path_parts[0] != "download"
                or path_parts[1] != set_name
            ):
                return None
            set_title = collection_title.removeprefix("Redump - ").strip()
            if not set_title:
                return None
            item_url = f"https://archive.org/details/{set_name}"
            projections.add(("Redump", set_title, item_url))
        if len(projections) != 1:
            return None
        collection, name, url = next(iter(projections))
        return {"collection": collection, "name": name, "url": url}

    projections: set[tuple[str, str, str, str | None, str | None]] = set()
    for source in sources:
        if not isinstance(source, dict):
            return None
        collection = source.get("collection")
        set_name = source.get("setName")
        if not isinstance(collection, str) or not collection.strip():
            return None
        if not isinstance(set_name, str) or not set_name.strip():
            return None
        url = OFFICIAL_SET_URLS.get((collection, set_name))
        if url is None:
            explicit_url = source.get("sourceURL")
            if not isinstance(explicit_url, str):
                return None
            parsed = urlsplit(explicit_url)
            if parsed.scheme not in ("http", "https") or not parsed.netloc:
                return None
            url = explicit_url
        display_name = "GBS Penultimate" if collection == "GBS Penultimate" and set_name == "." else set_name
        legacy_url = ARCHIVED_SOURCE_URLS.get(collection)
        archive_url = SOURCE_ARCHIVE_URLS.get(collection)
        projections.add((collection, display_name, url, legacy_url, archive_url))

    if len(projections) != 1:
        return None
    collection, name, url, legacy_url, archive_url = next(iter(projections))
    result = {"collection": collection, "name": name, "url": url}
    if legacy_url is not None:
        result["legacyURL"] = legacy_url
    if archive_url is not None:
        result["archiveURL"] = archive_url
    return result


def add_source_set_metadata(manifest: dict) -> bool:
    """Add the source-derived game.metadata.set when it is unambiguous."""
    game = manifest.get("game")
    if not isinstance(game, dict):
        return False
    metadata = game.get("metadata")
    if not isinstance(metadata, dict) or "set" in metadata:
        return False
    set_metadata = source_set_metadata(manifest.get("sources"))
    if set_metadata is None:
        return False
    metadata["set"] = set_metadata
    return True


def refresh_project2612_set_metadata(manifest: dict) -> bool:
    """Move prior Project2612 archive links to the current VGMRips system index."""
    game = manifest.get("game")
    metadata = game.get("metadata") if isinstance(game, dict) else None
    existing = metadata.get("set") if isinstance(metadata, dict) else None
    if not isinstance(existing, dict) or existing.get("collection") != "Project2612":
        return False
    if existing.get("url") != SOURCE_ARCHIVE_URLS["Project2612"]:
        return False
    updated = source_set_metadata(manifest.get("sources"))
    if updated is None or updated.get("collection") != "Project2612":
        return False
    metadata["set"] = updated
    return True


def compression_profile(level: int, frame_size: int) -> str:
    if not (0 <= level <= 22):
        raise UACError("Zstandard level must be 0 (default) through 22.")
    if not (1 <= frame_size <= ZSTD_MAX_FRAME_SIZE):
        raise UACError("Seek frame size must be between 1 byte and 64 MiB.")
    return f"uac-zstd-seekable-level-{level}-frame-{frame_size}-v1"


def discover_files(root: Path, include_macos_sidecars: bool) -> tuple[list[tuple[Path, str]], list[str]]:
    if not root.is_dir() or root.is_symlink():
        raise UACError(f"Input root must be a real directory: {root}")
    files: list[tuple[Path, str]] = []
    skipped: list[str] = []
    for path in sorted(
        root.rglob("*"),
        key=lambda item: (item.relative_to(root).as_posix().casefold(), item.relative_to(root).as_posix()),
    ):
        relative = path.relative_to(root).as_posix()
        mode = path.lstat().st_mode
        if stat.S_ISLNK(mode):
            raise UACError(f"Symlinks are not supported in UAC input: {relative}")
        if stat.S_ISDIR(mode):
            continue
        if not stat.S_ISREG(mode):
            raise UACError(f"Only regular files can be packaged: {relative}")
        if not safe_relative_path(relative):
            raise UACError(f"Unsafe or non-portable input path: {relative}")
        if not include_macos_sidecars and (path.name == ".DS_Store" or path.name.startswith("._")):
            skipped.append(relative)
            continue
        files.append((path, relative))
    if not files:
        raise UACError("Input contains no packageable files.")
    return files, skipped


def infer_role(relative_path: str) -> str:
    suffix = Path(relative_path).suffix.lower()
    if suffix in (".m3u", ".m3u8"):
        return "playlist"
    if suffix in PLAYABLE_EXTENSIONS:
        return "playable"
    return "asset"


def variant_member_path(relative_path: str, variant_id: str, variants: list[dict]) -> str:
    """Use source-relative paths for one-variant packages and namespaces for sets of variants."""
    if len(variants) == 1 and variants[0].get("id") == variant_id:
        return relative_path
    return f"variants/{variant_id}/{relative_path}"


def stream_digest(
    path: Path,
    suffix: str,
    raw_digest: str,
    raw_crc32: int | None = None,
) -> tuple[str, int, int]:
    if suffix.lower() != ".vgz":
        if raw_crc32 is None:
            raw_crc32 = file_crc32(path)
        return raw_digest, path.stat().st_size, raw_crc32
    hasher = blake3.blake3()
    size = 0
    playable_crc32 = 0
    try:
        with gzip.open(path, "rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                hasher.update(block)
                size += len(block)
                playable_crc32 = zlib.crc32(block, playable_crc32)
    except (OSError, EOFError) as error:
        raise UACError(f"Cannot derive the playable payload hash for {path.name}: {error}") from error
    return hasher.hexdigest(), size, playable_crc32


def reject_forbidden_vgm_members(root: Path) -> None:
    """Reject compressed VGM inputs before they can enter a UAC payload.

    VGZ is a distribution wrapper, not the canonical member format for the
    VGMMan sets.  A few archives also carry gzip bytes under a `.vgm` name;
    those are the same conversion error and must be expanded before packing.
    Keeping this check at the pack boundary prevents a caller from bypassing
    the source-tree conversion path with a direct `pack` invocation.
    """
    files, _ = discover_files(root, include_macos_sidecars=False)
    for path, relative in files:
        suffix = path.suffix.lower()
        if suffix == ".vgz":
            raise UACError(
                f"VGZ members are forbidden in UAC packages: {relative}. "
                "Decompress to a raw .vgm file first."
            )
        if suffix != ".vgm":
            continue
        try:
            with path.open("rb") as source:
                magic = source.read(2)
        except OSError as error:
            raise UACError(f"Cannot inspect VGM member {relative}: {error}") from error
        if magic == b"\x1f\x8b":
            raise UACError(
                f"gzip-wrapped .vgm is not a raw VGM member: {relative}. "
                "Decompress it before packaging."
            )


def file_crc32(path: Path) -> int:
    checksum = 0
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            checksum = zlib.crc32(block, checksum)
    return checksum


def vgm_version_text(value: int) -> str:
    return f"{value >> 8}.{value & 0xFF:02X}"


def spc_version_text(value: int) -> str:
    return f"0.{value:02d}"


def scan_contained_container_versions(root: Path) -> tuple[dict, dict[str, dict]]:
    """Read SPC/VGM version facts without changing any source member."""
    spc_versions: dict[int, dict] = {}
    versioned_members: dict[str, dict] = {}
    versions: dict[int, int] = {}
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix().casefold()):
        if not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix == ".spc":
            try:
                with path.open("rb") as source:
                    header = source.read(0x25)
            except OSError as error:
                raise UACError(f"Cannot read contained SPC header in {path.name}: {error}") from error
            signature = header[:0x21]
            match = re.fullmatch(rb"SNES-SPC700 Sound File Data v([0-9]+\.[0-9]{2})", signature)
            if (
                len(header) < 0x25
                or not match
                or header[0x21:0x23] != b"\x1A\x1A"
                or header[0x23] not in (0x1A, 0x1B)
            ):
                raise UACError(f"Invalid or truncated SPC container: {path.name}")
            header_version = match.group(1).decode("ascii")
            version_byte = header[0x24]
            version = spc_version_text(version_byte)
            group = spc_versions.setdefault(version_byte, {"memberCount": 0, "headerVersions": {}})
            group["memberCount"] += 1
            group["headerVersions"][header_version] = group["headerVersions"].get(header_version, 0) + 1
            relative = path.relative_to(root).as_posix()
            versioned_members[relative] = {
                "sub-container-version": version,
                "spcVersion": version,
                "spcVersionByte": version_byte,
                "spcHeaderVersion": header_version,
            }
            continue
        if suffix not in (".vgm", ".vgz"):
            continue
        try:
            opener = gzip.open if suffix == ".vgz" else open
            with opener(path, "rb") as source:
                header = source.read(0x40)
        except (OSError, EOFError) as error:
            raise UACError(f"Cannot read contained VGM header in {path.name}: {error}") from error
        if len(header) < 0x40 or header[:4] != b"Vgm ":
            raise UACError(f"Invalid or truncated VGM container: {path.name}")
        version = int.from_bytes(header[0x08:0x0C], "little")
        if version < 0x100:
            raise UACError(f"Invalid VGM container version in {path.name}: 0x{version:08X}")
        versions[version] = versions.get(version, 0) + 1
        relative = path.relative_to(root).as_posix()
        versioned_members[relative] = {"sub-container-version": vgm_version_text(version)}

    spc_groups = [
        {
            "version": spc_version_text(version_byte),
            "versionByte": version_byte,
            "memberCount": group["memberCount"],
            "headerVersions": [
                {"version": header_version, "memberCount": count}
                for header_version, count in sorted(group["headerVersions"].items())
            ],
        }
        for version_byte, group in sorted(spc_versions.items())
    ]
    vgm_groups = [
        {
            "version": vgm_version_text(version),
            "versionRaw": f"0x{version:08X}",
            "memberCount": count,
        }
        for version, count in sorted(versions.items())
    ]
    mixed_formats = [
        format_name
        for format_name, groups in (("spc", spc_groups), ("vgm", vgm_groups))
        if len(groups) > 1
    ]
    inventory = {
        "schemaVersion": 1,
        "formatsScanned": ["spc", "vgm"],
        "mixedVersionFormats": mixed_formats,
        "versions": {
            "spc": spc_groups,
            "vgm": vgm_groups,
        },
    }
    return inventory, versioned_members


def contained_container_versions(root: Path) -> dict:
    """Summarize versioned SPC/VGM containers without changing source members."""
    inventory, _ = scan_contained_container_versions(root)
    return inventory


def apply_contained_container_versions(root: Path, recipe: dict) -> None:
    reject_forbidden_vgm_members(root)
    detected, versioned_members = scan_contained_container_versions(root)
    game_metadata = recipe["game"].setdefault("metadata", {})
    if not isinstance(game_metadata, dict):
        raise UACError("Game metadata must be a JSON object.")
    authored = game_metadata.get("containedContainerVersions")
    if authored is not None and authored != detected:
        raise UACError("Recipe containedContainerVersions disagrees with detected SPC/VGM headers.")
    game_metadata["containedContainerVersions"] = detected

    for path, fields in versioned_members.items():
        override = recipe["memberOverrides"].setdefault(path, {})
        if not isinstance(override, dict):
            raise UACError(f"Member override must be an object: {path}")
        metadata = override.setdefault("metadata", {})
        if not isinstance(metadata, dict):
            raise UACError(f"Member metadata override must be an object: {path}")
        for key, value in fields.items():
            if key in metadata and metadata[key] not in (None, "", value):
                raise UACError(f"Recipe {key} disagrees with detected SPC header: {path}")
            metadata[key] = value

    # A mixed version inventory is a provenance warning, not a reason to
    # discard the package.  Keep it in the manifest so the dashboard can make
    # the critical condition visible while preserving every source member.
    critical_flags = [
        item for item in game_metadata.get("criticalFlags", [])
        if not (isinstance(item, dict) and item.get("code") == "mixed-sub-container-version")
    ] if isinstance(game_metadata.get("criticalFlags", []), list) else []
    for format_name in detected.get("mixedVersionFormats", []):
        groups = detected.get("versions", {}).get(format_name, [])
        critical_flags.append({
            "code": "mixed-sub-container-version",
            "severity": "critical",
            "format": format_name,
            "versions": [group.get("version") for group in groups],
            "reason": "One title contains multiple sub-container versions; review source provenance before treating it as a clean single-source rip.",
        })
    if critical_flags:
        game_metadata["criticalFlags"] = critical_flags
    else:
        game_metadata.pop("criticalFlags", None)


def load_recipe(path: Path) -> dict:
    try:
        recipe = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise UACError(f"Cannot read UAC metadata recipe {path}: {error}") from error
    if not isinstance(recipe, dict):
        raise UACError("Metadata recipe must be a JSON object.")
    required = ("game", "variants")
    if any(key not in recipe for key in required):
        raise UACError("Metadata recipe requires 'game' and 'variants'.")
    allowed = {
        "packageID", "game", "variants", "sources", "transformations",
        "playlists", "extensions", "memberOverrides",
    }
    unknown = set(recipe) - allowed
    if unknown:
        raise UACError(f"Unknown recipe keys: {', '.join(sorted(unknown))}")
    for field in ("sources", "transformations", "playlists"):
        recipe.setdefault(field, [])
    recipe.setdefault("extensions", {})
    recipe.setdefault("memberOverrides", {})
    if not all(isinstance(recipe[key], list) for key in ("sources", "transformations", "playlists")):
        raise UACError("Recipe sources, transformations, and playlists must be arrays.")
    if not isinstance(recipe["memberOverrides"], dict):
        raise UACError("Recipe memberOverrides must be an object keyed by input-relative path.")
    return normalize_recipe(recipe)


def harvest_spc_metadata(
    root: Path,
    helper: Path,
    recipe: dict,
    member_path_map: dict[str, str] | None = None,
) -> tuple[int, int, list[str]]:
    """Import MetaMan projections without changing the original SPC members."""
    if not helper.is_file() or not os.access(helper, os.X_OK):
        raise UACError(f"UACMan metadata helper is missing or not executable: {helper}")
    try:
        result = subprocess.run(
            [str(helper), "harvest-spc-directory", str(root)],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise UACError(f"Cannot start UACMan's MetaMan-backed SPC reader: {error}") from error
    try:
        response = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        detail = result.stderr.strip()
        raise UACError(f"UACMan metadata helper returned invalid JSON: {detail or error}") from error
    if not isinstance(response, dict) or response.get("schemaVersion") != 1:
        raise UACError("UACMan metadata helper returned an unsupported response.")

    failures = response.get("failures")
    members = response.get("memberMetadata")
    game_metadata = response.get("gameMetadata")
    conflicts = response.get("sharedFieldConflicts")
    diagnostic_count = response.get("diagnosticCount")
    if (not isinstance(failures, list) or not isinstance(members, dict)
            or not isinstance(game_metadata, dict) or not isinstance(conflicts, list)
            or not isinstance(diagnostic_count, int)):
        raise UACError("UACMan metadata helper returned malformed SPC metadata.")
    if result.returncode or failures:
        rendered = "; ".join(str(item) for item in failures[:8])
        detail = result.stderr.strip()
        raise UACError(
            f"MetaMan SPC harvest failed ({len(failures)} member errors). "
            f"{rendered or detail or 'No partial metadata was imported.'}"
        )

    included, _ = discover_files(root, include_macos_sidecars=False)
    spc_paths = {relative for _, relative in included if Path(relative).suffix.lower() == ".spc"}
    members = match_unicode_member_paths(members, spc_paths, "MetaMan SPC harvest")
    if any(not isinstance(fields, dict) for fields in members.values()):
        raise UACError("UACMan metadata helper returned a non-object member projection.")

    game = recipe["game"]
    for key, value in game_metadata.items():
        if key not in game["metadata"] or game["metadata"][key] in (None, ""):
            game["metadata"][key] = value
    for path, fields in members.items():
        override = recipe["memberOverrides"].setdefault(path, {})
        if not isinstance(override, dict):
            raise UACError(f"Member override must be an object: {path}")
        metadata = override.setdefault("metadata", {})
        if not isinstance(metadata, dict):
            raise UACError(f"Member metadata override must be an object: {path}")
        for key, value in fields.items():
            if key not in metadata or metadata[key] in (None, ""):
                metadata[key] = value
    extension = recipe.setdefault("extensions", {}).setdefault("spcMetadataImport", {})
    if not isinstance(extension, dict):
        raise UACError("Recipe extensions.spcMetadataImport must be an object.")
    extension.update({
        "reader": "MetaManCore",
        "memberCount": len(members),
        "diagnosticCount": diagnostic_count,
        "sharedFieldConflicts": [str(item) for item in conflicts],
    })
    return len(members), diagnostic_count, [str(item) for item in conflicts]


def harvest_format_metadata(
    root: Path,
    helper: Path,
    recipe: dict,
    format_extension: str,
    variant_id: str = "original",
    member_path_map: dict[str, str] | None = None,
) -> tuple[int, int]:
    """Import MetaMan projections and represent multi-track members as subsongs."""
    extension = format_extension.strip().lower().removeprefix(".")
    if not re.fullmatch(r"[a-z0-9]+", extension) or extension == "spc":
        raise UACError("Generic MetaMan harvesting requires a supported extension other than spc.")
    included, _ = discover_files(root, include_macos_sidecars=False)
    expected_paths = {
        relative for _, relative in included
        if Path(relative).suffix.lower() == f".{extension}"
    }
    if not expected_paths:
        return 0, 0
    if not helper.is_file() or not os.access(helper, os.X_OK):
        raise UACError(f"UACMan metadata helper is missing or not executable: {helper}")
    try:
        result = subprocess.run(
            [str(helper), "harvest-format-directory", extension, str(root)],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        raise UACError(f"Cannot start UACMan's MetaMan-backed .{extension} reader: {error}") from error
    try:
        response = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        detail = result.stderr.strip()
        raise UACError(f"UACMan metadata helper returned invalid JSON: {detail or error}") from error
    if not isinstance(response, dict) or response.get("schemaVersion") != 1:
        raise UACError("UACMan metadata helper returned an unsupported response.")

    failures = response.get("failures")
    members = response.get("memberMetadata")
    track_metadata = response.get("trackMetadata", {})
    diagnostics = response.get("diagnosticCount")
    if (
        not isinstance(failures, list)
        or not isinstance(members, dict)
        or not isinstance(track_metadata, dict)
        or not isinstance(diagnostics, int)
    ):
        raise UACError(f"UACMan metadata helper returned malformed .{extension} metadata.")
    if result.returncode or failures:
        rendered = "; ".join(str(item) for item in failures[:8])
        detail = result.stderr.strip()
        raise UACError(
            f"MetaMan .{extension} harvest failed ({len(failures)} member errors). "
            f"{rendered or detail or 'No partial metadata was imported.'}"
        )

    members = match_unicode_member_paths(members, expected_paths, f"MetaMan .{extension} harvest")
    track_metadata = match_unicode_member_paths(
        track_metadata,
        expected_paths,
        f"MetaMan .{extension} track metadata",
        allow_partial=True,
    )
    if any(not isinstance(fields, dict) for fields in members.values()):
        raise UACError(f"UACMan metadata helper returned a non-object .{extension} projection.")

    normalized_tracks: dict[str, list[dict]] = {}
    for path, tracks in track_metadata.items():
        if not isinstance(tracks, list) or not tracks:
            raise UACError(f"UACMan metadata helper returned an empty or malformed track list: {path}")
        normalized: list[dict] = []
        indexes: list[int] = []
        for ordinal, track in enumerate(tracks):
            if not isinstance(track, dict) or not isinstance(track.get("metadata"), dict):
                raise UACError(f"UACMan metadata helper returned a malformed track projection: {path}#{ordinal}")
            source_index = track.get("sourceTrackIndex")
            if source_index is not None and (
                not isinstance(source_index, int) or isinstance(source_index, bool) or source_index < 0
            ):
                raise UACError(f"UACMan metadata helper returned an invalid source track index: {path}#{ordinal}")
            if source_index is not None:
                indexes.append(source_index)
            normalized.append({"sourceTrackIndex": source_index, "metadata": track["metadata"]})
        if len(normalized) > 1 and (len(indexes) != len(normalized) or len(set(indexes)) != len(indexes)):
            raise UACError(
                f"MetaMan .{extension} tracks do not have unique playable source indexes: {path}."
            )
        normalized_tracks[path] = normalized

    for path, fields in members.items():
        override = recipe["memberOverrides"].setdefault(path, {})
        if not isinstance(override, dict):
            raise UACError(f"Member override must be an object: {path}")
        # An explicit MetaMan read establishes a native track projection even
        # for formats outside the packer's built-in extension list. Respect an
        # authored role override, but make successfully harvested media visible
        # as a track in UAC readers by default.
        override.setdefault("role", "playable")
        metadata = override.setdefault("metadata", {})
        if not isinstance(metadata, dict):
            raise UACError(f"Member metadata override must be an object: {path}")
        for key, value in fields.items():
            if key not in metadata or metadata[key] in (None, ""):
                metadata[key] = value

    playlist_id = None
    # Track-aware formats need explicit playlist entries even when a stream
    # exposes only one track. This keeps the subsong API consistent and lets
    # callers attach per-track metadata uniformly.
    if extension in {"nsf", "nsfe", "gbs"} or any(len(tracks) > 1 for tracks in normalized_tracks.values()):
        if set(normalized_tracks) != expected_paths:
            missing = sorted(expected_paths - set(normalized_tracks))
            raise UACError(
                f"MetaMan .{extension} track metadata is incomplete for subsong mapping "
                f"(missing={missing[:5]})."
            )
        playlists = recipe.setdefault("playlists", [])
        if not isinstance(playlists, list):
            raise UACError("Recipe playlists must be an array before MetaMan subsongs can be added.")
        existing_ids = {item.get("id") for item in playlists if isinstance(item, dict)}
        base_id = f"metaman-{extension}-tracks"
        playlist_id = base_id
        suffix = 2
        while playlist_id in existing_ids:
            playlist_id = f"{base_id}-{suffix}"
            suffix += 1
        entries = []
        for path in sorted(expected_paths):
            tracks = normalized_tracks[path]
            for ordinal, track in enumerate(tracks):
                metadata = track["metadata"]
                source_index = track["sourceTrackIndex"]
                decoder_index = source_index if source_index is not None else 0
                source_path = original_member_path(path, member_path_map)
                target_path = variant_member_path(source_path, variant_id, recipe.get("variants", []))
                if not safe_relative_path(target_path):
                    raise UACError(f"Unsafe UAC subsong target path: {target_path}")
                title = metadata.get("title")
                artist = metadata.get("artist")
                extra_fields = {
                    "visibleTrackIndex": ordinal,
                    "trackCount": len(tracks),
                    "metaManMetadata": metadata,
                }
                if source_index is not None:
                    extra_fields["sourceTrackIndex"] = source_index
                entries.append({
                    "targetMemberPath": target_path,
                    "entryKind": "subsong",
                    "formatTag": extension,
                    "trackIndex": str(decoder_index),
                    "title": title if isinstance(title, str) and title.strip() else None,
                    "artist": artist if isinstance(artist, str) and artist.strip() else None,
                    "extraFields": extra_fields,
                    "extensions": {},
                })
        playlists.append({
            "id": playlist_id,
            "title": f"MetaMan {extension.upper()} tracks",
            "variantID": variant_id,
            "entries": entries,
            "metadata": {"reader": "MetaManCore", "format": extension},
            "extensions": {},
        })

    imports = recipe.setdefault("extensions", {}).setdefault("metaManMetadataImport", {})
    if not isinstance(imports, dict):
        raise UACError("Recipe extensions.metaManMetadataImport must be an object.")
    format_import = imports.setdefault(extension, {})
    if not isinstance(format_import, dict):
        raise UACError(f"Recipe extensions.metaManMetadataImport.{extension} must be an object.")
    format_import.update({
        "reader": "MetaManCore",
        "memberCount": len(members),
        "diagnosticCount": diagnostics,
    })
    if playlist_id is not None:
        format_import["trackAwareMemberCount"] = sum(
            len(tracks) > 1 for tracks in normalized_tracks.values()
        )
        format_import["playlistID"] = playlist_id
    return len(members), diagnostics


def compress_seekable_tar(tar_path: Path, payload_path: Path, level: int, frame_size: int) -> str:
    """Compress known-size chunks so each Zstandard frame gets exact size hints."""
    zstd = shutil.which("zstd")
    if not zstd:
        raise UACError("Packing requires the zstd command-line encoder.")
    try:
        version_result = subprocess.run([zstd, "--version"], check=True, capture_output=True, text=True)
        version_output = version_result.stdout.strip().splitlines()[0]
        version_match = re.search(r"\bv([0-9]+\.[0-9]+\.[0-9]+)\b", version_output)
        version = version_match.group(1) if version_match else version_output
    except (OSError, subprocess.CalledProcessError, IndexError) as error:
        raise UACError("Cannot identify the installed zstd encoder.") from error

    frame_entries: list[tuple[int, int]] = []
    with tar_path.open("rb") as source, payload_path.open("wb") as payload:
        frame_index = 0
        while chunk := source.read(frame_size):
            if len(chunk) > ZSTD_MAX_FRAME_SIZE:
                raise UACError("A TAR frame exceeds the Zstandard seek-table limit.")
            command = [zstd, "-q", f"-{level}", "-c", f"--stream-size={len(chunk)}"]
            if level >= 20:
                command.insert(2, "--ultra")
            try:
                result = subprocess.run(command, input=chunk, capture_output=True)
            except OSError as error:
                raise UACError(f"Could not start zstd for frame {frame_index}: {error}") from error
            if result.returncode:
                detail = result.stderr.decode("utf-8", errors="replace").strip()
                raise UACError(f"Zstandard compression failed on frame {frame_index}: {detail}")
            compressed_size = len(result.stdout)
            if not compressed_size or compressed_size > 0xFFFFFFFF:
                raise UACError(f"Compressed frame {frame_index} has an unsupported size.")
            payload.write(result.stdout)
            frame_entries.append((compressed_size, len(chunk)))
            frame_index += 1

        if not frame_entries:
            raise UACError("Cannot create a seekable payload from an empty TAR.")
        seek_table_content_size = len(frame_entries) * 8 + 9
        if seek_table_content_size > 0xFFFFFFFF:
            raise UACError("Zstandard seek table exceeds its 32-bit skippable-frame limit.")
        payload.write(struct.pack("<II", ZSTD_SEEK_TABLE_MAGIC, seek_table_content_size))
        for compressed_size, decompressed_size in frame_entries:
            payload.write(struct.pack("<II", compressed_size, decompressed_size))
        payload.write(struct.pack("<IBI", len(frame_entries), 0, ZSTD_SEEK_TABLE_FOOTER_MAGIC))
        payload.flush()
        os.fsync(payload.fileno())
    return f"zstd-cli-{version}; uacman-known-size-frame-writer-v1"


def compress_manifest(zstd: str, manifest: bytes) -> bytes | None:
    """Return an independent Zstandard frame only when the full envelope saves bytes."""
    command = [zstd, "-q", "-3", "-c", f"--stream-size={len(manifest)}"]
    try:
        result = subprocess.run(command, input=manifest, capture_output=True)
    except OSError as error:
        raise UACError(f"Could not start zstd for the UAC manifest: {error}") from error
    if result.returncode:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise UACError(f"Zstandard manifest compression failed: {detail}")
    if not result.stdout.startswith(ZSTD_FRAME_MAGIC):
        raise UACError("Zstandard did not return a valid manifest frame.")
    if len(result.stdout) + UAC_COMPRESSED_MANIFEST_PREFIX_SIZE >= len(manifest):
        return None
    return result.stdout


def decompress_manifest(zstd: str, frame: bytes, expected_size: int) -> bytes:
    """Decode one frame while refusing output beyond its bounded declared size."""
    if not (0 < expected_size <= UAC_MAX_MANIFEST_SIZE):
        raise UACError("Compressed UAC manifest declares an invalid decoded size.")
    if not frame.startswith(ZSTD_FRAME_MAGIC):
        raise UACError("Compressed UAC manifest is not a Zstandard frame.")

    try:
        with tempfile.TemporaryFile() as source:
            source.write(frame)
            source.seek(0)
            process = subprocess.Popen(
                [zstd, "-q", "-d", "-c", "--memory=32MB"],
                stdin=source,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            assert process.stdout is not None
            decoded = bytearray()
            try:
                while True:
                    remaining = expected_size + 1 - len(decoded)
                    if remaining <= 0:
                        process.kill()
                        process.wait()
                        raise UACError("Compressed UAC manifest exceeds its declared decoded size.")
                    chunk = process.stdout.read(min(64 * 1024, remaining))
                    if not chunk:
                        break
                    decoded.extend(chunk)
                return_code = process.wait(timeout=30)
            except (OSError, subprocess.TimeoutExpired) as error:
                process.kill()
                process.wait()
                raise UACError(f"Could not safely decode the compressed UAC manifest: {error}") from error
            finally:
                process.stdout.close()
    except OSError as error:
        raise UACError(f"Could not safely decode the compressed UAC manifest: {error}") from error

    if return_code:
        raise UACError("Compressed UAC manifest frame failed Zstandard validation.")
    if len(decoded) != expected_size:
        raise UACError("Compressed UAC manifest decoded size does not match its header.")
    return bytes(decoded)


def create_tar(
    root: Path,
    tar_path: Path,
    recipe: dict,
    variant_id: str,
    include_macos_sidecars: bool,
    member_path_map: dict[str, str] | None = None,
) -> tuple[list[dict], list[str]]:
    variants = {item.get("id") for item in recipe["variants"] if isinstance(item, dict)}
    if variant_id not in variants:
        raise UACError(f"Variant '{variant_id}' is not declared in the metadata recipe.")
    sources = recipe["sources"]
    source_ids = [item.get("id") for item in sources if isinstance(item, dict)]
    if any(not value for value in source_ids) or len(set(source_ids)) != len(source_ids):
        raise UACError("Every source needs a unique non-empty id.")

    files, skipped = discover_files(root, include_macos_sidecars)
    overrides = recipe["memberOverrides"]
    unknown_override_paths = set(overrides) - {relative for _, relative in files}
    if unknown_override_paths:
        raise UACError(f"Overrides do not match included files: {', '.join(sorted(unknown_override_paths))}")
    records: list[dict] = []
    with tarfile.open(tar_path, mode="w", format=tarfile.PAX_FORMAT) as archive:
        for source_path, relative in files:
            override = overrides.get(relative, {})
            if not isinstance(override, dict):
                raise UACError(f"Member override must be an object: {relative}")
            allowed_override_fields = {"role", "format", "metadata", "extensions", "sourceIDs"}
            unknown = set(override) - allowed_override_fields
            if unknown:
                raise UACError(f"Unknown override fields for {relative}: {', '.join(sorted(unknown))}")

            archive_relative = original_member_path(relative, member_path_map)
            member_path = variant_member_path(archive_relative, variant_id, recipe["variants"])
            if not safe_relative_path(member_path):
                raise UACError(f"Unsafe UAC member path: {member_path}")
            suffix = source_path.suffix.lower()
            role = override.get("role", infer_role(archive_relative))
            format_name = override.get("format", suffix.removeprefix(".") or None)
            if not isinstance(role, str) or not role.strip():
                raise UACError(f"Member role must be a non-empty string: {relative}")
            metadata = override.get("metadata", {})
            extensions = override.get("extensions", {})
            member_source_ids = override.get("sourceIDs", source_ids)
            if len(source_ids) > 1 and "sourceIDs" not in override:
                raise UACError(
                    f"Multiple sources are declared; explicitly set sourceIDs for member {relative}."
                )
            if not isinstance(metadata, dict) or not isinstance(extensions, dict):
                raise UACError(f"Member metadata and extensions must be JSON objects: {relative}")
            if not isinstance(member_source_ids, list) or any(item not in source_ids for item in member_source_ids):
                raise UACError(f"Member references an undeclared source: {relative}")

            before = source_path.stat()
            info = tarfile.TarInfo(member_path)
            info.size = before.st_size
            info.mode = 0o644
            info.mtime = 0
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            digest_reader: HashingReader
            with source_path.open("rb") as source:
                digest_reader = HashingReader(source)
                archive.addfile(info, digest_reader)
            raw_digest = digest_reader.hasher.hexdigest()
            raw_crc32 = digest_reader.crc32 & 0xFFFFFFFF
            stream_hash = None
            hash_records: list[dict] = [{
                "scope": "raw-member",
                "algorithm": "crc32-iso-hdlc",
                "digest": f"{raw_crc32:08X}",
                "profile": "uac-raw-member-v1",
                "byteSize": before.st_size,
            }]
            if role == "playable":
                stream_hash, stream_size, stream_crc32 = stream_digest(
                    source_path, suffix, raw_digest, raw_crc32
                )
                hash_records.append({
                    "scope": "playable-payload",
                    "algorithm": "blake3-256",
                    "digest": stream_hash,
                    "profile": "uac-playable-payload-v1",
                    "byteSize": stream_size,
                })
                hash_records.append({
                    "scope": "playable-payload",
                    "algorithm": "crc32-iso-hdlc",
                    "digest": f"{stream_crc32 & 0xFFFFFFFF:08X}",
                    "profile": "uac-playable-payload-v1",
                    "byteSize": stream_size,
                })
            after = source_path.stat()
            # SMB mounts can report a different nanosecond mtime on the second
            # stat despite a stable file.  Size and inode remain mandatory;
            # local files retain the stricter mtime guard.
            remote_mount = str(root).startswith("/Volumes/")
            changed_identity = (before.st_size, before.st_ino) != (after.st_size, after.st_ino)
            changed_local_mtime = before.st_mtime_ns != after.st_mtime_ns and not remote_mount
            if digest_reader.byte_count != before.st_size or changed_identity or changed_local_mtime:
                raise UACError(f"Input changed while it was being packaged: {relative}")
            records.append({
                "path": member_path,
                "originalName": PurePosixPath(archive_relative).name,
                "variantID": variant_id,
                "sourceIDs": member_source_ids,
                "role": role,
                "format": format_name,
                "byteSize": before.st_size,
                "tarDataOffset": 0,
                "blake3": raw_digest,
                "streamBlake3": stream_hash,
                "hashes": hash_records,
                "metadata": metadata,
                "extensions": extensions,
            })

    with tarfile.open(tar_path, mode="r:") as archive:
        offsets = {member.name: (member.offset_data, member.size) for member in archive.getmembers()}
    for record in records:
        offset = offsets.get(record["path"])
        if offset is None or offset[1] != record["byteSize"]:
            raise UACError(f"TAR writer did not produce an indexable regular member: {record['path']}")
        record["tarDataOffset"] = offset[0]

    return records, skipped


def validate_required_sub_container_tags(records: list[dict]) -> None:
    """Require the shared version tag on every versioned audio member."""
    for record in records:
        format_name = str(record.get("format") or "").lower()
        if format_name not in {"vgm", "spc"}:
            continue
        metadata = record.get("metadata")
        value = metadata.get("sub-container-version") if isinstance(metadata, dict) else None
        if not isinstance(value, str) or not value.strip():
            raise UACError(
                "Versioned audio member is missing required metadata.sub-container-version: "
                f"{record.get('path', '<unknown>')}"
            )


def finalize_playlists(playlists: list, records: list[dict]) -> list[dict]:
    members = {record["path"]: record for record in records}
    result: list[dict] = []
    for source in playlists:
        if not isinstance(source, dict):
            raise UACError("Every playlist recipe must be an object.")
        playlist = dict(source)
        original_path = playlist.get("originalMemberPath")
        if original_path is not None and original_path not in members:
            raise UACError(f"Playlist source member is not packaged: {original_path}")
        entries = playlist.get("entries")
        if not isinstance(entries, list):
            raise UACError(f"Playlist '{playlist.get('id', '?')}' requires an entries array.")
        normalized_entries = []
        for source_entry in entries:
            if not isinstance(source_entry, dict):
                raise UACError("Every playlist entry must be an object.")
            entry = dict(source_entry)
            target_path = entry.get("targetMemberPath")
            target = members.get(target_path)
            if target is None:
                raise UACError(f"Playlist target is not packaged: {target_path}")
            if entry.get("entryKind", "file") == "subsong" and target.get("role") not in ("playable", "track"):
                raise UACError(f"Subsong playlist targets a non-playable member: {target_path}")
            target_digest = entry.get("targetMemberBlake3")
            if target_digest is not None and target_digest != target["blake3"]:
                raise UACError(f"Playlist target hash disagrees with member bytes: {target_path}")
            entry["targetMemberBlake3"] = target["blake3"]
            normalized_entries.append(entry)
        playlist["entries"] = normalized_entries
        result.append(playlist)
    return result


def finalize_transformations(
    transformations: list,
    records: list[dict],
    variant_id: str,
    sources: list[dict],
    namespaces_variants: bool,
) -> list[dict]:
    members = {record["path"]: record for record in records}
    result = [dict(item) for item in transformations]
    used_ids = {item["id"] for item in result}
    for item in result:
        for output in item["outputs"]:
            member = members.get(output["memberPath"])
            if member is None or member["blake3"] != output["blake3"]:
                raise UACError(
                    f"Transformation output does not match a packaged member: {output['memberPath']}"
                )

    sources_by_id = {source["id"]: source for source in sources}
    member_prefix = f"variants/{variant_id}/"
    source_order = list(sources_by_id)
    for index, source_id in enumerate(source_order, start=1):
        linked = [record for record in records if source_id in record["sourceIDs"]]
        if not linked:
            continue
        transformation_id = f"uac-package-source-{index:04d}"
        if transformation_id in used_ids:
            raise UACError(f"Generated package transformation id conflicts with recipe: {transformation_id}")
        inputs = []
        outputs = []
        for member in linked:
            if namespaces_variants:
                if not member["path"].startswith(member_prefix):
                    raise UACError(f"Source-linked member is outside its variant: {member['path']}")
                source_path = member["path"][len(member_prefix):]
            else:
                source_path = member["path"]
            source_input = {
                "sourceID": source_id,
                "sourcePath": source_path,
                "blake3": member["blake3"],
            }
            if member.get("streamBlake3"):
                source_input["streamBlake3"] = member["streamBlake3"]
            inputs.append(source_input)
            outputs.append({"memberPath": member["path"], "blake3": member["blake3"]})
        applied_at = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        result.append({
            "id": transformation_id,
            "operation": "package",
            "inputs": inputs,
            "outputs": outputs,
            "tool": "uacman",
            "toolVersion": UACMAN_VERSION,
            "appliedAt": applied_at,
            "reason": "Recorded source-member inclusion in the UAC package.",
            "details": {"sourceID": source_id},
        })
        used_ids.add(transformation_id)
    return result


def manifest_bytes(recipe: dict, records: list[dict], payload: Path, level: int, frame_size: int, zstd_version: str) -> bytes:
    game = recipe["game"]
    game_id = game.get("id")
    if not isinstance(game_id, str) or not game_id.strip():
        raise UACError("Recipe game requires a non-empty id.")
    package_id = recipe.get("packageID", game_id)
    if not isinstance(package_id, str) or not package_id.strip():
        raise UACError("packageID must be a non-empty string.")

    manifest = {
        "manifestVersion": 2,
        "packageID": package_id,
        "payload": {
            "format": "tar+zstd-seekable",
            "compressionProfile": compression_profile(level, frame_size),
            "encoderVersion": zstd_version,
            "blake3": b3_file_from_offset(payload),
        },
        "game": game,
        "variants": recipe["variants"],
        "members": records,
        "playlists": finalize_playlists(recipe["playlists"], records),
        "sources": recipe["sources"],
        "transformations": finalize_transformations(
            recipe["transformations"],
            records,
            records[0]["variantID"],
            recipe["sources"],
            len(recipe["variants"]) > 1,
        ),
        "extensions": recipe["extensions"],
    }
    try:
        encoded = json.dumps(manifest, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise UACError(f"Recipe contains a value that is not valid JSON: {error}") from error
    if len(encoded) > UAC_MAX_MANIFEST_SIZE:
        raise UACError("UAC manifest exceeds the 16 MiB reader limit.")
    return encoded


def pack(args: argparse.Namespace) -> tuple[int, int, list[str], list[tuple[str, int, int]]]:
    root = Path(args.input_dir).expanduser().absolute()
    recipe = args.recipe if isinstance(args.recipe, dict) else load_recipe(Path(args.recipe).expanduser())
    add_source_set_metadata(recipe)
    apply_contained_container_versions(root, recipe)
    output = Path(args.output).expanduser().absolute()
    if output.exists():
        raise UACError(f"Refusing to overwrite existing output: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    profile = compression_profile(args.level, args.frame_size)
    del profile  # validate the requested profile before creating any output

    harvested_spc = 0
    metadata_diagnostics = 0
    metadata_conflicts: list[str] = []
    metadata_helper = getattr(args, "harvest_spc_metadata", None)
    if metadata_helper:
        harvested_spc, metadata_diagnostics, metadata_conflicts = harvest_spc_metadata(
            root,
            Path(metadata_helper).expanduser().absolute(),
            recipe,
            getattr(args, "member_path_map", None),
        )
    generic_harvests: list[tuple[str, int, int]] = []
    for extension, helper_path in getattr(args, "harvest_format_metadata", []) or []:
        count, diagnostics = harvest_format_metadata(
            root,
            Path(helper_path).expanduser().absolute(),
            recipe,
            extension,
            args.variant_id,
            getattr(args, "member_path_map", None),
        )
        if count or diagnostics:
            generic_harvests.append((extension.lower().removeprefix("."), count, diagnostics))

    with tempfile.TemporaryDirectory(prefix="uacman-pack-") as temporary:
        work = Path(temporary)
        tar_path = work / "payload.tar"
        payload_path = work / "payload.tar.zst"
        records, skipped = create_tar(
            root,
            tar_path,
            recipe,
            args.variant_id,
            args.include_macos_sidecars,
            getattr(args, "member_path_map", None),
        )
        validate_required_sub_container_tags(records)
        tar_size = tar_path.stat().st_size
        zstd_version = compress_seekable_tar(tar_path, payload_path, args.level, args.frame_size)
        if not payload_path.is_file():
            raise UACError("Seekable Zstandard compression did not produce a payload.")

        manifest = manifest_bytes(recipe, records, payload_path, args.level, args.frame_size, zstd_version)
        manifest_zstd = shutil.which("zstd")
        if not manifest_zstd:
            raise UACError("Packing requires the zstd command-line encoder.")
        compressed_manifest = compress_manifest(manifest_zstd, manifest)
        if compressed_manifest is None:
            stored_manifest = manifest
            manifest_encoding = "json"
        else:
            stored_manifest = (
                UAC_MANIFEST_ZSTD_MAGIC
                + struct.pack("<I", len(manifest))
                + compressed_manifest
            )
            manifest_encoding = "zstd-json"
        metadata_frame = (
            UAC_METADATA_MAGIC
            + struct.pack("<HH", 1, 0)
            + hashlib.sha256(manifest).digest()
            + stored_manifest
        )
        if len(metadata_frame) > 0xFFFFFFFF:
            raise UACError("UAC metadata frame exceeds the Zstandard skippable-frame limit.")
        header = struct.pack("<II", UAC_SKIPPABLE_MAGIC, len(metadata_frame)) + metadata_frame

        fd, staging_name = tempfile.mkstemp(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent)
        staging = Path(staging_name)
        try:
            with os.fdopen(fd, "wb") as target, payload_path.open("rb") as payload:
                target.write(header)
                shutil.copyfileobj(payload, target, length=1024 * 1024)
                target.flush()
                os.fsync(target.fileno())
            try:
                os.link(staging, output)
            except OSError as error:
                # Some SMB shares do not implement hard links.  The staged
                # file is already fsynced and lives beside the destination,
                # so an atomic rename preserves the same no-overwrite rule.
                if getattr(error, "errno", None) not in (errno.EOPNOTSUPP, errno.ENOTSUP, errno.EXDEV):
                    raise
                os.replace(staging, output)
        except FileExistsError as error:
            raise UACError(f"Refusing to overwrite output created concurrently: {output}") from error
        finally:
            staging.unlink(missing_ok=True)

    if skipped and not getattr(args, "quiet", False):
        print(f"Excluded {len(skipped)} macOS sidecar(s): " + ", ".join(skipped), file=sys.stderr)
    if not getattr(args, "quiet", False):
        output_size = output.stat().st_size
        print(f"Packed {len(records)} members into {output} ({output_size:,} bytes).")
        print(
            f"Manifest: {len(manifest):,} -> {len(stored_manifest):,} bytes "
            f"({manifest_encoding})."
        )
        if tar_size:
            print(f"TAR bytes: {tar_size:,}; UAC/TAR ratio: {output_size / tar_size:.3f}.")
        if metadata_helper:
            print(
                f"MetaMan SPC tags: {harvested_spc} members; "
                f"{metadata_diagnostics} diagnostics; "
                f"{len(metadata_conflicts)} shared-field conflicts."
            )
        for extension, count, diagnostics in generic_harvests:
            print(f"MetaMan .{extension} metadata: {count} members; {diagnostics} diagnostics.")
    return harvested_spc, metadata_diagnostics, metadata_conflicts, generic_harvests


def extract_zstd_tar(
    source_path: Path,
    destination: Path,
    member_path_map: dict[str, str] | None = None,
) -> tuple[int, int]:
    """Safely extract regular files from one source .tar.zst into a new directory."""
    zstd = shutil.which("zstd")
    if not zstd:
        raise UACError("Source archive conversion requires the zstd command-line decoder.")
    destination.mkdir(parents=True, exist_ok=False)
    if member_path_map is not None:
        member_path_map.clear()
    seen_paths: set[str] = set()
    folded_paths: set[str] = set()
    file_count = 0
    total_bytes = 0
    with tempfile.TemporaryDirectory(prefix="uacman-source-tar-") as temporary:
        tar_path = Path(temporary) / "source.tar"
        with tar_path.open("wb") as tar_output:
            result = subprocess.run(
                [zstd, "-q", "-d", "-c", "--", str(source_path)],
                stdout=tar_output,
                stderr=subprocess.PIPE,
            )
        if result.returncode:
            detail = result.stderr.decode("utf-8", errors="replace").strip()
            raise UACError(f"Cannot decode {source_path.name}: {detail or 'Zstandard error'}")

        try:
            archive_context = tarfile.open(tar_path, mode="r:")
        except tarfile.TarError as error:
            raise UACError(f"Source is not a readable TAR archive: {source_path}") from error
        with archive_context as archive:
            for member in archive:
                raw_name = member.name
                while raw_name.startswith("./"):
                    raw_name = raw_name[2:]
                if raw_name in ("", "."):
                    if member.isdir():
                        continue
                    raise UACError(f"Source archive has an empty member path: {source_path.name}")
                if not safe_relative_path(raw_name):
                    raise UACError(f"Unsafe source archive member path in {source_path.name}: {member.name}")
                relative = PurePosixPath(raw_name)
                normalized = relative.as_posix()
                if member.isdir():
                    (destination.joinpath(*relative.parts)).mkdir(parents=True, exist_ok=True)
                    continue
                if not member.isfile() or getattr(member, "issparse", lambda: False)():
                    raise UACError(f"Unsupported non-regular source member in {source_path.name}: {member.name}")
                unicode_key = unicodedata.normalize("NFC", normalized)
                folded = unicode_key.casefold()
                if normalized in seen_paths or folded in folded_paths:
                    raise UACError(f"Duplicate or case-colliding source member in {source_path.name}: {normalized}")
                if member.size < 0:
                    raise UACError(f"Negative source member size in {source_path.name}: {normalized}")
                seen_paths.add(normalized)
                folded_paths.add(folded)
                if member_path_map is not None:
                    member_path_map[unicode_key] = normalized
                target = destination.joinpath(*relative.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                source = archive.extractfile(member)
                if source is None:
                    raise UACError(f"Cannot read source member in {source_path.name}: {normalized}")
                copied = 0
                with source, target.open("xb") as output:
                    while block := source.read(1024 * 1024):
                        output.write(block)
                        copied += len(block)
                if copied != member.size:
                    raise UACError(f"Truncated source member in {source_path.name}: {normalized}")
                file_count += 1
                total_bytes += copied
    if not file_count:
        raise UACError(f"Source archive contains no regular files: {source_path}")
    return file_count, total_bytes


def verify_uac_members(path: Path, manifest: dict) -> None:
    zstd = shutil.which("zstd")
    if not zstd:
        raise UACError("Full UAC verification requires the zstd command-line decoder.")
    with tempfile.TemporaryDirectory(prefix="uacman-verify-") as temporary:
        tar_path = Path(temporary) / "payload.tar"
        with tar_path.open("wb") as tar_output:
            result = subprocess.run(
                [zstd, "-q", "-d", "-c", "--", str(path)],
                stdout=tar_output,
                stderr=subprocess.PIPE,
            )
        if result.returncode:
            detail = result.stderr.decode("utf-8", errors="replace").strip()
            raise UACError(f"UAC payload failed full decompression verification: {detail}")
        verify_tar_members(manifest, tar_path)


def pack_source_archive_tree(args: argparse.Namespace) -> None:
    root = Path(args.source_root).expanduser().absolute()
    output = Path(args.output_root).expanduser().absolute()
    helper = Path(args.metadata_cli).expanduser().absolute()
    if args.progress_interval < 1:
        raise UACError("Progress interval must be at least 1 source package.")
    if not root.is_dir() or root.is_symlink():
        raise UACError(f"Source tree must be a real directory: {root}")
    if not helper.is_file() or not os.access(helper, os.X_OK):
        raise UACError(f"UACMan metadata helper is missing or not executable: {helper}")
    if output.exists():
        raise UACError(f"Refusing to overwrite existing output tree: {output}")
    if output == root or output.is_relative_to(root) or root.is_relative_to(output):
        raise UACError("Source and output trees must be disjoint.")

    archives: list[tuple[Path, str]] = []
    ignored: list[str] = []
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix().casefold()):
        mode = path.lstat().st_mode
        relative = path.relative_to(root).as_posix()
        if stat.S_ISLNK(mode):
            raise UACError(f"Source tree contains a symlink: {relative}")
        if stat.S_ISDIR(mode):
            continue
        if not stat.S_ISREG(mode):
            raise UACError(f"Source tree contains a non-regular item: {relative}")
        if relative.endswith(".tar.zst"):
            archives.append((path, relative))
        elif path.name == ".DS_Store" or path.name.startswith("._"):
            ignored.append(relative)
        else:
            raise UACError(f"Unclassified non-archive file in source tree: {relative}")
    if not archives:
        raise UACError(f"No .tar.zst source packages found under {root}")

    parent_existed = output.parent.exists()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise UACError(f"Refusing to overwrite existing output tree: {output}")
    staging = Path(tempfile.mkdtemp(prefix=f".{output.name}.uac-build-", dir=output.parent))
    converted = 0
    spc_count = 0
    diagnostics = 0
    conflict_fields: set[str] = set()
    conflict_packages = 0
    format_harvest_totals: dict[str, list[int]] = {}
    format_extensions = [
        str(extension).strip().lower().removeprefix(".")
        for extension in (getattr(args, "metadata_format", None) or [])
    ]
    if len(set(format_extensions)) != len(format_extensions):
        raise UACError("Each --metadata-format extension may be specified only once.")
    if "spc" in format_extensions:
        raise UACError("SPC metadata is included by default; do not pass --metadata-format spc.")
    total_source_bytes = 0
    observed_at = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    source_name = args.source_name or root.name
    source_slug = re.sub(r"[^a-z0-9._-]+", "-", source_name.lower()).strip("-._") or "source"

    try:
        for archive_index, (source_path, relative_text) in enumerate(archives, start=1):
            relative = PurePosixPath(relative_text)
            source_stamp = source_path.stat()
            source_hash = b3_file_from_offset(source_path)
            relative_base = relative_text[:-len(".tar.zst")]
            output_relative = PurePosixPath(relative_base + ".uac")
            target = staging.joinpath(*output_relative.parts)
            if not safe_relative_path(output_relative.as_posix()):
                raise UACError(f"Unsafe UAC output path derived from source name: {relative_text}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix="uacman-source-set-") as temporary:
                members_root = Path(temporary) / "members"
                member_path_map: dict[str, str] = {}
                file_count, source_member_bytes = extract_zstd_tar(
                    source_path,
                    members_root,
                    member_path_map,
                )
                total_source_bytes += source_member_bytes
                source_id = "source-archive"
                game_id = f"{source_slug}-{source_hash[:20]}"
                title = relative.name[:-len(".tar.zst")]
                console = relative.parent.name or source_name
                source_record = {
                    "id": source_id,
                    "collection": source_name,
                    "setName": relative.parent.as_posix(),
                    "sourceName": relative_text,
                    "observedAt": observed_at,
                    "packageBlake3": source_hash,
                    "metadata": {"format": "tar+zstd", "sourceRelativePath": relative_text},
                    "extensions": {},
                }
                if args.source_url:
                    source_record["sourceURL"] = args.source_url
                recipe = {
                    "packageID": game_id,
                    "game": {
                        "id": game_id,
                        "title": title,
                        "console": console,
                        "canonicalIDs": [],
                        "metadata": {},
                        "extensions": {},
                    },
                    "variants": [{"id": "original", "label": "Original source members", "kind": "release"}],
                    "sources": [source_record],
                    "transformations": [],
                    "playlists": [],
                    "extensions": {},
                    "memberOverrides": {},
                }
                recipe = normalize_recipe(recipe)
                pack_args = argparse.Namespace(
                    input_dir=str(members_root),
                    recipe=recipe,
                    output=str(target),
                    variant_id="original",
                    level=args.level,
                    frame_size=args.frame_size,
                    include_macos_sidecars=False,
                    harvest_spc_metadata=str(helper),
                    harvest_format_metadata=[(extension, str(helper)) for extension in format_extensions],
                    member_path_map=member_path_map,
                    quiet=True,
                )
                with contextlib.redirect_stdout(io.StringIO()):
                    harvested, package_diagnostics, package_conflicts, package_formats = pack(pack_args)
                spc_count += harvested
                diagnostics += package_diagnostics
                conflict_fields.update(package_conflicts)
                conflict_packages += int(bool(package_conflicts))
                for extension, member_count, reader_diagnostics in package_formats:
                    totals = format_harvest_totals.setdefault(extension, [0, 0])
                    totals[0] += member_count
                    totals[1] += reader_diagnostics
                manifest, _, _, _, _, _ = read_uac(target, verify_payload=True)
                verify_uac_members(target, manifest)
                spc_members = [
                    member for member in manifest["members"]
                    if str(member.get("format", "")).lower() == "spc"
                ]
                if any(not isinstance(member.get("metadata"), dict)
                       or "nativeMetadata" not in member["metadata"] for member in spc_members):
                    raise UACError(f"SPC tag metadata is missing from the UAC manifest: {relative_text}")
                if any(Path(str(member.get("originalName", ""))).suffix.lower() == ".spc"
                       for member in manifest["members"]) and len(spc_members) == 0:
                    raise UACError(f"SPC files were not classified as SPC members: {relative_text}")
            after = source_path.stat()
            if (source_stamp.st_size, source_stamp.st_mtime_ns, source_stamp.st_ino) != (
                after.st_size, after.st_mtime_ns, after.st_ino
            ) or b3_file_from_offset(source_path) != source_hash:
                raise UACError(f"Source archive changed during conversion: {relative_text}")
            converted += 1
            if archive_index % args.progress_interval == 0 or archive_index == len(archives):
                print(
                    f"[{archive_index}/{len(archives)}] UAC packages built; "
                    f"{spc_count:,} SPC members metadata-tagged; "
                    f"{diagnostics:,} reader diagnostics; "
                    f"source members {total_source_bytes:,} bytes.",
                    flush=True,
                )
                for extension, (member_count, reader_diagnostics) in sorted(format_harvest_totals.items()):
                    print(
                        f"MetaMan .{extension}: {member_count:,} members; "
                        f"{reader_diagnostics:,} diagnostics.",
                        flush=True,
                    )

        if output.exists():
            raise UACError(f"Refusing to replace output tree created during conversion: {output}")
        os.rename(staging, output)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        if not parent_existed:
            try:
                output.parent.rmdir()
            except OSError:
                pass
        raise

    if ignored:
        print(f"Ignored {len(ignored)} macOS sidecar(s) outside source archives.")
    print(
        f"Published {converted} verified UAC packages to {output}; "
        f"{spc_count:,} SPC members carry MetaMan projections, "
        f"with {diagnostics:,} parser diagnostics and "
        f"{conflict_packages} packages with cross-track metadata disagreements "
        f"across {len(conflict_fields)} fields. "
        "Original source archives were read-only inputs."
    )


def read_uac(path: Path, verify_payload: bool = True) -> tuple[dict, int, int, str, int, int]:
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            frame_header = handle.read(8)
            if len(frame_header) != 8:
                raise UACError("Truncated UAC metadata frame.")
            magic, metadata_size = struct.unpack("<II", frame_header)
            if magic != UAC_SKIPPABLE_MAGIC or metadata_size < UAC_METADATA_HEADER_SIZE + 1:
                raise UACError("Not a supported UAC metadata frame.")
            if metadata_size > UAC_METADATA_HEADER_SIZE + UAC_COMPRESSED_MANIFEST_PREFIX_SIZE + UAC_MAX_MANIFEST_SIZE:
                raise UACError("UAC manifest exceeds the 16 MiB reader limit.")
            metadata_frame = handle.read(metadata_size)
            if len(metadata_frame) != metadata_size or metadata_frame[:4] != UAC_METADATA_MAGIC:
                raise UACError("Truncated or invalid UAC metadata marker.")
            major, minor = struct.unpack_from("<HH", metadata_frame, 4)
            if (major, minor) != (1, 0):
                raise UACError(f"Unsupported UAC version {major}.{minor}.")
            stored_manifest = metadata_frame[UAC_METADATA_HEADER_SIZE:]
            manifest_encoding = "json"
            if stored_manifest.startswith(UAC_MANIFEST_ZSTD_MAGIC):
                if len(stored_manifest) <= UAC_COMPRESSED_MANIFEST_PREFIX_SIZE:
                    raise UACError("Compressed UAC manifest frame is truncated.")
                decoded_size = struct.unpack_from("<I", stored_manifest, 4)[0]
                if not (0 < decoded_size <= UAC_MAX_MANIFEST_SIZE):
                    raise UACError("Compressed UAC manifest declares an invalid decoded size.")
                if len(stored_manifest) >= decoded_size:
                    raise UACError("Compressed UAC manifest does not save bytes over raw JSON.")
                zstd = shutil.which("zstd")
                if not zstd:
                    raise UACError("Reading compressed UAC manifests requires the zstd command-line decoder.")
                manifest_data = decompress_manifest(
                    zstd,
                    stored_manifest[UAC_COMPRESSED_MANIFEST_PREFIX_SIZE:],
                    decoded_size,
                )
                manifest_encoding = "zstd-json"
            else:
                manifest_data = stored_manifest
                if len(manifest_data) > UAC_MAX_MANIFEST_SIZE:
                    raise UACError("UAC manifest exceeds the 16 MiB reader limit.")
            expected_sha256 = metadata_frame[8:40]
            if hashlib.sha256(manifest_data).digest() != expected_sha256:
                raise UACError("UAC manifest SHA-256 mismatch.")
            manifest = json.loads(manifest_data.decode("utf-8"))
            if not isinstance(manifest, dict):
                raise UACError("UAC manifest must be a JSON object.")
            if manifest.get("manifestVersion") not in (1, 2):
                raise UACError("Unsupported UAC manifest version.")
            payload_offset = 8 + metadata_size
            if size - payload_offset < 4:
                raise UACError("UAC payload is truncated.")
            handle.seek(payload_offset)
            if handle.read(4) != ZSTD_FRAME_MAGIC:
                raise UACError("UAC payload does not begin with a Zstandard frame.")
    except (OSError, UnicodeError, json.JSONDecodeError, struct.error) as error:
        if isinstance(error, UACError):
            raise
        raise UACError(f"Cannot read UAC container {path}: {error}") from error

    payload = manifest.get("payload")
    if not isinstance(payload, dict) or payload.get("format") != "tar+zstd-seekable":
        raise UACError("This prototype only supports seekable TAR+Zstandard payloads.")
    if not SEEKABLE_PROFILE.fullmatch(payload.get("compressionProfile", "")):
        if payload.get("compressionProfile") != "uac-zstd-seekable-3-v1":
            raise UACError("Unsupported UAC seekable compression profile.")
    if verify_payload and b3_file_from_offset(path, payload_offset) != payload.get("blake3"):
        raise UACError("Compressed payload BLAKE3 mismatch.")
    return (
        manifest,
        payload_offset,
        size - payload_offset,
        manifest_encoding,
        len(manifest_data),
        len(stored_manifest),
    )


def filesystem_identity(path: Path) -> tuple[int, int, int, int, int]:
    info = path.stat()
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns


def rewrite_uac_manifest(path: Path, manifest: dict, expected_original_manifest: dict) -> None:
    """Atomically replace only a UAC manifest while byte-copying its payload."""
    if path.is_symlink() or not path.is_file():
        raise UACError(f"Refusing to rewrite a symlink or non-file: {path}")
    identity_before_read = filesystem_identity(path)
    original_manifest, payload_offset, payload_size, _, _, _ = read_uac(path, verify_payload=False)
    if filesystem_identity(path) != identity_before_read:
        raise UACError(f"UAC changed while its manifest was being read: {path}")
    if original_manifest != expected_original_manifest:
        raise UACError(f"UAC manifest changed after the collection scan: {path}")
    if manifest.get("payload") != original_manifest.get("payload"):
        raise UACError("Manifest-only updates may not alter payload metadata.")
    try:
        manifest_data = json.dumps(
            manifest,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise UACError(f"Updated manifest is not valid JSON: {error}") from error
    if not (0 < len(manifest_data) <= UAC_MAX_MANIFEST_SIZE):
        raise UACError("Updated manifest exceeds the 16 MiB reader limit.")

    zstd = shutil.which("zstd")
    compressed_manifest = compress_manifest(zstd, manifest_data) if zstd else None
    if compressed_manifest is None:
        stored_manifest = manifest_data
    else:
        stored_manifest = UAC_MANIFEST_ZSTD_MAGIC + struct.pack("<I", len(manifest_data)) + compressed_manifest
    metadata_frame = (
        UAC_METADATA_MAGIC
        + struct.pack("<HH", 1, 0)
        + hashlib.sha256(manifest_data).digest()
        + stored_manifest
    )
    if len(metadata_frame) > 0xFFFFFFFF:
        raise UACError("Updated UAC metadata frame exceeds its 32-bit framing limit.")
    header = struct.pack("<II", UAC_SKIPPABLE_MAGIC, len(metadata_frame)) + metadata_frame
    expected_payload_hash = original_manifest.get("payload", {}).get("blake3")
    hasher = blake3.blake3()
    mode = stat.S_IMODE(path.stat().st_mode)
    staging_fd, staging_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".uac-tmp", dir=path.parent)
    staging = Path(staging_name)
    try:
        os.fchmod(staging_fd, mode)
        with os.fdopen(staging_fd, "wb") as target, path.open("rb") as source:
            if filesystem_identity(path) != identity_before_read:
                raise UACError(f"UAC changed before its payload was copied: {path}")
            source.seek(payload_offset)
            target.write(header)
            while True:
                chunk = source.read(1024 * 1024)
                if not chunk:
                    break
                target.write(chunk)
                hasher.update(chunk)
            if source.tell() - payload_offset != payload_size:
                raise UACError(f"UAC payload length changed while copying: {path}")
            if filesystem_identity(path) != identity_before_read:
                raise UACError(f"UAC changed while its payload was copied: {path}")
            if hasher.hexdigest() != expected_payload_hash:
                raise UACError(f"Copied payload BLAKE3 does not match the source manifest: {path}")
            target.flush()
            os.fsync(target.fileno())

        staged_manifest, staged_offset, staged_payload_size, _, _, _ = read_uac(staging, verify_payload=False)
        if staged_manifest != manifest or staged_payload_size != payload_size:
            raise UACError(f"Staged UAC did not validate as the requested metadata-only update: {path}")
        if staged_offset + staged_payload_size != staging.stat().st_size:
            raise UACError(f"Staged UAC has an invalid payload boundary: {path}")
        if filesystem_identity(path) != identity_before_read:
            raise UACError(f"UAC changed before the metadata update could be committed: {path}")
        os.replace(staging, path)
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        staging.unlink(missing_ok=True)


def enrich_set_metadata(args: argparse.Namespace) -> None:
    root = Path(args.root).expanduser().absolute()
    if not root.is_dir():
        raise UACError(f"UAC collection root is not a directory: {root}")
    counts = {"scanned": 0, "updated": 0, "alreadyPresent": 0, "unmapped": 0, "errors": 0}
    errors: list[dict[str, str]] = []
    for path in sorted(root.rglob("*.uac")):
        if path.is_symlink() or not path.is_file():
            continue
        counts["scanned"] += 1
        try:
            manifest, _, _, _, _, _ = read_uac(path, verify_payload=False)
            original_manifest = json.loads(json.dumps(manifest, ensure_ascii=False))
            game = manifest.get("game")
            metadata = game.get("metadata", {}) if isinstance(game, dict) else {}
            if isinstance(metadata, dict) and "set" in metadata:
                if not refresh_project2612_set_metadata(manifest):
                    counts["alreadyPresent"] += 1
                    continue
            elif not add_source_set_metadata(manifest):
                counts["unmapped"] += 1
                continue
            if args.apply:
                rewrite_uac_manifest(path, manifest, original_manifest)
            counts["updated"] += 1
        except (OSError, UACError, ValueError, TypeError, AttributeError) as error:
            counts["errors"] += 1
            if len(errors) < 100:
                errors.append({"path": str(path), "error": str(error)})
    print(json.dumps({"root": str(root), "mode": "apply" if args.apply else "dry-run", **counts, "errors": errors}, ensure_ascii=False, indent=2))


def inspect(args: argparse.Namespace) -> None:
    path = Path(args.container).expanduser().resolve()
    manifest, _, payload_size, manifest_encoding, manifest_bytes, stored_manifest_bytes = read_uac(
        path,
        verify_payload=args.verify,
    )
    summary = {
        "packageID": manifest.get("packageID"),
        "game": manifest.get("game"),
        "variants": len(manifest.get("variants", [])),
        "members": len(manifest.get("members", [])),
        "playlists": len(manifest.get("playlists", [])),
        "sources": len(manifest.get("sources", [])),
        "transformations": len(manifest.get("transformations", [])),
        "compressionProfile": manifest.get("payload", {}).get("compressionProfile"),
        "encoderVersion": manifest.get("payload", {}).get("encoderVersion"),
        "manifestEncoding": manifest_encoding,
        "manifestBytes": manifest_bytes,
        "storedManifestBytes": stored_manifest_bytes,
        "manifestSavedBytes": manifest_bytes - stored_manifest_bytes,
        "payloadBytes": payload_size,
        "verifiedPayload": args.verify,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))


def verify_tar_members(manifest: dict, tar_path: Path) -> list[tarfile.TarInfo]:
    expected_records = manifest.get("members")
    if not isinstance(expected_records, list):
        raise UACError("UAC manifest has no member list.")
    expected = {record.get("path"): record for record in expected_records if isinstance(record, dict)}
    if len(expected) != len(expected_records):
        raise UACError("UAC manifest contains duplicate or malformed members.")
    with tarfile.open(tar_path, mode="r:") as archive:
        members = archive.getmembers()
        if len(members) != len(expected) or {member.name for member in members} != set(expected):
            raise UACError("TAR member paths do not match the UAC manifest.")
        for member in members:
            record = expected[member.name]
            if not member.isfile() or not safe_relative_path(member.name):
                raise UACError(f"UAC TAR contains an unsafe or non-regular member: {member.name}")
            if member.offset_data != record.get("tarDataOffset") or member.size != record.get("byteSize"):
                raise UACError(f"UAC TAR member range disagrees with its manifest: {member.name}")
            source = archive.extractfile(member)
            if source is None:
                raise UACError(f"Cannot read TAR member: {member.name}")
            hasher = blake3.blake3()
            checksum = 0
            with source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    hasher.update(block)
                    checksum = zlib.crc32(block, checksum)
            if hasher.hexdigest() != record.get("blake3"):
                raise UACError(f"Raw member BLAKE3 mismatch: {member.name}")
            expected_crc = next((
                item.get("digest") for item in record.get("hashes", [])
                if isinstance(item, dict)
                and item.get("scope") == "raw-member"
                and item.get("algorithm") == "crc32-iso-hdlc"
            ), None)
            if expected_crc is not None and expected_crc != f"{checksum & 0xFFFFFFFF:08X}":
                raise UACError(f"Raw member CRC32 mismatch: {member.name}")
        return members


def unpack(args: argparse.Namespace) -> None:
    path = Path(args.container).expanduser().resolve()
    output = Path(args.output).expanduser().absolute()
    if output.exists():
        raise UACError(f"Refusing to overwrite existing output directory: {output}")
    zstd = shutil.which("zstd")
    if not zstd:
        raise UACError("Unpacking requires the zstd command-line decoder.")
    manifest, _, _, _, _, _ = read_uac(path, verify_payload=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{output.name}.uacman-", dir=output.parent))
    try:
        with tempfile.TemporaryDirectory(prefix="uacman-unpack-") as temporary:
            tar_path = Path(temporary) / "payload.tar"
            with tar_path.open("wb") as tar_output:
                result = subprocess.run(
                    [zstd, "-q", "-d", "-c", str(path)],
                    stdout=tar_output,
                    stderr=subprocess.PIPE,
                )
            if result.returncode:
                detail = result.stderr.decode("utf-8", errors="replace").strip()
                raise UACError(f"Zstandard payload verification failed: {detail}")
            members = verify_tar_members(manifest, tar_path)
            records = {record["path"]: record for record in manifest["members"]}
            with tarfile.open(tar_path, mode="r:") as archive:
                for member in members:
                    destination = staging.joinpath(*PurePosixPath(member.name).parts)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    source = archive.extractfile(member)
                    if source is None:
                        raise UACError(f"Cannot extract TAR member: {member.name}")
                    record = records[member.name]
                    with destination.open("xb") as target:
                        with source:
                            shutil.copyfileobj(source, target, length=1024 * 1024)
                    os.chmod(destination, 0o644)
                    stream_digest_value = record.get("streamBlake3")
                    if stream_digest_value and record.get("role") == "playable":
                        actual, _, stream_crc32 = stream_digest(
                            destination,
                            "." + str(record.get("format") or ""),
                            record["blake3"],
                        )
                        if actual != stream_digest_value:
                            raise UACError(f"Playable-payload BLAKE3 mismatch: {member.name}")
                        expected_crc = next((
                            item.get("digest") for item in record.get("hashes", [])
                            if isinstance(item, dict)
                            and item.get("scope") == "playable-payload"
                            and item.get("algorithm") == "crc32-iso-hdlc"
                        ), None)
                        if expected_crc is not None and expected_crc != f"{stream_crc32 & 0xFFFFFFFF:08X}":
                            raise UACError(f"Playable-payload CRC32 mismatch: {member.name}")
            if not args.omit_manifest:
                sidecar = staging / "manifest.json"
                sidecar.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.rename(staging, output)
    except FileExistsError as error:
        raise UACError(f"Refusing to overwrite output directory created concurrently: {output}") from error
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    print(f"Unpacked {len(manifest.get('members', []))} verified members to {output}.")
    if not args.omit_manifest:
        print("Embedded metadata was also written to manifest.json.")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Build, inspect, and unpack metadata-bearing UAC audio packages.")
    commands = root.add_subparsers(dest="command", required=True)

    pack_parser = commands.add_parser("pack", help="Pack one game's directory using a JSON metadata recipe.")
    pack_parser.add_argument("input_dir", help="Directory containing one variant's original members.")
    pack_parser.add_argument("recipe", help="JSON file with game, variants, source, and optional playlist metadata.")
    pack_parser.add_argument("output", help="New .uac path; existing files are never overwritten.")
    pack_parser.add_argument("--variant-id", default="original")
    pack_parser.add_argument("--level", type=int, default=3, help="Zstandard level 0-22 (default: 3; 20-22 use --ultra).")
    pack_parser.add_argument("--frame-size", type=int, default=4194304, help="Maximum seek frame size in bytes (default: 4 MiB; limit: 64 MiB).")
    pack_parser.add_argument("--include-macos-sidecars", action="store_true", help="Include .DS_Store and AppleDouble files intentionally.")
    pack_parser.add_argument(
        "--harvest-spc-metadata",
        metavar="UACMAN_METADATA_CLI",
        help="Read SPC tags through UACManMetadataCLI/MetaManCore before writing the manifest.",
    )
    pack_parser.add_argument(
        "--harvest-format-metadata",
        action="append",
        nargs=2,
        metavar=("EXTENSION", "UACMAN_METADATA_CLI"),
        help=(
            "Read a MetaMan-supported format before writing the manifest; "
            "track-aware results become ordered subsong playlist entries; "
            "may be repeated for different extensions (SPC keeps its specialized option)."
        ),
    )
    pack_parser.set_defaults(run=pack)

    source_tree_parser = commands.add_parser(
        "pack-source-tree",
        help="Convert a tree of per-game .tar.zst source packages into a parallel .uac tree.",
    )
    source_tree_parser.add_argument("source_root", help="Read-only root containing per-game .tar.zst packages.")
    source_tree_parser.add_argument("output_root", help="New output tree; it must not already exist.")
    source_tree_parser.add_argument("--metadata-cli", required=True, help="Built UACManMetadataCLI executable linked to MetaManCore.")
    source_tree_parser.add_argument("--source-name", help="Source collection label (defaults to the input root name).")
    source_tree_parser.add_argument("--source-url", help="Verified source website URL to embed in each package.")
    source_tree_parser.add_argument(
        "--metadata-format",
        action="append",
        metavar="EXTENSION",
        help="Also harvest this MetaMan-supported format; track-aware results become subsong entries (SPC is included by default).",
    )
    source_tree_parser.add_argument("--level", type=int, default=3, help="Zstandard level 0-22 (default: 3).")
    source_tree_parser.add_argument("--frame-size", type=int, default=4194304, help="Maximum seek frame size in bytes (default: 4 MiB).")
    source_tree_parser.add_argument("--progress-interval", type=int, default=25, help="Report progress after this many source packages (default: 25).")
    source_tree_parser.set_defaults(run=pack_source_archive_tree)

    inspect_parser = commands.add_parser("inspect", help="Read UAC metadata and optionally verify the compressed payload hash.")
    inspect_parser.add_argument("container")
    inspect_parser.add_argument("--verify", action="store_true")
    inspect_parser.set_defaults(run=inspect)

    enrich_sets_parser = commands.add_parser(
        "enrich-sets",
        help="Add source-backed game.metadata.set records or refresh the retired Project2612 links.",
    )
    enrich_sets_parser.add_argument("root", help="Collection directory to scan recursively for .uac files.")
    enrich_sets_parser.add_argument("--apply", action="store_true", help="Apply updates; without this flag, report a dry run.")
    enrich_sets_parser.set_defaults(run=enrich_set_metadata)

    unpack_parser = commands.add_parser("unpack", help="Verify and extract every listed member; metadata is emitted by default.")
    unpack_parser.add_argument("container")
    unpack_parser.add_argument("output")
    unpack_parser.add_argument("--omit-manifest", action="store_true", help="Explicitly omit the manifest.json sidecar.")
    unpack_parser.set_defaults(run=unpack)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        args.run(args)
    except UACError as error:
        print(f"uacman: {error}", file=sys.stderr)
        return 2
    except (OSError, subprocess.SubprocessError, tarfile.TarError) as error:
        print(f"uacman: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
