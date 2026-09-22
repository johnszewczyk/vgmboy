# Native Operation Presentation

## Scope

The ScanSong app's catalog actions, progress display, and close behavior.
Scanner data and checkpoint rules remain in [scanner-contract.md](scanner-contract.md).

## Ownership

- `ScannerAppModel` owns visible state and starts utility-priority workers for
  catalog mutations, root/tally refresh, scanning, and link maintenance.
- `ScanSongKit` owns the work and emits source, phase, and detail progress.
  The UI does not call into a worker synchronously to render a progress frame.
- `ScannerOperationTelemetry` gives the window a phase label, elapsed time,
  source/item count, failure count, and completion summary. It never invents a
  percentage for work with no stable denominator.

## Concurrency

- Catalog reads and path enable/disable, bulk toggles, removal, reset, and
  creation run off the main actor. The worker returns one snapshot of roots and
  tallies; the model applies it on the main actor. A busy operation disables
  conflicting controls while leaving the window and scan cancellation live.
- Scanner and link-maintenance callbacks publish into a lock-protected
  latest-value buffer. The main actor samples at 250 ms. Neither callbacks nor
  view animation wait for a render or reduce worker throughput.
- The source fraction is determinate only for planning and inspection after
  discovery established a stable source total. Checkpoint persistence reports
  its own saved count without recycling the inspection percentage. Discovery,
  archive extraction/materialization, publication, and cleanup show
  indeterminate activity instead of a misleading near-complete bar. An archive
  remains one source; completed member details never increment the source
  counter.
- Elapsed time is driven by the window's timeline, independently of worker
  callbacks. A long archive or SQLite publication therefore retains visible
  activity even when its source counter cannot advance.
- Last-result log persistence and catalog snapshots run off the main actor
  before operation completion is reported.

## Failure Boundaries

- A failed mutation re-reads the selected catalog before reporting the error,
  so a partially completed multi-path operation does not leave stale toggles
  on screen. A refresh failure is reported as an unavailable catalog, not a
  successful path update; a database mutation may already have committed.
- Scan cancellation requests a checkpoint-safe stop and waits for child
  processes; catalog maintenance and path changes finish their current
  database operation before the app closes.
- A completed source fraction does not imply catalog publication or UI
  completion. Keep phase and completion telemetry separate from the source
  meter.

## Files

- [ScanSongApp.swift](../../Sources/ScanSongApp/ScanSongApp.swift)
- [ScannerOperationTelemetry.swift](../../Sources/ScanSongApp/ScannerOperationTelemetry.swift)
- [ScannerScanLog.swift](../../Sources/ScanSongApp/ScannerScanLog.swift)
- [CatalogScanner.swift](../../Sources/ScanSongKit/CatalogScanner.swift)
