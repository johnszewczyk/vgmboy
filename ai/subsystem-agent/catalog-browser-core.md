# Catalog Browser Core

## Scope

`CatalogBrowserCore` owns behavior shared by native, WebKit, and future skins:
browser modes including Favorites, temporary search semantics, game grouping, disambiguation,
stable row identity, deterministic ordering, and renderer-independent sidebar
row gesture intent. It also owns the UI-neutral Console → Game disclosure and
selection reducer and the incremental `CatalogSearchIndex` used by projected
game searches. `CatalogReader` supplies the
same folder-versus-metadata aggregation policy to every skin before projection.

## Ownership

The package consumes published `CatalogReader` records and returns UI-neutral
models. It does not render controls, persist frontend preferences, scan files,
write SQLite, or activate playback.

## Invariants

- Search temporarily presents catalog-console results and clearing search restores the stored mode.
- Favorites keeps its own searchable track-history content boundary rather than becoming a catalog aggregation.
- Duplicate game names are disambiguated consistently from system and root information.
- Display labels never become selection identity.
- Search terms match the same normalized name, system, root, and display-label fields in every skin; extending a query may reuse prior candidates, while backspace or replacement restarts from all rows.
- Empty folder console tags fall through to stored track metadata before the
  projection creates an `Unknown Console` group.
- Folder, leaf, and group gestures reduce to select, preview, expansion, or
  activation intents without importing SwiftUI, AppKit, WebKit, or DOM state.
- `CatalogBrowserGroupState` owns Console → Game group selection and disclosure
  transitions. A group toggle clears game selection and never activates a
  child; frontends retain only their row rendering, focus, scroll, and
  persistence adapters.

## Files

- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Tests/CatalogBrowserCoreTests/CatalogBrowserCoreTests.swift`
