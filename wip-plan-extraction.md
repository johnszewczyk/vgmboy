# VGMMan Shared-Core Extraction Plan

Status: active WIP — the major shared boundaries are in place; the remaining
work is frontend transition parity, adoption cleanup, and live verification.
Date: 2026-08-29

Latest bounded slice (2026-08-28): `PlaybackTransportStatusPayload` now owns
the JSON projection shared by SPCBoyWK playback command replies and native
status/end broadcasts. This prevents elapsed-position and diagnostic fields
from drifting between the two WebKit paths; the native transport remains the
position authority.

Latest bounded slice (2026-08-29): `CatalogReader` now detects ScanSong's dirty
sidebar projections and derives Games/Files buckets from visible tracks until
ScanSong republishes them. Both frontends therefore share the same in-scan
fallback instead of maintaining separate database-query workarounds.

Live packaged verification snapshot (2026-08-29): a fresh production build of
SPCBoyWK launched from `.build/SPCBoy (WK).app` and opened the shared ScanSong
catalog. Filtering to Cyberbots exposed all 53 archive-backed tracks with
native lengths, including the 0:02 `Credit` and `You Face A New Challenger`
fixtures. Selection and playlist hydration were visible in the real WebKit
window. Natural-end/repeat behavior remains unclaimed: the live CUA session
could not dispatch the Long Play toolbar/settings click reliably, so it did
not falsify the five-minute manual timing cap. The existing transport tests
remain the evidence for stale-completion protection until that UI gate is
repeatable.

## Objective

Keep CocoaSpice and SPCBoyWK as thin frontends over one tested native machinery
set. CocoaSpice remains the behavior reference during extraction. Frontends may
retain AppKit/SwiftUI/WebKit construction, DOM/AppKit rendering, event capture,
and thin typed adapters, but must not own codecs, SQLite query policy, archive
expansion policy, playback queue state, timing/fade policy, or preference
semantics.

## Current state

- [x] Both apps link the shared catalog, archive, favorites, identity,
  preferences, queue, transport, and VGMBoy packages.
- [x] Decoder and audio-output ownership remains in VGMBoy/native Swift.
- [x] Catalog/sidebar session generations are shared.
- [x] Queue target calculations and transport continuation claims are shared.
- [x] CocoaSpice's newest-request lifecycle and one-shot completion claim now
  run through `PlaybackSessionLifecycleCoordinator` in `PlaybackQueueCore`;
  its local adapter retains only `TrackItem` and presentation state.
- [x] CocoaSpice uses the extracted native transport coordinator.
- [x] SPCBoyWK consumes complete native transport status and natural-end
  events in both its main and separate Options windows; its JavaScript no
  longer polls native playback state.
- [x] Offline AAC conversion progress and cancellation now cross the same
  native transport boundary: VGMBoy renders to a disposable partial file,
  CocoaSpice and SPCBoyWK display progress, and cancellation removes the
  incomplete output before either frontend reports completion.
- [x] Native tempo changes use the shared in-place `set_tempo` operation;
  neither frontend reloads the active decoder just to change speed.
- [x] SPCBoyWK uses the shared native bridge contracts and no JavaScript
  decoder implementation.
- [x] SPCBoyWK now keeps visible browsing separate from its active playing
  playlist.
- [x] CatalogReader derives Games/Files sidebar buckets from visible tracks
  while ScanSong's materialized sidebar projections are dirty.
- [x] CocoaSpice's unreachable duplicate Games/Files SQL reader was removed;
  its active browser path now has one catalog-reader owner.
- [ ] The complete visible playback transition handoff is not yet one shared
  frontend boundary; WebKit still retains presentation sequencing.
- [ ] Remaining CocoaSpice and SPCBoyWK adapters need contract cleanup where
  an already-shared service can be consumed more directly.
- [ ] Packaged-app parity still needs direct evidence for transition and
  failure cases; compilation and focused tests are not sufficient.

## Extraction slices

### 1. Shared playback session and queue

- [ ] Characterize CocoaSpice behavior for natural end, End Fade, Faded Skip,
  explicit stop, pause/resume, seek, Long Play, repeat modes, queue
  replacement, and stale requests.
- [x] Extract queue identity/target calculations, completion claims, request
  invalidation, transport serialization, timing, and fade policy into typed
  native boundaries.
- [x] Relink CocoaSpice and SPCBoyWK through the shared native transport and
  request contracts.
- [ ] Reduce only the remaining WebKit presentation handoff after the live
  transition cases are characterized; do not move DOM policy into the core.

### 2. Shared catalog-to-playlist service

- [x] Extract catalog reads, playlist projections, row identity, metadata,
  archive identity, and column-width hints into CatalogReader/CatalogPlaylistCore.
- [x] Preserve read-only SQLite behavior, bounded queries, cancellation, and
  scoped latest-request semantics.
- [x] Relink CocoaSpice and SPCBoyWK to the shared catalog/session boundary.
- [x] Remove CocoaSpice's obsolete duplicate sidebar query policy after
  verifying the active browser loader uses CatalogReader.
- [ ] Verify database hydration remains an instant lookup and never performs a
  source scan or full UI rebuild at the packaged-app boundary.

### 3. Shared archive and playlist intake

- [x] Extract folder/archive/M3U intake, selected-entry and dependency-complete
  materialization, cache leases, bounded extraction, cleanup, and tar.zst
  precedence into shared FrontendCore services.
- [x] Relink CocoaSpice and SPCBoyWK; frontends submit clean materialized-file
  requests to VGMBoy without decoder access.
- [ ] Finish duplicate-policy audit and run the same archive fixtures through
  both packaged apps.

### 4. Shared frontend contracts

- [x] Share typed playback, Favorites, preferences, catalog, archive, and
  format-capability contracts while retaining frontend-specific presentation.
- [x] Continue adoption cleanup only where it removes a real duplicate policy;
  CocoaSpice's duplicate sidebar query policy is removed.
- [ ] Keep auditing remaining adapters without moving SwiftUI views or WebKit
  DOM rendering into the shared core.

### 5. Deletion and parity gate

- [ ] Search both apps for remaining duplicate queue, timing, catalog, archive,
  and preference policy before deleting any adapter.
- [ ] Run shared package tests, CocoaSpice tests/build, SPCBoyWK tests/build,
  and fresh production launch smoke tests.
- [ ] Verify FLAC, VGM, Namco System 22, QSound, SPC, archive-backed tracks,
  standalone zst, pause, seek, Long Play, End Fade, Faded Skip, natural
  advancement, Enter activation, Favorites, and window restoration.
- [ ] Confirm selecting or browsing another item never silently replaces the
  active playing playlist, and retain the old playlist on failed replacement.

## Completion rule

This plan is complete only when both apps have one tested native owner for
playback lifecycle, queue state, timing/fade policy, catalog hydration,
archive intake, and preference semantics. JavaScript may then capture events,
send typed intents, and render returned state; it must not decide playback
identity or implement fallback mechanics.

Porting CocoaSpice's SwiftUI interface to WebKit is explicitly not the goal.
It would be a UI rewrite, not a shortcut around the remaining ownership work.
