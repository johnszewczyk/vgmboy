# CocoaSpice / SPCBoyWK Parity WIP Report

Status: **active**  
Reference date: 2026-08-29  
Reference app: CocoaSpice native Swift implementation  
Target app: SPCBoyWK native WebKit frontend

## Purpose

This report is the working ledger for behavioral parity after the shared-core
extraction. It is separate from `WIP-PLAN.md`: the extraction plan records
module boundaries and migration slices; this report records what the user can
observe in each app, which layer owns the behavior, what evidence exists, and
what remains to be proven.

The governing rule is simple:

> If CocoaSpice and SPCBoyWK present the same feature, they must use the same
> shared policy and VGMBoy command contract. A renderer-specific adapter may
> differ, but it may not create a second behavioral implementation.

Playlist columns follow the same rule. CocoaSpice is the reference for the
column set and ordering. Every playlist column is now visibility-configurable
in both frontends, including File; the favorite marker remains
non-reorderable in CocoaSpice, and both frontends retain one visible column so
the playlist never becomes an unusable empty table.

Packaged-app verification completed on 2026-08-28: CocoaSpice hid File through
the native header menu and retained it after relaunch. SPCBoyWK hid File and
the favorite marker through its WebKit menu and retained both after relaunch
and library reload. The apps expose the same user-facing hideability contract;
the native and WebKit menu implementations remain renderer-specific.

Packaged transition check on 2026-08-29: a fresh SPCBoyWK production build
launched and opened the shared ScanSong catalog. Searching `Cyberbots` showed
the 53-track archive playlist and native lengths, including two 0:02 fixtures;
the selected row and playlist projection were visible in the actual WebKit
window. This proves catalog/playlist admission at the packaged boundary, not
natural-end behavior. Long Play remained enabled because the computer-use
click path did not dispatch the toolbar/settings action reliably, so the
five-minute manual timing cap prevented a valid short-track completion claim.
Keep the natural-end, repeat, and stale-end checks open until the control can
be changed in a repeatable packaged run. The shared transport/queue tests are
still green and remain the current evidence for stale-completion protection.

Format-intake check on 2026-08-29: VGMBoy and ScanSong now share the MDX/PDX
dependency rule and the UADE-backed Amiga prefix manifest. CocoaSpice and
SPCBoyWK route LHA through the shared FrontendCore materializer; Amiga archives
are staged as complete sets so player/sample companions remain available. This
establishes the archive and admission boundary, while broad corpus qualification
and live playback sampling remain fixture work.

## Ownership rules

- CocoaSpice's native Swift behavior is the reference when the two apps differ.
- VGMBoyKit owns decoder routing, format capability, playback timing, tempo,
  audio output, fade execution, and offline AAC conversion.
- FrontendCore owns UI-neutral preferences, archive materialization/cache,
  catalog projections, queue/request primitives, and other extracted policy.
- CatalogReader owns read-only catalog access and playlist projections.
- CocoaSpice and SPCBoyWK own only their native/AppKit or WebKit presentation,
  focus, selection, scroll, window, and adapter state.
- The abandoned Electron SPCBoy tree is not a reference or implementation
  source.
- No parity fix is complete from compilation alone; the visible app boundary
  and a representative fixture must be exercised.

## Current parity matrix

