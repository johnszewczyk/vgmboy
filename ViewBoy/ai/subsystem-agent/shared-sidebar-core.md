# System and Game Sidebar

The LCD sidebar offers Console (Library) and Path catalog modes, Queue and Favorites playlist views, and an Open action for local paths. Console mode groups the read-only catalog's games by system. Selecting a system opens or closes its game rows; child game labels align two bitmap glyph advances after the disclosure marker. Selecting a game loads its tracks into the main pane. Path mode renders `databaseFileTree` and uses `databaseFolderTracks`/`databaseFileTracks`; single-click folders fold or unfold, double-click loads a folder, and selecting a file loads that file's indexed tracks. Persist expanded Path nodes and the sidebar mode as display/native preferences respectively.

`CatalogBrowserCore` reduces system disclosure and game selection through the native `databaseGroupState` bridge. JavaScript keeps the returned expansion and selection state for rendering. Disclosure follows the shared auto-resize motion setting and duration. `CatalogReader` supplies catalog games, tracks, and the indexed file tree; the UI does not scan source folders or write catalog data.

The Library pane has a fixed width derived from its navigation controls and interface gap. Keep that width as its flex basis and minimum/maximum width, with flex growth and shrink disabled. Its tree viewport takes only the remaining vertical space (`flexBasis: 0`, `minHeight: 0`) and clips the expanding row content. Large group disclosures may animate rows, but they must not resize the pane or shift the adjacent playlist pane. Keep the search and navigation controls directly above the tree without section banners. Pane bottoms remain content areas with no status bar; the app footer owns file and playback-time readouts.

Queue displays the active playback list, falling back to the browsed playlist before playback starts. Favorites reads and updates the shared `FavoriteStoreCore`. Open uses the native path chooser and folder projection; it is separate from Path mode, which browses the catalog's indexed paths.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `../../../CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
