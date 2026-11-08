import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings
from .vgmboy_prepare import prepare_selected_member


class VGMBoyPreparationTests(SimpleTestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.helper = self.root / "prepare"
        self.output = self.root / "selected.spc"
        self.settings_override = override_settings(SPCBOY_PREPARE_EXECUTABLE=self.helper)
        self.settings_override.enable()
        self.addCleanup(self.settings_override.disable)

    def helper_script(self, body):
        self.helper.write_text(f"#!{sys.executable}\n{body}\n")
        self.helper.chmod(0o755)

    def test_selected_bytes_and_request_owned_scratch(self):
        self.helper_script("import os,sys; assert os.path.isdir(os.environ['TMPDIR']); sys.stdout.buffer.write(b'original-source')")
        self.assertTrue(prepare_selected_member("archive.uac", "Game/track.spc", self.output))
        self.assertEqual(self.output.read_bytes(), b"original-source")
        self.assertFalse(list(self.root.glob("vgmboy-source-*")))

    def test_output_limit_is_enforced_while_reading(self):
        self.helper_script("import sys; sys.stdout.buffer.write(b'x' * 1000000)")
        with patch("accounts.vgmboy_prepare.MAX_PREPARED_MEMBER_BYTES", 32):
            with self.assertRaisesRegex(RuntimeError, "oversized"):
                prepare_selected_member("archive.uac", "track.spc", self.output)
        self.assertFalse(self.output.exists())
        self.assertFalse(list(self.root.glob("vgmboy-source-*")))

    def test_failed_and_empty_helpers_leave_no_source(self):
        for body in ("raise SystemExit(1)", "pass"):
            self.helper_script(body)
            with self.assertRaises(RuntimeError):
                prepare_selected_member("archive.uac", "track.spc", self.output)
            self.assertFalse(self.output.exists())

    def test_timeout_reclaims_source_and_scratch(self):
        self.helper_script("import time; time.sleep(10)")
        with patch("accounts.vgmboy_prepare.PREPARATION_TIMEOUT_SECONDS", .05):
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                prepare_selected_member("archive.uac", "track.spc", self.output)
        self.assertFalse(self.output.exists())
        self.assertFalse(list(self.root.glob("vgmboy-source-*")))

    def test_missing_runtime_fails_without_reusing_old_output(self):
        self.output.write_bytes(b"stale-source")
        with self.assertRaisesRegex(RuntimeError, "not installed"):
            prepare_selected_member("archive.uac", "track.spc", self.output)
        self.assertFalse(self.output.exists())
