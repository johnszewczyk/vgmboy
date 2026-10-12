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
- `TitleSnapArtworkReader` is the shared safe PNG boundary for Gallery previews.
  The frontend injects a Gallery-isolated materializer and owns thumbnail
  decoding, cache sizing, and presentation.
- `ArchiveManifestReader` owns temporary non-cache manifest reads with frontend-
  supplied extraction.
- `ArchiveMaterializationCore` consumes `UACWrapperCore`, owned by
  `UACMan/Wrapper`, to validate the wrapper manifest and route members for
  playback. FrontendCore does not own UAC encoding or package creation.
- `UACZstandardCLIFrameCodec` adapts the host-installed Zstandard executable
  to UAC's bounded manifest and independent-frame decoder callbacks. It does
  not bundle a codec; callers may inject alternate decoders for testing or a
  host-specific executable configuration.
- Both `ArchiveMaterializer` and `ArchivePlaybackMaterializer` use
  `UACSeekableMemberFile` for a selected member in `tar+zstd-seekable`
  packages, then stage only that member in bounded chunks. The seekable reader
  decompresses only TAR frames intersecting the member's byte range. Legacy
  `tar+zstd` packages and dependency-complete requests retain the sequential
  extraction route.
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
- UAC member paths are manifest-relative archive paths, never filesystem
  locations; invalid manifests must not fall back to another container route.
- The seek-table parser rejects compressed frames larger than 65 MiB and TAR
  frames larger than 64 MiB before allocating frame data. CLI decoding enforces
  the same 64 MiB stdout bound while the child process is running.
- Loose `.tar.zst`, `.tar.zstd`, and `.tzst` source archives are retired and
  must not return to archive routing. Standalone media `.zst`/`.zstd` files
  remain single-file wrappers, and UAC's internal TAR+Zstandard payload stays
  behind the UAC manifest boundary.
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
