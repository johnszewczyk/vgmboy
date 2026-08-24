# Catalog Session Core

## Scope

- Shared lifecycle ownership for database-backed frontend reads.
- Shared raw Games and Files sidebar projections.

## Ownership

- `LatestTaskOwner` owns only one workflow's task handle, generation, and
  cooperative cancellation state. The consuming frontend owns observable UI
  state, selection, presentation, and completion callbacks.
- `CatalogSidebarReader` opens a read-only schema-23 `CatalogReader` connection
  for each snapshot request and returns published `CatalogGameBucket` or
  `CatalogFileBucket` values. It does not build rows, trees, search indexes, or
  queues.
- ScanSong remains the sole catalog writer. Frontends remain read-only.

## Invariants

- Replacing, completing, or cancelling a task invalidates older generations;
  stale callbacks must not publish results.
- Games and Files workflows use independent task owners, so one large snapshot
  cannot cancel or block the other.
- Sidebar reads are database projections only. They must not walk source paths,
  rescan files, inspect decoders, materialize archives, or write the catalog.
- Reader failures are surfaced to the frontend; no empty-database or alternate
  database fallback is permitted.

## Files

- `Sources/CatalogSessionCore/CatalogSessionCore.swift`
- `Tests/CatalogSessionCoreTests/CatalogSessionCoreTests.swift`
