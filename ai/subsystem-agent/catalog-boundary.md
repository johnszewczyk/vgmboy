# Catalog Boundary

## Scope

`CatalogReader` opens MediaScanner's schema-23 catalog read-only and publishes
canonical roots, aggregated sidebar buckets, and track records.

## Ownership

MediaScanner owns catalog mutation and projection maintenance. CatalogReader
owns validation and read queries. Consumers own playlist construction and UI.

## Invariants

- Only attached and enabled roots are visible to browser projections.
- Dead sources are excluded from active read results.
- Catalog identity preserves root ID, source path, archive entry, and track index.
- Game-sidebar aggregation has one explicit preference: use the recognized
  folder-derived `browser_system` first or use stored track metadata first.
  Either order falls back to the other source when the preferred value is
  empty, so a valid metadata system cannot become `Unknown System` merely
  because a folder was not recognized.
- Game activation uses the same aggregation expression as the visible bucket;
  the row and its playlist projection cannot disagree about the selected
  system.

## Files

- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogReader/CatalogReader.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/CatalogReaderElectronBridge/main.swift`
