# Shared Sidebar Core

## Scope

The WebKit frontend consumes `CatalogBrowserCore` for browser modes, search
semantics, game grouping, stable identity, disambiguation, and deterministic
ordering.

## Ownership

`CatalogReader` owns read-only catalog records. `CatalogBrowserCore` owns
UI-neutral browser and search resolution. FrontendCore owns favorite identity
and persistence. This project owns only the typed native adapter and WebKit rendering.

## Invariants

- Search is a temporary catalog-console view and clearing it restores the stored mode. Favorites is a playlist projection and is not a CatalogReader aggregation mode.
- The sidebar view button is one toggle cycling `Console View` and `Path View`.
  `Local Files` remains an explicitly enabled local-filesystem state and is not
  part of the library-view cycle.
- Game identity includes the catalog root ID, game name, and system.
- Game console labels come from CatalogReader's shared folder-versus-metadata
  aggregation; empty folder tags fall through to stored metadata before the
  UI receives a row.
- Catalog writes, scans, decoder selection, and playback do not belong here.
- Favorite identity/history and path-free `GAME-NN-SONG` labels are defined by FavoriteStoreCore and persisted in the shared VGMMan application-support sidecar. Historical or Alphabetical presentation is requested from Swift and never rewrites storage order. The WebKit adapter renders native snapshots and sends named toggle/import requests; it does not construct favorite identity or mutate SQLite.
- Local Files uses `LocalFileBrowserCore`; enabling it in the Database options page disables catalog view commands. Command-O opens a native file/folder panel and publishes the Swift browser snapshot to the skin.
- Sidebar mode/search resolution is performed by CatalogBrowserCore through the native bridge. The deleted Electron-era `sidebar-view-state.js` is not a second behavior implementation.
- Browser-tree row click/disclosure/activation intent is reduced by
  `CatalogBrowserCore.SidebarRowInteraction` through the native bridge. The
  WebKit controller dispatches that returned intent and does not duplicate the
  browser-tree selection rule table. Database Console → Game group disclosure
  and selection state are reduced by `CatalogBrowserGroupState` through the
  native bridge; WebKit retains only DOM rows, focus, and persistence.
- Database game selection updates the playlist directly; it must not invoke a full sidebar redraw or deferred metadata pass when catalog rows already contain metadata.
- Large catalog playlists are rendered through a fixed-height visible window;
  the database result remains fully selectable without creating one WebKit DOM
  row per catalog track.
- Native View-menu commands use the shared `FrontendCommandCore` command
  contract; the WebKit skin maps catalog commands to the same two view values.
  `Favorites Playlist` uses Command-Shift-D and changes only the queue snapshot,
  never the sidebar mode.
- Catalog-backed playlist rows must not stat source paths during hydration. CatalogReader supplies
  the metadata required for the playlist; decoder inspection and duration authority belong to
  VGMBoy through the native playback bridge, not to JavaScript hydration workers.
- Files-sidebar source selections use the shared `CatalogSourceSelection` projection, and folder
  selections use the shared root-path folder projection. The bridge does not issue one bespoke
  source query per file or reconstruct catalog predicates in JavaScript.

## Files

- `../../../CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `../../Sources/SPCBoyWK/Resources/index.html`
- `../../Sources/SPCBoyWK/Resources/sidebar-controller.js`
