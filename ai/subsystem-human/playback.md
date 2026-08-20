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
- Standard audio (AVFoundation): `.aac`, `.aif`, `.aiff`, `.caf`, `.flac`, `.m4a`, `.mp3`, `.wav`,
  and `.wave`
- Streamed game audio (vgmstream): `.adx`, `.xa`, `.at3`, `.fsb`, `.vag`, `.aifc`, `.ogg`, and the
  other registered stream/bank extensions
- Nintendo 64 (lazyusf): `.usf`, `.miniusf` — needs its companion `.usflib` files beside it
- Game Boy Advance (Highly Complete): `.gsf`, `.minigsf` — miniGSF needs its companion `.gsflib` files beside it
- Nintendo DS (2sf2wav): `.2sf`, `.mini2sf` — mini2SF needs its companion library files beside it
- PlayStation / PlayStation 2 (Play!): `.psf`, `.minipsf`, `.psf2`, `.minipsf2`

Long play, fade, and seek work across all families. Tempo is available only where the decoder
supports it.

VGMBoyKit also exposes an in-process `PlaybackController` for native app hosts. It owns the
decoder, transport, timing, and ten-band EQ; a host keeps its own playlist, repeat/shuffle policy,
catalog, and macOS media-key integration.

## Files

- [VGMBoyCommand.swift](/Users/john/Downloads/Code/VGMBoy/Sources/vgmboy/VGMBoyCommand.swift)
- [PlayerViewModel.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyApp/PlayerViewModel.swift)
- [ContentView.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyApp/ContentView.swift)
