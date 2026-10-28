# Project Info

## Product

VGMBoy owns playback format admission, decoder integration, timing, output gain,
transport, and the macOS audio device for the VGMMan family. It is a shared
in-process kit, not a daemon or catalog service.

CocoaSpice, SB2, ViewBoy, and LineBoy are maintained player clients. Each
bundles the shared playback core behind its own host adapter. SPCBoyWK's source
is archived and no longer a maintained client. ScanSong consumes
VGMBoy-built inspection helpers, but does not link the playback kit or invoke
a player app.

## Major Components

- `Sources/VGMBoyKit/` — playback core, decoder boundaries, and timing.
- `Sources/VGMBoyArchiveCore/` — bounded archive inspection, safe member
  selection, UAC decompression, and temporary playback/export source
  preparation.
- `Sources/VGMBoyEndpointCore/` — versioned endpoint and capability map.
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
  `subsystem-agent/playback-control-v1.md`.
- Archive/member preparation and temporary-source lifetime:
  `subsystem-agent/archive-preparation.md`.
- Audio output, transport, de-click, and diagnostics:
  `subsystem-agent/audio-output-transport.md`.
- Format admission, decoder routes, and adding a playback core:
  `subsystem-agent/decoder-routing.md`.
- Dependency and scanner-plugin builds:
  `subsystem-agent/build-integration.md`.
- Family ownership: `subsystem-agent/app-family-boundary.md`.
- Imported source provenance: `vendor/PROVENANCE.md`.
- Standalone WebKit application and its local bridge: `subsystem-agent/standalone-webkit.md`.
- User-visible playback behavior: `subsystem-human/`.
- Decoder/dependency matrix and exact pins:
  [plugin-catalog.md](../../VGMManDocs/Docs/md/VGMBoy/plugin-catalog.md) and
  `../Docs/plugin-versions.json`.
- Decoder update checks and fixture evidence:
  [plugin-updates.md](verification/plugin-updates.md).

## Local Rules

- VGMBoyArchiveCore and VGMBoyKit own playback/export source preparation,
  decoded transport, and audio output. Frontends own queue policy, durable
  cache preferences for browsing/artwork, persistence keys, and user
  interfaces.
- ScanSong is the only schema-25 catalog writer. It consumes MetaMan results
  and any required VGMBoy-built inspection executables.
- Never fork an upstream decoder per app. Keep host bridges and build staging
  owned by this package.
- Unsupported input is an explicit error; do not invent a track.
- Scanner inspection targets must stay separate from `VGMBoyKit` and must not
  launch a player frontend.

## Human Docs

`README.md` lists instantiated decoder plugins and build prerequisites.
The published [plugin catalog](../../VGMManDocs/Docs/md/VGMBoy/plugin-catalog.md)
explains decoder, scanner, dependency, provenance, and format boundaries; exact
pins remain in `../Docs/plugin-versions.json`.
