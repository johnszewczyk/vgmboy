# Project Info

## Product

VGMMan is the canonical Git repository for the game-music application family.
Apps retain separate package, app, and release boundaries; family source and
history live in this repository.

## Major Components

- VGMBoy and MetaMan provide playback and native metadata interpretation.
- ScanSong writes the catalog; CatalogReader and FrontendCore provide shared
  read and frontend policy boundaries.
- UACMan owns its package format and editor. CocoaSpice, SPCBOY SB2, and ViewBoy
  are active separate player apps; SB2 is the current SPCBOY frontend under
  development. SPCBoyWK is retired and retained for historical reference.
- LineBoy is a standalone monochrome line-grid player experiment in its own
  family subfolder. It uses CatalogReader for catalog access, FrontendCore for
  favorites and queue policy, and VGMBoy for playback.

## Task Routing

Select the smallest owner that matches the request and read only its route.
For a component task, do not inspect sibling components or scan the family
repository by default. Add another component route only when the requested work
crosses that ownership boundary.

| Work | Owner and route |
| --- | --- |
| Format admission, decoding, timing, transport, and audio output | [VGMBoy/AGENTS.md](VGMBoy/AGENTS.md) |
| Source discovery, inspection orchestration, and schema-24 catalog writes | [ScanSong/AGENTS.md](ScanSong/AGENTS.md) |
| Decoder-independent native-format metadata | [MetaMan/AGENTS.md](MetaMan/AGENTS.md) |
| UAC editing, wrapper format, and package consumers | [UACMan/AGENTS.md](UACMan/AGENTS.md) |
| Read-only catalog access and browser projections | [CatalogReader/AGENTS.md](CatalogReader/AGENTS.md) |
| Shared archive/cache, preferences, queue, and transport policy | [FrontendCore/AGENTS.md](FrontendCore/AGENTS.md) |
| AppKit/SwiftUI presentation | [CocoaSpice/AGENTS.md](CocoaSpice/AGENTS.md) |
| Retired native WebKit SPCBOY frontend | [SPCBoyWK/AGENTS.md](SPCBoyWK/AGENTS.md) |
| SPCBOY SB2 pixel-style WebKit frontend | [SB2/AGENTS.md](SB2/AGENTS.md) |
| Screen-first Yoga LCD player | [ViewBoy/AGENTS.md](ViewBoy/AGENTS.md) |
| Monochrome DOS-style line-grid display experiment | [LineBoy/AGENTS.md](LineBoy/AGENTS.md) |
| Published Markdown library and native documentation viewer | [VGMManDocs/AGENTS.md](VGMManDocs/AGENTS.md) |

For a component task, follow that owner's `AGENTS.md` → `ai/AGENTS.md` →
`ai/project-info.md` → focused-note route. `README.md` is a family index, not
default intake.

Family-level references are conditional routes, not required reading for a
component task:

- Cross-component ownership or priorities:
  [ai/plans/family-priorities.md](ai/plans/family-priorities.md).
- Player frontend comparison or parity:
  [ai/reports/frontend-parity.md](ai/reports/frontend-parity.md).
- Family-wide clean checkout or build evidence:
  [ai/verification/family.md](ai/verification/family.md).
- Repository recovery or Git ownership:
  [ai/subsystem-agent/repository-recovery.md](ai/subsystem-agent/repository-recovery.md).
- Workspace-wide intake/build method, when relevant:
  [DocMan](../DocMan/AGENTS.md) and
  [agent-onboarding-and-builds.md](../DocMan/docs-agent/agent-onboarding-and-builds.md).

## Local Rules

- Run Git commands from this root. Component folders are not nested Git
  repositories or submodules. Cross-package changes belong in one family-root
  commit.
- Catalog writes belong to ScanSong; player frontends use read-only catalog
  access. Native-format metadata parsing belongs to MetaMan; UAC package parsing
  belongs to UACMan; playback decoding belongs to VGMBoy.
- Shared frontend policy belongs in CatalogReader or FrontendCore. Keep
  AppKit, SwiftUI, WebKit, and renderer-specific behavior in each app.
- UAC is a reversible wrapper around original format members. Native SPC
  conversion was closed; do not add capture or repackaging work.
- Generated builds, app bundles, local archives, and fixture payloads are
  excluded from Git. `LocalRecovery/README.md` inventories retained local
  recovery assets.
- Compilation is package evidence, not proof of packaged UI or audible output.
  Use `ai/verification/family.md` for current checks and evidence limits.

## Documentation

Published VGMMan project documentation lives in
[`VGMManDocs/Docs/md/`](VGMManDocs/Docs/md/), grouped by owning project name.
The viewer reads these Markdown sources directly. Keep DocMan intake,
engineering notes, plans, reports, and verification records in their required
routed locations under each project's `ai/` tree. `README.md` remains the
family entry point.
