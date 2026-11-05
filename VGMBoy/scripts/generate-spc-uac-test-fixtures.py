#!/usr/bin/env python3
"""Generate synthetic SPC/UAC loop fixtures for VGMBoy regression tests.

The destination must not exist. Metadata and loop points are test values, not
claims about the vendored track's authored metadata.
"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="new directory for loop.uac and none.uac")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    source = project / "VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc"
    packer = project / "UACMan/Wrapper/python/uacman.py"
    output = args.output.resolve()
    output.mkdir(exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="fixture-build-", dir=output) as temporary:
        work = Path(temporary)
        inputs = work / "source"
        inputs.mkdir()
        shutil.copyfile(source, inputs / "tone.spc")
        response = {
            "schemaVersion": 1,
            "memberMetadata": {"tone.spc": {"Play Length (ms)": 3000}},
            "sourceTimedMemberPaths": ["tone.spc"],
            "gameMetadata": {}, "sharedFieldConflicts": [], "diagnosticCount": 0, "failures": [],
        }
        helper = work / "spc-metadata-helper"
        helper.write_text("#!/usr/bin/env python3\nimport json\nprint(json.dumps(" + repr(response) + "))\n")
        helper.chmod(0o755)
        recipe = {
            "game": {"id": "test-spc", "title": "SPC Test", "console": "Super Nintendo"},
            "variants": [{"id": "original", "label": "Original", "kind": "release"}],
            "sources": [], "transformations": [], "playlists": [], "extensions": {}, "memberOverrides": {},
        }
        for name in ("loop", "none"):
            recipe["memberOverrides"] = ({"tone.spc": {"metadata": {"loop": {
                "startSamples": 11025, "endSamples": 22050, "sampleRateHz": 44100,
                "mode": "forward", "repeat": 2, "source": "test",
            }}}} if name == "loop" else {})
            recipe_path = work / "recipe.json"
            recipe_path.write_text(json.dumps(recipe))
            subprocess.run([sys.executable, "-B", str(packer), "pack", str(inputs), str(recipe_path),
                            str(output / f"{name}.uac"), "--harvest-spc-metadata", str(helper)], check=True)


if __name__ == "__main__":
    main()
