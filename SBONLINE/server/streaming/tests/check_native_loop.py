"""Run against a built spcboy-stream; no collection files are required.

The intro and loop deliberately have different pitches. Reopening the whole
file at a loop boundary reintroduces the intro and fails the pitch checks.
"""
import array
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from accounts.aac_transport import AACADTSPrimingFrameStripper


def fixture():
    def tone(period):
        return bytes((0x50, 0x80 | (period & 15), 0x50, period >> 4, 0x50, 0x90))

    wait = bytes((0x61, 0x3A, 0x11))  # 4410 samples = 100 ms
    intro = tone(40) + wait
    loop = tone(200) + wait + b"\x66"
    header = bytearray(64)
    header[:4] = b"Vgm "
    for offset, value in ((4, 64 + len(intro + loop) - 4), (8, 0x150),
                          (12, 3579545), (0x18, 8820),
                          (0x1C, 64 + len(intro) - 0x1C), (0x20, 4410)):
        struct.pack_into("<I", header, offset, value)
    return header + intro + loop


def main():
    decoder = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix="spcboy-native-loop-") as directory:
        source = Path(directory) / "intro-and-loop.vgm"
        source.write_bytes(fixture())
        for offset in (0, 250):
            pcm = subprocess.run([decoder, str(source), "0", "1000", "0", str(offset), "1"],
                                 capture_output=True, check=True, timeout=20).stdout
            assert len(pcm) == (1000 - offset) * 44100 * 4 // 1000
            samples = array.array("h", pcm)
            if sys.byteorder != "little":
                samples.byteswap()
            # Check every later 50-ms window, including repeated loop seams.
            for start in range(150 if offset == 0 else 0, 1000 - offset - 50, 50):
                left = samples[start * 44100 // 1000 * 2:(start + 50) * 44100 // 1000 * 2:2]
                crossings = sum(a <= 0 < b for a, b in zip(left, left[1:]))
                frequency = crossings / .05
                assert 400 < frequency < 800, (offset, start, frequency, "intro replayed")
        # The fade is absolute across loop seams and resumed streams.
        def fading(offset, long_play="1"):
            raw = subprocess.run([decoder, str(source), "0", "750", "250", str(offset), long_play],
                                 capture_output=True, check=True, timeout=20).stdout
            values = array.array("h", raw)
            if sys.byteorder != "little": values.byteswap()
            return values
        faded = fading(0)
        resumed = fading(900)
        def rms(values, start, end):
            window = values[start * 44100 // 1000 * 2:end * 44100 // 1000 * 2]
            return (sum(x*x for x in window) / len(window)) ** .5
        before, middle, ending = (rms(faded, a, b) for a, b in ((650,700),(850,900),(975,1000)))
        assert .3 < middle / before < .7, (before, middle)
        assert ending / before < .1, (before, ending)
        assert abs(rms(resumed, 75,100) / ending - 1) < .05, "resume reset the fade"
        normal_vgm = fading(0, "0")
        assert rms(normal_vgm,975,1000) / rms(normal_vgm,650,700) < .1, "normal VGM missed fade"
        # Minimal NES square wave: exercise libgme's normal (non-Long Play)
        # path, where its built-in fixed-length fade must not override ours.
        nsf = bytearray(128)
        nsf[:8] = b"NESM\x1a\x01\x01\x01"
        init = bytes.fromhex("a9018d1540a9bf8d0040a9c88d0240a9008d034060")
        struct.pack_into("<HHH", nsf, 8, 0x8000, 0x8000, 0x8000 + len(init))
        struct.pack_into("<H", nsf, 110, 16639)
        source = Path(directory) / "steady-tone.nsf"
        source.write_bytes(nsf + init + b"\x60")
        def normal_fade(milliseconds):
            raw = subprocess.run([decoder, str(source), "0", "1000", str(milliseconds), "0", "0"],
                                 capture_output=True, check=True, timeout=20).stdout
            samples = array.array("h", raw)
            if sys.byteorder != "little": samples.byteswap()
            assert len(raw) == (1000 + milliseconds) * 44100 * 4 // 1000
            return samples
        normal = normal_fade(1000)
        baseline = rms(normal, 800,900)
        assert baseline > 100
        assert .35 < rms(normal, 1450,1550) / baseline < .65
        assert rms(normal, 1950,2000) / baseline < .05
        dry = normal_fade(0)
        assert rms(dry,950,1000) / rms(dry,800,900) > .8, "zero fade altered the ending"
        ffmpeg = shutil.which("ffmpeg")
        assert ffmpeg, "FFmpeg is required for the transport check"
        # Exercise the same AAC-only ADTS output used by the HTTP endpoint.
        media = subprocess.run([ffmpeg, "-v", "error", "-f", "s16le", "-ar", "44100",
                                "-ac", "2", "-i", "pipe:0", "-c:a", "aac", "-b:a", "128k",
                                "-f", "adts", "pipe:1"], input=pcm,
                               capture_output=True, check=True, timeout=20).stdout
        assert media[:1] == b"\xff" and media[1] & 0xF0 == 0xF0, "FFmpeg did not emit ADTS AAC"
        first_frame_length = ((media[3] & 0x03) << 11) | (media[4] << 3) | (media[5] >> 5)
        assert 7 <= first_frame_length < len(media), first_frame_length
        stripped = AACADTSPrimingFrameStripper().push(media)
        assert stripped == media[first_frame_length:], "AAC priming frame was not removed exactly once"
        print("Native loops retain loop pitch across seams; VGM/NSF fades, zero fade, AAC ADTS output, and priming-frame removal passed.")


if __name__ == "__main__":
    main()
