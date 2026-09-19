# Project Info

## Product

VGMBoy owns playback format admission, decoder integration, timing, output gain,
transport, and the macOS audio device for the VGMMan family. It is a shared
in-process kit, not a daemon or catalog service.

CocoaSpice, SPCBoyWK, and ViewBoy are maintained player clients. Each bundles
the shared playback core behind its own host adapter. The Electron SPCBoy tree
and its compatibility bridge are recovery-only; neither is used by maintained
frontends. ScanSong consumes VGMBoy-built inspection helpers, but does not link
the playback kit or invoke a player app.

## Major Components

- `Sources/VGMBoyKit/` — playback core, decoder boundaries, and timing.
- `Sources/VGMBoyEndpointCore/` — versioned endpoint and capability map.
- `Sources/VGMBoyElectronBridge/` — recovery-only Electron compatibility path.
- `Sources/VGMBoyMDXInspect/` and `Sources/VGMBoyAmigaInspect/` — focused
  scanner inspection boundaries.
- `Sources/vgmboy/` and `Sources/VGMBoyApp/` — CLI and native test clients.
- `vendor/`, `patches/`, and `scripts/` — imported decoder sources,
  compatibility patches, and dependency/scanner-plugin build inputs.

MetaMan owns complete decoder-independent metadata readers. VGMBoy retains
playback ownership for those formats and inspection helpers only where
scanner-specific decoding remains necessary.

## Task Routing

- Playback control protocol and host contract:
  `ai/subsystem-agent/playback-control-v1.md`.
- Audio output, transport, de-click, and diagnostics:
  `ai/subsystem-agent/audio-output-transport.md`.
- Format admission, decoder routes, and adding a playback core:
  `ai/subsystem-agent/decoder-routing.md`.
- Dependency and scanner-plugin builds:
  `ai/subsystem-agent/build-integration.md`.
- Family ownership: `Docs/app-family-boundary.md`.
- Imported source provenance: `vendor/PROVENANCE.md`.
- User-visible playback behavior: `ai/subsystem-human/`.
- Decoder/dependency matrix and exact pins:
  `Docs/plugin-catalog.md` and `Docs/plugin-versions.json`.

## Local Rules

- VGMBoy owns decoded transport and audio output; frontends own queue policy,
  persistence keys, and user interfaces.
- ScanSong is the only schema-23 catalog writer. It consumes MetaMan results
  and any required VGMBoy-built inspection executables.
- Never fork an upstream decoder per app. Keep host bridges and build staging
  owned by this package.
- Unsupported input is an explicit error; do not invent a track.
- Scanner inspection targets must stay separate from `VGMBoyKit` and must not
  launch a player frontend.

## Human Docs

`README.md` lists instantiated decoder plugins and build prerequisites.
`Docs/plugin-catalog.md` explains decoder, scanner, dependency, provenance, and
format boundaries; exact pins remain in `Docs/plugin-versions.json`.
