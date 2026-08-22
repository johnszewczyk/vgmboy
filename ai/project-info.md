# Project Info

## Product

VGMBoy is the shared macOS game-music playback core and decoder/plugin owner for the
CocoaSpice, SPCBoy, and ScanSong app family. It owns format routing, decoder integration,
timing, Long Play, tempo, fade, equalizer processing, and the audio device.

The repository is database-free. CocoaSpice links `VGMBoyKit` in-process, SPCBoy bundles the
same core as `vgmboy-electron-bridge`, and ScanSong receives VGMBoy-built inspection executables.

## Major Components

- `Sources/VGMBoyKit` — the audio core and decoder boundary.
- `Sources/VGMBoyElectronBridge` and `Sources/VGMBoyHighlyCompleteInspect` — narrow process
  boundaries used by SPCBoy and ScanSong.
- `Sources/vgmboy` and `Sources/VGMBoyApp` — command-line and native test clients.
- `vendor/`, `patches/`, and `scripts/` — shared upstream source, compatibility patches, and
  dependency/scanner-plugin build inputs.
- `vendor/PROVENANCE.md` — pinned submodule commits and honest snapshot identities for ordinary
  source imports.

## Task Routing

- Constitution and documentation method:
  [DocMan AGENTS.md](/Users/john/Downloads/Code/DocMan/AGENTS.md) and
  [DocMan docs-agent/documentation-method.md](/Users/john/Downloads/Code/DocMan/docs-agent/documentation-method.md)
- Engineering constraints: `ai/subsystem-agent/`
- Playback-control ownership and API: `ai/subsystem-agent/playback-control-v1.md`
- Device output, de-click envelope, and diagnostics: `ai/subsystem-agent/audio-output-transport.md`
- Decoder families and routing: `ai/subsystem-agent/decoder-routing.md`
- Shared dependency and scanner-plugin builds: `ai/subsystem-agent/build-integration.md`
- App-family ownership boundary: `Docs/app-family-boundary.md`
- Source provenance: `vendor/PROVENANCE.md`
- User-facing behavior: `ai/subsystem-human/`
- Adding a decoder core: `decoder-routing.md` and the owning `VGMBoyKit` decoder files.

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

## Human Docs

- `ai/subsystem-human/` is the human-facing behavior reference.
- `README.md` contains the current supported-decoder and build overview.
