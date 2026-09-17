# VGMMan

VGMMan is the canonical Git repository for the game-music application family.
Each child keeps its own package, app, tests, and release boundary; family
source and history live in this repository. See
[`MONOREPO-MIGRATION.md`](MONOREPO-MIGRATION.md) for the repository and
recovery layout.

## Projects

| Project | Responsibility |
| --- | --- |
| [VGMBoy](VGMBoy/README.md) | Decoder routing, timing, playback, audio output, and scanner helpers. |
| [ScanSong](ScanSong/README.md) | Source discovery, format inspection, and schema-23 catalog writing. |
| [MetaMan](MetaMan/README.md) | Decoder-independent metadata reading and typed source facts. |
| [UACMan](UACMan/README.md) | UAC package metadata browser/editor and reversible wrapper tools. |
| [CatalogReader](CatalogReader/README.md) | Read-only catalog access and shared browser projections. |
| [FrontendCore](FrontendCore/README.md) | Shared archive, preference, queue, and transport policy. |
| [CocoaSpice](CocoaSpice/README.md) | Native AppKit/SwiftUI player frontend. |
| [SPCBoyWK](SPCBoyWK/README.md) | Native WebKit player frontend. |
| [ViewBoy](ViewBoy/README.md) | Independent phosphor-styled WebKit player frontend. |

The older Electron `SPCBoy/` tree is archived source, not a release target.
LaunchPad remains a sibling workspace tool because it launches projects beyond
this family.

## Start here

Read [`AGENTS.md`](AGENTS.md), then [`project-info.md`](project-info.md), then
the owning component's `AGENTS.md` and routed `ai/project-info.md`. Keep
user-visible behavior in `subsystem-human/` and engineering invariants in
`subsystem-agent/`.

Family coordination and evidence:

- [`WIP-PLAN.md`](WIP-PLAN.md) — current shared-core priorities and owners.
- [`PARITY-WIP-REPORT.md`](PARITY-WIP-REPORT.md) — frontend parity evidence and
  open user-boundary checks.
- [`verification.md`](verification.md) — package checks and evidence limits.
- [`VGMBoy/Docs/plugin-catalog.md`](VGMBoy/Docs/plugin-catalog.md) — decoder,
  dependency, provenance, and scanner-product reference.
- [`ScanSong/ai/subsystem-agent/format-accommodations.md`](ScanSong/ai/subsystem-agent/format-accommodations.md)
  — scanner routes and inspection boundaries.
- [`MetaMan/FORMAT-LAYOUTS.md`](MetaMan/FORMAT-LAYOUTS.md) — native metadata
  layouts and bounded reader contracts.
- [`UACMan/Container/README.md`](UACMan/Container/README.md) — closed native
  SPC conversion decision and the supported wrapper boundary.
