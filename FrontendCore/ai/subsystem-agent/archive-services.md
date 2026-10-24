# Archive Services

## Scope

Frontend archive caching, artwork reads, and catalog-facing adapters. VGMBoy
playback and export source preparation lives in VGMBoyArchiveCore.

## Ownership

- `ArchiveCacheCore` owns stable source identity, durable/disposable roots,
  recovery, free-space and size policy, touching, bounded LRU pruning, and cache
  leases.
- FrontendCore's `ArchiveMaterializationCore` adapts VGMBoyArchiveCore to
  cache-backed artwork and frontend cache preferences. Its cached-artwork
  adapter may materialize an image copy, but it is not the playback or AAC
  export source path.
- `TitleSnapArtworkReader` is the shared safe PNG boundary for Gallery previews.
  The frontend injects a Gallery-isolated materializer and owns thumbnail
  decoding, cache sizing, and presentation.
- `VGMBoyArchiveCore` owns bounded archive listing/process execution, path
  validation, archive-tool routing, selected-entry and dependency-complete
  preparation, PSF closure, lazyUSF/TXTP preparation, and UAC frame decoding.
  VGMBoyKit invokes it with the original archive/member for playback and AAC.
- `UACZstandardCLIFrameCodec` is the single bounded adapter from UAC's frame
  callbacks to the host Zstandard executable. Frontend artwork adapters may
  inject it into VGMBoyArchiveCore; no frontend ships a separate manifest
  decompressor.
- `ArchiveMaterializer` uses `UACSeekableMemberFile` for selected members in
  `tar+zstd-seekable` packages, staging only intersecting frames when possible.
  Legacy `tar+zstd` packages and dependency-complete requests retain the
  sequential extraction route.

## Invariants

- Format requirements come from VGMBoy rather than a frontend registry.
- Playback/export load requests supply either a direct file or the original
  archive path and selected member. VGMBoy prepares the source before the
  decoder sees it.
- Frontend cache settings may affect artwork/cache-backed browsing only; they
  cannot change VGMBoy's temporary playback source preparation or decoder
  dependency policy.
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
- The playback controller holds one temporary source lease per active session
  and releases it on replacement or stop. Cache leases remain separate.

## Files

- `Sources/ArchiveMaterializationCore/`
- `Sources/ArchiveCacheCore/`
- `Tests/ArchiveMaterializationCoreTests/`
- `Tests/ArchiveCacheCoreTests/`
- VGMBoy owns the engine under `VGMBoy/Sources/VGMBoyArchiveCore/`.
