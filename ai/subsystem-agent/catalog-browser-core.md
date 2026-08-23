# Catalog Browser Core

## Scope

`CatalogBrowserCore` owns behavior shared by native, WebKit, and future skins:
browser modes, temporary search semantics, game grouping, disambiguation,
stable row identity, and deterministic ordering. `CatalogReader` supplies the
same folder-versus-metadata aggregation policy to every skin before projection.

## Ownership

The package consumes published `CatalogReader` records and returns UI-neutral
models. It does not render controls, persist frontend preferences, scan files,
write SQLite, or activate playback.

## Invariants

- Search temporarily presents catalog-console results and clearing search restores the stored mode.
- Duplicate game names are disambiguated consistently from system and root information.
- Display labels never become selection identity.
- Empty folder console tags fall through to stored track metadata before the
  projection creates an `Unknown Console` group.

## Files

- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogBrowserCore/CatalogBrowserCore.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Tests/CatalogBrowserCoreTests/CatalogBrowserCoreTests.swift`
