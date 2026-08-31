# Archive Services

## Scope

UI-neutral archive listing, process execution, materialization, cache policy,
and playable-member lifetime shared by native frontends.

## Ownership

- `ArchiveListingParser` parses bounded 7-Zip, TAR, and RSN listings and
  preserves reversible BSD-tar pathname rendering.
- `ArchiveProcessRunner` owns bounded process output, timeouts, cancellation,
  and injected executable invocation.
- `ArchiveMaterializationCore` owns selected-entry or dependency-complete
  extraction, PSF closure, lazyUSF/TXTP preparation, LHA routing, cleanup, and
  cache-backed atomic materialization.
- `ArchiveManifestReader` owns temporary non-cache manifest reads with frontend-
  supplied extraction.
- `ArchiveCacheCore` owns stable source identity, durable/disposable roots,
  recovery, free-space and size policy, touching, bounded LRU pruning, and cache
  leases.

## Invariants

- Format requirements come from VGMBoy rather than a frontend registry.
- Archive tools are injected operations; executable discovery and presentation
  errors remain outside the shared policy.
- A warm cache hit is usable only when the requested playable member exists and
  is nonempty.
- Selected-entry and complete-set materialization remain distinct contracts.
- Scanner discovery, scanner resource policy, and catalog grouping remain in
  ScanSong.

## Concurrency

- Process completion, timeout, cancellation, pipe draining, permit release, and
  continuation resumption must each complete exactly once.
- Temporary sessions and cache leases must release the previous playable member
  before replacement.

## Files

- `Sources/ArchiveMaterializationCore/`
- `Sources/ArchiveCacheCore/`
- `Tests/ArchiveMaterializationCoreTests/`
- `Tests/ArchiveCacheCoreTests/`

