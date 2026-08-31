# Project Info

## Product

`VGMMan` is the coordination workspace for the game-music application family.
It is not an umbrella Git repository or a second owner of product behavior.

## Major Components

- `VGMBoy`: decoder routing, timing, playback, audio output, and scanner helpers.
- `ScanSong`: discovery, inspection orchestration, schema-23 catalog writing,
  and the native scanner application.
- `CatalogReader`: read-only schema-23 access and catalog/browser projections.
- `FrontendCore`: UI-neutral archive, preferences, favorites, queue, request,
  and transport policy.
- `CocoaSpice`: native AppKit/SwiftUI playlist frontend.
- `SPCBoyWK`: native WebKit frontend and typed host bridge.

## Task Routing

- Decoder, format admission, timing, playback, audio, or scanner-helper work:
  `VGMBoy/AGENTS.md`
- Scanning, inspection orchestration, catalog publication, or scanner UI:
  `ScanSong/AGENTS.md`
- Read-only catalog queries and shared browser projections:
  `CatalogReader/AGENTS.md`
- Shared frontend policy and archive/cache infrastructure:
  `FrontendCore/AGENTS.md`
- Native CocoaSpice presentation and integration:
  `CocoaSpice/AGENTS.md`
- SPCBoyWK WebKit presentation, native host, and bridge:
  `SPCBoyWK/AGENTS.md`
- Active cross-frontend parity evidence: `PARITY-WIP-REPORT.md`
- Active shared-core coordination: `WIP-PLAN.md`
- Exact six-repository source-state and check evidence: `verification.md`

## Local Rules

- Preserve the six independent Git histories and worktrees.
- Shared behavior belongs in the narrow owning package, not copied between
  frontends.
- Catalog writes belong only to ScanSong; player frontends are read-only.
- Decoder, timing, and audio ownership belong to VGMBoy.
- Frontend-specific AppKit, SwiftUI, WebKit, focus, and selection presentation
  stay in the owning frontend.
- Verify cross-repository work against exact child revisions and dirty states.
- Compilation alone does not prove packaged, visible, or audible behavior.

## Human Docs

- `README.md` is the compact family overview.
- Working plans and parity reports are coordination evidence, not default child-
  repository intake.
