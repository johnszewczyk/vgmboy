# Scanner Contract

## Scope

Cross-format ownership, catalog persistence, archive safety, concurrency,
resumption, diagnostics, and child-process boundaries. Format-specific routes
and reader behavior live in
[format-accommodations.md](format-accommodations.md).

## Ownership

- `ScanSongKit` owns source discovery, safe file/archive handling, inspection
  orchestration, checkpointing, schema-23 projection, and root publication.
- `CatalogScanner` coordinates discovery, reuse, inspection, and publication.
  `CanonicalCatalogSchema` owns the exact schema; `CanonicalCatalogWriter`
  owns every SQLite mutation and transaction boundary.
- `CatalogLinkAuditor` checks filesystem existence. The writer alone persists
  `dead_sources` and rebuilds projections transactionally.
- `MetaManCore` owns decoder-independent metadata interpretation. ScanSong
  supplies bounded source/context bytes and adapts ordered documents; it does
  not maintain duplicate format parsers.
- VGMBoy owns decoder code and scanner inspection products. ScanSong owns the
  host process adapter and app-bundle assembly for those products.
- `scansong` owns ordered JSONL serialization, exit status, and process-signal
  cancellation. `ScanSongApp` owns catalog management and user-facing progress.
- CocoaSpice and SPCBoyWK own playback and presentation. They open catalogs
  query-only and never receive scanner write access.

## Catalog and Resume Invariants

- ScanSong creates or accepts the exact supported schema 23; it does not
  migrate an unrelated or older application database.
- Player connections use OS-level read-only SQLite handles and
  `PRAGMA query_only=ON`. Opening a player does not block a ScanSong writer.
- The writer holds an OS advisory lease beside the selected catalog. The lease
  excludes another ScanSong writer only; normal SQLite `BUSY`/`LOCKED` remains
  retryable rather than being reported as corruption.
- A hidden staging root represents an unpublished scan. Publication replaces
  the live root rows and both sidebar projections in one transaction.
- A checkpoint represents one complete loose source or one complete physical
  archive. Partial archive results are never resumable or published.
- Resume rediscovers sources and validates fingerprints before reusing
  checkpoints. Fingerprint reuse compares the persisted epoch `modified_at`
  double to the filesystem value; converting through `Date` can shift one
  double ULP and cause an unchanged source to be rescanned.
- A failed refresh preserves last-known-good playable rows, records the
  current failure in staged inventory, and omits its checkpoint so it retries.
- Attached roots are catalog state. Detaching a root does not purge its indexed
  records. Missing sources enter `dead_sources` and leave player projections;
  only the explicit Clean Links action deletes their indexed rows.
- Catalog journal mode is preserved (`DELETE` or `WAL`). New catalogs use
  SQLite's default `DELETE` mode; active WAL sidecar files remain with the
  catalog until their connections close.

## Inspection and Metadata Boundary

- `MetaManCore.readResult(fileURL:)` is the shared ordered metadata contract.
  Result order is authoritative; repeated native source indices remain
  separate tracks. ScanSong owns only its schema projection and publication.
- UAC reads use MetaMan's package/member documents. For a compressed manifest,
  ScanSong supplies a bounded Zstandard callback for the JSON frame only. The
  callback never sees the TAR/audio payload. Catalog scans do not expand,
  hash, or inspect that payload, invoke an inner-format reader, or fill missing
  manifest fields from native member tags.
- Structure and optional metadata policy are separate. Required child or
  dependency enumeration cannot be deferred because a metadata option is off.
- A scanner plugin has a `ScannerPluginDescriptor` for routing and a
  `ScanFormatHandler` for structure and metadata. Handlers return a complete
  `ScanInspection`; they never write the catalog directly.
- Unknown inputs and unavailable required adapters produce typed diagnostics,
  never invented playable rows or calls into a host player application.
- File-type policy controls discovery and archive-member admission. It is not
  a corruption filter: malformed supported inputs remain failures. The
  default ignored extensions are documented in
  [format-accommodations.md](format-accommodations.md).
- Archive paths, symlinks, member count/name size, and expanded bytes are
  validated before records are accepted. Unknown archive members may appear in
  the post-operation unsupported-format inventory; known decoder sidecars and
  documentation stay out of the playable catalog.
- vgmstream extension roles come from VGMBoy's database-free
  `VGMBoyFormatCore`; per-format routing and direct MetaMan readers are
  recorded in [format-accommodations.md](format-accommodations.md).

## Concurrency, Progress, and Process Lifetime

- Sources use a bounded cross-archive pipeline (default four archives in
  flight). Member inspectors share a bounded permit pool (default eight,
  tunable through `--permits`); catalog checkpoints commit serially.
  Extraction is serialized to one expanded payload at a time, so per-archive
  size limits do not multiply across the pipeline.
- Archive member result order remains deterministic. Loose inspection and
  catalog persistence remain ordered even when archive members inspect in
  parallel.
- Cancellation is checked during discovery, archive processes, inspection,
  persistence boundaries, and between roots. Completed source checkpoints
  survive cancellation.
- Every scanner-launched process has an owned lifecycle: private process
  group, concurrent bounded output draining, timeout, cancellation
  termination, and wait-before-close. The native process runner currently
  limits execution to 30 seconds, stdout to 4 MiB, and stderr to 256 KiB.
- TAR.ZST streams `zstd -dc` into `tar` without a second full temporary TAR.
  Both processes are awaited. If `tar` accepts its end markers before zstd
  drains the frame, a separate `zstd -t` must validate the source.
- Standard output from `scansong` contains JSONL events only, with explicit
  contract name/version and increasing sequence numbers. Progress events are
  rate-limited to phase changes, completion, or one event per second.
- The app retains the latest operation update and samples it every 250 ms on
  the main actor. Progress presentation must not enqueue one UI task per file
  or pace worker operations. Scan totals count loose sources and archives;
  member inspections update detail only.
- Closing the native app during work asks the scanner to cancel cooperatively
  and waits for its checkpoint boundary. The development launcher's SIGTERM
  follows the same path rather than abruptly tearing down an active scan.

## Files

- `Sources/ScanSongKit/CatalogScanner.swift`
- `Sources/ScanSongKit/CanonicalCatalogWriter.swift`
- `Sources/ScanSongKit/CanonicalCatalogSchema.swift`
- `Sources/ScanSongKit/CatalogLinkAuditor.swift`
- `Sources/ScanSongKit/ScannerInspectors.swift`
- `Sources/ScanSongKit/InspectorProcessRunner.swift`
- `Sources/ScanSongKit/TXTPDependencyResolver.swift`
- `Sources/ScanSongKit/ArchiveMemberEnumerator.swift`
- `Sources/ScanSongKit/StandaloneArchiveExtractor.swift`
- `Sources/scansong/ScanSongCommand.swift`
- `Sources/ScanSongApp/ScanSongApp.swift`
