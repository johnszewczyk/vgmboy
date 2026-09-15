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
complete readers for AY, SAP, S98, VGM/VGZ, the PSF-style PSF/PSF2/SSF/USF/2SF
family, SPC, SID, APE, CRI/Monster ADX, Atomic Planet AUS, RIFF ATRAC3/ATRAC3+,
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
  MetaMan Debug and Release suites each pass 66 tests; ScanSong Debug and
  Release suites each pass 113 tests, with fixture-gated checks skipped when
  their inputs are unavailable. VGMBoy's focused format-data suite passes 7
  tests; six focused VGMBoy format-data tests pass, while its NSFE corpus test
  is fixture-gated. No further single-track reader is currently queued; the
  next boundary is the track-aware
  result contract.
- **Track-aware result contract:** MetaMan defines an ordered
  `MetadataReadResult` of `MetadataTrack` documents with optional native
  source indices; list order is authoritative and repeated indices remain
  distinct. AY and SAP are complete full multi-track extractions: MetaMan owns
  their direct readers, ScanSong consumes the shared ordered result, and the
  single-document API rejects either format instead of flattening subtunes.
  SAP retains its bounded CR/LF header, ordered/unknown directives, per-track
  TIME facts, and the prior catalog timing projection. The duplicate
  `VGMBoyFormatDataCore` SAP reader is removed; VGMBoy retains SAP playback.
  SAP's synthetic scanner projection passes in both Debug and Release. The
  pre-cutover 6,335-file ASMA comparison is documented, but post-cutover corpus parity is not
  verified because `SCANSONG_SAP_FIXTURE_DIR` is unset. The AY corpus test is
  likewise fixture-gated. Remaining multi-track candidates are NSF/GBS/NSFE,
  HES, SNDH, KSS, and XA; NSF/GBS/NSFE are next for fixed-header/chunk-layout
  review and complete projection comparison before moving their reader.
  GSF/QSF dependency-aware results need a bounded source/dependency context
  before their full readers can move.
- **Dependency-aware direct readers:** GSF/miniGSF and QSF/miniQSF already
  avoid playback cores but validate companion libraries and container blocks.
  A future MetaMan API must accept a bounded source/dependency context; do not
  move only their tag parsing.
- **Audio containers:** Core Audio is currently the scanner's native
  standard-audio reader. Treat it as a separate platform-boundary decision,
  not as a playback-plugin removal.
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

## Contribution rule

Before adding behavior to either frontend, place it in the narrow existing
shared owner or create a narrow shared module. Keep rendering, focus, scrolling,
window management, and accessibility adaptation frontend-local. Update the
owning subsystem note and the current parity ledger when the boundary changes.
