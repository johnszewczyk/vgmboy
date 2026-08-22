# Catalog Boundary

## Scope

`CatalogReader` opens MediaScanner's schema-23 catalog read-only and publishes
canonical roots, sidebar buckets, and track records.

## Ownership

MediaScanner owns catalog mutation and projection maintenance. CatalogReader
owns validation and read queries. Consumers own playlist construction and UI.

## Invariants

- Only attached and enabled roots are visible to browser projections.
- Dead sources are excluded from active read results.
- Catalog identity preserves root ID, source path, archive entry, and track index.

## Files

- `/Users/john/Downloads/Code/CatalogReader/Sources/CatalogReader/CatalogReader.swift`
- `/Users/john/Downloads/Code/CatalogReader/Sources/CatalogReaderElectronBridge/main.swift`
