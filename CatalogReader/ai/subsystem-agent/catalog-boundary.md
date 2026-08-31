# Catalog Boundary

## Scope

`CatalogReader` opens ScanSong's schema-23 catalog read-only and publishes
canonical roots, aggregated sidebar buckets, and track records. It also owns
the exact source, folder, and path projections used to hydrate a selected
playlist. The exact Games playlist query recovered from CocoaSpice lives in
the sibling `CatalogPlaylistCore` target.

## Ownership

ScanSong owns catalog mutation and projection maintenance. CatalogReader
owns validation and general read queries. CatalogPlaylistCore owns the exact
extracted root/game/system Games playlist query. Consumers own frontend-specific
row models, queue publication, and UI.

## Invariants

- Only attached and enabled roots are visible to browser projections.
- Dead sources are excluded from active read results.
- Catalog identity preserves root ID, source path, archive entry, and track index.
- Source, folder, and path hydration are bounded SQLite projections; they never
  inspect source paths, invoke a decoder, or rebuild a complete frontend.
- `CatalogSourceSelection` keeps root identity attached to an exact Files row;
  consumers must not infer root ownership from filesystem state.
- Game-sidebar aggregation and Games playlist hydration use the same explicit
  system projection: use the recognized folder-derived `browser_system` first
  or use stored track metadata first, according to the requested mode. A blank
  folder system therefore remains selectable through the metadata system shown
  by the sidebar.
- CatalogPlaylistCore preserves the folder-first and metadata-first modes as
  projection choices, not host-specific fallback behavior. The selected game,
  root, and projected system must identify the same rows in both frontends.
- Games playlist selection keeps folder-system and metadata-system branches
  separate with `UNION ALL` so SQLite can use
  `tracks_game_sidebar_index`. Replacing those branches with one broad `OR`
  predicate is a performance regression even when it returns the same rows.
- Games playlist activation accepts multiple stable sidebar identities in one
  read-only query and returns the catalog metadata projection, including
  Dumper when the optional schema-23 column exists. Older schema-23 catalogs
  without that column read an empty value.
- When ScanSong marks either sidebar projection dirty during a scan,
  `CatalogReader` derives that projection from visible tracks until ScanSong
  republishes the materialized buckets. This keeps CocoaSpice and SPCBoyWK
  consistent without duplicating scanner-write logic in either frontend.

## Files

- [CatalogReader.swift](../../Sources/CatalogReader/CatalogReader.swift)
- [CatalogReaderTests.swift](../../Tests/CatalogReaderTests/CatalogReaderTests.swift)
- [CatalogPlaylistCore.swift](../../Sources/CatalogPlaylistCore/CatalogPlaylistCore.swift)
- [main.swift](../../Sources/CatalogReaderElectronBridge/main.swift)
