# Catalog Gallery Core

## Scope

`CatalogGalleryCore` owns the UI-neutral Title Snap Gallery projection shared
by native and WebKit frontends: console fallback names, deterministic console
groups, matching console groups for catalog search, and artwork game membership
for a selected console.

## Ownership

- `CatalogSidebarReader` and `CatalogReader` supply read-only
  `CatalogGalleryGame` records from the published catalog.
- `CatalogGalleryIndex` projects those records into stable console groups and
  uses `CatalogBrowserCore` search semantics to identify matching groups.
- Frontends own card layout, sidebar controls, selection presentation, lazy
  artwork reads, caches, and app-specific artwork materialization.
- The module must remain UI-framework-free and must not read the filesystem or
  write to the catalog. Root names are derived only from published paths for
  search projection.

## Invariants

- A console is present only when at least one indexed Title Snap game belongs
  to it.
- Empty or whitespace-only system names use `Unknown Console`, matching the
  catalog browser's shared grouping policy.
- Console group ordering and search terms use `CatalogBrowserCore` behavior.
- Game IDs retain the published root/game/system identity; display labels are
  never identity.
- A nil selected console returns all Gallery games; an unknown selected console
  returns no games.
- Gallery records and group projections remain restricted to the active,
  attached catalog roots returned by the reader.

## Files

- `../../Sources/CatalogGalleryCore/CatalogGalleryCore.swift`
- `../../Package.swift`
