# VGMMan Shared-Core State

## Objective

CocoaSpice and SPCBoyWK are thin presentation clients. Reusable catalog,
archive, preference, queue, timing, transport, decoder, and audio behavior has
one Swift owner and is consumed by both apps.

## Current ownership

| Concern | Owner |
| --- | --- |
| Catalog writing and inspection | ScanSong |
| Decoder-independent metadata reading | MetaMan; ScanSong adapts results to schema 23 |
| Read-only catalog queries and browser projections | CatalogReader |
| Decoder routing, timing, output, and playback session | VGMBoy |
| Archive materialization, cache, preferences, favorites, queue, and frontend-neutral transport policy | FrontendCore |
| Native AppKit/SwiftUI rendering and controls | CocoaSpice |
| WebKit rendering, DOM interaction, and typed host adaptation | SPCBoyWK |

SPCBoyWK receives shared projections and typed bridge contracts. It does not
perform independent catalog queries, archive preparation, decoder control,
timing calculation, or transport policy.

## Current guarantees

- Catalog rows retain shared natural order until an explicit user sort.
- A selected track starts at `0:00`; changing a sidebar source or playlist
  leaves no residual row selection or transport position.
- Selection presentation is local to each renderer; it does not alter text
  color or create a second selection model.
- Queue transitions, timing/tempo, audio configuration, seek/ramp, and queued
  fade inputs use named shared contracts.
- Preferences are normalized by FrontendCore; renderers own only their local
  storage/adaptation and visual presentation.
- `FrontendPlaylistColumnSizing` now carries the common eight-point-per-side
  header minimum padding through the CocoaSpice AppKit adapter and the
  SPCBoyWK typed settings snapshot; font measurement and native width units
  remain renderer-local.

## Open verification gates

MetaMan is the shared decoder-independent metadata boundary. It now has
complete readers for AY, SAP, NSF, GBS, NSFE, HES, SNDH, KSS/KSSX, Sony XA,
GSF/miniGSF, QSF/miniQSF, S98, VGM/VGZ, the PSF-style
PSF/PSF2/SSF/USF/2SF family, SPC, SID, APE, CRI/Monster ADX, Atomic Planet
AUS, RIFF ATRAC3/ATRAC3+,
Sony MSF, and Konami/SNK SVAG. The per-format byte layouts, pointer bases,
chunk boundaries, and stream walks are documented in `MetaMan/FORMAT-LAYOUTS.md`.
ADX, AUS, ATRAC3, MSF, and SVAG retain their existing
catalog projections while adding native source facts and named raw blocks.
Recognized inputs are read without playback decoding; nonmatching aliases
retain vgmstream. These are reader-ownership moves, not playback-decoder
removals: ScanSong still needs vgmstream for other formats and aliases. Keep
GYM out of scope.

Remaining metadata-reader targets are grouped by the boundary they need:

- **Single-track readers:** Sony MSF and Konami/SNK SVAG are complete in
  MetaManCore. MSF matches all 799 root-1 rows/files in four archives against
  the saved catalog and vgmstream. SVAG matches all 284 root-1 rows/files in
  eight archives against the saved catalog, the former in-process ScanSong
  reader, and vgmstream; every live entry uses the Konami layout, while SNK
  `VAGm` is covered by fixtures. The same-run Release means were 0.155 ms/file
  through MetaMan plus the adapter, 0.056 ms/file through the former reader,
  and 236.895 ms/file through vgmstream CLI, including process startup. The
  richer neutral document adds about 0.099 ms/file over the former parser.
  The MetaMan Debug suite passes all 99 tests. ScanSongKit builds, and all 124
  ScanSong test cases pass from a test-only package harness. The ordinary
  `swift test --package-path ScanSong` command still fails while SwiftPM links
  the standalone `ScanSong` and `scansong` executables (`_ScanSongApp_main` /
  `_scansong_main` unresolved); this is separate from the scanner library and
  harness test results. VGMBoy's focused format-data suite has previously
  passed; its corpus comparison remains fixture-gated. The single-track
  direct-reader set is complete for the formats currently claimed by MetaMan.
