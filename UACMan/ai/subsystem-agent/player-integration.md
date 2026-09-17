# UAC Consumer Integration

## Scope

UACMan owns the package format. This note defines consumer boundaries only;
[`uac-wrapper-format.md`](uac-wrapper-format.md) is the authoritative binary
and manifest contract.

## Ownership

- `UACMan/Wrapper` owns manifest and seek-table parsing, validation, and the
  shared member reader.
- ScanSong owns catalog publication. It passes `.uac` file URLs to
  `MetaManCore.readResult`, projects the returned member documents to schema
  23, and uses the declared member hash for member identity.
- FrontendCore owns shared path-based archive materialization and cache policy;
  it consumes `UACWrapperCore` but does not implement UAC parsing.
- CocoaSpice owns UAC playback adaptation. For SPC playback it passes a
  seekable UAC member to the in-memory decoder path; formats requiring a file
  path use FrontendCore materialization.
- VGMBoy owns decoder admission and playback behavior. AudioMan owns `/audio`
  source selection and package recipes, not UAC implementation.

## Invariants

- Treat the UAC manifest as authoritative during catalog scans. Do not unpack
  members or parse enclosed native tags to fill absent UAC metadata. An
  explicit UACMan harvest/edit operation may request SPC reading through
  MetaManCore.
- `MetaManCore` owns UAC package/member metadata documents and uses
  `UACWrapperCore` for framing, manifest, and seek-table parsing. Other
  consumers may use `UACWrapperCore` for container operations; do not fork UAC
  parsing in ScanSong, FrontendCore, or players.
- Seekable SPC playback reads only the frames intersecting the selected member
  and does not write the decompressed SPC to a playback cache.
- Path-based playback remains materialized through FrontendCore when a decoder
  cannot accept an in-memory member. Do not treat path materialization as
  permission for catalog scanning to inspect native tags.
- Full payload/member hashing is explicit verification work, not an implicit
  metadata-enrichment step during catalog scanning.

## Failure Boundaries

- Reject malformed or unsupported UAC packages; never reinterpret an invalid
  `.uac` as TAR, ZIP, or standalone audio.
- Compressed manifest and member-frame decoding must use bounded host-supplied
  Zstandard adapters. The format core owns bounds and validation, not the codec
  process lifecycle.
- If the selected decoder requires a filesystem path, use the existing shared
  materialization route. Do not add another archive extractor to a frontend.

## Files

- `UACMan/Wrapper/Sources/UACWrapperCore/UACContainerReader.swift`
- `ScanSong/Sources/ScanSongKit/CatalogScanner.swift`
- `ScanSong/Sources/ScanSongKit/UACCatalogMetadataAdapter.swift`
- `ScanSong/Tests/ScanSongKitTests/ScanSongContractTests.swift`
- `FrontendCore/Sources/ArchiveMaterializationCore/ArchivePlaybackMaterializer.swift`
- `CocoaSpice/Sources/CocoaSpice/App/ZipArchiveSupport.swift`
- `CocoaSpice/Sources/CocoaSpice/App/VGMBoyPlaybackEngine.swift`
