# VGMMan

VGMMan is the single Git repository for the game-music application family.
Every maintained app and shared package is backed up in this repository. Its
child directories retain their own package, build, and release boundaries, but
are not independently maintained Git repositories or remotes. Their earlier
histories are retained as archive refs. See
[`MONOREPO-MIGRATION.md`](MONOREPO-MIGRATION.md) for the repository and history
layout.

## Projects

- `VGMBoy`: playback core, decoder routing, timing, audio output, and shared
  playback controls.
- `CocoaSpice`: native macOS playlist frontend.
- `SPCBoyWK`: native WebKit frontend. The older `SPCBoy` Electron frontend is
  preserved at [`SPCBoy/`](SPCBoy/) as an archived, non-release source tree.
- `ScanSong`: ScanSong catalog writer and scanner application.
- `MetaMan`: decoder-independent metadata-reading library and thin JSON CLI;
  currently owns complete S98, VGM/VGZ, PSF-style, SPC, SID, APE, and
  CRI/Monster ADX readers.
- `UACMan`: native package browser/editor for UAC game and SPC-member
  metadata; it uses the shared UAC envelope code and does not alter member
  payload bytes when saving metadata.
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

- [`WIP-PLAN.md`](/Users/john/Downloads/Code/VGMMan/WIP-PLAN.md) — current shared-core ownership and remaining verification gates.
- [`PARITY-WIP-REPORT.md`](/Users/john/Downloads/Code/VGMMan/PARITY-WIP-REPORT.md) — current CS/SPCBoyWK parity evidence and open fixtures.
- [`verification.md`](/Users/john/Downloads/Code/VGMMan/verification.md) — family-wide checks and their evidence boundaries.
- [`SPCBoy/`](SPCBoy/) — retired Electron frontend source and tests; not part of routine family verification.

Decoder and scanner documentation:

- [`VGMBoy plugin catalog`](/Users/john/Downloads/Code/VGMMan/VGMBoy/Docs/plugin-catalog.md) — decoder pins, provenance, scanner products, dependencies, and format boundaries.
- [`ScanSong format accommodations`](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-agent/format-accommodations.md) — scanner-side routing, archive, sidecar, and multitrack behavior.
- [`MetaMan`](/Users/john/Downloads/Code/VGMMan/MetaMan/README.md) — supported metadata readers, methodology, library/CLI use, and migration boundary.
- [`UACMan`](/Users/john/Downloads/Code/VGMMan/UACMan/README.md) — metadata application, reversible wrapper, and future native-container boundary.