| Area | CocoaSpice | SPCBoyWK | Shared boundary | Status |
| --- | --- | --- | --- | --- |
| Catalog reads | Native `CatalogReader` projection | WK bridge over `CatalogReader` | `CatalogReader`, `CatalogBrowserCore`, `CatalogPlaylistCore` | Shared; RE2 PSF timing verified from ScanSong catalog through CocoaSpice |
| Sidebar file tree | Native row adapter | DOM row adapter | `CatalogBrowserCore` tree/search projection | Shared policy |
| Database search | Native adapter/search presentation | Immediate local filter over native-published projection | `CatalogSearchIndex` matching policy / browser projection | Shared semantics; WebKit no longer debounces or round-trips per keypress |
| Playlist identity | `TrackItem` adapter | JSON/DOM track adapter | `PlaylistIdentityCore` and catalog row envelope | Shared identity |
| Queue transitions | Native queue coordinator | JS presentation + shared native request boundary | `PlaybackQueueCore`, `PlaybackRequestCore`, `PlaybackTransportCore` | Completion claim/decision shared; WK stop/advance handoff remains |
| Archive intake | Native archive adapter | `SPCArchiveMaterialization` adapter | `ArchiveMaterializationCore`, `ArchiveCacheCore` | Shared machinery; ZIP/7z/LHA/RSN/TAR+Zstandard, with complete-set Amiga materialization |
| Decoder/format routing | VGMBoyKit | VGMBoyKit | `FormatRegistry` / endpoint manifest | Shared authority |
| Playback timing | VGMBoyKit via CS adapter; selected catalog timing now drives pre-play readout | VGMBoyKit via WK bridge | `PlaybackTimingPolicy` / `PlaybackTimingRequest` | Shared policy; RE2 PSF duration verified |
| End Fade | Native option, configurable duration | WK option, configurable duration | `PlaybackTimingPreferences` | Shared semantics; live parity pending |
| Faded Skip | Native transport control | WK transport control | `PlaybackTransportCore` fade policy | Shared decision policy |
| Tempo | Native VGMBoy control | WK VGMBoy control | shared tempo value and playback request | Shared contract; format fixture coverage pending |
| Archive cache | FrontendCore policy and CS namespace | FrontendCore policy and SB namespace | `ArchiveCachePolicy` | Choices/default now match |
| Preferences | Shared coordinator/store plus CS schema | Shared coordinator/store plus SB schema | `FrontendPreferencesCore` | Shared subset; app-specific keys remain |
| Font controls | One CS interface style surface | One SB interface style surface | Renderer-specific settings adapters | Visible parity restored |
| Selection highlight | Native sidebar/playlist indicators using macOS control accent | One CSS accent capsule shared by sidebar and playlist | Renderer-specific presentation; no shared custom color value | SPCBoyWK flicker fix and selection-color unification verified in focused tests |
| Accent color | Follows `NSColor.controlAccentColor`; no app-specific persisted color option | Existing CSS color setting applied to root tint, list selection, and active controls | Frontend preference snapshots; rendering remains native/WebKit-specific | Deliberately renderer-specific: CS is vanilla macOS, SB retains its style option |
| Column auto-size | Native checkbox/default-on | WK checkbox/default-on | Frontend preferences contract | Shared meaning |
| Animations | Native checkbox + retained duration | WK checkbox + retained duration | Frontend preferences contract | Shared meaning |
| Always on Top | Native windows | Native-hosted WK windows | Frontend preferences contract | Shared meaning |
| AAC export | Native context menu and folder option | WK context menu, folder option, native bridge | VGMBoyKit `AACExporter` | UI/bridge wired; RE2 archive fixture and packaged CocoaSpice action verified |
| Toolbar | Native SwiftUI/AppKit toolbar | WebKit toolbar | Shared commands/state only | Intentionally renderer-specific |

## Open disparities and work slices

### P0 — Verify no user-visible loading regression

The apps must not display or perform a full playlist rebuild for a database
lookup. A playlist selection should hydrate from the already-published catalog
projection without scanning source paths or decoding audio.

Evidence to collect:

- cold and warm database-game selection in both apps;
- repeated selection of a 53-track arcade archive and a normal Sega title;
- elapsed time from click/Return to first visible row;
- whether the current playlist is retained until a complete replacement exists;
- no disk scan, archive extraction, decoder construction, or per-row progress
  flood during lookup.

Current implementation: Games, Files, playlist, and search requests use scoped
native session generations, and stale detached catalog work returns an explicit
stale envelope instead of publishing rows. CatalogReader also detects dirty
ScanSong sidebar projections and derives the visible Games/Files buckets from
tracks until publication catches up; both frontends now consume that same
fallback. Remaining work is visible parity measurement—cold/warm hydration,
retaining the old playlist on failure, and no scan/decode work—not another
generation implementation. Do not merge AppKit/WebKit loading copy or row
rendering into the shared core.

