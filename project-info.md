# Project Info

## Product

VGMMan is the canonical Git repository for the game-music application family.
Apps retain separate package, app, and release boundaries; family source and
history live in this repository.

## Major Components

- VGMBoy and MetaMan provide playback and native metadata interpretation.
- ScanSong writes the catalog; CatalogReader and FrontendCore provide shared
  read and frontend policy boundaries.
- UACMan owns its package format and editor. CocoaSpice, SPCBoyWK, and ViewBoy
  are separate player apps.

## Task Routing

| Work | Owner and route |
| --- | --- |
| Format admission, decoding, timing, transport, and audio output | [VGMBoy/AGENTS.md](VGMBoy/AGENTS.md) |
| Source discovery, inspection orchestration, and schema-24 catalog writes | [ScanSong/AGENTS.md](ScanSong/AGENTS.md) |
| Decoder-independent native-format metadata | [MetaMan/AGENTS.md](MetaMan/AGENTS.md) |
| UAC editing, wrapper format, and package consumers | [UACMan/AGENTS.md](UACMan/AGENTS.md) |
| Read-only catalog access and browser projections | [CatalogReader/AGENTS.md](CatalogReader/AGENTS.md) |
| Shared archive/cache, preferences, queue, and transport policy | [FrontendCore/AGENTS.md](FrontendCore/AGENTS.md) |
| AppKit/SwiftUI presentation | [CocoaSpice/AGENTS.md](CocoaSpice/AGENTS.md) |
| Native WebKit player and typed host bridge | [SPCBoyWK/AGENTS.md](SPCBoyWK/AGENTS.md) |
| Phosphor-styled WebKit player | [ViewBoy/AGENTS.md](ViewBoy/AGENTS.md) |
| Legacy Electron recovery material | [LocalRecovery/README.md](LocalRecovery/README.md) |

For a component task, follow its `AGENTS.md` → `ai/AGENTS.md` →
`ai/project-info.md` → focused-note route. See `README.md` for the family
index.

- Shared ownership and remaining cross-app gates: [WIP-PLAN.md](WIP-PLAN.md).
- Frontend parity and open user-boundary checks:
  [PARITY-WIP-REPORT.md](PARITY-WIP-REPORT.md).
- Clean checkout, build, and evidence procedure:
  [verification.md](verification.md).
- Workspace-wide agent intake and build method, when DocMan is a sibling:
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
  Use `verification.md` for current checks and evidence limits.

## Human Docs

User-facing behavior lives under each app’s `ai/subsystem-human/`.
`README.md` indexes the family; `MONOREPO-MIGRATION.md` records its repository
and recovery layout. Shared decoder and dependency references live in
`VGMBoy/Docs/`.
