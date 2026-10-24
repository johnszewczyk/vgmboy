# Archive Materialization

## Ownership

- SB2 sends VGMBoy the source path and optional archive member. VGMBoy owns
  validation, extraction, dependency preparation, UAC decompression, and the
  temporary playback/export source lifetime.
- `SB2ArchiveMaterialization` remains only for Gallery artwork and cache
  management. It uses VGMBoy's shared `UACZstandardCLIFrameCodec`.

## Invariants

- The browser bridge must pass `archivePath` and `archiveEntry` through the
  typed transport request and must not call a frontend playback materializer.
- Gallery cache policy remains SB2-owned; archive parsing and decompression
  mechanics come from VGMBoy.

## Files

- `Sources/SB2/SB2ArchiveMaterialization.swift`