- **Track-aware result contract:** MetaMan defines an ordered
  `MetadataReadResult` of `MetadataTrack` documents with optional native
  source indices; list order is authoritative and repeated indices remain
  distinct. AY and SAP are complete full multi-track extractions: MetaMan owns
  their direct readers, ScanSong consumes the shared ordered result, and the
  single-document API rejects either format instead of flattening subtunes.
  SAP retains its bounded CR/LF header, ordered/unknown directives, per-track
  TIME facts, and the prior catalog timing projection. The duplicate
  `VGMBoyFormatDataCore` SAP reader is removed; VGMBoy retains SAP playback.
  NSF/GBS/NSFE now join the ordered result contract. Their fixed-header and
  chunk readers live in MetaMan; ScanSong adapts the ordered documents, and
  the duplicate NSF/GBS/NSFE reader sources/tests have been removed from
  `VGMBoyFormatDataCore`. HES/M3U has also moved in full: MetaMan owns the HES
  header, bounded playlist parsing, ordered rows, native slot indices, and
  timing; ScanSong is only the compatibility/catalog adapter. SNDH, KSS/KSSX,
  and Sony XA have now also moved completely into MetaMan. Their scanner paths
  only adapt ordered documents into schema 23; the prior SNDH oracle remains
  test-only, and the playback engines remain in VGMBoy.
  A read-only Release comparison of the MetaMan documents mapped to ScanSong's
  catalog fields matched all 66 live archive members and 1,418 root-1 rows:
  12,762 exact fields, 1,418 comment enrichments, 1,418 authored-fade
  enrichments, and zero mismatches. Parsing averaged 0.313 ms/member, excluding
  archive extraction; this is a measurement, not a speedup claim, because the
  old in-process reader was not benchmarked in the same run. The production
  ScanSongKit target builds. HES live parity against the CocoaSpice root-1
  catalog extracted 291/291 archives and compared 294 source files / 4,925
  tracks: all 44,325 title, identity, comment, and timing fields matched with
  zero mismatches. The HES route preserves the sibling-M3U track map and the
  no-playlist compatibility listing. A paired 101-pass info-only benchmark
  on the public ZXTune Raiden HES sample with a synthetic three-row M3U measured
  0.456 ms for ScanSong/MetaMan versus 0.057 ms for libgme (~8.0x slower, both
  still sub-millisecond). Since the former ScanSong route used the Swift
  `HESFormatDataReader`, not libgme, this is a format-reference measurement,
  not a like-for-like regression or a 1:1 parity claim; compare against the
  pre-extraction reader before drawing that conclusion. ScanSong's
  executable-product link
  failure is no longer current: the full ScanSong package test target links
  and passes. SNDH's full root-26 comparison covered 5,897 files and 11,758
  tracks with 94,064 exact text-field checks and zero mismatches; that corpus
  contained no ICE-compressed sources, so ICE behavior is covered separately
  by a synthetic fixture against PSGPlay and the production scanner route.
  The paired 256-track SNDH benchmark measured 27.435 ms for MetaMan parsing
  versus 12.077 ms for the former parser; the full scanner projections measured
  33.783 ms versus 26.525 ms. The extraction preserves data but is not a 1:1
  speed claim; its absolute additional parse cost is about 15 ms per file for
  that unusually track-heavy sample.
  KSS root-1 live parity covered 368 archives and 94,208 rows with zero
  mismatches. Its same-file paired Release benchmark measured 0.113667 ms for
  MetaMan plus the scanner adapter versus 0.027875 ms for the former inspector
  (0.085792 ms additional per file; not 1:1 timing).
  Sony XA now uses the same complete-reader boundary. Its root-1 production
  route matches all 867 saved rows in 827 files across 18 archives; the latest
  route mean was 0.716 ms/file. Unrelated XA aliases still route to vgmstream.
  This corpus run was kept separate from the full package suite because it
  temporarily starves a timeout-sensitive subprocess test when run concurrently.
  SAP's synthetic scanner projection passes in both Debug and Release. The
  pre-cutover 6,335-file ASMA comparison is documented, but post-cutover corpus parity is not
  verified because `SCANSONG_SAP_FIXTURE_DIR` is unset. The AY corpus test is
  likewise fixture-gated. All current direct multi-track readers—AY, SAP, NSF,
  GBS, NSFE, HES, SNDH, KSS, and XA—now live in MetaMan.
- **GSF/miniGSF complete reader:** moved into MetaManCore as one unit: PSF
  v0x22 bounds, CRC/zlib validation, ordered/unknown/repeated tags, declared
  PSFLib chains, GBA executable-segment assembly and image-header checks, and
  the existing timing/catalog projection. ScanSong now only routes and adapts
  the document; mGBA remains playback-only. New MetaMan contract tests and the
  GSF scanner-route test pass; the complete 124-test ScanSong suite also passes
  in the test-only harness. Live root-1 catalog parity and paired Release
  timing remain unverified because `SCANSONG_GSF_LIVE_DB` is unset; run those
  before claiming corpus-level parity or 1:1 performance.
