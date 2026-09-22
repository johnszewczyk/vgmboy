# Project Info

## Product

MetaMan provides direct, decoder-independent metadata readers for its
explicitly registered formats. Clients import `MetaManCore`; the `metaman`
executable is a thin JSON inspection client.

## Major Components

- `MetaManCore` owns native source parsing and ordered metadata documents.
- `MetaManZlib` supplies bounded gzip/zlib integration for applicable readers.
- `UACWrapperCore` supplies UAC framing and manifest validation as MetaMan's
  only local Swift-package dependency.
- The `metaman` command exposes single-document and ordered-track inspection.

## Task Routing

- Public result contract, source preservation, dependencies, and failure
  boundaries: [reader-boundary.md](subsystem-agent/reader-boundary.md).
- Exact supported formats, layouts, and reader bounds:
  [FORMAT-LAYOUTS.md](../FORMAT-LAYOUTS.md).
- Command-line behavior: [inspection.md](subsystem-human/inspection.md).
- ScanSong catalog projection and per-format routing:
  [format-accommodations.md](../../ScanSong/ai/subsystem-agent/format-accommodations.md).

## Local Rules

- A registered reader covers its known metadata structure from bounded source
  data; no hidden decoder or playback fallback belongs in MetaManCore.
- Preserve ordered duplicate tags, unknown fields, source bytes, and
  diagnostics where the format permits. Normalized fields are additive.
- Reading does not imply safe writing. Decoder comparisons belong in tests,
  not production readers. GYM is not an extraction target.
- A change to a field projected by ScanSong includes adapter and compatibility
  checks there.

## Human Docs

- [Inspection](subsystem-human/inspection.md) describes the CLI.
- [FORMAT-LAYOUTS.md](../FORMAT-LAYOUTS.md) is the format fact map.
