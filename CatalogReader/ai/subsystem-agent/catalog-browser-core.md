# Catalog Browser Core

## Scope

`CatalogBrowserCore` owns behavior shared by native, WebKit, and future skins:
catalog browser modes, temporary search semantics, game grouping, disambiguation,
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
- Favorites is not a catalog-browser mode. Frontends project the shared favorite
  snapshot into the playlist without changing this catalog state.
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
- `CatalogFileTreeIndex` owns the database-only Files graph: root/folder
  identity, parent links, localized deterministic ordering, and flattening
  against a caller-supplied disclosure set. `CatalogFileSearchIndex` owns the
  filename/folder/full-path matching fields and cooperative cancellation.
  These indexes never enumerate the filesystem, inspect archives, render rows,
  or own selection and scroll state.
- The native and WebKit frontends may map `CatalogFileTreeIndex.Row` and
  `CatalogFileBucket` into AppKit row enums or bridge records. That mapping is
  an adapter; a frontend must not rebuild the folder graph or create a second
  file-search policy.
- `CatalogFileTreeIndex.nodes()` exposes the complete nested tree for a
  frontend bridge that needs hierarchical records. Its child ordering and
  source payloads are still produced by the shared index; the bridge may only
  rename fields or add renderer-local paths.

## Files

- `../../Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `../../Tests/CatalogBrowserCoreTests/CatalogBrowserCoreTests.swift`
