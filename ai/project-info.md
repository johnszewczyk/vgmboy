# Project Info

## Identity

VGMBoy is the game-music audio core and shared decoder/plugin owner for the CocoaSpice/SPCBoy/ScanSong
app family. It owns format routing,
decoder integration, timing, Long Play, tempo, fade, ten-band equalizer processing, and the macOS
audio device. CocoaSpice links VGMBoyKit in-process and controls it through PlaybackControl v1;
SPCBoy bundles the same core as its private `vgmboy-electron-bridge` helper.

MediaScanner remains the sole schema-23 catalog writer. ScanSong obtains its vgmstream and Highly
Complete inspection executables through VGMBoy's scanner-plugin build boundary. This repository is
database-free: it decodes files, supplies inspection plugins, and plays them.

## Major Components

- `Sources/VGMBoyKit` — the audio core: `FormatRegistry` (family/extensions/capabilities),
  `DecoderFactory` + `AudioDecoder` protocol, `TimingPolicy`/`PlaybackPlan`,
  `AudioOutput` (direct DefaultOutput AudioUnit host), and `PlaybackSession` (transport home).
- `Sources/vgmboy` — the command-line playback harness: `play`.
- `scripts/build-dependencies.sh` — stages compiled shared dependency archives under VGMBoy's
  `.build/dependencies` directory.
- `scripts/build-scanner-plugins.sh` — builds the scanner-facing vgmstream CLI and prepares the
  shared Highly Complete build prerequisite used by ScanSong.
- `PlaybackControl v1` — versioned in-process control and event API used by CocoaSpice, the CLI,
  and the test GUI over the same playback session shape.
- `Sources/VGMBoyApp` — native test GUI, organized as CocoaSpice-style Playback, Audio,
  Diagnostics, and Core pages. It exercises transport, Long Play, tempo, the shared ten-band EQ,
  and output diagnostics without owning a catalog or playlist.
- Bridge targets over shared upstream cores (staged and linked by VGMBoy, not forked here):
  `VGMBoyCGameMusicEmu` (libgme), `VGMBoyCLibVGM`, `VGMBoyCHighlyComplete` (mGBA + PSFLib),
  `VGMBoyC2SF`, `VGMBoyCVGmstream`, `VGMBoyCLazyUSF`, `VGMBoyCPlayPSF`, and
  `VGMBoyCOpenMPT` (libopenmpt), `VGMBoyCFFmpeg` (MP2/TAK), and
  `VGMBoyCAudioUnit` (the owned direct output transport).

## Decoder Families

| Family | Extensions | Long play | Tempo | Natural ending |
| --- | --- | --- | --- | --- |
| `libgme` | ay gbs hes kss nsf nsfe sap spc | yes | yes | yes |
| `sidplayfp` | sid | yes | no | no |
| `openmpt` | 669 dmf far it mod mptm mtm okt ptm s3m stm ult xm | yes | no | yes |
| `libvgm` | vgm vgz gym s98 dro | yes | yes | yes |
| `standardaudio` | aac aif aiff caf flac m4a mp3 wav wave | no | no | yes |
| `highlycomplete` | gsf minigsf | yes | no | yes |
| `twosf` | 2sf mini2sf | yes | no | yes |
| `vgmstream` | aa3 adp adpcm adx ads aifc at3 aus bik bika bk2 bnk dvi fsb genh hd hbd iecs int mib msf mtaf ogg ps3 rws s14 ss2 stream strm svag swav txtp vag xa xmd xvag | yes | no | yes |
| `lazyusf` | usf miniusf | yes | no | no |
| `playpsf` | psf minipsf psf2 minipsf2 | yes | no | yes |

Decoder cores that only stream real PCM (Highly Complete, vgmstream, lazyusf, playpsf) cannot fade internally; the
session owns the fade DSP for them (`appliesFadeInternally == false`).

## Task Routing

- Constitution and documentation method:
  [DocMan AGENTS.md](/Users/john/Downloads/Code/DocMan/AGENTS.md) and
  [DocMan docs-agent/documentation-method.md](/Users/john/Downloads/Code/DocMan/docs-agent/documentation-method.md)
- Engineering constraints: `ai/subsystem-agent/`
- Playback-control ownership and API: `ai/subsystem-agent/playback-control-v1.md`
- Device output, de-click envelope, and diagnostics: `ai/subsystem-agent/audio-output-transport.md`
- User-facing behavior: `ai/subsystem-human/`
- Add a decoder core: `FormatRegistry.family(for:)` + `DecoderFactory.make` + a new
  `Sources/VGMBoyKit/<X>Decoder.swift` conforming to `AudioDecoder`.

## Local Rules

- VGMBoy owns the macOS audio device, decoded transport, timing, and equalizer; front-ends own queue policy and their user interfaces.
- Piece out the best bridge cores from SPCBoy and CocoaSpice; never fork the shared upstream
  decoder libraries per app. Bridge glue and compiled dependency staging belong to VGMBoy. A frontend removes its old bridge objects before
  linking VGMBoyKit; duplicate bridge implementations are a deliberate linker error.
- Use boring, simple vanilla features. Fail hard and loud: unsupported input is an explicit error,
  never an invented track.
- Keep the kit's public API surface small and deliberate; the CLI and the SwiftUI app are two thin
  skins over one core.
- MediaScanner remains a separate catalog-writer product. ScanSong consumes
  VGMBoy-built inspection executables, but never links VGMBoyKit or invokes a
  player frontend.
- ScanSong may consume VGMBoy-built inspection executables, but it does not link VGMBoyKit or
  invoke a player frontend. Keep inspection packaging behind `build-scanner-plugins.sh`.
