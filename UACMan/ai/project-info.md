# UACMan

## Product

UACMan is the native macOS browser/editor for UAC package metadata.

## Major Components

- `Application/`: `UACManApp`, metadata editing/projection, and the
  MetaMan-backed creation-time metadata CLI.
- `Wrapper/`: an independent Swift package for current `.uac`
  TAR+seekable-Zstandard wrapper reading/writing, plus the Python
  pack/inspect/unpack tool and wrapper tests.
- `Container/`: reserved for a future native audio container; no native
  replacement format is implemented here yet.
- `MetaManCore`: read-only native format metadata extraction; UACMan consumes
  its SPC reader and never writes native SPC tag bytes.

## Task Routing

- Visible browser/editor behavior: `subsystem-human/metadata-browser.md`.
- Manifest editing and save invariants: `subsystem-agent/uac-editor.md`.
- Current wrapper binary contract and reader/writer:
  `subsystem-agent/uac-wrapper-format.md`.
- Player and scanner consumer boundaries:
  `subsystem-agent/player-integration.md`.

## Local Rules

- ScanSong treats the UAC manifest as authoritative and does not open enclosed
  native files to fill missing fields. Native SPC harvesting is an explicit
  UACMan creation/editor action through MetaManCore, not a catalog fallback.
- Metadata edits do not change the compressed payload or original member bytes.
- MetaManCore owns native SPC tag reading; UACMan does not rewrite native
  source-format tag bytes.

## Human Docs

- `README.md` explains the current app surface and launch procedure.
