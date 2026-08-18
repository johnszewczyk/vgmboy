# Project Info

## Identity

VGMBoy is the game-music audio core for the CocoaSpice/SPCBoy app family. It owns format routing,
decoder integration, timing, long play, tempo, fade, and the macOS audio device; export (WAV→AAC)
and the equalizer are planned. Parent apps become database browsers plus transport/codec control
interfaces over a versioned `playback-core v1` protocol (not yet implemented).

MediaScanner is left as-is and remains the sole schema-23 catalog writer. This repository is
database-free: it decodes files and plays them.

## Major Components

- `Sources/VGMBoyKit` — the audio core: `FormatRegistry` (family/extensions/capabilities),
  `DecoderFactory` + `AudioDecoder` protocol, `TimingPolicy`/`PlaybackPlan`, `PCMRingBuffer`,
  `AudioOutput` (AVAudioEngine + AVAudioSourceNode), `PlaybackSession` (transport home),
  `AudioInspector`.
- `Sources/vgmboy` — the command-line core: `inspect` (JSON) and `play`.
- `Sources/VGMBoyApp` — minimal SwiftUI test GUI (File Open + transport + Long Play/tempo/fade),
  borrowed from parent-app Options UI.
- Bridge targets over vendored upstream cores (built by CocoaSpice, not forked here):
  `CGameMusicEmu` (libgme), `CLibVGM`, `CVGmstream`, `CLazyUSF`, `CPlayPSF`.

## Decoder Families

| Family | Extensions | Long play | Tempo | Natural ending |
| --- | --- | --- | --- | --- |
| `libgme` | ay gbs hes kss nsf nsfe sap spc | yes | yes | yes |
| `libvgm` | vgm vgz gym s98 dro | yes | yes | yes |
| `vgmstream` | aa3 adx ads aifc at3 aus bnk dvi fsb genh hd hbd iecs int mib msf mtaf ogg rws ss2 stream svag txtp vag xa | yes | no | yes |
| `lazyusf` | usf miniusf | yes | no | no |
| `playpsf` | psf minipsf psf2 minipsf2 | yes | no | yes |

Decoder cores that only stream real PCM (vgmstream, lazyusf, playpsf) cannot fade internally; the
session owns the fade DSP for them (`appliesFadeInternally == false`).

## Task Routing

- Constitution and documentation method:
  [DocMan AGENTS.md](/Users/john/Downloads/Code/DocMan/AGENTS.md) and
  [DocMan docs-agent/documentation-method.md](/Users/john/Downloads/Code/DocMan/docs-agent/documentation-method.md)
- Engineering constraints: `ai/subsystem-agent/`
- User-facing behavior: `ai/subsystem-human/`
- Add a decoder core: `FormatRegistry.family(for:)` + `DecoderFactory.make` + a new
  `Sources/VGMBoyKit/<X>Decoder.swift` conforming to `AudioDecoder`.

## Local Rules

- VGMBoy owns the macOS audio device and transport; front-ends are thin clients.
- Piece out the best bridge cores from SPCBoy and CocoaSpice; never fork the shared upstream
  decoder libraries per app. Bridge glue is copied into VGMBoy; the static libs are built by
  CocoaSpice and linked from its `.build`.
- Use boring, simple vanilla features. Fail hard and loud: unsupported input is an explicit error,
  never an invented track.
- Keep the kit's public API surface small and deliberate; the CLI and the SwiftUI app are two thin
  skins over one core.
- Leave parent apps (SPCBoy, CocoaSpice, MediaScanner) untouched until VGMBoy reaches a ready
  state; wire them in later.
