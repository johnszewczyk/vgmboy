# Playback

VGMBoy's command line (`vgmboy-cli`) and test GUI (`VGMBoy`) play game-music files through one audio
core.

## Inspect

`vgmboy-cli inspect <path>` prints the detected format family, system name, track count, and
per-track timing (length, intro, loop, fade) as JSON.

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
- Streamed game audio (vgmstream): `.adx`, `.xa`, `.at3`, `.fsb`, `.vag`, `.aifc`, `.ogg`, and the
  other registered stream/bank extensions
- Nintendo 64 (lazyusf): `.usf`, `.miniusf` — needs its companion `.usflib` files beside it
- PlayStation / PlayStation 2 (Play!): `.psf`, `.minipsf`, `.psf2`, `.minipsf2`

Long play, fade, and seek work across all families. Tempo is available only where the decoder
supports it.

## Files

- [VGMBoyCommand.swift](/Users/john/Downloads/Code/VGMBoy/Sources/vgmboy/VGMBoyCommand.swift)
- [PlayerViewModel.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyApp/PlayerViewModel.swift)
- [ContentView.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyApp/ContentView.swift)
