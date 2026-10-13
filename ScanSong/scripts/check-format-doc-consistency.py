#!/usr/bin/env python3
"""Check format coverage, plugin profiles, and scanner routes against source."""

from collections import Counter
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
DOC_PATH = ROOT / "ScanSong/ai/subsystem-agent/format-accommodations.md"
REGISTRY_PATH = ROOT / "VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift"
MANIFEST_PATH = ROOT / "VGMBoy/Sources/VGMBoyFormatCore/VGMStreamFormatManifest.swift"
PLUGINS_PATH = ROOT / "ScanSong/Sources/ScanSongKit/BuiltInScannerPlugins.swift"
PROFILE_DIR = ROOT / "ScanSong/ai/subsystem-agent/format-profiles"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extension_array(source: str, name: str) -> set[str]:
    pattern = rf"public\s+static\s+let\s+{re.escape(name)}\s*:\s*Set<String>\s*=\s*\[(.*?)\]"
    match = re.search(pattern, source, re.DOTALL)
    if not match:
        raise ValueError(f"could not find {name} in FormatRegistry.swift")
    return set(re.findall(r'"([a-z0-9]+)"', match.group(1)))


def table_section(document: str, heading: str) -> str:
    start = document.find(heading)
    if start < 0:
        raise ValueError(f"could not find {heading!r} in format documentation")
    remainder = document[start + len(heading) :]
    next_section = re.search(r"\n## ", remainder)
    return remainder[: next_section.start()] if next_section else remainder


