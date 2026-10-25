# Archive and Source Preparation

## Scope

VGMBoyArchiveCore prepares archive members and standalone compressed files for
the VGMBoy decoders. It is an in-process service used by VGMBoyKit playback and
finite AAC export; it has no catalog, queue, or UI policy.

## Ownership

- Frontends pass a direct path or the original archive path plus the selected
  member through the typed playback/export contract. They keep source/member
  identity for queue and presentation purposes.
- `VGMBoyFormatCore` and `VGMBoyKit.FormatRegistry` determine whether a
  selected entry needs extraction alone, a complete archive set, or a complete
  set with lazyUSF aliases.
- `ArchiveMaterializer.listEntries` owns bounded archive member discovery for
  local file-open workflows. UAC entries come from the validated manifest;
  other containers use the configured listing tools and shared parsers. A
  frontend filters those entries through `FormatRegistry` and retains the
  original source/member pair for playback.
- `VGMBoyArchiveCore.ArchiveMaterializer` validates the source and member,
  routes the required archive operation, prepares format dependencies, and
  holds the temporary result for the active playback session. AAC export uses
  the same preparation rules in an independent temporary session.
- UAC manifest, seek-table, and member-range validation remain in
  `UACWrapperCore`; `UACZstandardCLIFrameCodec` supplies bounded Zstandard
  frame decoding. Seekable UAC selected-member reads use only frames that
  intersect the requested member. Legacy sequential payloads and complete-set
  formats use the archive pipeline.
- `FrontendCore.ArchiveCacheCore` owns durable/disposable frontend cache roots,
  limits, leases, and eviction. Its archive adapters support cached browsing
  and artwork; they do not prepare VGMBoy playback or AAC inputs.
- The `vgmboy-prepare` executable is a narrow process bridge for hosts that
  cannot link `VGMBoyArchiveCore` in-process. It accepts the original archive
  path and selected member path, writes only prepared member bytes to stdout,
  and writes diagnostics to stderr. It uses the same `.selectedEntry`
  materialization path as native playback. The manual Ubuntu 24.04 workflow
  packages the x86_64 executable and required Swift libraries with a source
  revision. Selected ZIP bytes, traversal rejection and real hosted UAC byte
  parity are verified on Linux. MathBook stages the runtime outside app releases.

## Invariants

- A transport `load` with `archiveEntry` treats `path` as the archive source;
  VGMBoy validates and prepares the member before handing a normal playable
  path to a decoder. Hosts must not pre-extract playback members.
- Standalone `.zst` and `.zstd` files represent one compressed media source.
  TAR+Zstandard archive suffixes `.tar.zst`, `.tar.zstd`, and `.tzst` are not
  accepted as archive containers.
- Archive member paths are normalized and traversal is rejected before files
  are written. UAC membership is checked against the authoritative manifest.
- Amiga/UADE and other dependency-complete formats keep required siblings in
  the prepared set. PSF-family dependencies and lazyUSF/TXTP preparation stay
  in this shared engine rather than frontend bridges.
- Replacing or stopping a track releases its previous temporary source only
  after the decoder session no longer needs it. AAC export releases its own
  source after the offline render completes or fails.
- Archive-tool discovery/configuration is host-specific input to the shared
  engine. The engine owns command routing, bounded process execution, member
  safety, preparation, and error semantics.
- A foreign-host adapter must pass source/member identity to
  `vgmboy-prepare`; it must not implement its own archive or UAC extraction.
  Supply the target host's archive-tool paths explicitly. Package the runtime
  with `scripts/package-linux-prepare.sh` and verify selected-member bytes before
  replacing a production helper. Do not install a Swift toolchain on the player host.

## Failure Boundaries

- Missing tools, invalid members, malformed UAC metadata, empty output, and
  extraction failures are explicit preparation errors; the decoder is not
  asked to open an unprepared archive.
- Cancellation and replacement must not leave a partial source available as
  a completed session. The active materializer lease is released on stop,
  replacement, and natural completion.

## Files

- `Sources/VGMBoyArchiveCore/ArchiveMaterializer.swift`
- `Sources/VGMBoyArchiveCore/ArchiveToolRouting.swift`
- `Sources/VGMBoyArchiveCore/ArchiveProcessRunner.swift`
- `Sources/VGMBoyArchiveCore/ArchiveEntryPath.swift`
- `Sources/VGMBoyArchiveCore/UACSeekableMemberMaterializer.swift`
- `Sources/VGMBoyArchiveCore/UACZstandardCLIFrameCodec.swift`
- `Sources/VGMBoyPrepareCLI/main.swift`
- `Sources/VGMBoyKit/PlaybackController.swift`
- `Sources/VGMBoyKit/AACExport.swift`
- `Sources/VGMBoyKit/PlaybackControlProtocol.swift`
