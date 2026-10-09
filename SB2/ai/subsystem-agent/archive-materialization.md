# Archive Materialization

## Ownership

- `SB2ArchiveMaterialization` adapts catalog-selected members to FrontendCore's
  cache-backed `ArchivePlaybackMaterializer`.
- `SB2UACManifestFrameCodec` is the SB2 host adapter for compressed UAC
  manifests. UACWrapperCore requires a decoder callback; it does not choose or
  launch a codec.

## Invariants

- Inject the bounded manifest decoder into playback, AAC export, and artwork
  materializers.
- Resolve Zstandard through `ArchiveMaterializerConfiguration` so manifest
  reads and payload extraction use the same executable candidates.
- Leave archive membership, path validation, cache policy, and extraction
  routing in FrontendCore and UACWrapperCore.

## Files

- `Sources/SB2/SB2ArchiveMaterialization.swift`
- `Sources/SB2/SB2UACManifestFrameCodec.swift`
