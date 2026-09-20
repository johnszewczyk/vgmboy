from __future__ import annotations

import hashlib
import gzip
import importlib.util
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import tarfile
import unicodedata
import unittest
import zlib
from pathlib import Path


UACMAN = Path(__file__).resolve().parents[1] / "uacman.py"
UACMAN_SPEC = importlib.util.spec_from_file_location("uacman", UACMAN)
uacman = importlib.util.module_from_spec(UACMAN_SPEC)
assert UACMAN_SPEC and UACMAN_SPEC.loader
UACMAN_SPEC.loader.exec_module(uacman)


def minimal_vgm(version: int, commands: bytes = b"\x66") -> bytes:
    header = bytearray(0x40)
    header[:4] = b"Vgm "
    struct.pack_into("<I", header, 0x04, len(commands) + len(header) - 4)
    struct.pack_into("<I", header, 0x08, version)
    struct.pack_into("<I", header, 0x34, 0x0C)
    return bytes(header) + commands


@unittest.skipUnless(
    shutil.which("zstd"),
    "UAC round-trip integration test requires the zstd command-line tool",
)
class UACManRoundTripTests(unittest.TestCase):
    def test_archive_member_names_survive_filesystem_unicode_normalization(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-unicode-path-test-") as temporary:
            root = Path(temporary)
            original_name = "track Flügels.spc"
            source_tar = root / "source.tar"
            source_zst = root / "source.tar.zst"
            contents = b"SPC member bytes"
            with tarfile.open(source_tar, mode="w", format=tarfile.PAX_FORMAT) as archive:
                info = tarfile.TarInfo(original_name)
                info.size = len(contents)
                archive.addfile(info, io.BytesIO(contents))
            with source_zst.open("wb") as output:
                subprocess.run(
                    ["zstd", "-q", "-c", str(source_tar)],
                    stdout=output,
                    check=True,
                )

            extracted = root / "extracted"
            member_path_map: dict[str, str] = {}
            uacman.extract_zstd_tar(source_zst, extracted, member_path_map)
            files, _ = uacman.discover_files(extracted, include_macos_sidecars=False)
            filesystem_path = files[0][1]
            self.assertEqual(
                member_path_map[unicodedata.normalize("NFC", filesystem_path)],
                original_name,
            )

            recipe = uacman.normalize_recipe({
                "game": {"id": "unicode", "title": "Unicode", "console": "Nintendo SNES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [],
                "extensions": {}, "memberOverrides": {},
            })
            output_tar = root / "output.tar"
            records, _ = uacman.create_tar(
                extracted,
                output_tar,
                recipe,
                "original",
                False,
                member_path_map,
            )
            self.assertEqual(records[0]["path"], original_name)
            self.assertEqual(records[0]["originalName"], original_name)
            with tarfile.open(output_tar, mode="r:") as archive:
                member = archive.getmembers()[0]
                self.assertEqual(member.name, original_name)
                self.assertEqual(archive.extractfile(member).read(), contents)

    def test_unicode_metadata_paths_match_and_reject_normalization_collisions(self) -> None:
        composed = "15 - Yokohama Flügels.spc"
        decomposed = unicodedata.normalize("NFD", composed)
        self.assertEqual(
            uacman.match_unicode_member_paths(
                {decomposed: {"title": "Track"}},
                {composed},
                "fixture metadata",
            ),
            {composed: {"title": "Track"}},
        )
        with self.assertRaisesRegex(uacman.UACError, "collide after Unicode normalization"):
            uacman.match_unicode_member_paths(
                {composed: {}},
                {composed, decomposed},
                "fixture metadata",
            )

    def test_multiple_sources_require_explicit_member_attribution(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-sources-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "track.spc").write_bytes(make_spc_fixture())
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
            cover = source / "scans" / "front.png"
            cue_sheet = source / "audio" / "disc.cue"
            notes = source / "notes.md"
            cover.parent.mkdir(parents=True)
            cue_sheet.parent.mkdir(parents=True)
            track_bytes = make_spc_fixture()
            playlist_bytes = b"#EXTM3U\r\n# Song title\r\ntrack 01.spc\r\n"
            cover_bytes = b"fixture PNG scan bytes"
            cue_bytes = b'FILE "album.flac" WAVE\n  TRACK 01 AUDIO\n    INDEX 01 00:00:00\n'
            notes_bytes = b"# Source notes\nPreserved verbatim.\n"
            track.write_bytes(track_bytes)
            playlist.write_bytes(playlist_bytes)
            cover.write_bytes(cover_bytes)
            cue_sheet.write_bytes(cue_bytes)
            notes.write_bytes(notes_bytes)

            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps({
                "packageID": "fixture-game",
                "game": {
                    "id": "fixture-game",
                    "title": "Fixture Game",
                    "console": "Nintendo SNES",
                    "metadata": {
                        "cover_front": [{
                            "memberPath": "scans/front.png",
                            "mediaType": "image/png",
                        }],
                        "cue_sheet": {
                            "memberPath": "audio/disc.cue",
                            "mediaType": "application/x-cue",
                        },
                        "documents": [{
                            "memberPath": "notes.md",
                            "mediaType": "text/markdown",
                        }],
                    },
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
                    "originalMemberPath": "album.m3u",
                    "entries": [{
                        "targetMemberPath": "track 01.spc",
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
                    "scans/front.png": {"role": "artwork"},
                    "audio/disc.cue": {"role": "cue-sheet"},
                    "notes.md": {"role": "documentation"},
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
            self.assertEqual(inspected["members"], 5)
            self.assertEqual(inspected["playlists"], 1)
            self.assertEqual(inspected["transformations"], 1)
            self.assertTrue(inspected["verifiedPayload"])

            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            restored_track = (unpacked / "track 01.spc").read_bytes()
            self.assertEqual(restored_track, track_bytes)
            self.assertEqual(len(restored_track), 0x10200)
            self.assertEqual(restored_track[:27], b"SNES-SPC700 Sound File Data")
            self.assertEqual((unpacked / "album.m3u").read_bytes(), playlist_bytes)
            self.assertEqual((unpacked / "scans/front.png").read_bytes(), cover_bytes)
            self.assertEqual((unpacked / "audio/disc.cue").read_bytes(), cue_bytes)
            self.assertEqual((unpacked / "notes.md").read_bytes(), notes_bytes)

            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["manifestVersion"], 2)
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
            self.assertEqual(len(package_step["inputs"]), 5)
            self.assertEqual(len(package_step["outputs"]), 5)
            self.assertEqual(package_step["inputs"][0]["sourceID"], "fixture-source")
            self.assertEqual(manifest["game"]["metadata"]["cover_front"][0]["memberPath"], "scans/front.png")
            member_by_path = {item["path"]: item for item in manifest["members"]}
            self.assertEqual(member_by_path["scans/front.png"]["role"], "artwork")
            self.assertEqual(member_by_path["audio/disc.cue"]["role"], "cue-sheet")
            self.assertEqual(member_by_path["notes.md"]["role"], "documentation")

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

    def test_nsf_harvest_packages_ordered_subsongs_without_rewriting_source_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-nsf-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            game = source / "game.nsf"
            one_track = source / "one-track.nsf"
            game_bytes = make_nsf_fixture("Game bytes")
            one_track_bytes = make_nsf_fixture("One-track bytes")
            game.write_bytes(game_bytes)
            one_track.write_bytes(one_track_bytes)
            helper = root / "metadata-helper"
            response = {
                "schemaVersion": 1,
                "memberMetadata": {
                    "game.nsf": {"game": "Fixture Game", "system": "Nintendo NES", "artist": "Composer"},
                    "one-track.nsf": {"title": "Solo", "game": "Fixture Game", "system": "Nintendo NES"},
                },
                "trackMetadata": {
                    "game.nsf": [{
                        "sourceTrackIndex": index,
                        "metadata": {
                            "title": f"Track {index + 1}", "game": "Fixture Game",
                            "artist": "Composer", "playLengthMs": 150000,
                            "nativeMetadata": {"format": "nsf", "technicalFacts": {"sourceTrackIndex": str(index)}},
                        },
                    } for index in range(3)],
                    "one-track.nsf": [{"sourceTrackIndex": 0, "metadata": {"title": "Solo"}}],
                },
                "gameMetadata": {}, "sharedFieldConflicts": [], "diagnosticCount": 1, "failures": [],
            }
            helper.write_text(
                "#!/usr/bin/env python3\nimport json\nprint(json.dumps(" + repr(response) + "))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe = {
                "game": {"id": "fixture", "title": "Fixture Game", "console": "Nintendo NES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [{
                    "id": "source", "collection": "Fixture", "setName": "NSF",
                    "sourceName": "fixture", "observedAt": "2026-09-17T00:00:00Z",
                }],
                "playlists": [], "extensions": {}, "memberOverrides": {},
            }

            count, diagnostics = uacman.harvest_format_metadata(source, helper, recipe, "nsf")

            self.assertEqual((count, diagnostics), (2, 1))
            self.assertNotIn("title", recipe["memberOverrides"]["game.nsf"]["metadata"])
            imported = recipe["playlists"][0]
            self.assertEqual(imported["id"], "metaman-nsf-tracks")
            self.assertEqual(len(imported["entries"]), 4)
            self.assertEqual([entry["trackIndex"] for entry in imported["entries"]], ["0", "1", "2", "0"])
            self.assertEqual({entry["targetMemberPath"] for entry in imported["entries"][:3]}, {"game.nsf"})
            self.assertEqual(imported["entries"][1]["extraFields"]["metaManMetadata"]["title"], "Track 2")
            self.assertEqual(game.read_bytes(), game_bytes)
            self.assertEqual(one_track.read_bytes(), one_track_bytes)

            pack_recipe = {
                "game": {"id": "fixture", "title": "Fixture Game", "console": "Nintendo NES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [{
                    "id": "source", "collection": "Fixture", "setName": "NSF",
                    "sourceName": "fixture", "observedAt": "2026-09-17T00:00:00Z",
                }],
                "transformations": [], "playlists": [], "extensions": {}, "memberOverrides": {},
            }
            recipe_path = root / "pack-recipe.json"
            recipe_path.write_text(json.dumps(pack_recipe), encoding="utf-8")
            container = root / "fixture.uac"
            self.run_uacman(
                "pack", str(source), str(recipe_path), str(container),
                "--harvest-format-metadata", "nsf", str(helper),
            )
            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            track_list = next(item for item in manifest["playlists"] if item["id"] == "metaman-nsf-tracks")
            self.assertEqual(len(track_list["entries"]), 4)
            self.assertEqual((unpacked / "game.nsf").read_bytes(), game_bytes)
            self.assertEqual((unpacked / "one-track.nsf").read_bytes(), one_track_bytes)

    def test_gbs_harvest_packages_ordered_subsongs_and_round_trips_source_bytes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-gbs-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            game = source / "game.gbs"
            one_track = source / "one-track.gbs"
            game_bytes = make_gbs_fixture("Fixture Game", track_count=2)
            one_track_bytes = make_gbs_fixture("One Track Game", track_count=1)
            game.write_bytes(game_bytes)
            one_track.write_bytes(one_track_bytes)

            helper = root / "metadata-helper"
            response = {
                "schemaVersion": 1,
                "memberMetadata": {
                    "game.gbs": {"game": "Fixture Game", "system": "Nintendo Game Boy", "artist": "Composer"},
                    "one-track.gbs": {"game": "One Track Game", "system": "Nintendo Game Boy", "artist": "Composer"},
                },
                "trackMetadata": {
                    "game.gbs": [{
                        "sourceTrackIndex": index,
                        "metadata": {
                            "game": "Fixture Game", "system": "Nintendo Game Boy", "artist": "Composer",
                            "nativeMetadata": {"format": "gbs", "technicalFacts": {"sourceTrackIndex": str(index)}},
                        },
                    } for index in range(2)],
                    "one-track.gbs": [{
                        "sourceTrackIndex": 0,
                        "metadata": {
                            "game": "One Track Game", "system": "Nintendo Game Boy", "artist": "Composer",
                            "nativeMetadata": {"format": "gbs", "technicalFacts": {"sourceTrackIndex": "0"}},
                        },
                    }],
                },
                "gameMetadata": {}, "sharedFieldConflicts": [], "diagnosticCount": 0, "failures": [],
            }
            helper.write_text(
                "#!/usr/bin/env python3\nimport json\nprint(json.dumps(" + repr(response) + "))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe = {
                "game": {"id": "fixture", "title": "Fixture Game", "console": "Nintendo Game Boy"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [{
                    "id": "source", "collection": "Fixture", "setName": "GBS",
                    "sourceName": "fixture", "observedAt": "2026-09-17T00:00:00Z",
                }],
                "transformations": [], "playlists": [], "extensions": {}, "memberOverrides": {},
            }
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
            container = root / "fixture.uac"
            self.run_uacman(
                "pack", str(source), str(recipe_path), str(container),
                "--harvest-format-metadata", "gbs", str(helper),
            )
            inspected = json.loads(self.run_uacman("inspect", str(container), "--verify").stdout)
            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))

            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            track_list = next(item for item in manifest["playlists"] if item["id"] == "metaman-gbs-tracks")
            self.assertTrue(inspected["verifiedPayload"])
            self.assertEqual(inspected["members"], 2)
            self.assertEqual(manifest["manifestVersion"], 2)
            self.assertEqual([entry["trackIndex"] for entry in track_list["entries"]], ["0", "1", "0"])
            self.assertEqual(
                [entry["targetMemberPath"] for entry in track_list["entries"]],
                ["game.gbs", "game.gbs", "one-track.gbs"],
            )
            self.assertEqual(
                track_list["entries"][1]["extraFields"]["metaManMetadata"]["nativeMetadata"]["format"],
                "gbs",
            )
            self.assertEqual((unpacked / "game.gbs").read_bytes(), game_bytes)
            self.assertEqual((unpacked / "one-track.gbs").read_bytes(), one_track_bytes)

    def test_single_track_gbs_still_gets_an_explicit_subsong_entry(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-gbs-single-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            payload = make_gbs_fixture("Single Track", track_count=1)
            (source / "single.gbs").write_bytes(payload)
            helper = root / "metadata-helper"
            response = {
                "schemaVersion": 1,
                "memberMetadata": {"single.gbs": {"game": "Single Track", "system": "Nintendo Game Boy"}},
                "trackMetadata": {"single.gbs": [{"sourceTrackIndex": 0, "metadata": {"title": "Only Track"}}]},
                "gameMetadata": {}, "sharedFieldConflicts": [], "diagnosticCount": 0, "failures": [],
            }
            helper.write_text(
                "#!/usr/bin/env python3\nimport json\nprint(json.dumps(" + repr(response) + "))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps({
                "game": {"id": "single", "title": "Single Track", "console": "Nintendo Game Boy"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [], "extensions": {}, "memberOverrides": {},
            }), encoding="utf-8")
            container = root / "single.uac"
            self.run_uacman(
                "pack", str(source), str(recipe_path), str(container),
                "--harvest-format-metadata", "gbs", str(helper),
            )
            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            track_list = next(item for item in manifest["playlists"] if item["id"] == "metaman-gbs-tracks")
            self.assertEqual(len(track_list["entries"]), 1)
            self.assertEqual(track_list["entries"][0]["trackIndex"], "0")
            self.assertEqual(track_list["entries"][0]["targetMemberPath"], "single.gbs")
            self.assertEqual((unpacked / "single.gbs").read_bytes(), payload)

    def test_packages_with_multiple_variants_keep_variant_namespaces(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-variants-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            track_bytes = minimal_vgm(0x171)
            (source / "track.vgm").write_bytes(track_bytes)
            recipe = {
                "game": {"id": "fixture", "title": "Fixture Game", "console": "Sega Genesis"},
                "variants": [
                    {"id": "original", "label": "Original", "kind": "release"},
                    {"id": "europe", "label": "Europe", "kind": "regional"},
                ],
                "sources": [{
                    "id": "source", "collection": "Fixture", "setName": "VGM",
                    "sourceName": "fixture", "observedAt": "2026-09-17T00:00:00Z",
                }],
            }
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
            container = root / "fixture.uac"
            self.run_uacman("pack", str(source), str(recipe_path), str(container), "--variant-id", "original")
            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))

            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["manifestVersion"], 2)
            self.assertEqual(manifest["members"][0]["path"], "variants/original/track.vgm")
            self.assertEqual((unpacked / "variants/original/track.vgm").read_bytes(), track_bytes)

    def test_package_records_contained_vgm_versions_and_crc32_hashes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-vgm-version-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            members = {
                "01-old.vgm": minimal_vgm(0x170),
                "02-new.vgm": minimal_vgm(0x171),
                "cover.png": b"fixture PNG bytes",
            }
            for name, contents in members.items():
                (source / name).write_bytes(contents)
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps({
                "game": {"id": "vgm-fixture", "title": "VGM Fixture", "console": "Sega Genesis"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [],
            }), encoding="utf-8")
            container = root / "vgm-fixture.uac"
            self.run_uacman("pack", str(source), str(recipe_path), str(container))
            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))

            self.assertEqual(
                manifest["game"]["metadata"]["containedContainerVersions"],
                {
                    "schemaVersion": 1,
                    "formatsScanned": ["spc", "vgm"],
                    "mixedVersionFormats": ["vgm"],
                    "versions": {
                        "spc": [],
                        "vgm": [
                            {"version": "1.70", "versionRaw": "0x00000170", "memberCount": 1},
                            {"version": "1.71", "versionRaw": "0x00000171", "memberCount": 1},
                        ]
                    },
                },
            )
            by_path = {member["path"]: member for member in manifest["members"]}
            self.assertEqual(by_path["01-old.vgm"]["metadata"]["sub-container-version"], "1.70")
            self.assertEqual(by_path["02-new.vgm"]["metadata"]["sub-container-version"], "1.71")
            self.assertEqual(
                manifest["game"]["metadata"]["criticalFlags"],
                [{
                    "code": "mixed-sub-container-version",
                    "severity": "critical",
                    "format": "vgm",
                    "versions": ["1.70", "1.71"],
                    "reason": "One title contains multiple sub-container versions; review source provenance before treating it as a clean single-source rip.",
                }],
            )
            for name, contents in members.items():
                self.assertEqual((unpacked / name).read_bytes(), contents)
                expected_crc = f"{zlib.crc32(contents) & 0xFFFFFFFF:08X}"
                raw_crc = next(
                    item["digest"] for item in by_path[name]["hashes"]
                    if item["scope"] == "raw-member" and item["algorithm"] == "crc32-iso-hdlc"
                )
                self.assertEqual(raw_crc, expected_crc)
                if name.endswith(".vgm"):
                    playable_crc = next(
                        item["digest"] for item in by_path[name]["hashes"]
                        if item["scope"] == "playable-payload" and item["algorithm"] == "crc32-iso-hdlc"
                    )
                    self.assertEqual(playable_crc, expected_crc)

    def test_pack_rejects_malformed_vgm_when_recording_container_version(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-vgm-invalid-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "bad.vgm").write_bytes(b"not a VGM file")
            recipe = uacman.normalize_recipe({
                "game": {"id": "bad", "title": "Bad", "console": "Sega Genesis"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [],
            })
            with self.assertRaisesRegex(uacman.UACError, "Invalid or truncated VGM"):
                uacman.apply_contained_container_versions(source, recipe)

    def test_pack_rejects_vgz_and_gzip_wrapped_vgm_members(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-vgz-reject-test-") as temporary:
            root = Path(temporary)
            recipe = uacman.normalize_recipe({
                "game": {"id": "compressed", "title": "Compressed", "console": "Sega Genesis"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [],
            })

            vgz_source = root / "vgz-source"
            vgz_source.mkdir()
            with gzip.open(vgz_source / "track.vgz", "wb") as output:
                output.write(minimal_vgm(0x171))
            with self.assertRaisesRegex(uacman.UACError, "VGZ members are forbidden"):
                uacman.apply_contained_container_versions(vgz_source, recipe)

            wrapped_source = root / "wrapped-source"
            wrapped_source.mkdir()
            with gzip.open(wrapped_source / "track.vgm", "wb") as output:
                output.write(minimal_vgm(0x171))
            with self.assertRaisesRegex(uacman.UACError, "gzip-wrapped \.vgm"):
                uacman.apply_contained_container_versions(wrapped_source, recipe)

    def test_package_records_spc_versions_and_per_member_metadata(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-spc-version-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            members = {
                "current.spc": make_spc_fixture(30, "0.30"),
                "old-header-current-byte.spc": make_spc_fixture(10, "0.30"),
                "old.spc": make_spc_fixture(10, "0.10"),
            }
            for name, contents in members.items():
                (source / name).write_bytes(contents)
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps({
                "game": {"id": "spc-fixture", "title": "SPC Fixture", "console": "Nintendo SNES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [],
            }), encoding="utf-8")
            container = root / "spc-fixture.uac"
            self.run_uacman("pack", str(source), str(recipe_path), str(container))
            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))

            inventory = manifest["game"]["metadata"]["containedContainerVersions"]
            self.assertEqual(inventory["formatsScanned"], ["spc", "vgm"])
            self.assertEqual(inventory["mixedVersionFormats"], ["spc"])
            self.assertEqual(inventory["versions"]["spc"], [
                {
                    "version": "0.10",
                    "versionByte": 10,
                    "memberCount": 2,
                    "headerVersions": [
                        {"version": "0.10", "memberCount": 1},
                        {"version": "0.30", "memberCount": 1},
                    ],
                },
                {
                    "version": "0.30",
                    "versionByte": 30,
                    "memberCount": 1,
                    "headerVersions": [{"version": "0.30", "memberCount": 1}],
                },
            ])
            by_name = {member["originalName"]: member for member in manifest["members"]}
            self.assertEqual(by_name["old-header-current-byte.spc"]["metadata"]["spcVersion"], "0.10")
            self.assertEqual(by_name["old-header-current-byte.spc"]["metadata"]["spcVersionByte"], 10)
            self.assertEqual(by_name["old-header-current-byte.spc"]["metadata"]["spcHeaderVersion"], "0.30")
            for name, contents in members.items():
                self.assertEqual((unpacked / name).read_bytes(), contents)

    def test_pack_rejects_malformed_spc_when_recording_container_version(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-spc-invalid-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "bad.spc").write_bytes(b"not an SPC file")
            recipe = uacman.normalize_recipe({
                "game": {"id": "bad", "title": "Bad", "console": "Nintendo SNES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [], "transformations": [], "playlists": [],
            })
            with self.assertRaisesRegex(uacman.UACError, "Invalid or truncated SPC"):
                uacman.apply_contained_container_versions(source, recipe)

    def test_standard_audio_and_ape_are_playable_uac_members_with_native_metadata(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-audio-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            album = source / "Album"
            album.mkdir(parents=True)
            source_bytes = {
                "Album/01.flac": b"unchanged FLAC member bytes",
                "Album/02.ape": b"unchanged APE member bytes",
            }
            for relative, data in source_bytes.items():
                (source / relative).write_bytes(data)

            helper = root / "metadata-helper"
            helper.write_text(
                "#!/usr/bin/env python3\n"
                "import json, pathlib, sys\n"
                "extension = sys.argv[2]\n"
                "root = pathlib.Path(sys.argv[3])\n"
                "members = {}\n"
                "tracks = {}\n"
                "for path in root.rglob('*'):\n"
                "    if path.is_file() and path.suffix.lower() == '.' + extension:\n"
                "        relative = path.relative_to(root).as_posix()\n"
                "        fields = {'title': path.stem, 'nativeMetadata': {'format': extension, 'tags': [{'name': 'X-CUSTOM', 'value': 'preserved'}]}}\n"
                "        members[relative] = fields\n"
                "        tracks[relative] = [{'sourceTrackIndex': None, 'metadata': fields}]\n"
                "print(json.dumps({'schemaVersion': 1, 'memberMetadata': members, 'trackMetadata': tracks, 'gameMetadata': {}, 'sharedFieldConflicts': [], 'diagnosticCount': 0, 'failures': []}))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe = {
                "game": {"id": "lossless-album", "title": "Lossless Album", "console": "Standard audio"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [{
                    "id": "source", "collection": "Fixture", "setName": "Album",
                    "sourceName": "Album", "observedAt": "2026-09-17T00:00:00Z",
                }],
            }
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
            container = root / "album.uac"

            self.run_uacman(
                "pack", str(source), str(recipe_path), str(container),
                "--harvest-format-metadata", "flac", str(helper),
                "--harvest-format-metadata", "ape", str(helper),
            )

            unpacked = root / "unpacked"
            self.run_uacman("unpack", str(container), str(unpacked))
            manifest = json.loads((unpacked / "manifest.json").read_text(encoding="utf-8"))
            members = {member["originalName"]: member for member in manifest["members"]}
            for relative, data in source_bytes.items():
                name = Path(relative).name
                member = members[name]
                self.assertEqual(member["role"], "playable")
                self.assertEqual(member["metadata"]["title"], Path(name).stem)
                self.assertEqual(
                    member["metadata"]["nativeMetadata"]["tags"],
                    [{"name": "X-CUSTOM", "value": "preserved"}],
                )
                self.assertEqual(
                    (unpacked / relative).read_bytes(), data
                )

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


class SetMetadataTests(unittest.TestCase):
    def test_source_set_projection_requires_one_consistent_source_and_official_url(self) -> None:
        self.assertEqual(
            uacman.source_set_metadata([{
                "collection": "JoshW", "setName": "Nintendo SNES",
            }]),
            {
                "collection": "JoshW",
                "name": "Nintendo SNES",
                "url": "https://spc.joshw.info/",
            },
        )
        archived = uacman.source_set_metadata([{
            "collection": "Project2612", "setName": "Sega Genesis",
        }])
        self.assertEqual(archived["url"], "https://vgmrips.net/packs/system/sega/mega-drive")
        self.assertEqual(archived["legacyURL"], "https://project2612.org/list.php")
        self.assertEqual(archived["archiveURL"], "https://web.archive.org/web/20240809092444/https://project2612.org/list.php")
        self.assertIsNone(uacman.source_set_metadata([
            {"collection": "JoshW", "setName": "Nintendo SNES"},
            {"collection": "ZopharsDomain", "setName": "Game Boy"},
        ]))
        self.assertIsNone(uacman.source_set_metadata([{
            "collection": "Mr Norbert GBS Development", "setName": "GBS Rips",
        }]))

    def test_redump_projection_uses_disc_source_over_derived_and_metadata_links(self) -> None:
        sources = [
            {
                "id": "redump-disc-archive",
                "collection": "Redump - SNK - Neo Geo CD - (2019-10-16)",
                "setName": "RedumpSnkNeoGeoCd16Oct2019",
                "sourceURL": "https://archive.org/download/RedumpSnkNeoGeoCd16Oct2019/2020%20Super%20Baseball.7z",
            },
            {
                "id": "loose-flac-output",
                "collection": "AudioMan derived Neo Geo CD Red Book FLAC-8 output",
                "setName": "2020 Super Baseball",
            },
            {
                "id": "joshw-legacy-metadata-01",
                "collection": "ISOShare/JoshW (ISO)/NeoGeoCD",
                "setName": "legacy-snapshot",
                "metadata": {"metadataOnlyAssociation": True},
            },
        ]
        expected = {
            "collection": "Redump",
            "name": "SNK - Neo Geo CD - (2019-10-16)",
            "url": "https://archive.org/details/RedumpSnkNeoGeoCd16Oct2019",
        }
        self.assertEqual(uacman.source_set_metadata(sources), expected)
        manifest = {"game": {"metadata": {}}, "sources": sources}
        self.assertTrue(uacman.add_source_set_metadata(manifest))
        self.assertEqual(manifest["game"]["metadata"]["set"], expected)

    def test_redump_projection_requires_download_item_to_match_set_identifier(self) -> None:
        source = {
            "id": "redump-disc-archive",
            "collection": "Redump - SNK - Neo Geo CD - (2019-10-16)",
            "setName": "RedumpSnkNeoGeoCd16Oct2019",
            "sourceURL": "https://archive.org/download/another-item/game.7z",
        }
        self.assertIsNone(uacman.source_set_metadata([source]))

    def test_project2612_legacy_projection_refreshes_only_known_old_links(self) -> None:
        manifest = {
            "game": {"metadata": {"set": {
                "collection": "Project2612", "name": "Sega Genesis",
                "url": "https://web.archive.org/web/20240809092444/https://project2612.org/list.php",
                "legacyURL": "https://project2612.org/list.php",
            }}},
            "sources": [{"collection": "Project2612", "setName": "Sega Genesis"}],
        }
        self.assertTrue(uacman.refresh_project2612_set_metadata(manifest))
        self.assertEqual(manifest["game"]["metadata"]["set"]["url"], "https://vgmrips.net/packs/system/sega/mega-drive")
        self.assertFalse(uacman.refresh_project2612_set_metadata(manifest))

    def test_manifest_rewrite_adds_set_metadata_without_changing_payload_bytes(self) -> None:
        if not shutil.which("zstd"):
            self.skipTest("UAC rewrite integration test requires the zstd command-line tool")
        with tempfile.TemporaryDirectory(prefix="uacman-set-metadata-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "track.spc").write_bytes(make_spc_fixture())
            recipe = {
                "game": {"id": "set-test", "title": "Set Test", "console": "Nintendo SNES"},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "sources": [{
                    "id": "test-source", "collection": "Fixture", "setName": "Test Set",
                    "sourceName": "Test Set", "sourceURL": "https://example.invalid/test-set",
                    "observedAt": "2026-09-17T00:00:00Z",
                }],
            }
            recipe_path = root / "recipe.json"
            recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
            container = root / "test.uac"
            subprocess.run(
                [sys.executable, "-B", str(UACMAN), "pack", str(source), str(recipe_path), str(container)],
                check=True,
                capture_output=True,
                text=True,
            )

            manifest, old_offset, _, _, _, _ = uacman.read_uac(container)
            expected_payload = container.read_bytes()[old_offset:]
            old_manifest = json.loads(json.dumps(manifest))
            del manifest["game"]["metadata"]["set"]
            self.assertTrue(uacman.add_source_set_metadata(manifest))
            self.assertEqual(manifest["game"]["metadata"]["set"]["url"], "https://example.invalid/test-set")

            uacman.rewrite_uac_manifest(container, manifest, old_manifest)
            rewritten, new_offset, _, _, _, _ = uacman.read_uac(container)
            self.assertEqual(container.read_bytes()[new_offset:], expected_payload)
            self.assertEqual(rewritten["game"]["metadata"]["set"], manifest["game"]["metadata"]["set"])

class MetaManMetadataImportTests(unittest.TestCase):
    def test_unicode_metadata_and_subsong_paths_resolve_to_source_spelling(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-metaman-unicode-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            native_name = "track Flügels.nsf"
            (source / native_name).write_bytes(b"original NSF bytes")
            files, _ = uacman.discover_files(source, include_macos_sidecars=False)
            filesystem_path = files[0][1]
            helper_path = unicodedata.normalize("NFD", filesystem_path)
            helper = root / "metadata-helper"
            response = {
                "schemaVersion": 1,
                "memberMetadata": {helper_path: {"title": "Native title"}},
                "trackMetadata": {helper_path: [
                    {"sourceTrackIndex": 0, "metadata": {"title": "Track one"}},
                    {"sourceTrackIndex": 1, "metadata": {"title": "Track two"}},
                ]},
                "gameMetadata": {}, "sharedFieldConflicts": [],
                "diagnosticCount": 0, "failures": [],
            }
            helper.write_text(
                "#!/usr/bin/env python3\nimport json\nprint(json.dumps(" + repr(response) + "))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe = {
                "game": {"id": "unicode", "title": "Unicode", "console": "Nintendo NES", "metadata": {}},
                "variants": [{"id": "original", "label": "Original", "kind": "release"}],
                "playlists": [], "memberOverrides": {}, "extensions": {},
            }
            member_path_map = {
                unicodedata.normalize("NFC", filesystem_path): native_name,
            }

            count, diagnostics = uacman.harvest_format_metadata(
                source,
                helper,
                recipe,
                "nsf",
                member_path_map=member_path_map,
            )

            self.assertEqual((count, diagnostics), (1, 0))
            self.assertEqual(recipe["memberOverrides"][filesystem_path]["metadata"]["title"], "Native title")
            self.assertEqual(recipe["playlists"][0]["entries"][0]["targetMemberPath"], native_name)
            self.assertEqual(recipe["playlists"][0]["entries"][1]["targetMemberPath"], native_name)

    def test_explicit_metaman_harvest_promotes_other_readable_formats_to_playable(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-metaman-role-test-") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            (source / "track.mib").write_bytes(b"MIB source bytes")
            (source / "keep-as-asset.mib").write_bytes(b"authored asset bytes")
            helper = root / "metadata-helper"
            response = {
                "schemaVersion": 1,
                "memberMetadata": {
                    "track.mib": {"title": "Native track"},
                    "keep-as-asset.mib": {"title": "Native track"},
                },
                "trackMetadata": {}, "gameMetadata": {},
                "sharedFieldConflicts": [], "diagnosticCount": 0, "failures": [],
            }
            helper.write_text(
                "#!/usr/bin/env python3\nimport json\nprint(json.dumps(" + repr(response) + "))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            recipe = {
                "memberOverrides": {"keep-as-asset.mib": {"role": "asset"}},
                "extensions": {},
            }

            count, _ = uacman.harvest_format_metadata(source, helper, recipe, "mib")

            self.assertEqual(count, 2)
            self.assertEqual(recipe["memberOverrides"]["track.mib"]["role"], "playable")
            self.assertEqual(recipe["memberOverrides"]["keep-as-asset.mib"]["role"], "asset")

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

    def test_track_aware_harvest_rejects_duplicate_decoder_indexes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="uacman-metaman-test-") as temporary:
            root = Path(temporary)
            source = root / "track.nsf"
            source.write_bytes(b"unchanged")
            helper = root / "metadata-helper"
            helper.write_text(
                "#!/usr/bin/env python3\n"
                "import json\n"
                "print(json.dumps({"
                "'schemaVersion': 1,"
                "'memberMetadata': {'track.nsf': {}},"
                "'trackMetadata': {'track.nsf': ["
                "{'sourceTrackIndex': 0, 'metadata': {}},"
                "{'sourceTrackIndex': 0, 'metadata': {}}]},"
                "'gameMetadata': {}, 'sharedFieldConflicts': [], 'diagnosticCount': 0, 'failures': []"
                "}))\n",
                encoding="utf-8",
            )
            helper.chmod(0o755)
            with self.assertRaisesRegex(uacman.UACError, "unique playable source indexes"):
                uacman.harvest_format_metadata(
                    root,
                    helper,
                    {"memberOverrides": {}, "extensions": {}, "playlists": []},
                    "nsf",
                )
            self.assertEqual(source.read_bytes(), b"unchanged")

def make_spc_fixture(version_minor: int = 30, header_version: str = "0.30") -> bytes:
    """Build a minimal-size SPC with a text-layout ID666 header."""
    data = bytearray(0x10200)
    data[:0x21] = f"SNES-SPC700 Sound File Data v{header_version}".encode("ascii")
    data[0x21] = 0x1A
    data[0x22] = 0x1A
    data[0x23] = 0x1A
    data[0x24] = version_minor
    data[0x2E:0x4E] = b"Track 01".ljust(32, b"\x00")
    data[0x4E:0x6E] = b"Fixture Game".ljust(32, b"\x00")
    data[0x6E:0x7E] = b"Codex".ljust(16, b"\x00")
    data[0x7E:0x9E] = b"UAC test fixture".ljust(32, b"\x00")
    data[0x9E:0xA9] = b"09/13/2026\x00"
    data[0xA9:0xAC] = b"154"
    data[0xAC:0xB1] = b"05000"
    data[0xB1:0xD1] = b"Codex".ljust(32, b"\x00")
    return bytes(data)


def make_nsf_fixture(title: str) -> bytes:
    data = bytearray(0x81)
    data[:5] = b"NESM\x1a"
    data[5] = 1
    data[6] = 3
    data[7] = 1
    data[0x0E:0x2E] = title.encode("ascii").ljust(32, b"\x00")[:32]
    data[0x2E:0x4E] = b"Fixture Composer".ljust(32, b"\x00")
    data[0x80] = 0x60
    return bytes(data)


def make_gbs_fixture(title: str, track_count: int) -> bytes:
    data = bytearray(0x70 + 4)
    data[:3] = b"GBS"
    data[3] = 1
    data[4] = track_count
    data[5] = 1
    data[0x06:0x08] = b"\x00\x40"
    data[0x08:0x0A] = b"\x00\x40"
    data[0x0A:0x0C] = b"\x08\x40"
    data[0x0C:0x0E] = b"\xff\xdf"
    data[0x0E] = 0xAA
    data[0x0F] = 0x05
    data[0x10:0x30] = title.encode("ascii").ljust(32, b"\x00")[:32]
    data[0x30:0x50] = b"Fixture Composer".ljust(32, b"\x00")
    data[0x50:0x70] = b"Fixture Copyright".ljust(32, b"\x00")
    data[0x70:] = b"\xC9\xC9\xC9\xC9"
    return bytes(data)


if __name__ == "__main__":
    unittest.main()