- **QSF/miniQSF complete reader:** moved the entire PSF v0x41 container,
  CRC/zlib validation, QSound block bounds, ordered root tags/timing, and
  declared QSFLib validation into MetaManCore. ScanSong now only routes and
  projects the neutral document; VGMBoy retains QSF playback. The MetaMan
  Debug suite passes all 99 tests, and production ScanSongKit plus all scanner
  test sources pass in an isolated harness that excludes app/CLI executables
  (124 tests).
  Read-only root-1 parity after the final parser change covered 18 archives /
  720 rows: 7,920 exact field checks, zero improvements, zero mismatches. One
  previously failed `vsav04.miniqsf` is structurally readable by MetaMan; the
  saved catalog is unchanged. A paired Release benchmark against the former
  in-process reader has not yet been run, so do not claim 1:1 performance. The
  new file-URL reader parses the root once before resolving dependencies;
  this avoids a double parse present in its initial implementation, not in the
  former ScanSong reader.
- **Standard audio extraction — complete:** moved ScanSong's complete existing
  `standard-audio` reader into MetaManCore's file-URL API for `.aif`, `.aiff`,
  `.flac`, `.m4a`, `.mp3`, `.ogg`, and `.wav`. The reader preserves AVFoundation
  common-tag and exact decoded-frame duration behavior; FLAC comment order,
  duplicates, unknown keys, and source comment bytes are now retained. ScanSong
  owns only route selection and schema-23 projection. This removes the last
  ordinary-audio metadata implementation from ScanSong, but AVFoundation
  remains an OS framework dependency; it does not remove or replace a playback
  plugin. The ScanSong target no longer declares AVFoundation as a direct
  linker dependency. Verification: all 145 MetaMan tests passed; all 148 ScanSongKit tests
  passed under a temporary test-only manifest that excluded the known failing
  ScanSongApp link target. The read-only CocoaSpice catalog check compared all
  1,471 rows in 127 source archives against both MetaMan and a frozen test-only
  copy of the former ScanSong reader: zero mismatches. Warmed, alternating-order
  means were 1.571 ms/file for MetaMan and 1.560 ms/file for the old reader
  (0.7% slower, within this single-run measurement noise). The temporary
  ScanSongApp exclusion was reverted; the production app target remains in the
  package. Only ScanSongKit's obsolete direct AVFoundation linker entry was
  intentionally removed.
- **Next scope:** keep this extraction pass limited to readers that already
  existed inside ScanSong and can move completely into MetaMan. Do not start
  new vgmstream format implementations or cut over decoder-backed routes as a
  side effect of this migration. Preserve those routes until a separate
  complete-reader plan is explicitly selected.
- **Still decoder/inspector-backed:** The remaining vgmstream format set,
  MDX, and UADE/Amiga require format-specific full-reader feasibility work;
  OpenMPT currently contributes only an optional/deferred scanner row. Do not
  replace these with partial tag readers. GYM remains excluded.

MetaMan is included in the VGMMan family repository and consumed by ScanSong as
a sibling path dependency. Family clients can now share the same source and
release state; a separately published Swift package is only needed if an
external client requires an independent package distribution.

Remaining family playback work is fixture coverage:

- real archive fixtures for RE2/AAC transport, Doom transitions, and Amiga LHA;
- packaged seek, fade interruption, natural completion, repeat, and non-VGM
  playback interactions;
- repeatable packaged WebKit row/toolbar automation.

The current evidence and its limits live in `PARITY-WIP-REPORT.md`. Run
`scripts/verify-family.sh` for a new family check; do not append run histories
to this document.

## GitHub backup status

The local VGMMan checkout is the single source tree for MetaMan, ScanSong,
VGMBoy, CocoaSpice, SPCBoyWK, and shared clients; `origin` is
`johnszewczyk/vgmboy`. Keep family changes in this repository, push by normal
fast-forward, and verify remote `main` matches local `HEAD` after each backup.
The three old public component repositories—`CocoaSpice`, `scansong`, and
`spcboy`—still exist and are confirmed unarchived; they have not been deleted.
The GitHub browser session is signed out and the authenticated connector has no
repository-settings/archive write operation. Once an authenticated settings
path is available, archive these superseded repos (reversible) and verify the
archived state; do not delete them.

## Contribution rule

Before adding behavior to either frontend, place it in the narrow existing
shared owner or create a narrow shared module. Keep rendering, focus, scrolling,
window management, and accessibility adaptation frontend-local. Update the
owning subsystem note and the current parity ledger when the boundary changes.
