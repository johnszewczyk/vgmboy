import unittest
from .spcboy_timing import long_play_timing


class LongPlayTimingTests(unittest.TestCase):
    def test_finite_duration_includes_fade(self):
        self.assertEqual(long_play_timing(185, 5000, 0, 3600000), (180000, 5000))

    def test_short_duration_clamps_fade_without_rejecting_playback(self):
        self.assertEqual(long_play_timing(1, 5000, 0, 3600000), (1, 999))

    def test_unlimited_continues_from_offset_without_musical_fade(self):
        self.assertEqual(long_play_timing(0, 5000, 123000, 25000), (173000, 0))

    def test_invalid_or_excessive_duration_is_rejected(self):
        for value in (-1, 86401, 1.5, True, '60'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                long_play_timing(value, 5000, 0, 3600000)

    def test_long_finite_duration_preserves_musical_timing(self):
        # The HTTP stream loop independently enforces the page deadline.
        self.assertEqual(long_play_timing(86400, 5000, 0, 5000), (86395000, 5000))

    def test_unlimited_rejects_position_beyond_decoder_window(self):
        with self.assertRaises(ValueError):
            long_play_timing(0, 5000, 86400000, 25000)
