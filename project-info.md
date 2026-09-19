# Project Info

## Product

VGMMan is the canonical Git repository for the game-music application family.
Apps retain separate package, app, and release boundaries; family source and
history live in this repository.

## Ownership and task routing

| Work | Owner and route |
| --- | --- |
| Format admission, decoding, timing, transport, and audio output | [VGMBoy/AGENTS.md](VGMBoy/AGENTS.md) |
| Source discovery, inspection orchestration, and schema-23 catalog writes | [ScanSong/AGENTS.md](ScanSong/AGENTS.md) |
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

## Repository rules

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

## Family documents

- Shared ownership and remaining cross-app gates: [WIP-PLAN.md](WIP-PLAN.md).
- Frontend parity evidence: [PARITY-WIP-REPORT.md](PARITY-WIP-REPORT.md).
- Build/test coverage and current evidence: [verification.md](verification.md).
- History and recovery layout: [MONOREPO-MIGRATION.md](MONOREPO-MIGRATION.md).
- Workspace-wide documentation method: [DocMan](../DocMan/AGENTS.md) and
  [documentation-method.md](../DocMan/docs-agent/documentation-method.md).
- User-facing behavior lives under each app’s `ai/subsystem-human/`; shared
  decoder and dependency references live in `VGMBoy/Docs/`.
