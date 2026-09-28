# System and Game Sidebar

The LCD sidebar presents four views: Library, Current Queue, Favorites, and Open Path. The Library view groups the read-only catalog's games by system. Selecting a system opens or closes its game rows; selecting a game loads its tracks into the main pane.

`CatalogBrowserCore` reduces system disclosure and game selection through the native `databaseGroupState` bridge. JavaScript keeps the returned expansion and selection state for rendering. Disclosure animates the affected rows over 250 ms. `CatalogReader` supplies catalog games and tracks; the UI does not scan folders or write catalog data.

Current Queue displays the active playback list, falling back to the selected game's tracks before playback starts. Favorites reads and updates the shared `FavoriteStoreCore`. Open Path uses the native path chooser and folder projection.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `../../../CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