CocoaSpice's former duplicate sidebar SQL reader has been removed after a
caller audit; its active browser loader now consumes CatalogReader directly.

### P0 — Verify playback selection cannot jump or truncate

The Apple crash report was traced to CocoaSpice's adapter reading a mutable
`TrackItem` while transport callbacks and async replacement work used different
executors. CocoaSpice now keeps that presentation snapshot behind a lock and
uses the transport's queue-confined track ID for status callbacks. The focused
concurrency regression passes; the visible rapid-track-change test remains a
manual app-boundary gate.

The known failure family includes SPCBoyWK Return activating the previous item,
playlist selection jumping to Contra Shattered Soldier, playback stopping when
the selection/view changes, and CocoaSpice selection/scroll movement after
expansion. These are related symptoms but must not be assumed to share one
cause.

Required fixtures/actions:

- click a different database title, then press Return;
- focus a playlist row, press Return, then use arrow keys;
- expand a sidebar item while another row is selected;
- change sidebar view while audio is active;
- replace the playlist while a delayed natural-end or faded-skip callback is
  pending.

Capture selected ID, current ID, focus row ID, queue order, playback generation,
and visible scroll position before and after each action. Shared request
generation already rejects stale native work; remaining failures are likely
frontend selection/focus or queue handoff behavior until evidence says otherwise.

### P1 — FLAC and standard audio duration parity

Catalog duration is display metadata; VGMBoy decoder timing is playback truth.
Both apps must read standard FLAC metadata where the scanner can, and neither
app may apply Long Play or the unknown-duration default to ordinary finite FLAC
audio.

Required evidence:

- scanner-recorded FLAC duration;
- catalog row duration;
- VGMBoy timing plan with Long Play off and on;
- actual playback end and fade boundary in each app;
- whether AAC export uses the same finite timing plan.

The prior 2:30 value remains only for explicit unknown-duration timed requests.
It must not become a blanket audio duration. Any user-configurable unknown
duration setting must affect only formats with no natural duration.

### P1 — Format admission, archive expansion, and playback

Arcade archives containing `.vgm` members must expand and play identically to
other VGM archives. Cyberbots (53 VGM members), Cyber Cycles (13), and
Cadillacs and Dinosaurs are required fixtures. MiniQSF remains an explicit
format fixture because it has previously been admitted but failed to play.

For every fixture record:

- scanner admission and published track count;
- database row count and playlist expansion count;
- selected archive member and materialized path;
- VGMBoy format family and decoder result;
- actual audio start, natural end, and fade behavior.

Do not add a CPS2/Namco decoder when the archive payload is already VGM. Trace
the member and the actual `FormatRegistry`/libvgm path instead.

### P1 — AAC export end-to-end

The converter is now correctly layered: VGMBoyKit owns `AACExporter` and the
typed `export_aac` command; each frontend chooses a folder and supplies a
track/timing request. SPCBoyWK uses a separate shared materialization session
so export cannot release active playback material.

Still required:

- direct FLAC export;
- archive-member VGM export;
- export while another track is playing;
- collision-safe filenames;
- missing folder and unsupported-format errors;
- confirm output duration equals the requested finite plan, including fade.

### P1 — SPCBoyWK visible clock and immediate search

The native transport status remains the source of truth. SPCBoyWK now
interpolates the readout between native status events only while a matching
track is playing; the interpolation is cancelled on pause, seek, replacement,
stop, and end. Sidebar search now filters the already-loaded database game
projection synchronously with the shared all-terms search semantics, without a
120 ms debounce or a native bridge call per keypress.

Evidence currently available:

- 20 focused SPCBoyWK transport/resource tests pass, including a clock advance
  between native events, stale-status rejection, and shared selection styling.
- A real SPC fixture reports non-zero native timing and advances the VGMBoy
  decoder frame clock. `FrontendCore.PlaybackTransportCore` now stamps every
  status reply/broadcast with a monotonic sequence, and SPCBoyWK drops an older
  delayed event before it can clear the visible clock.
