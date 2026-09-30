# System and Game Sidebar

The LCD sidebar presents four views: Library, Current Queue, Favorites, and Open Path. The Library view groups the read-only catalog's games by system. Selecting a system opens or closes its game rows; child game labels align two bitmap glyph advances after the disclosure marker. Selecting a game loads its tracks into the main pane.

`CatalogBrowserCore` reduces system disclosure and game selection through the native `databaseGroupState` bridge. JavaScript keeps the returned expansion and selection state for rendering. Disclosure follows the shared auto-resize motion setting and duration. `CatalogReader` supplies catalog games and tracks; the UI does not scan folders or write catalog data.

The Library pane has a fixed width derived from its navigation controls and interface gap. Keep that width as its flex basis and minimum/maximum width, with flex growth and shrink disabled. Its tree viewport takes only the remaining vertical space (`flexBasis: 0`, `minHeight: 0`) and clips the expanding row content. Large group disclosures may animate rows, but they must not resize the pane or shift the adjacent playlist pane. Keep the search and navigation controls directly above the tree without section banners; reserve the pinned footer for the active search, system, or game summary.

Current Queue displays the active playback list, falling back to the selected game's tracks before playback starts. Favorites reads and updates the shared `FavoriteStoreCore`. Open Path uses the native path chooser and folder projection.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `../../../CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
