# UAC Metadata Editing

## Ownership

- `UACManCore` edits known JSON fields while retaining unmodeled keys in the
  original manifest document, performs selected-member batch edits across any
  member role, and
  projects MetaMan SPC results into game/member metadata.
- Package-wide tag renames and selected-track tag additions are core edit
  operations. They validate every destination before returning a new manifest,
  preserve unknown JSON, and report the number of affected records. Keep these
  mutations out of the WebView and app-model dictionary plumbing.
- `UACCollectionScanner` recursively enumerates regular `.uac` files beneath a
  selected folder and asks `UACWrapperCore` for each manifest. It is a
  transient browser index only: do not persist it as a second catalog, follow
  symlinks, or decompress/extract payloads for collection summaries.
- `UACTagAnalyzer` reuses collection path discovery, then reads each candidate
  package manifest once. It inventories keys in `game.metadata`,
  `game.extensions`, and every member's `metadata` and `extensions`; extension
  keys use the `extension.` namespace shown by the editor. It returns field
  names and per-scope occurrence counts, never metadata values. Unreadable
  paths/packages remain issues so the UI can label an incomplete result.
- `Application/Sources/UACManMetadataCLI` exposes the same
  `SPCMetadataHarvester` and
  `SPCMetadataProjector` for raw-directory creation-time import. It depends on
  MetaManCore; it must not add a second SPC parser.
- `Wrapper/UACWrapperCore` validates the supported wrapper and rewrites its
  envelope; it does not implement a native audio container.
- The app-local Zstandard CLI adapter only supplies bounded manifest encode and
  decode operations plus bounded seekable-frame decode/checksum validation; it
  does not own container semantics.
- `UACManWebWorkspace` hosts the bundled local WKWebView surface. Swift and
  `UACManModel` remain authoritative for package state, file access, prompts,
  validation, harvest, and writes. The page may filter/sort its current
  snapshot, but all mutations go through the named `uacman` script-message
  actions. Do not expose arbitrary file reads, shell commands, or network
  access to the page.
- MetaManCore owns native SPC tag reading. UACMan never writes ID666/xID6 into
  native SPC bytes.

## Invariants

- `CanonicalTable` is the shared div-based field-grid renderer and nested-fold
  owner. Give each unfold a hierarchical ID and render its child table through
  `rowWithUnfolds`; a child can contain further unfold rows at any depth. Keep
  multiple unfolds on one row in declared hierarchical order, open ancestors
  when a deeper fold is activated, and clear descendant fold state when a
  parent closes. Inserted unfold rows span one full-width grid track. Table
  column rules must target direct headers and data rows while excluding
  `.inserted-table-row`, or nested levels inherit the data columns and drift.
- Rewrites use the original payload offset and length and copy those compressed
  bytes directly. Never materialize the TAR/audio members to edit metadata.
- A rewrite writes to a new sibling file and is reopened/validated before the
  app atomically replaces the original. The writer refuses an existing
  destination.
- Keep unknown top-level, member, and extension JSON values through edits.
- Tag analysis scans manifests only and never changes packages. The matched
  field popup may explicitly update or remove one field; rewrite only the
  manifest and preserve all compressed payload bytes. Keep cancellation checks
  between directory entries and package reads; a cancelled run must not present
  its partial field set as exhaustive.
- Parent-level Tag Analyzer deletion targets playable-track occurrences of the
  exact field name in packages matched by the current filename filter. Group
  matches by archive and rewrite each manifest once, after verifying every
  stored value still matches the analysis snapshot. Report successful and
  failed packages so a partial collection update is visible.
- The package inspector lists and edits metadata for every manifest member.
  Only playable/track roles represent song rows in MetaMan and ScanSong;
  artwork, cue sheets, and documents remain inspectable package assets.
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
- Keep the WebView bridge main-frame-only and local-file-only. Treat all page
  input as untrusted, and keep destructive or source-changing decisions in the
  native model's existing confirmation and validation paths.
- Bound decoded manifest output by the declared size and the shared 16 MiB /
  32 MiB reader limits.
- Keep the new branded image on the UACMan application only via
  `CFBundleIconFile` and `UACManAppIcon.icns`. Leave the exported UAC type and
  `.uac` document type without custom icon keys so Launch Services supplies the
  system document icon. The PNG source and repeatable ICNS generator live in
  `Application/AppIcon/`; `Application/launch.sh` regenerates the app ICNS from
  the PNG before copying it into the app bundle's `Contents/Resources`.

## Files

- `Application/Sources/UACManCore/UACManifestEditor.swift`
- `Application/Sources/UACManCore/UACTagAnalyzer.swift`
- `Application/Tests/UACManCoreTests/UACManifestEditorTests.swift`
- `Application/Sources/UACManApp/UACManModel.swift`
- `Application/Sources/UACManApp/UACManWebWorkspace.swift`
- `Application/Sources/UACManApp/Resources/`
- `Application/Sources/UACManApp/ZstandardCLIManifestCodec.swift`
- `Application/Sources/UACManCore/SPCMetadataHarvester.swift`
- `Application/Sources/UACManCore/SPCMetadataProjection.swift`
- `Application/Resources/Info.plist`
- `Application/AppIcon/`
- `Application/launch.sh`
- `Application/Sources/UACManMetadataCLI/main.swift`
- `Wrapper/Sources/UACWrapperCore/UACContainerReader.swift`
- `Wrapper/Sources/UACWrapperCore/UACManifest.swift`
- `Wrapper/Sources/UACWrapperCore/UACManifestValidator.swift`
- `Wrapper/Sources/UACWrapperCore/UACSeekableFrameChecksum.swift`
- `Wrapper/Sources/UACWrapperCore/UACContainerWriter.swift`