- SPCBoyWK release product build passes.

Still required:

- fresh packaged-app check that the readout advances during playback and snaps
  correctly after pause/seek/end;
- a large-catalog typing check while playback continues;
- AAC fixture export and output-duration verification.

### P0 — Shared completion ownership and remaining WK handoff

SPCBoyWK no longer owns a second native continuation gate. Completion requests
are generation-checked and claimed by `PlaybackTransportCore`, then the shared
queue policy computes the explicit stop/play decision. The remaining disparity
is the renderer handoff after that decision: WebKit still retires its native
session, clears presentation state, and asks for the next track in separate
JavaScript steps. Archive-materialization release now occurs inside the
serialized native stop/close/unload boundary, so it cannot race a replacement.
The remaining extraction target is the stop/advance ordering around presentation
cleanup and the next-track request.

Evidence currently available:

- 20 focused SPCBoyWK transport/resource tests pass, including delegation to
  the shared transport.
- Focused FrontendCore transport tests pass.
- SPCBoyWK release product links against the updated shared transport core.

Required next test matrix:

- natural end with Repeat Off, Song, and Playlist;
- faded skip followed by a second skip;
- replacement during archive materialization;
- stale end event after explicit stop or replacement;
- archive lease release before the next track begins.

### P1 — Options parity audit

The following must remain mirrored in meaning, copy, defaults, and persistence:

- Interface Style font size/color/monospace;
- Column Auto-size, default on;
- independent Auto-Resize and Selection Bar enable flags;
- retained 0–1000 ms animation values while disabled;
- main/options Always on Top and explanatory subtext;
- Long Play, unknown-duration default, configurable End Fade, and inline Faded
  Skip;
- shared cache choices of 2/4/8/16 GB with a 2 GB default;
- libgme/libvgm tempo controls and supported-format descriptions;
- AAC export destination and action availability.

The exact SwiftUI toolbar cannot be copied into WebKit. Its command names,
state meanings, Long Play/Repeat/Random/Equalizer behavior, and enabled/disabled
states must remain equivalent.

### P2 — Shared persistence and migration cleanup

The shared coordinator/store now governs the extracted interface subset, while
each app retains its own broader snapshot and key namespace. Audit for any
remaining direct writes that bypass the coordinator, especially animation,
column auto-size, and window-level settings. Legacy fields may remain for
compatibility, but new UI writes must update the canonical shared values.

### P2 — Documentation and release evidence

Every completed parity slice updates:

- this report's matrix and evidence;
- `WIP-PLAN.md` extraction status;
- the affected human subsystem docs;
- focused tests and the user-boundary verification record.

## Validation gates

No slice moves to complete until applicable gates pass:

1. shared package tests;
2. CocoaSpice full tests and production build;
3. SPCBoyWK JS syntax checks, transport tests, and production build;
4. fresh launch of the actual CocoaSpice and SPCBoyWK native builds;
5. visible user-boundary test on the representative fixture;
6. no source scan or decoder work on a database-only playlist lookup;
7. no stale-generation selection or playback callback after replacement;
8. `git diff --check` in every touched child repository;
9. no dirty vendor state, handoff file, or unrelated user work included;
10. documentation updated with observed evidence, not inferred parity.

## Next bounded sequence

1. Run the P0 selection/hydration matrix in both apps and record IDs, timing,
   generation, and scroll state.
2. If the same failure exists in both, fix the shared request/session boundary;
   if only SPCBoyWK fails, fix its thin selection adapter against the CS
   behavior without changing the shared core.
3. Run the P1 FLAC/unknown-duration matrix and verify the actual end boundary.
4. Run the P1 archive VGM and MiniQSF matrix.
5. Run AAC export end-to-end, then close any remaining options/persistence
   disparities.

## Change discipline

- Keep this report WIP until the visible matrix is actually exercised.
- Preserve the current CS-first extraction order.
- Do not refactor a working implementation merely to make the files look
  similar.
- Do not add a fallback route to hide a missing shared contract.
- Make one bounded parity change at a time and leave an inspectable test or
  runtime record for it.
