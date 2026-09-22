# Project Info

## Product

ScanSong is the VGMMan family's native catalog-management app and command-line
scanner. It writes schema-24 catalogs read by CocoaSpice, SPCBoyWK, and ViewBoy.

## Major Components

- `ScanSongKit` discovers sources, inspects admitted formats, stages checkpoints,
  and publishes catalogs.
- `ScanSongApp` presents catalog selection, scan paths, operations, and results.
- `scansong` exposes a versioned JSONL command-line boundary.
- MetaManCore supplies decoder-independent native metadata; VGMBoy supplies
  format admission and the scanner helpers that still need decoder-backed
  inspection.

## Task Routing

- Scanner persistence, concurrency, and publication:
  [scanner-contract.md](subsystem-agent/scanner-contract.md).
- Native operation state, progress delivery, and UI responsiveness:
  [operation-presentation.md](subsystem-agent/operation-presentation.md).
- Format admission, archives, and metadata adapters:
  [format-accommodations.md](subsystem-agent/format-accommodations.md).
- Builds and scanner-helper packaging:
  [build-integration.md](subsystem-agent/build-integration.md).
- Command-line behavior: [cli.md](subsystem-human/cli.md).
- Native catalog management: [catalog-management.md](subsystem-human/catalog-management.md).

## Local Rules

- ScanSong alone writes catalogs. Player apps open schema 24 read-only; the
  ScanSong writer can upgrade schema 23 by adding `tracks.track_number`.
- Keep scanner discovery, source admission, archive handling, and catalog
  projection in ScanSongKit. Keep native format interpretation in MetaManCore
  and playback/decoder products in VGMBoy.
- A scan checkpoint covers a complete loose source or physical archive.
  Failed refreshes retain last-known-good playable rows for retry.
- The UI samples worker progress without pacing the worker. Exact progress and
  cancellation boundaries are in the routed operation note.

## Human Docs

- [Catalog management](subsystem-human/catalog-management.md) describes the
  native app.
- [CLI](subsystem-human/cli.md) describes command-line behavior.
