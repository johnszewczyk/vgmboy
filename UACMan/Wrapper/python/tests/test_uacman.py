from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


UACMAN = Path(__file__).resolve().parents[1] / "uacman.py"
UACMAN_SPEC = importlib.util.spec_from_file_location("uacman", UACMAN)
uacman = importlib.util.module_from_spec(UACMAN_SPEC)
assert UACMAN_SPEC and UACMAN_SPEC.loader
UACMAN_SPEC.loader.exec_module(uacman)


@unittest.skipUnless(
    shutil.which("zstd"),
    "UAC round-trip integration test requires the zstd command-line tool",
)
class UACManRoundTripTests(unittest.TestCase):
    def test_multiple_sources_require_explicit_member_attribution(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-sources-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "track.spc").write_bytes(b"fixture")
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps({
                "game": {"id": "game", "title": "Game", "console": "Nintendo SNES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [{
                    "id": source_id,
                    "collection": "Fixture",
                    "setName": "Fixture Set",
                    "sourceName": f"{source_id}.tar",
                    "observedAt": "2026-09-13T00:00:00Z",
                } for source_id in ("source-a", "source-b")],
            }), encoding="utf-8")
            output = root / "game.uac"
            result = subprocess.run(
                [sys.executable, "-B", str(UACMAN), "pack", str(source), str(recipe_path), str(output)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("explicitly set sourceIDs", result.stderr)
            self.assertFalse(output.exists())

    def test_pack_inspect_unpack_preserves_members_and_playlist_semantics(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            track = source / "track 01.spc"
            playlist = source / "album.m3u"
            track_bytes = make_spc_fixture()
            playlist_bytes = b"#EXTM3U\r\n# Song title\r\ntrack 01.spc\r\n"
            track.write_bytes(track_bytes)
            playlist.write_bytes(playlist_bytes)

            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps({
                "packageID": "fixture-game",
                "game": {
                    "id": "fixture-game",
                    "title": "Fixture Game",
                    "console": "Nintendo SNES",
                },
                "variants": [{"id": "original", "label": "Original", "kind": "retail"}],
                "sources": [{
                    "id": "fixture-source",
                    "collection": "Fixture",
                    "setName": "Fixture Set",
                    "sourceName": "fixture.tar",
                    "observedAt": "2026-09-13T00:00:00Z",
                }],
                "playlists": [{
                    "id": "main",
                    "title": "Album playlist",
                    "variantID": "original",
                    "originalMemberPath": "variants/original/album.m3u",
                    "entries": [{
                        "targetMemberPath": "variants/original/track 01.spc",
                        "rawLine": "track 01.spc",
                        "title": "Song title",
                        "lengthRaw": "2:34",
                        "loopStartRaw": "0:42",
                        "repeatRaw": "3",
                    }],
                }],
                "memberOverrides": {
                    "track 01.spc": {
                        "metadata": {
                            "system": "Super Nintendo",
                            "game": "Fixture Game",
                            "song": "Track 01",
                            "playLengthMs": 154000,
                            "fadeLengthMs": 5000,
                        },
                    },
                },
            }), encoding="utf-8")

            container = root / "fixture.uac"
            self.run_uacman("pack", str(source), str(recipe_path), str(container), "--frame-size", "65536")
            inspect = self.run_uacman("inspect", str(container), "--verify")
            inspected = json.loads(inspect.stdout)
            self.assertEqual(inspected["compressionProfile"], "uac-zstd-seekable-level-3-frame-65536-v1")
            self.assertEqual(inspected["manifestEncoding"], "zstd-json")
            self.assertLess(inspected["storedManifestBytes"], inspected["manifestBytes"])
            self.assertGreater(inspected["manifestSavedBytes"], 0)
            self.assertEqual(inspected["members"], 2)
            self.assertEqual(inspected["playlists"], 1)
            self.assertEqual(inspected["transformations"], 1)
            self.assertTrue(inspected["verifiedPayload"])

            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            restored_track = (unpacked / "variants/original/track 01.spc").read_bytes()
            self.assertEqual(restored_track, track_bytes)
            self.assertEqual(len(restored_track), 0x10200)
            self.assertEqual(restored_track[:27], b"SNES-SPC700 Sound File Data")
            self.assertEqual((unpacked / "variants/original/album.m3u").read_bytes(), playlist_bytes)

            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            member = next(item for item in manifest["members"] if item["originalName"] == "track 01.spc")
            entry = manifest["playlists"][0]["entries"][0]
            package_step = manifest["transformations"][0]
            self.assertEqual(member["format"], "spc")
            self.assertEqual(member["role"], "playable")
            self.assertEqual(member["metadata"]["song"], "Track 01")
            self.assertEqual(member["metadata"]["playLengthMs"], 154000)
            self.assertEqual(entry["targetMemberBlake3"], member["blake3"])
            self.assertEqual(entry["lengthRaw"], "2:34")
            self.assertEqual(entry["loopStartRaw"], "0:42")
            self.assertEqual(entry["repeatRaw"], "3")
            self.assertEqual(package_step["operation"], "package")
            self.assertEqual(len(package_step["inputs"]), 2)
            self.assertEqual(len(package_step["outputs"]), 2)
            self.assertEqual(package_step["inputs"][0]["sourceID"], "fixture-source")

            legacy_manifest = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
            with container.open("rb") as source_container:
                _, metadata_size = struct.unpack("<II", source_container.read(8))
                source_container.seek(8 + metadata_size)
                compressed_payload = source_container.read()
            legacy_metadata = (
                b"UACM"
                + struct.pack("<HH", 1, 0)
                + hashlib.sha256(legacy_manifest).digest()
                + legacy_manifest
            )
            legacy_container = root / "legacy-raw-manifest.uac"
            legacy_container.write_bytes(
                struct.pack("<II", 0x184D2A55, len(legacy_metadata))
                + legacy_metadata
                + compressed_payload
            )
            legacy_inspected = json.loads(self.run_uacman("inspect", str(legacy_container)).stdout)
            self.assertEqual(legacy_inspected["manifestEncoding"], "json")
            self.assertEqual(legacy_inspected["manifestSavedBytes"], 0)

            oversized_manifest = root / "oversized-manifest.uac"
            malformed = bytearray(container.read_bytes())
            metadata_size = struct.unpack_from("<I", malformed, 4)[0]
            stored_body_size = metadata_size - 40
            struct.pack_into("<I", malformed, 8 + 40 + 4, stored_body_size + 1)
            oversized_manifest.write_bytes(malformed)
            result = subprocess.run(
                [sys.executable, "-B", str(UACMAN), "inspect", str(oversized_manifest)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("exceeds its declared decoded size", result.stderr)

    def run_uacman(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        return subprocess.run(
            [sys.executable, "-B", str(UACMAN), *arguments],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )

class MetaManMetadataImportTests(unittest.TestCase):
    def test_generic_single_track_harvest_imports_existing_sid_metadata(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-metaman-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            sid = source / "track.sid"
            source_bytes = b"original SID bytes remain unchanged"
            sid.write_bytes(source_bytes)

            helper = root / "metadata-helper"
            helper.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({"
                "'schemaVersion': 1,"
                "'memberMetadata': {'track.sid': {'title': 'Native title', 'artist': 'Native composer', 'nativeMetadata': {'format': 'sid'}}},"
                "'gameMetadata': {}, 'sharedFieldConflicts': [], 'diagnosticCount': 2, 'failures': []"
                "}))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe = {
                "memberOverrides": {"track.sid": {"metadata": {"title": "Curator title"}}},
                "extensions": {},
            }

            member_count, diagnostic_count = uacman.harvest_format_metadata(
                source,
                helper,
                recipe,
                "sid",
            )

            self.assertEqual((member_count, diagnostic_count), (1, 2))
            self.assertEqual(recipe["memberOverrides"]["track.sid"]["metadata"]["title"], "Curator title")
            self.assertEqual(recipe["memberOverrides"]["track.sid"]["metadata"]["artist"], "Native composer")
            self.assertEqual(
                recipe["extensions"]["metaManMetadataImport"]["sid"],
                {"reader": "MetaManCore", "memberCount": 1, "diagnosticCount": 2},
            )
            self.assertEqual(sid.read_bytes(), source_bytes)

    def test_generic_harvest_skips_formats_absent_from_a_source_tree(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-metaman-test-") as temporary:
            root = Path(temporary)
            (root / "track.spc").write_bytes(b"not parsed by the generic SID route")
            member_count, diagnostic_count = uacman.harvest_format_metadata(
                root,
                root / "not-needed-helper",
                {"memberOverrides": {}, "extensions": {}},
                "sid",
            )
            self.assertEqual((member_count, diagnostic_count), (0, 0))

    def test_generic_harvest_reserves_spc_specialized_merge(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-metaman-test-") as temporary:
            root = Path(temporary)
            helper = root / "unused"
            with self.assertRaises(uacman.UACError):
                uacman.harvest_format_metadata(root, helper, {"memberOverrides": {}, "extensions": {}}, "spc")

def make_spc_fixture() -> bytes:
    """Build a minimal-size SPC with a text-layout ID666 header."""
    data = bytearray(0x10200)
    data[:27] = b"SNES-SPC700 Sound File Data"
    data[0x21] = 0x1A
    data[0x22] = 0x1A
    data[0x23] = 0x1A
    data[0x2E:0x4E] = b"Track 01".ljust(32, b"\x00")
    data[0x4E:0x6E] = b"Fixture Game".ljust(32, b"\x00")
    data[0x6E:0x7E] = b"Codex".ljust(16, b"\x00")
    data[0x7E:0x9E] = b"UAC test fixture".ljust(32, b"\x00")
    data[0x9E:0xA9] = b"09/13/2026\x00"
    data[0xA9:0xAC] = b"154"
    data[0xAC:0xB1] = b"05000"
    data[0xB1:0xD1] = b"Codex".ljust(32, b"\x00")
    return bytes(data)


if __name__ == "__main__":
    unittest.main()
