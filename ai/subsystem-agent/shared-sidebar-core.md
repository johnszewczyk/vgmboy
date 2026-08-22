# Shared Sidebar Core

## Scope

The WebKit frontend consumes `CatalogBrowserCore` for browser modes, search
semantics, game grouping, stable identity, disambiguation, and deterministic
ordering.

## Ownership

`CatalogReader` owns read-only catalog records. `CatalogBrowserCore` owns
UI-neutral browser behavior. This project owns only the WebKit adapter and
rendering.

## Invariants

- Search is a temporary catalog-console view and clearing it restores the stored mode.
- The sidebar view button opens a flat in-app menu with `Consoles`, `Paths`, and `Disk Path`; the
  first two are the catalog database views and the last is the explicitly opened local filesystem.
- Game identity includes the catalog root ID, game name, and system.
- Catalog writes, scans, decoder selection, and playback do not belong here.

## Files

- `/Users/john/Downloads/Code/CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `/Users/john/Downloads/Code/SPCBoy (WK)/Sources/SPCBoyWK/Resources/index.html`
