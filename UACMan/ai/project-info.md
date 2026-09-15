# UACMan agent routing

## Product

UACMan is the native macOS browser/editor for UAC package metadata.

## Major Components

- `UACManCore`: format-neutral JSON editing, SPC metadata projection/harvest,
  and seek-table checksum validation.
- `UACManApp`: SPC member browser/editor, batch metadata tools, and the app-local
  Zstandard command-line adapter.
- `MetaManCore`: read-only native format metadata extraction; UACMan consumes
  its SPC reader and never writes native SPC tag bytes.
- `FrontendCore/UACContainerCore`: UAC envelope validation and byte-preserving
  manifest rewrite.

## Task Routing

- Visible browser/editor behavior: `subsystem-human/metadata-browser.md`.
- Manifest editing and save invariants: `subsystem-agent/uac-editor.md`.
- Binary contract and shared reader/writer: `../../FrontendCore/ai/subsystem-agent/uac-format.md`.

## Local Rules

- Metadata edits do not change the compressed payload or original member bytes.
- Shared soundtrack facts live in `game.metadata`; track-specific projections,
  ordered native tags, parser diagnostics/facts, and raw-block byte counts live
  in `member.metadata`. The original native block bytes remain in the unchanged
  SPC member payload rather than being duplicated in the manifest.
- Import requires a seekable `tar+zstd-seekable` payload. It fills missing
  values by default and promotes only unanimous complete fields to the shared
  record; track-level projections are kept even when they agree.
- The Zstandard process adapter is a prototype host integration, not a
  bundled codec dependency.

## Human Docs

- `README.md` explains the current app surface and launch procedure.
