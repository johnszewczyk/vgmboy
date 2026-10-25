"""Exercise the packaged process boundary using disposable public-format fixtures."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="vgmboy-prepare-check-") as folder:
    root = Path(folder)
    archive = root / "source.zip"
    expected = b"native-source-bytes\x00" * 256
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as source:
        source.writestr("Game/Track.spc", expected)
    result = subprocess.run([binary, str(archive), "Game/Track.spc"], capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    assert result.stdout == expected, "selected member bytes changed"
    for member in ("../escape.spc", "/escape.spc", "Game/missing.spc"):
        result = subprocess.run([binary, str(archive), member], capture_output=True)
        assert result.returncode != 0 and not result.stdout, "invalid member was accepted"
print("VGMBoy preparation: selected bytes and rejection boundaries passed")
