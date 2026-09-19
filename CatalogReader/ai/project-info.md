# Project Info

## Product

`CatalogReader` is the shared read-only catalog and browser-behavior package
for the active VGMMan player frontends: CocoaSpice, SPCBoyWK, and ViewBoy.

## Major Components

- `CatalogReader`: schema-23 SQLite reader and canonical catalog records.
- `CatalogSessionCore`: shared read-only sidebar bucket access and latest-task
  cancellation/stale-result ownership.
- `CatalogBrowserCore`: UI-neutral browser state, grouping, search, identity,
  and deterministic presentation data.
- `FrontendCommandCore`: shared semantic shortcut definitions for native and
  WebKit hosts.
- `CatalogReaderElectronBridge`: recovery-only command bridge for the archived
  Electron player; it is not used by maintained frontends.

## Task Routing

Agent engineering notes:

- Catalog ownership and schema contract:
  [catalog-boundary.md](subsystem-agent/catalog-boundary.md)
- Shared browser state, grouping, and search:
  [catalog-browser-core.md](subsystem-agent/catalog-browser-core.md)
- Playlist row text, filename identity, and duration projection:
  [catalog-playlist-presentation-core.md](subsystem-agent/catalog-playlist-presentation-core.md)
- Read-only session generations and stale-task cancellation:
  [catalog-session-core.md](subsystem-agent/catalog-session-core.md)
- Native/WebKit semantic command definitions:
  [frontend-command-core.md](subsystem-agent/frontend-command-core.md)

## Local Rules

- ScanSong is the catalog writer and scanner owner.
- VGMBoy is the playback and decoder owner.
- Frontends render snapshots and issue activation requests; they do not write
  the catalog or duplicate its SQL.

## Human Docs

- `ai/subsystem-human/` contains human-facing behavior notes routed by the owning frontend.
