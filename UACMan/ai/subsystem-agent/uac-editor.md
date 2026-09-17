# UAC Metadata Editing

## Ownership

- `UACManCore` edits known JSON fields while retaining unmodeled keys in the
  original manifest document, performs selected-member batch edits, and
  projects MetaMan SPC results into game/member metadata.
- `Application/Sources/UACManMetadataCLI` exposes the same
  `SPCMetadataHarvester` and
  `SPCMetadataProjector` for raw-directory creation-time import. It depends on
  MetaManCore; it must not add a second SPC parser.
- `Wrapper/UACWrapperCore` validates the supported wrapper and rewrites its
  envelope; it does not implement a native audio container.
- The app-local Zstandard CLI adapter only supplies bounded manifest encode and
  decode operations plus bounded seekable-frame decode/checksum validation; it
  does not own container semantics.
- MetaManCore owns native SPC tag reading. UACMan never writes ID666/xID6 into
  native SPC bytes.

## Invariants

- Rewrites use the original payload offset and length and copy those compressed
  bytes directly. Never materialize the TAR/audio members to edit metadata.
- A rewrite writes to a new sibling file and is reopened/validated before the
  app atomically replaces the original. The writer refuses an existing
  destination.
- Keep unknown top-level, member, and extension JSON values through edits.
- Batch operations must be path-scoped to the explicit member selection. Fill
  missing is the default import behavior; replacement requires explicit user
  action and remains reversible until Save.
- Store ordered native tags, parser facts/diagnostics, and raw-block byte counts
  on the member whose SPC was read. Do not duplicate raw ID666/xID6 bytes in
  manifest JSON; those remain in the immutable SPC member payload. Promote
  shared game/soundtrack fields only when every successfully inspected member
  provides the same non-empty value; keep normalized per-track values too.
- Native SPC harvesting is currently limited to seekable
  `tar+zstd-seekable` payloads. Use `UACSeekableMemberFile` and validate the
  seek-table frame checksum; do not extract members to edit manifest metadata.
- Creation-time SPC harvesting reads bounded raw members from the staged input
  directory before packing. A failed or partial read must abort publication of
  the UAC; imported fields fill missing recipe values and never rewrite SPC
  bytes. Shared values are promoted only when all successfully read members
  agree, and failures/diagnostics remain visible to the caller.
- Refuse to save if the package's file identity, modification stamp, size, or
  manifest digest changed since it was opened.
- Bound decoded manifest output by the declared size and the shared 16 MiB /
  32 MiB reader limits.

## Files

- `Application/Sources/UACManCore/UACManifestEditor.swift`
- `Application/Sources/UACManApp/UACManModel.swift`
- `Application/Sources/UACManApp/ZstandardCLIManifestCodec.swift`
- `Application/Sources/UACManApp/MetadataObjectEditor.swift`
- `Application/Sources/UACManCore/SPCMetadataHarvester.swift`
- `Application/Sources/UACManCore/SPCMetadataProjection.swift`
- `Application/Sources/UACManMetadataCLI/main.swift`
- `Wrapper/Sources/UACWrapperCore/UACContainerReader.swift`
- `Wrapper/Sources/UACWrapperCore/UACSeekableFrameChecksum.swift`
- `Wrapper/Sources/UACWrapperCore/UACContainerWriter.swift`
