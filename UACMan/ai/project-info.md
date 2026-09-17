# Project Info

## Product

UACMan is the native macOS browser/editor for `.uac` package manifests. It
keeps package and track metadata separate, supports scoped metadata edits, and
preserves the seekable-Zstandard payload and original member bytes when saving.

## Components

- `Application/` contains the browser/editor, manifest editing, and the
  MetaManCore-backed directory metadata harvester.
- `Wrapper/` is the supported Swift reader/writer package and Python
  pack/inspect/unpack CLI for the reversible TAR+seekable-Zstandard envelope.
- `Container/README.md` records the closed SPC successor decision. No native
  SPC conversion, playback, or ingestion package is supported.
- `MetaManCore` owns native-format metadata reading. UACMan consumes its
  structured results and never rewrites native source-format tags.

## Task Routing

- Visible browser/editor behavior: `subsystem-human/metadata-browser.md`.
- Manifest editing and save invariants: `subsystem-agent/uac-editor.md`.
- Wrapper binary contract and reader/writer: `subsystem-agent/uac-wrapper-format.md`.
- Player and scanner consumer boundaries: `subsystem-agent/player-integration.md`.
- Closed SPC research context: [Container/README.md](../Container/README.md).

## Local Rules

- ScanSong treats manifest metadata as authoritative and does not open UAC
  members to fill missing fields. Explicit UACMan harvesting is separate from
  catalog scanning.
- Metadata edits may replace manifest data only; compressed payload bytes and
  original member bytes remain unchanged.
- MetaManCore owns native SPC tag reading. UACMan does not write ID666/xID6
  back into SPC files.

## Human Docs

`README.md` describes the supported app surface and launch procedure.
