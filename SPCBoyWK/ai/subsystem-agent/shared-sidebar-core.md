# Shared Sidebar Core

## Scope

The WebKit frontend consumes `CatalogBrowserCore` for catalog search, game
grouping, stable identity, disambiguation, and deterministic ordering.

## Ownership

`CatalogReader` owns read-only catalog records. `CatalogBrowserCore` owns
UI-neutral browser and search resolution. FrontendCore owns favorite identity
and persistence. This project owns only the typed native adapter and WebKit rendering.

## Invariants

- Search is a temporary projection over the stored Console or Path View, and clearing it restores that mode. Favorites is a playlist projection and is not a CatalogReader aggregation mode.
- SPCBoyWK exposes the database Console View and a read-only catalog Path View.
  The removed Local Files/Open Path flow is not part of the maintained product.
- Game identity includes the catalog root ID, game name, and system.
- The native adapter forwards `CatalogBrowserGame.id` unchanged, and the WebKit
  group projection keys game rows by that same value so console membership and
  selection resolve against one shared identity.
- Game console labels come from CatalogReader's shared folder-versus-metadata
  aggregation; empty folder tags fall through to stored metadata before the
  UI receives a row.
- Catalog writes, scans, decoder selection, and playback do not belong here.
- Favorite identity/history and path-free `GAME-NN-SONG` labels are defined by FavoriteStoreCore and persisted in the shared VGMMan application-support sidecar. Historical or Alphabetical presentation is requested from Swift and never rewrites storage order. The WebKit adapter renders native snapshots and sends named toggle/import requests; it does not construct favorite identity or mutate SQLite.
- Database Console → Game group disclosure and selection state are reduced by
  `CatalogBrowserGroupStateRequest` through the native bridge; WebKit sends the
  typed shared state/action envelope and retains only DOM rows, focus, and
  persistence.
- Database game selection updates the playlist directly; it must not invoke a full sidebar redraw or deferred metadata pass when catalog rows already contain metadata.
- Large catalog playlists are rendered through a fixed-height visible window;
  the database result remains fully selectable without creating one WebKit DOM
  row per catalog track.
- Native playback and playlist commands use the shared `FrontendCommandCore`
  command contract. `Favorites Playlist` uses Command-Shift-D and changes only the queue snapshot,
  never the sidebar mode.
- Catalog-backed playlist rows must not stat source paths during hydration. CatalogReader supplies
  the metadata required for the playlist; decoder inspection and duration authority belong to
  VGMBoy through the native playback bridge, not to JavaScript hydration workers.

## Files

- `../../../CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `../../Sources/SPCBoyWK/Resources/index.html`
