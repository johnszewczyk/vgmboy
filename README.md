# VGMMan

VGMMan is the single Git repository for the game-music application family.
Every child directory keeps its own package boundary, build script, and release
boundary while sharing the family root's history.

## Projects

- `VGMBoy`: playback core, decoder routing, timing, audio output, and shared
  playback controls.
- `CocoaSpice`: native macOS playlist frontend.
- `SPCBoyWK`: native WebKit frontend. The older `SPCBoy` Electron frontend is
  retained separately as a deprecated historical project.
- `ScanSong`: ScanSong catalog writer and scanner application.
- `CatalogReader`: read-only catalog and catalog-browser packages.
- `FrontendCore`: shared frontend commands, local-file browser, archive
  materialization/cache, archive playback adapter, preferences, queue, and
  playback-request infrastructure.

The projects remain siblings so local Swift package dependencies such as
`../VGMBoy`, `../CatalogReader`, and `../FrontendCore` stay explicit and
inspectable. Shared behavior belongs in a maintained package boundary; an app
must not copy another app's UI implementation to obtain it.

LaunchPad remains one level above this directory because it launches the whole
development workspace rather than belonging to the playback product family.

Working coordination documents:

- [`WIP-PLAN.md`](/Users/john/Downloads/Code/VGMMan/WIP-PLAN.md) — shared-core extraction plan.
- [`PARITY-WIP-REPORT.md`](/Users/john/Downloads/Code/VGMMan/PARITY-WIP-REPORT.md) — CS/SPCBoyWK behavioral parity ledger and next validation slices.

Decoder and scanner documentation:

- [`VGMBoy plugin catalog`](/Users/john/Downloads/Code/VGMMan/VGMBoy/Docs/plugin-catalog.md) — decoder pins, provenance, scanner products, dependencies, and format boundaries.
- [`ScanSong format accommodations`](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-agent/format-accommodations.md) — scanner-side routing, archive, sidecar, and multitrack behavior.
