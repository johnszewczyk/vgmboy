# Project Info

## Product

UACMan is the VGMMan-owned native macOS browser/editor for `.uac` packages. It
browses filesystem collections from manifests and opens packages to inspect or
edit game metadata and every member, including assets and documents. Saves
preserve the seekable-Zstandard payload and original member bytes. The
collection view is a transient filesystem browser, not a cross-set media
database or playback frontend. MetaMan remains a CLI backed by MetaManCore;
UACMan is the UI for working with UAC manifests. AudioMan is a downstream
operator that invokes UACMan tools for its data workflow, not an owner or
runtime dependency.

## Components

- `Application/` contains the filesystem collection browser, WKWebView
  workspace, native file/open/save model, manifest editing, collection
  manifest scanner, and MetaManCore-backed directory metadata harvester.
- `Wrapper/` is the supported Swift reader/writer package and Python
  pack/inspect/unpack CLI for the reversible TAR+seekable-Zstandard envelope.
- `Container/README.md` records the closed SPC successor decision. No native
  SPC conversion, playback, or ingestion package is supported.
- `MetaManCore` owns native-format metadata reading. UACMan consumes its
  structured results and never rewrites native source-format tags.
- UAC metadata uses one shared vocabulary across all sets and consumers. Use
  the canonical field names and meanings in
  `subsystem-agent/uac-wrapper-format.md`; keep genuinely custom or
  format-specific fields in typed, namespaced `extensions` instead of adding
  aliases for an existing shared concept.
- AudioMan may impose set-specific requirements such as
  `member.metadata.sub-container-version` and mixed-version review. UACMan
  remains generic: it rejects `.vgz` members because the gzip wrapper harms
  the outer Zstandard compression, while leaving other format policy to the
  caller. Package-level `game.metadata.containedContainerVersions` is an
  optional inspection projection, not a UACMan validation gate.
- PNG scans, CUE sheets, notes, and other regular files are ordinary hashed
  members. Game metadata fields such as `cover_front`, `cover_back`, and
  `cue_sheet` reference those member paths; the current player boundary does
  not interpret external CUE indexes as virtual FLAC tracks.

## Task Routing

- Visible browser/editor behavior: `subsystem-human/metadata-browser.md`.
- Manifest editing and save invariants: `subsystem-agent/uac-editor.md`.
- Wrapper binary contract and reader/writer: `subsystem-agent/uac-wrapper-format.md`.
- Player and scanner consumer boundaries: `subsystem-agent/player-integration.md`.
- SNESMusic.org SPC metadata and four-hash profile: `../protocols/SNES-SPC.protocol.md`.
- PlayStation CD-XA preservation profile: `../protocols/PSX-CDXA.protocol.md`.
- Closed SPC research context: [Container/README.md](../Container/README.md).

## Local Rules

- ScanSong treats manifest metadata as authoritative and does not open UAC
  members to fill missing fields. Explicit UACMan harvesting is separate from
  catalog scanning.
- Collection browsing reads the UAC manifest and seek-table index through
  `UACWrapperCore`; it never decompresses or extracts TAR/audio payload data.
  The folder scan is in-memory and does not create another catalog.
- Metadata edits may replace manifest data only; compressed payload bytes and
  original member bytes remain unchanged.
- MetaManCore owns native SPC tag reading. UACMan does not write ID666/xID6
  back into SPC files.

## Human Docs

`README.md` describes the supported app surface and launch procedure.
