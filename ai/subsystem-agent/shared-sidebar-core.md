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

- Search is a temporary catalog-console view and clearing it restores the stored mode. Favorites is a separate frontend-owned track-history view and is not a CatalogReader aggregation mode.
- The sidebar view button opens a flat in-app menu with `Consoles`, `Paths`, and `Disk Path`; the
  first two are the catalog database views and the last is the explicitly opened local filesystem.
- Game identity includes the catalog root ID, game name, and system.
- Game console labels come from CatalogReader's shared folder-versus-metadata
  aggregation; empty folder tags fall through to stored metadata before the
  UI receives a row.
- Catalog writes, scans, decoder selection, and playback do not belong here.
- Favorite identity/order is defined by FavoriteTrackCore. The current WebKit adapter renders a loading status while it reads the indexed catalog and uses database track queries directly for game previews; it does not walk source folders. Playlist rows support Command-click and Shift-click multi-selection. Cross-app favorite persistence still needs the planned shared sidecar store; the current local WebKit preference data is not the final shared storage contract.
- Database game selection updates the playlist directly; it must not invoke a full sidebar redraw or deferred metadata pass when catalog rows already contain metadata.

## Files

- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/index.html`
