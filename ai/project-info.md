# Project Info

## Identity

VGMBoy is the game-music audio core for the CocoaSpice/SPCBoy app family. It owns format routing,
decoder integration, timing, long play, tempo, fade, the macOS audio device, and (later) export and
the equalizer. Parent apps become database browsers plus transport/codec control interfaces over a
versioned `playback-core v1` protocol (not yet implemented).

MediaScanner is left as-is and remains the sole schema-23 catalog writer. This repository is
database-free: it decodes files and plays them.

## Layout

- `Sources/VGMBoyKit` — the audio core: `FormatRegistry`, `TimingPolicy`/`PlaybackPlan`,
  `GMEDecoder` (libgme wrapper), `PCMRingBuffer`, `AudioOutput` (AVAudioEngine + AVAudioSourceNode),
  `PlaybackSession` (transport home), `AudioInspector`.
- `Sources/vgmboy` — the nearly-command-line core: `inspect` (JSON) and `play`.
- `Sources/VGMBoyApp` — minimal SwiftUI test GUI (File Open + transport + Long Play/tempo/fade),
  borrowed from parent-app Options UI.
- `Sources/CGameMusicEmu` — system library over Homebrew `game-music-emu` (libgme) via pkg-config,
  same pattern as MediaScanner.

## Current Checkpoint

- Checkpoint 1 (in progress): libgme family end-to-end (NSF/NSFE/GBS/AY/HES/KSS/SAP/SPC) through
  the core's own AVAudioEngine transport. Long Play, tempo, fade, seek, and inspect work.
- Next checkpoints: remaining bridge cores (libvgm, vgmstream, lazyusf, Highly Complete, 2SF,
  Play! PSF, SID, OpenMPT), equalizer, export (WAV→AAC), `playback-core v1` protocol, then wire
  parent apps in.

## Files

- `Sources/VGMBoyKit/PlaybackSession.swift`
- `Sources/VGMBoyKit/GMEDecoder.swift`
- `Sources/VGMBoyKit/AudioOutput.swift`
- `Sources/vgmboy/VGMBoyCommand.swift`