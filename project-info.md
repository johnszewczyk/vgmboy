# Project Info

## Product and repository

`VGMMan` is the game-music application family and its single canonical Git
repository. The GitHub repository is `johnszewczyk/vgmboy`; the family root
contains every maintained application and shared package. Component folders
remain independent Swift package, UI, and release boundaries, but are not
independent Git repositories.

## Major Components

- `VGMBoy`: decoder routing, timing, playback, audio output, and scanner helpers.
- `ScanSong`: discovery, inspection orchestration, schema-23 catalog writing,
  and the native scanner application.
- `MetaMan`: decoder-independent format metadata readers, shared result model,
  and a thin JSON command-line frontend.
- `UACMan`: native metadata browser/editor, current reversible wrapper and
  pack/inspect/unpack tooling, plus a reserved future native-container
  component. Playback and scanner consumers depend on its wrapper library.
- `CatalogReader`: read-only schema-23 access and catalog/browser projections.
- `FrontendCore`: UI-neutral archive, preferences, favorites, queue, request,
  and transport policy.
- `CocoaSpice`: native AppKit/SwiftUI playlist frontend.
- `SPCBoyWK`: native WebKit frontend and typed host bridge.

## Archived Components

- `SPCBoy`: retired Electron frontend source. Kept for recovery and historical
  reference; it is not an active release target and is excluded from routine
  family verification. `SPCBoyWK` is the maintained native frontend.

## Task Routing

- Decoder, format admission, timing, playback, audio, or scanner-helper work:
  `VGMBoy/AGENTS.md`
- Scanning, inspection orchestration, catalog publication, or scanner UI:
  `ScanSong/AGENTS.md`
- Metadata format readers, normalized/raw metadata contracts, or parser tests:
  `MetaMan/AGENTS.md`, `MetaMan/README.md`, and
  `ScanSong/ai/subsystem-agent/format-accommodations.md`
- UAC package browsing/editing:
  `UACMan/AGENTS.md`, `UACMan/README.md`, and
  `UACMan/ai/subsystem-agent/uac-wrapper-format.md`; player/scanner integration:
  `UACMan/ai/subsystem-agent/player-integration.md`
- Read-only catalog queries and shared browser projections:
  `CatalogReader/AGENTS.md`
- Shared frontend policy and archive/cache infrastructure:
  `FrontendCore/AGENTS.md`
- Native CocoaSpice presentation and integration:
  `CocoaSpice/AGENTS.md`
- SPCBoyWK WebKit presentation, native host, and bridge:
  `SPCBoyWK/AGENTS.md`
- Archived Electron-source review, when explicitly needed: `SPCBoy/AGENTS.md`
- Active cross-frontend parity evidence: `PARITY-WIP-REPORT.md`
- Active shared-core coordination: `WIP-PLAN.md`
- Single-repository source-state and family check evidence: `verification.md`
- Repository layout, archived component refs, and source exclusions:
  `MONOREPO-MIGRATION.md`

## Repository and local rules

- Run Git operations from this directory. Commit family changes here; do not
  create or update a nested component repository.
- Earlier component histories are retained under `archive/<component>/...`
  refs in this same Git repository. They are archival only; current source of
  truth is the family tree on `main`.
- Retired SPCBoy Electron branches and its recovered source snapshot are also
  preserved under `SPCBoy/` and `archive/SPCBoy/...` refs.
- `VGMBoy/vendor/` contains checked-in upstream source snapshots with versions
  and provenance documented in `VGMBoy/Docs/` and `VGMBoy/vendor/PROVENANCE.md`.
  There are no Git submodules to initialize.
- Build output, packaged apps, Node modules, local archives, and fixture payloads
  are ignored and are not GitHub backups. Keep reproducible build instructions
  and upstream pins in source documentation instead.
- Shared behavior belongs in the narrow owning package, not copied between
  frontends.
- Catalog writes belong only to ScanSong; player frontends are read-only.
- Decoder, timing, and audio ownership belong to VGMBoy.
- Frontend-specific AppKit, SwiftUI, WebKit, focus, and selection presentation
  stay in the owning frontend.
- Verify the combined package set at the family root and inspect the root Git
  status before committing.
- Compilation alone does not prove packaged, visible, or audible behavior.

## Human Docs

- `README.md` is the compact family overview.
- Working plans and parity reports are coordination evidence, not default child-
  repository intake.
