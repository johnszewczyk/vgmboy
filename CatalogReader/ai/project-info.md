# Project Info

## Product

`CatalogReader` is the shared read-only catalog and browser-behavior package
for the CocoaSpice family of frontends.

## Major Components

- `CatalogReader`: schema-23 SQLite reader and canonical catalog records.
- `CatalogSessionCore`: shared read-only sidebar bucket access and latest-task
  cancellation/stale-result ownership.
- `CatalogBrowserCore`: UI-neutral browser state, grouping, search, identity,
  and deterministic presentation data.
- `FrontendCommandCore`: shared semantic shortcut definitions for native and
  WebKit hosts.
- `CatalogReaderElectronBridge`: narrow command bridge for the archived SPCBoy
  Electron frontend.

## Task Routing

Agent engineering notes:

- Catalog ownership: [catalog-boundary.md](subsystem-agent/catalog-boundary.md)
- Shared browser behavior: [catalog-browser-core.md](subsystem-agent/catalog-browser-core.md)

## Local Rules

- ScanSong is the catalog writer and scanner owner.
- VGMBoy is the playback and decoder owner.
- Frontends render snapshots and issue activation requests; they do not write
  the catalog or duplicate its SQL.
- Dumper is read as catalog metadata when present; pre-Dumper schema-23
  catalogs remain readable and return an empty value.

## Human Docs

- `Docs/` is the human-side folder and is not default engineering intake.
