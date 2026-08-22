# Playback

VGMBoy's command line (`vgmboy-cli`) and test GUI (`VGMBoy`) play game-music files through one audio
core. The native test GUI is organized like CocoaSpice's Options window: Playback, Audio,
Diagnostics, and Core pages exercise the reusable control surface without becoming a playlist app.

The Core page is informational: VGMBoyKit is embedded into each frontend at build time. There is no
runtime core executable to browse for or launch.

## Play

`vgmboy-cli play <path>` plays a file through the core's own audio output and reports the system,
title, and track window. Supported options:

- `--track <n>` selects a subsong (0-based) when the file has several.
- `--long-play` plays a manual window instead of the tagged length.
- `--play-ms <n>` and `--fade-ms <n>` set the pre-fade window and fade duration in milliseconds.
- `--tempo <n>` changes playback speed for families that support it (libgme, libvgm).

## Supported Formats

- Chip music (libgme): `.ay`, `.gbs`, `.hes`, `.kss`, `.nsf`, `.nsfe`, `.sap`, `.spc`
- Sega/console logs (libvgm): `.vgm`, `.vgz`, `.gym`, `.s98`, `.dro`
- Tracker modules (libopenmpt): `.669`, `.dmf`, `.far`, `.it`, `.mod`, `.mptm`, `.mtm`, `.okt`,
  `.ptm`, `.s3m`, `.stm`, `.ult`, and `.xm`
- Standard audio: AVFoundation handles `.aac`, `.aif`, `.aiff`, `.caf`, `.flac`, `.m4a`, `.mp3`,
  `.wav`, and `.wave`; bundled FFmpeg handles `.mp2` and `.tak`
- Streamed game audio (vgmstream): `.adp`, `.adpcm`, `.adx`, `.at3`, `.bik`, `.bk2`, `.fsb`, `.vag`,
  `.xvag`, `.xmd`, `.aifc`, `.ogg`, and the other registered stream/bank extensions
- Nintendo 64 (lazyusf): `.usf`, `.miniusf` — needs its companion `.usflib` files beside it
- Game Boy Advance (Highly Complete): `.gsf`, `.minigsf` — miniGSF needs its companion `.gsflib` files beside it
- Nintendo DS (2sf2wav): `.2sf`, `.mini2sf` — mini2SF needs its companion library files beside it
- Nintendo DS legacy WAV payloads: `SWAV` payloads and recognized headerless `_NN.wav` signed PCM
- PlayStation / PlayStation 2 (Play!): `.psf`, `.minipsf`, `.psf2`, `.minipsf2`

Long play, fade, and seek work across all families. Tempo is available only where the decoder
supports it.

VGMBoyKit also exposes an in-process `PlaybackController` for native app hosts. It owns the
decoder, transport, timing, and ten-band EQ; a host keeps its own playlist, repeat/shuffle policy,
catalog, and macOS media-key integration.

## AAC Export

Hosts can ask VGMBoyKit for a finite offline AAC render. The core writes real ADTS `.aac` output
from a separately decoded session, so exporting does not pause, record, or otherwise disturb live
playback. The host supplies its display filename and folder; VGMBoy sanitizes the name and appends a
number rather than overwriting an existing file.

## Audio Output

- Playback, pause, stop, seeking, and track changes use one persistent macOS audio endpoint.
- Short output transitions fade cleanly at the device boundary; pausing or choosing the next track
  does not repeatedly reopen the system audio device.

## Files

- [VGMBoyCommand.swift](/Users/john/Downloads/Code/VGMBoy/Sources/vgmboy/VGMBoyCommand.swift)
- [PlayerViewModel.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyApp/PlayerViewModel.swift)
- [ContentView.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyApp/ContentView.swift)
