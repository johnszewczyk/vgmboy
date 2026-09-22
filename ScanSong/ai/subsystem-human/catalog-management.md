# Catalog Management

## Scope

- The ScanSong app manages a selected schema-24 catalog and its scan paths.

## Catalog

- Database File always shows one selected catalog-file row, or `(None)` when
  that file no longer exists. Its controls open an existing catalog, while
  `Use Default` selects the standard catalog location and `Add New` creates a
  fresh schema-24 SQLite catalog at a new path. Only one catalog is selected at
  a time; Add New refuses to replace an existing file. Reset empties its
  contents with the circular x icon, and Delete permanently removes the file
  after confirmation.
- Reset empties the catalog, including scan paths, indexed tracks, metadata,
  and scan history; Delete removes the SQLite file. Neither action deletes
  media files.

## Scan Paths

- Each scan path can be enabled or disabled without removing it.
- Every path has Scan, Show Last Scan Log, and Remove controls.
- A path shows its last scan time, physical file count, active playable-track
  count, and issue count.
- Scan All scans enabled paths. An individual path can be scanned without
  enabling it.

## Link Maintenance

- Check Links marks missing or moved sources inactive and removes them from
  the player-visible catalog without deleting their retained records.
- Remove Links permanently removes only inactive catalog entries. It never
  deletes media files.

## Scan Results

- The last-result log has fixed `status | detail | path` columns. Actual
  archive failures retain the root-relative `archive#member` path; successful members are
  never listed, and skipped archive members are grouped by archive and
  extension. Scan Status is the only in-window summary.
- Scanner-owned extraction scratch prefixes are removed from diagnostic details;
  the archive/member path remains the stable identifier.
- During a scan or catalog operation, the relevant controls dim and Scan Status
  shows the current phase, a live elapsed clock, and an activity indicator.
  Scan and link checks show source/item and failure counts when available.
  Scan cancellation remains available while the worker is stopping.
- The linear bar shows a source fraction only while planning or inspecting
  with a known source total. Saving checkpoints reports a separate saved
  count; discovery, archive work, publication, and cleanup show ongoing
  indeterminate activity instead of a
  percentage that would appear stuck at the end. Current File and a concise
  operation detail report what is being handled; completed archive members
  update the detail while the archive remains one source item.
- Multi-root scans discover their total before inspection, so the source
  denominator stays stable. Standalone `.pdx.zst` sidecars are prepared with
  their owning `.mdx.zst`, not counted as separate source items. A completion
  summary distinguishes source counts from member failures.
- Adding, enabling, disabling, or removing paths and creating, opening,
  resetting, or deleting a catalog show an in-progress state while database
  work runs. Mutating actions finish with a checkmark row showing duration,
  finish time, and result. The window remains responsive during that work.
- Closing the app while a scan or link-maintenance operation is active presents
  a warning. A scan can be cancelled and closes only after completed checkpoints
  are retained; maintenance closes only after its current database operation.
- The development launcher sends `SIGTERM` to the previous ScanSong instance.
  The GUI handles that signal through the same cooperative close path: active
  scans cancel and retain completed checkpoints, while link/path maintenance
  finishes its current database operation. Scanner-owned decoder and archive
  subprocesses are terminated and reaped before their output handles close.

## Options

- The Options window uses the CocoaSpice split-sidebar layout. Its first sidebar
  section is `File Types`.
- File Types shows checkbox controls for documented decoder-absent extensions.
  Checked types are ignored before discovery and archive-member inspection;
  supported formats remain active so malformed files still appear in the scan
  result and last-result log.
- The ignore selection is persisted in ScanSong preferences. Explicitly ignored
  files are recorded in the post-operation scan log. Archive members without a
  scanner route are grouped as `unrecognized` diagnostics unless they are known
  decoder support files, archive documentation, or extensionless material; none
  become playable candidates.

## Files

- `Sources/ScanSongApp/ScanSongApp.swift`
- `Sources/ScanSongApp/ScannerOptionsView.swift`
- `Sources/ScanSongApp/ScannerScanLog.swift`
