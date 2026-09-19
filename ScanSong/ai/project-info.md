# Project Info

## Product

ScanSong is the native catalog-management app and command-line scanner for the
VGMMan library. Its `ScanSongKit` package discovers source files, inspects
supported formats, and writes schema-23 catalogs read by CocoaSpice, SPCBoyWK,
and ViewBoy.

## Ownership

- `ScanSongKit` owns source discovery, safe archive handling, reader routing,
  resumable scan state, schema-23 projection, and catalog publication.
- `MetaManCore` owns decoder-independent format metadata interpretation.
  ScanSong adapts MetaMan's ordered documents and does not duplicate those
  parsers. SAP headers and per-song TIME hints come from MetaMan; ScanSong
  projects those bounded song documents to catalog rows. MOD and MDX title/module
  fields come from MetaMan; ScanSong's
  VGMBoy helper remains responsible for MDX playback/dependency validation,
  and returns no metadata or timing. Uncompressed MDX sequence timing comes from
  MetaMan; LZX-compressed bodies currently have no MetaMan duration.
  Recognized 31-sample ProTracker-family MOD headers
  use MetaMan; other OpenMPT-family modules remain structure-only until
  MetaMan has complete bounded readers for them. See the per-format matrix
  before describing ScanSong as a MetaMan-only reader.
- VGMBoy owns decoder products and scanner inspection executables. ScanSong
  packages the registered scanner helpers into its app bundle.
- `scansong` owns the versioned JSONL command-line boundary. `ScanSongApp`
  owns catalog selection, attached scan paths, progress, and per-path result
  logs.
- The catalog writer is exclusive to ScanSong. Player apps use query-only
  catalog connections.

## Important Contracts

- For UAC, MetaMan reads the package manifest and playable-member or explicitly
  mapped subsong documents. ScanSong may decode the bounded compressed JSON
  manifest frame, but never opens, hashes, extracts, or decompresses the
  TAR/audio payload during a catalog scan. Manifest fields are authoritative;
  missing values remain blank/default rather than being filled from enclosed
  native metadata.
- A scan checkpoint represents a complete loose source or physical archive.
  Partial archive results are not resumable or published. Failed refreshes
  retain last-known-good playable rows and remain eligible for retry.
- Cancellation preserves completed source checkpoints and waits for owned
  child processes to finish. Catalog publication and link maintenance remain
  transactional.
- File-type policy controls admission; it is not a corruption filter. A
  malformed supported source remains a diagnostic instead of disappearing.

## Task Routing

- Scanner ownership, persistence, concurrency, and process boundaries:
  [scanner-contract.md](subsystem-agent/scanner-contract.md)
- Per-format routes, archive behavior, and decoder coverage:
  [format-accommodations.md](subsystem-agent/format-accommodations.md)
- Build, helper packaging, and launch integration:
  [build-integration.md](subsystem-agent/build-integration.md)
- Command-line behavior:
  [cli.md](subsystem-human/cli.md)
- Native catalog-management behavior:
  [catalog-management.md](subsystem-human/catalog-management.md)

## Local Rules

- Keep format-specific reader facts in `format-accommodations.md`; this file
  records product ownership and stable cross-format contracts only.
- Human documents describe visible behavior. Agent documents describe code
  ownership, invariants, and failure boundaries.
- Verification claims belong in the family-level `verification.md` and must
  distinguish package tests, packaged UI, and live-fixture evidence.
