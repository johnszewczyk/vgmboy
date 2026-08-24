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
- Game-sidebar aggregation has one explicit preference: use the recognized
  folder-derived `browser_system` first or use stored track metadata first.
  That display aggregation is separate from the exact playlist selection
  predicate.
- CatalogPlaylistCore preserves CocoaSpice's original folder-first activation
  predicate (`t.browser_system = ?`) and its explicit metadata-first mode. It
  does not add a fallback predicate or broaden the selection.
- Games playlist activation accepts multiple stable sidebar identities in one
  read-only query and returns exactly the original fourteen projected columns.

## Files

- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogReader/CatalogReader.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Tests/CatalogReaderTests/CatalogReaderTests.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogPlaylistCore/CatalogPlaylistCore.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogReaderElectronBridge/main.swift`
