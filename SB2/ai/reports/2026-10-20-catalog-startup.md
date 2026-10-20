# Catalog startup and view reuse

## Implemented

- SB2 validates the selected catalog by schema without a full active-track count.
- Archive-cache configuration saves policy without walking the cache. Inventory is requested by Options.
- Both players reveal restored controls and playlists while sidebar projections load independently.
- SB2 Games and Files loads use explicit loaded flags, including successful empty results, and share in-flight requests. Reload invalidates generations; old results cannot overwrite the new session.
- Gallery uses its own artwork projection and search without first loading all Games. Ordinary Games loads do not invalidate Gallery.
- Search retains the selected Games/Files source. CocoaSpice builds its Games search index off the main actor.
- ScanSong publishes both resolved system-assignment modes in an additive schema-25 table. Track, metadata, and dead-source triggers invalidate per-root state, including changes made by older writers. Writer opening republishes invalid clean roots. Publication and link maintenance maintain the projection transactionally.
- CatalogReader checks projection validity and reads rows within one read-only SQLite snapshot. It preserves derivation for supported catalogs without a current projection. Frontend projection adapters skip the redundant raw-bucket sort.
- SB2 Path View statistics use source/root counts; Gallery statistics use its own dataset.

## Evidence

The selected catalog was approximately 2.3 GB, with 15 visible roots and 672,999 stored tracks, including retained history. Read-only query timings before changes: schema/open about 3 ms, roots about 1 ms, active-track count 7.54–8.15 seconds, folder-first Games query 4.87–5.15 seconds. These are query timings, not complete launch benchmarks.

A SQLite backup of the real catalog was used as a disposable fixture. Both published modes exactly matched active-track/metadata derivation: 49,866 folder-first rows and 49,650 metadata-first rows. Direct projection SQL reads took 0.19–0.23 seconds on the fixture. The live projection read took 0.167 seconds after installation. No cold-cache claim is made.

A compiled reader probe verified both modes and system filtering. Disposable transactions verified invalidation for tracks, metadata, and dead sources; an older-writer-style metadata update was followed by successful ScanSong republication. No media rescan was performed.

The selected live catalog was backed up to `/tmp/vgmman-startup-backup.sqlite` before ScanSong installed the projections. The backup is temporary local recovery data, not a repository artifact.

SB2, CocoaSpice, and ScanSong app bundles were rebuilt. Player packaging reused existing decoder archives. JavaScript syntax checks and Git whitespace checks passed. SB2 was reopened interactively with its saved playlist; creating and closing a duplicate tab retained the loaded Path sidebar without a loading screen. CocoaSpice interactive behavior and an instrumented end-to-end cold launch were not measured. No app test suites were run.
