#!/usr/bin/env python3
"""Generate disposable UAC loop fixtures; requires the UAC packer and zstd."""
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import wave

out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
source = out / 'input'
source.mkdir(exist_ok=True)
with wave.open(str(source / 'tone.wav'), 'wb') as audio:
    audio.setnchannels(2)
    audio.setsampwidth(2)
    audio.setframerate(44_100)
    frames = bytearray()
    for index in range(44_100):
        sample = int(12_000 * math.sin(2 * math.pi * 440 * index / 44_100))
        frames.extend(struct.pack('<hh', sample, sample))
    audio.writeframes(frames)
root = Path(__file__).resolve().parents[2]
packer = root / 'UACMan/Wrapper/python/uacman.py'
loop = {'mode': 'forward', 'startSamples': 2205, 'endSamples': 4410,
        'sampleRateHz': 44100, 'repeat': 2, 'source': 'generated-test'}
for name, metadata in [('loop', {'loop': loop}), ('none', {}),
                       ('endloop', {'loop': {**loop, 'startSamples': 22050, 'endSamples': 44100, 'repeat': 1}}),
                       ('invalid', {'loop': {**loop, 'sampleRateHz': 0}})]:
    recipe = {'packageID': 'loop-fixture', 'game': {'id': 'loop-fixture', 'title': 'Loop fixture', 'console': 'WAV'},
              'variants': [{'id': 'original', 'label': 'Original', 'kind': 'release'}], 'sources': [],
              'memberOverrides': {'tone.wav': {'metadata': metadata}}}
    recipe_path = out / f'{name}.json'
    recipe_path.write_text(json.dumps(recipe), encoding='utf-8')
    subprocess.run([sys.executable, '-B', str(packer), 'pack', str(source), str(recipe_path), str(out / f'{name}.uac')], check=True)
