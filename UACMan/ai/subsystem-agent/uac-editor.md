# UAC Metadata Editing

## Ownership

- `UACManCore` edits known JSON fields while retaining unmodeled keys in the
  original manifest document, performs selected-member batch edits, and
  projects MetaMan SPC results into game/member metadata.
- `FrontendCore/UACContainerCore` validates the UAC and rewrites its envelope.
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
- Refuse to save if the package's file identity, modification stamp, size, or
  manifest digest changed since it was opened.
- Bound decoded manifest output by the declared size and the shared 16 MiB /
  32 MiB reader limits.

## Files

- `Sources/UACManCore/UACManifestEditor.swift`
- `Sources/UACManApp/UACManModel.swift`
- `Sources/UACManApp/ZstandardCLIManifestCodec.swift`
- `Sources/UACManApp/MetadataObjectEditor.swift`
- `Sources/UACManCore/SPCMetadataHarvester.swift`
- `Sources/UACManCore/SPCMetadataProjection.swift`
- `Sources/UACManCore/UACSeekableFrameChecksum.swift`
- `../../../FrontendCore/Sources/UACContainerCore/UACContainerReader.swift`
- `../../../FrontendCore/Sources/UACContainerCore/UACContainerWriter.swift`