def main() -> int:
    errors: list[str] = []
    document = read(DOC_PATH)
    registry = read(REGISTRY_PATH)
    manifest = read(MANIFEST_PATH)
    plugins = read(PLUGINS_PATH)

    family_arrays = {
        "libgme": "libgmeExtensions",
        "asap": "asapExtensions",
        "libvgm": "libvgmExtensions",
        "psgplay": "psgPlayExtensions",
        "mdx": "mdxExtensions",
        "standard-audio": "standardAudioExtensions",
        "ffmpeg-audio": "ffmpegAudioExtensions",
        "highly-complete": "highlyCompleteExtensions",
        "twosf": "twoSFExtensions",
        "lazyusf": "lazyusfExtensions",
        "playpsf": "playpsfExtensions",
        "qsf": "qsfExtensions",
        "sidplayfp": "sidplayfpExtensions",
        "openmpt": "openMPTExtensions",
    }
    playback_section = table_section(
        document, "## Format coverage and eventual playback target"
    )
    documented_families: set[str] = set()
    all_documented_extensions: dict[str, str] = {}

    for line in playback_section.splitlines():
        cells = line.split("|")
        if len(cells) < 4:
            continue
        family_match = re.fullmatch(r"\s*`([^`]+)`\s*", cells[1])
        if not family_match:
            continue
        family = family_match.group(1)
        documented_families.add(family)
        extensions = set(re.findall(r"\.([a-z0-9]+)", cells[2]))
        if family == "amiga-uade":
            continue  # This family is selected by filename prefixes, not suffixes.
        if family == "vgmstream":
            manifest_section = manifest.split("public static let formats:", 1)[1]
            manifest_section = manifest_section.split(
                "public static let playbackExtensions", 1
            )[0]
            source_extensions = set(re.findall(r'"([a-z0-9]+)"', manifest_section))
        else:
            array_name = family_arrays.get(family)
            if array_name is None:
                errors.append(f"playback table has unrecognized family {family!r}")
                continue
            try:
                source_extensions = extension_array(registry, array_name)
            except ValueError as error:
                errors.append(str(error))
                continue

        missing = source_extensions - extensions
        extra = extensions - source_extensions
        if missing:
            errors.append(
                f"{family} playback table omits source extensions: "
                + ", ".join(f".{ext}" for ext in sorted(missing))
            )
        if extra:
            errors.append(
                f"{family} playback table has unsupported extensions: "
                + ", ".join(f".{ext}" for ext in sorted(extra))
            )

        for ext in extensions:
            previous_family = all_documented_extensions.get(ext)
            if previous_family:
                errors.append(
                    f".{ext} appears in both {previous_family} and {family} playback rows"
                )
            else:
                all_documented_extensions[ext] = family

    expected_families = set(family_arrays) | {"vgmstream", "amiga-uade"}
    for family in sorted(expected_families - documented_families):
        errors.append(f"playback table is missing family {family!r}")

    playback_descriptors = registry.split(
        "public static let playbackDescriptors:", 1
    )[1].split("public static let playbackExtensions", 1)[0]
    source_profiles = set(
        re.findall(r'PlaybackFormatDescriptor\(id:\s*"([^"]+)"', playback_descriptors)
    )
    profile_section = table_section(document, "## Parent plugin profiles")
    profile_rows = [
        (match.group(1), match.group(2))
        for line in profile_section.splitlines()
        if (
            match := re.match(
                r"\|\s*`([^`]+)`\s*\|\s*\[[^]]+\]\((format-profiles/[^)]+\.md)\)\s*\|",
                line,
            )
        )
    ]
    documented_profiles = Counter(plugin_id for plugin_id, _ in profile_rows)
    for plugin_id, count in sorted(documented_profiles.items()):
        if count > 1:
            errors.append(f"parent plugin profile table repeats {plugin_id!r} {count} times")
    for plugin_id in sorted(source_profiles - documented_profiles.keys()):
        errors.append(f"parent plugin profile table is missing {plugin_id!r}")
    for plugin_id in sorted(documented_profiles.keys() - source_profiles):
        errors.append(f"parent plugin profile table documents unknown playback plugin {plugin_id!r}")

    expected_profile_paths = {
        f"format-profiles/{plugin_id}.md" for plugin_id in source_profiles
    }
    for plugin_id, profile_path in profile_rows:
        if profile_path != f"format-profiles/{plugin_id}.md":
            errors.append(
                f"{plugin_id!r} profile must be named "
                f"format-profiles/{plugin_id}.md, not {profile_path!r}"
            )
        if not (DOC_PATH.parent / profile_path).is_file():
            errors.append(f"parent plugin profile file is missing: {profile_path}")

    linked_profile_paths = set(
        re.findall(r"\]\((format-profiles/[^)]+\.md)\)", document)
    )
    profile_files = {
        path.relative_to(DOC_PATH.parent).as_posix() for path in PROFILE_DIR.glob("*.md")
    }
    for profile_path in sorted(expected_profile_paths - linked_profile_paths):
        errors.append(f"parent plugin profile is not linked from the index: {profile_path}")
    for profile_path in sorted(linked_profile_paths - profile_files):
        errors.append(f"format index links to a missing profile: {profile_path}")
    for profile_path in sorted(profile_files - linked_profile_paths):
        errors.append(f"format profile is not linked from the index: {profile_path}")

    route_section = table_section(document, "## Route summary")
    documented_routes = [
        match.group(1)
        for line in route_section.splitlines()
        if (match := re.match(r"\|\s*`([^`]+)`\s*\|", line))
    ]
    source_routes = re.findall(r'pluginID:\s*"([^"]+)"', plugins)
    documented_counts = Counter(documented_routes)
    source_counts = Counter(source_routes)

    for route, count in sorted(documented_counts.items()):
        if count > 1:
            errors.append(f"route summary repeats {route!r} {count} times")
    for route in sorted(source_counts.keys() - documented_counts.keys()):
        errors.append(f"route summary is missing registered route {route!r}")
    for route in sorted(documented_counts.keys() - source_counts.keys()):
        errors.append(f"route summary documents unregistered route {route!r}")

    if errors:
        for error in errors:
            fail(error)
        return 1

    print(
        f"Format documentation is consistent: {len(documented_families)} playback "
        f"families, {len(source_profiles)} parent plugin profiles, and "
        f"{len(source_routes)} scanner routes checked."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
