# VGMMan Shared-Core Extraction WIP Plan

## Purpose

Reduce CocoaSpice and SPCBoyWK to frontend shells around one maintained set of
Swift components while preserving CocoaSpice behavior during every extraction.

This plan is deliberately CocoaSpice-first:

1. Identify the superior native Swift implementation in CocoaSpice.
2. Characterize it with behavior and performance tests.
3. Extract it into the smallest appropriate shared Swift package.
4. Wire the extracted module back into CocoaSpice.
5. Verify CocoaSpice still behaves identically.
6. Only then wire SPCBoyWK to the same module.
7. Remove the replaced SPCBoyWK JavaScript/native duplicate.

SPCBoyWK is allowed to remain transitional while CocoaSpice is being split and
relinked. CocoaSpice is not allowed to regress while SPCBoyWK catches up.

## Current truth — extraction, format intake, and parity state (2026-08-29)

### Management baseline — 2026-08-28

The VGMMan family is managed as six independent repositories: VGMBoy,
CocoaSpice, SPCBoyWK, ScanSong, CatalogReader, and FrontendCore. The prior
management baseline was committed and its configured remote state was recorded
there. The current working trees intentionally contain follow-up WIP in VGMBoy,
ScanSong, CocoaSpice, SPCBoyWK, FrontendCore, and LaunchPad; those dirty trees
must not be described as released snapshots. CatalogReader has no current code
WIP. The generated CatalogReader `.DS_Store` and the pre-existing dirty
`VGMBoy/vendor/aosdk` submodule remain deliberately outside any cleanup or
extraction change.

The CocoaSpice playback adapter now protects its frontend `TrackItem` snapshot
from concurrent transport callbacks and reports callback identity from the
queue-confined transport status. Shared catalog, archive, queue, request, and
transport policy is linked into both native frontends. The remaining parity work
is the visible app-boundary matrix and fixture-gated decoder/archive checks,
including the newer MDX/PDX and UADE/Amiga intake paths.

### Fixture parity gate — 2026-08-28

- [x] Validate the real JoshW Resident Evil 2 PSX archive through ScanSong:
  75 PSF tracks publish, `11 Secure Place.psf` retains 43,000 ms play and
  10,000 ms fade metadata, and archive-level progress remains one source.
- [x] Validate the real Resident Evil 2 GameCube archive with the VGMBoy
  vgmstream inspector configured: underscore TXTH aliases resolve and the
  scan publishes at least 131 playable tracks without failures.
- [x] Validate the real Dungeons & Dragons Tower of Doom QSF archive with the
  VGMBoy QSF inspector configured: all 39 MiniQSF members publish as real
  single-track records with their adjacent `.qsflib` dependency.
- [x] Re-run the shared FLAC and Cyberbots VGM fixture checks; both open and
  report finite timing through VGMBoy.
- [x] Verify the packaged SPCBoyWK catalog boundary: Cyberbots hydrates all
  53 tracks and the selected track's native playback clock advances.

The archive tests require the VGMBoy-built inspector executables when run
outside the assembled ScanSong bundle. An unset inspector path produces the
intentional `missingRequiredAdapter` failure; it is not evidence that the
archive or decoder is broken.

The earlier “complete” transport status was premature. The shared packages
currently cover catalog projections, archive materialization, format
capabilities, timing policy, preference values, queue-target calculations, and
the low-level VGMBoy command protocol. They do not yet own the complete
frontend transport lifecycle.

### Current parity slice — SPCBoyWK clock, search, and AAC access (2026-08-28)

- [x] Keep the native VGMBoy/FrontendCore status snapshot as the playback clock
  authority while adding a bounded WebKit-only interpolation between status
  broadcasts. Pause, seek, replacement, stop, tempo changes, and natural end
  remain native-anchored.
- [x] Remove the sidebar search debounce and per-keypress native bridge query.
  SPCBoyWK now filters the already-loaded catalog projection synchronously using
  the same all-terms fields as `CatalogBrowserCore`.
- [x] Confirm AAC export is present in SPCBoyWK: playlist context action,
  destination controls, native cancellation/progress events, and VGMBoy-backed
  offline export are all wired.
- [x] Validate the archive-backed AAC boundary against the real JoshW Resident
  Evil 2 PSF member: VGMBoy materializes the member, renders a finite export,
  publishes completion, and the output opens as AAC. Shared VGMBoy tests still
  cover ADTS output, cancellation cleanup, filename sanitization, and timing/
  fade policy; loose-FLAC and archive-member VGM remain the next fixture inputs.
- [x] Run the packaged CocoaSpice clock/search/playback checks against the RE2
  library. The visible clock advances and search updates synchronously while
  playback is active.
- [x] Recheck the packaged row context-menu Export AAC action. A fresh RE2
  export produced a 2.4 MB MPEG ADTS AAC file in Downloads, confirming the
  AppKit action-to-status path in addition to the direct PlaybackEngine test.

### Current parity slice — selection presentation, native accent, and ordered clock status (2026-08-29)

- [x] Unify SPCBoyWK sidebar and playlist selection on one accent-colored
  capsule. Selected rows no longer paint a competing instantaneous background;
  text color transitions with the capsule so selection changes do not flicker.
- [x] Keep SPCBoyWK's existing CSS accent setting wired through its typed
  settings snapshot and apply it to both list surfaces and active controls.
  CocoaSpice now follows `NSColor.controlAccentColor` and native control styles;
  its app-specific persisted accent ColorPicker/root-tint setting was removed.
  The two renderers therefore share behavior contracts, not a custom color value.
- [x] Add a monotonic `status_sequence` to `FrontendCore.PlaybackTransportCore`
  status replies and broadcasts. SPCBoyWK rejects a delayed older status event
  instead of allowing a stale pause/stop snapshot to clear an advancing SPC
  clock. This is a shared transport ordering fix, not a WebKit polling loop.
- [x] Verify a real SPC fixture reports native timing and advances its decoder
  frame clock through VGMBoy. The packaged SPCBoyWK release build also links
  the updated shared transport core; live accessibility playback control still
  needs a repeatable manual fixture run before it is marked fully closed.

### Current format-intake slice — MDX/PDX and Amiga/UADE (2026-08-29)

- [x] Link ScanSong to the VGMBoy-built `vgmboy-mdx-inspect` and
  `vgmboy-amiga-inspect` products. MDX keeps its adjacent PDX bank as dependency
  data; PDX is never published as a playlist source.
- [x] Route Amiga prefix-led modules through the shared `AmigaFormatManifest`
  and stage LHA/loose Amiga sets as complete dependency sets before UADE
  inspection or playback. The original module and companion bytes remain the
  source representation.
- [x] Route LHA playback through the shared FrontendCore archive boundary and
  admit Amiga prefix members in CocoaSpice and SPCBoyWK. Remaining work is
  representative corpus qualification, not another frontend archive engine.

### Current extraction slice — shared completion ownership (2026-08-28)

- [x] Move the completion claim and repeat/advance decision into
  `PlaybackTransportCore.PlaybackTransportCoordinator`, including a native
  generation check against the active VGMBoy session.
- [x] Make SPCBoyWK's `WKNativeBridge` delegate completion decisions through
  `WKPlaybackBridge`; it no longer owns a second continuation gate.
- [x] Verify the shared package and dependent SPCBoyWK release product build.
- [x] Move archive-materialization release into the serialized native
  stop/close/unload boundary and remove the second WebKit release request.
- [x] Remove the now-empty `PlaybackSessionLifecycleCoordinator` wrapper;
  CocoaSpice uses the shared `PlaybackRequestLifecycle` primitive directly.
- [x] Extract native retirement into the same typed completion operation as the
  generation claim and repeat/advance decision. CocoaSpice and SPCBoyWK now
  retire the completed VGMBoy session through the shared coordinator.
- [x] Carry the completion lifecycle through one shared
  `PlaybackContinuationRequest` envelope instead of frontend-specific policy
  fields.
- [x] Isolate SPCBoyWK's post-retirement presentation cleanup and typed target
  request in one WebKit adapter handoff.
- [x] Add a shared/native continuation-start primitive that accepts only a
  materialized `PlaybackTransportTrack` and finite VGMBoy payload.
- [x] Convert CocoaSpice's natural-end adapter to the continuation-start
  primitive first; archive materialization and timing resolution remain in its
  adapter.
- [x] Preserve SPCBoyWK's archive-lease transaction at the WebKit boundary:
  native completion decides and retires first, releases the old lease, and
  only then does the presentation handoff request target materialization/start.

The historical duplicated ownership caused real regressions: SPCBoyWK once kept
the completion decision beside its JavaScript finalizer, while CocoaSpice kept
its equivalent lifecycle in Swift. The decision, generation claim, and native
retirement are now shared; WebKit retains only presentation clearing and named
target/adjacent intent forwarding. SPCBoyWK's separate Options WebView also now
relays playback preference changes to the active main-window session.

### Current extraction slice — one transport-status projection (2026-08-28)

- [x] Extract the JSON-facing transport status payload into
  `PlaybackTransportCore.PlaybackTransportStatusPayload`.
- [x] Use that projection for SPCBoyWK command replies and asynchronous native
  status/end events, so elapsed position and diagnostics cannot drift between
  the two WebKit paths.
- [x] Add shared tests for complete diagnostics, millisecond rounding, and the
  drained natural-end override; SPCBoyWK's bridge contract tests remain green.

This slice is intentionally a contract cleanup, not a playback redesign. The
native transport remains authoritative for position and end state; WebKit only
renders the payload and performs bounded presentation interpolation.

The archive lifecycle gate also found and fixed a legacy-cache edge case:
archive directory modes such as `0644` made an incomplete or warm cache set
impossible to replace. `ArchiveCacheMaterializer` now repairs directory modes
before validating warm hits or replacing stale sets, while preserving file
contents. The real JoshW Resident Evil 2 PSX archive and both JoshW/SNESMusicOrg
Doom SNES archives now pass the archive-to-VGMBoy lifecycle fixtures.

The RE2 PSF timing path was revalidated end to end. ScanSong's direct PSF tag
reader and schema-23 catalog persist `length=43` and `fade=10` for `11 Secure
Place.psf`; CocoaSpice now displays that catalog duration before playback and
does not fall back to its 150-second unknown-duration default when a selected
row has known metadata. The audit also removed only confirmed-dead local
CocoaSpice transport/completion scaffolds left after extraction; no active
VGMBoy or SPCBoyWK code was removed.

The Atari ST/SNDH path was sampled through the real VGMBoy `psgplay` bridge.
The native bridge had a source-buffer lifetime defect: uncompressed SNDH input
was freed before the open path copied it, so a multi-track header could be
corrupted between metadata enumeration and playback. The fix retains the input
until the decoder owns its copy. A deterministic 1,024-file sample spanning
the 5,897-file corpus rendered 2,030 declared subtunes with zero selection,
timing, or silent initial-render failures, including 4-Mat's eight-subtune
Shadow Dancer. This is decoder-path evidence, not a claim that every SNDH is
conventional music; SNDH can contain loaders, sound effects, DMA/STE-specific
routines, or intentionally non-musical captures.

The active recovery plan below supersedes any older “final parity” wording in
this document. Historical slice notes remain as provenance; they are not a
claim that the apps are already reduced to GUI shells.

### Behavioral provenance rule — 2026-08-28

CocoaSpice remains the reference implementation for shared playback behavior.
The continuation coordinator was introduced in FrontendCore from the
CocoaSpice completion behavior, CocoaSpice was routed to that shared contract
first, and SPCBoyWK was routed afterward. The current transport move only
removed CocoaSpice's duplicate native completion gate; it did not import
SPCBoyWK behavior into CocoaSpice. Any future SPCBoyWK improvement must first
be characterized against CocoaSpice, then promoted into FrontendCore only when
it is demonstrably superior and applicable to both frontends.

### Current UI parity slice — playlist column visibility (2026-08-28)

- [x] Keep CocoaSpice's column set and ordering behavior as the reference.
- [x] Make every CocoaSpice playlist column visibility-configurable, including
  File and the favorite marker; keep at least one column visible and keep the
  favorite marker non-reorderable.
- [x] Remove SPCBoyWK's filename-only visibility restriction and apply the same
  at-least-one-visible rule without forcing File back on.
- [x] Verify the menu and persisted visibility from the packaged CocoaSpice
  and SPCBoyWK app boundaries. CocoaSpice's native menu hid File and retained
  that choice after relaunch; SPCBoyWK's WebKit menu hid File and the favorite
  marker, and both remained hidden after relaunch and library reload.

### Current pass — bounded USF failure and continuation ownership (2026-08-26)

- [x] Confirm the CocoaSpice Turok Rage Wars failure at the shared VGMBoy
  boundary. The archive expands correctly and the nine `.miniusf` members are
  admitted, but the rip enters an unbounded TLB/jump loop during lazyUSF
  startup; this is decoder/data incompatibility, not playlist hydration or
  sidebar UI.
- [x] Add a shared lazyUSF render budget and propagate native render errors
  through `LazyUSFDecoder` and `PlaybackSession` instead of silently treating
  failed decoder reads as audio end. The bounded path uses the pure interpreter
  for safety, so malformed/incompatible USF cannot exhaust the native stack.
- [x] Verify the bad Turok member returns a decoder error in about three
  seconds rather than freezing or crashing; verify a known-good Blast Corps
  member still reaches the normal macOS audio-output boundary.
- [x] Extract `PlaybackContinuationCoordinator` into `PlaybackQueueCore` and
  relink CocoaSpice and SPCBoyWK's native continuation state to it.
- [x] Move SPCBoyWK's JavaScript completion decision onto one native
  coordinator call carrying the native generation. Duplicate completion
  events now return no decision before JavaScript can retire or advance the
  queue; JavaScript retains only the UI sequencing and output-retirement
  adapter.
- [x] Move SPCBoyWK's native stop for natural-end completion onto the shared
  transport coordinator.
- [x] Move SPCBoyWK presentation clearing and next-track request sequencing
  behind the shared typed lifecycle result. JavaScript still owns the WebKit
  generation guard and visible-state reset, but no longer chooses completion
  policy or retires the native session itself.

The lazyUSF source is recorded as a gitlink in this checkout without a usable
submodule mapping. The render-safety change is now portable through the tracked
`VGMBoy/patches/lazyusf2-render-safety.patch`; a normal submodule checkout is
still required for a clean build, while the dependency script hashes a local
gitlink working tree to prevent stale products in this checkout.

## Actual remaining work — finite end state

This is not an open-ended sequence of dozens of equal-sized slices. The older
roadmap sections below preserve extraction history and backlog detail; the
active work remaining is:

1. Finish the final parity gate: builds, focused fixtures, and manual launch tests
   for Enter, playlist replacement, Long Play, fades, FLAC/VGM/archive tracks,
   pause/seek, and window/preferences restoration.

Once these gates close, remaining work is ordinary backlog—not extraction debt
required for app parity. SPCBoyWK still has UI-local playback-generation guards,
clock interpolation, queued-fade timers, and the final WebKit presentation
handoff. Those are renderer adapters, not duplicate decoder or queue policy; only
move more of that sequencing into shared code if a CocoaSpice-characterized
contract applies to both frontends. Porting the CocoaSpice UI to WebKit would be
a separate UI rewrite and is not a shorter path to this end state.

## Active recovery and final extraction plan

The detailed Slice A–E checklist below is retained as a historical roadmap
snapshot. The dated “Current truth” and “Actual remaining work” sections above
are authoritative; unchecked items below must not be treated as a second,
active backlog.

### Slice A — close the immediate SPCBoy regressions

- [x] Restore SPCBoy main and Options window frame autosave in the native
  AppKit host.
- [x] Relay shared timing preferences from the Options WebView to the main
  playback WebView.
- [x] Add a native reconfigure-loaded-session command using the existing
  `VGMBoyKit.PlaybackController.setPlaybackMode` contract, preserving pause,
  play position, and current-track identity.
- [x] Make Enter selection-authoritative and remove the current-track replay
  fallback.
- [ ] Verify the active production builds manually with: click/arrow to a new
  playlist row, press Enter, toggle Long Play from Options while playing and
  paused, move/resize both windows, relaunch, and confirm restoration.

### Slice B — extract the complete transport lifecycle from CocoaSpice

Use CocoaSpice’s working Swift behavior as the source implementation and
extract it without redesigning it:

- [x] Move loaded-track identity, pause/resume/seek/reconfigure state, request
  generations, and natural-end event delivery into a shared typed transport
  coordinator above `VGMBoyKit.PlaybackController`. The new
  `FrontendCore.PlaybackTransportCore.PlaybackTransportCoordinator` is linked
  to both apps; the adapters no longer instantiate their own controller or
  serial executor.
- [x] Make the coordinator expose one status snapshot and one completion event
  contract. `PlaybackTransportCoordinator` now listens to VGMBoy's `.ended`
  event, validates the active native generation, and gates duplicate/stale
  completion delivery before queue continuation.
- [x] Link CocoaSpice back to that extracted coordinator first and preserve its
  current behavior with characterization tests.
- [x] Replace SPCBoyWK’s native completion retirement call with the same
  coordinator through a narrow bridge projection.
- [ ] Replace SPCBoyWK’s remaining presentation/next-track finalization state
  machine with the typed lifecycle contract.
- [ ] Delete the replaced SPCBoyWK completion-generation and timing-refresh
  policy from JavaScript. JavaScript may render status and send named UI
  intents only.

### Slice C — extract queue state, not just queue functions

`PlaybackQueueCore` currently shares pure target calculations, but both apps
still own surrounding queue state. Extend the exact CocoaSpice behavior into a
typed state machine for:

- [ ] selected/current/pending track identity;
- [ ] playlist replacement while preserving a playing track;
- [ ] previous/next/repeat transitions;
- [ ] natural-end continuation; and
- [ ] stale request rejection.

Wire and test CocoaSpice first, then expose the same snapshot/intent contract
to SPCBoyWK. Random-library choice remains an explicit policy input, not a
reason for a second queue implementation.

### Slice D — unify frontend command and preference synchronization

- [ ] Make `FrontendCommandCore` the semantic command vocabulary for both
  native frontends: activate selection, play/pause, adjacent, seek, timing
  change, and window/options actions.
- [ ] Keep WebKit JavaScript responsible only for DOM event capture and DOM
  rendering. It must not decide which playback track is current or replay a
  fallback track.
- [ ] Keep AppKit/WebKit window construction local, but use one typed window
  preference/frame policy and identical restore/reset semantics.
- [ ] Add a cross-app contract fixture proving that the same preference change
  reaches the same loaded-track session in both apps.

### Slice E — deletion and parity gate

- [ ] Sweep for duplicate JS/Swift timing, completion, queue, and preference
  policies after each migration.
- [ ] Delete replaced adapters only after CocoaSpice and SPCBoyWK builds use
  the shared contract.
- [ ] Run shared-core tests, CocoaSpice tests/build, SPCBoyWK syntax/build,
  and production launch checks.
- [ ] Manually verify FLAC, QSound, SPC, archive-backed VGM, pause, seek,
  Long Play, End Fade, natural advance, Enter activation, window restoration,
  and separate Options-window synchronization.

Definition of completion for this plan: the frontends retain only native host
construction, DOM/AppKit presentation, event capture, and thin typed adapters.
Playback lifecycle, queue state, timing application, preferences, catalog
projections, and archive policy must have one shared owner and one tested
contract.

### Historical pass — native transport extraction and CS sidebar toolbar

- [x] Extract CocoaSpice's working serialized VGMBoy façade into
  `FrontendCore.PlaybackTransportCore.PlaybackTransportCoordinator`.
- [x] Relink CocoaSpice first, then SPCBoyWK, to that coordinator.
- [x] Move SPCBoyWK's native playback request-generation invalidation into the
  shared coordinator; no app-specific native controller/serial queue remains.
- [x] Put CocoaSpice library-view and fold/unfold controls beside the native
  sidebar disclosure as individual native navigation-toolbar items. They are
  no longer appended to the sidebar column, grouped into a custom capsule, or
  merged with the transport toolbar.
- [x] Move CocoaSpice natural-end advancement onto the coordinator's one-shot
  completion event. Its timer now observes diagnostics and elapsed position
  only; it does not decide that playback ended.
- [x] Move queue state and queue continuation—not just pure ID calculations—into
  the shared core. `PlaybackQueueState` and the native transport continuation
  boundary are now linked to both frontends; `app-playback.js` retains only the
  WebKit presentation handoff, renderer generation guards, and fade timer.

### Current slice — shared Favorites projection, playlist columns, and VGM fade boundary (2026-08-26)

- [x] Remove Favorites from `CatalogBrowserCore` and the two catalog sidebar
  state machines. Favorites is frontend-owned persisted data projected into the
  playlist, not a third catalog/sidebar mode.
- [x] Standardize `Favorites Playlist` on Command-Shift-D in CocoaSpice and
  SPCBoyWK. The command snapshots the shared Favorites list without changing
  sidebar mode, search, or catalog hydration.
- [x] Remove CocoaSpice's obsolete row-level Play/Stop playlist column. Row
  activation and the main transport remain the playback controls.
- [x] Correct the libvgm fade ownership boundary: ordinary VGM natural-end
  playback now uses VGMBoy's shared session output fade because the libvgm
  PlayerA wrapper does not start an internal fade at ordinary file end. Native
  Long Play capability remains intact.
- [x] Record the QSF clarification: QSF/miniQSF entries routed through libvgm
  are VGM playback for fade purposes; they are not a separate QSF fade case.
- [x] Update CatalogReader, CocoaSpice, SPCBoyWK, and VGMBoy subsystem notes
  to reflect the two-view catalog/sidebar contract and shared fade behavior.
- [x] Add fixture-backed VGM fade verification for Namco System 22 `.vgm`
  members from Cyber Commando and Cyber Cycles.
- [x] Extract `PlaybackQueueState` in `PlaybackQueueCore` as the shared,
  value-only contract for current/selected/pending identity, playlist
  replacement, transport navigation, and natural-end continuation.
- [x] Relink CocoaSpice to that state contract and delete its former local
  `QueueTransportNavigation` adapter. CocoaSpice remains the behavior
  reference; random-library choice and UI presentation remain local policy.
- [x] Route SPCBoyWK's existing queue bridge projections through
  `PlaybackQueueState`, so replacement, transport, adjacency, and completion
  requests use the same native contract as CocoaSpice.
- [x] Replace the four legacy queue projection requests with one typed
  `playbackQueueTransition` snapshot/intent bridge. The native bridge now
  routes adjacent, completion, and replacement intents through the shared
  state contract.
- [x] Forward the shared coordinator's generation-checked natural-end event
  into the SPCBoyWK WebKit page. JavaScript no longer decides that natural
  playback ended by polling `transport_state`.
- [x] Extract scoped catalog-session generations into
  `CatalogSessionCore.CatalogSessionCoordinator`. Games, Files, playlist
  reads, and search have independent latest-request ownership, and the
  lifecycle primitive is thread-safe so detached WK catalog work does not
  enter the UI actor.
- [x] Relink CocoaSpice's native Games/Files loader to the shared scoped
  coordinator without changing its status, cancellation, or snapshot
  behavior.
- [x] Relink SPCBoyWK's native catalog bridge to the same coordinator. Every
  detached catalog request still receives a reply, while stale work returns
  an explicit `{ "stale": true }` envelope and cannot publish rows.
- [x] Expose native `catalogSessionInvalidate("playlist")` as a named
  SPCBoyWK intent and remove the duplicate `playlistLoadGeneration` counter.
  Database/sidebar replacement paths now invalidate the shared native
  playlist session before reading or replacing rows.
- [x] Characterize the remaining browser-selection race. It is a DOM-intent
  ordering guard, not a catalog-session guard: an older preview could finish
  after an activation and overwrite the newly selected playlist. The guard is
  now advanced for browser selection/activation and activation refuses stale
  results; it remains UI-local by design.
    - [ ] Delete SPCBoyWK's remaining JavaScript stop-and-continue sequencing
  policy after the native transport coordinator exposes that continuation as a
  single event/intent boundary. JavaScript remains presentation/intent code
  until that handoff is migrated.

### Next extraction slices — playback continuation boundary

1. Characterize CocoaSpice's exact natural-end and faded-skip transitions,
   including repeat-off/playlist/song, queue replacement while playing, and
   interruption by a newer user request.
2. Extract a typed shared continuation coordinator above
   `PlaybackTransportCoordinator`. It must own one-shot completion claims,
   stale transition rejection, and the distinction between natural completion,
   faded skip, explicit stop, and replacement. It must not know AppKit,
   WebKit, track models, or decoder details.
3. [x] Extract the first typed continuation decision boundary: the shared
   queue core now returns explicit `play(trackID:)` or `stop` results instead
   of making each frontend interpret a nullable target independently.
4. [x] Extract the one-shot continuation claim into
   `PlaybackQueueCore.PlaybackContinuationGate`. CocoaSpice now uses it instead
   of a local Boolean, and SPCBoyWK claims through its native bridge instead
   of a JavaScript single-flight promise.
5. Wire CocoaSpice back first and retain its existing Swift behavior as the
   characterization reference.
6. Replace SPCBoyWK's `finalizePlaybackEnded`, `playbackGeneration` retirement,
   and queued-skip continuation decisions with the shared coordinator through
   a typed native bridge projection. JavaScript may render the resulting state
   and forward user intents, but must not decide whether a completed session
   advances, repeats, or stops.
7. Add parity fixtures for natural end, end fade, faded skip, Long Play,
   archive-backed VGM, FLAC, and a replacement arriving during completion.

## Non-negotiable rules

- CocoaSpice native Swift is the frontend behavioral reference.
- VGMBoyKit is the decoder, timing, transport, and audio-output authority.
- The abandoned Electron SPCBoy project is not an implementation source.
- Extract behavior; do not redesign it during the extraction slice.
- Do not introduce compatibility fallbacks, alternate routes, silent recovery,
  or duplicate implementations.
- Every extracted component must be linked back into CocoaSpice before it is
  wired to SPCBoyWK.
- A shared module must have one owner, one contract, and one set of tests.
- Database playlist hydration remains a database lookup. It must not walk source
  paths, rescan files, or rebuild the complete UI.
- Catalog duration is display metadata; decoder timing remains playback truth.
- CocoaSpice and SPCBoyWK never import, instantiate, or call playback codec
  bridges. They may call VGMBoy's typed playback facade and format-capability
  manifest only.
- Archive intake is the frontend boundary: CS/SPCBoy resolve archive identity
  through the shared native materializer, then hand VGMBoy a clean extracted
  filesystem path and typed playback intent.
- Archive materialization must remain atomic, dependency-complete, and
  recoverable after interruption.
- Preserve existing unrelated work. In particular, do not include the dirty
  `VGMBoy/vendor/aosdk` state or SPCBoyWK `.DS_Store` in extraction commits.

## Thin-adapter rule

A frontend adapter may translate shared value types into AppKit models, bridge
JSON, or DOM-facing records. It may add frontend-only fields such as native
selection state, focus handles, row geometry, or persistence keys. It must not
reimplement shared sorting, filtering, disambiguation, identity, catalog
aggregation, timing, archive policy, or playback transitions. If an adapter
contains one of those policies, that code is an extraction candidate.

## Current package boundary

Already shared and to be reused rather than copied:

- `VGMBoy/VGMBoyKit`
- `VGMBoy/VGMBoyFormatCore.VGMArchiveMaterializationRequirement`
- `VGMBoy/VGMBoyEndpointCore`
- `CatalogReader/CatalogReader`
- `CatalogReader/CatalogPlaylistCore`
- `CatalogReader/CatalogBrowserCore`
- `CatalogReader/CatalogSessionCore`
- `CatalogReader/FrontendCommandCore`
- `FrontendCore/ArchiveMaterializationCore`
- `FrontendCore.ArchivePlaybackMaterializer`
- `FrontendCore/ArchiveCacheCore`
- `FrontendCore/LocalFileBrowserCore`
- `FrontendCore/FavoriteTrackCore`
- `FrontendCore/FavoriteStoreCore`
- `FrontendCore/FrontendPreferencesCore`
- `FrontendCore/PlaybackTransportCore`
- `FrontendCore/PlaylistIdentityCore`
- `CatalogReader/CatalogSessionCore.CatalogSessionCoordinator`

## Boundary audit — current extraction backlog

The CS/SB sweep confirms that the major catalog, archive, preference, favorite,
local-file, queue, and native playback-command machinery is already shared.
The remaining work is mostly adoption and contract cleanup; it is not a license
to move AppKit or WebKit presentation code into the core packages.

### Concrete extraction or adoption candidates

1. **Adopt `CatalogBrowserProjection` in CocoaSpice.** **Complete.** CS now
   adapts both its shared `CatalogSidebarReader` path and its direct SQLite
   dirty-projection path through `CatalogBrowserProjection`. The duplicate
   `DatabaseSidebarPresentation.disambiguateGameItems` policy was removed;
   CS retains only its native `DatabaseGameItem` adapter, search index, and
   status text. A characterization test now locks the shared natural ordering,
   system disambiguation, and root disambiguation contract.
2. **Extract UI-neutral database group state.** **Complete.** Both frontends now
   use `CatalogBrowserGroupState` through their native Swift boundaries. Both
   retain only rendering, focus, scrolling, and persistence adapters; group
   toggles clear game selection and never activate a child. The contract keeps
   AppKit/WebKit rows, focus, scrolling, animation, and rendering local.
3. **Converge the catalog playlist row envelope.** **Complete for stable row
   identity.** `CatalogPlaylistCore` remains the shared data source, and the
   legacy-safe `pt1` playable identity now lives in `PlaylistIdentityCore` and
   is used by CS and SB. CS still maps rows to native models and SB to bridge
   JSON; those adapters remain intentionally frontend-specific because their
   AppKit/DOM fields differ. The catalog data envelope itself was already
   shared through `CatalogPlaylistTrack`.
4. **Finish Slice 6 transport transition parity.** **Complete at the module
   boundary.** The native request lifecycle,
   serial executor, queue target, and fade policy are shared. Remaining JS/native
   differences are transition presentation concerns (DOM generation, random
   choice, and delayed fade/status handoff). SPCBoyWK now rejects stale
   natural-end finalizers after replacement, with a production-module
   regression test. Live app-boundary interaction remains verification work,
   not an unshared policy implementation.
5. **Extract shared database-search policy.** **Complete.** The incremental
   candidate-index algorithm was extracted from CocoaSpice into
   `CatalogBrowserCore.CatalogSearchIndex`. CocoaSpice now keeps only its
   `DatabaseGameItem` adapter, while SPCBoyWK's authoritative native search
   path uses the same `CatalogBrowserProjection.search`; the duplicate
   immediate JavaScript filter was removed.
6. **Extract the catalog file-tree projection.** **Complete.** CocoaSpice's
   former `DatabaseFileSidebarTree.Index` owned a database-only folder graph,
   stable root/folder identity, deterministic child/file ordering,
   expanded-branch flattening, cancellation checks, and a compact file search
   index. Those policies now live in `CatalogBrowserCore`; neither frontend
   owns a second graph or search implementation.
   The UI-neutral graph/search indexes and nested tree nodes are now in
   `CatalogBrowserCore`. CS is wired back through a `DatabaseFileItem`/native-
   row adapter, while SPCBoyWK consumes the native `databaseFileTree` bridge
   and no longer rebuilds the graph in JavaScript. Keep AppKit/DOM disclosure
   rows, focus, scroll, animation, and persistence local.
7. **Audit catalog playlist hydration as a transaction.** **Complete; no new
   extraction.** CS `PlaylistQueueLoader` and SB
   `loadDatabaseGamesIntoPlaylist` both use the shared `CatalogPlaylistReader`
   projection and `PlaybackQueueState` replacement state. CS's
   `TrackItem`/metadata/column-width construction and SB's bridge/DOM track
   shape are frontend adapters with different fields; do not merge them into
   the core.
8. **Audit sidebar load/session lifecycle.** **Complete; no blind extraction.**
   CS has independent native Games/Files sessions, complete snapshot
   publication, stale-result rejection, and last-snapshot retention on
   failure. SB retains its loading copy and DOM snapshot application locally,
   but its detached catalog requests now use the shared scoped native session
   owner and explicit stale-result envelope.
9. **Unify catalog session generations at the native boundary.** **Complete for
   playlist invalidation; search and snapshot refinements remain.**
   Define a small shared session contract for catalog reads—request generation,
   cancellation/stale-result rejection, and complete-success/error snapshots—
   then wire CS and the WK bridge to it without moving frontend loading copy,
   DOM/AppKit state, or playlist hydration into the core. Add a race fixture
   before changing production behavior. The scoped coordinator, native
   stale-result envelope, and explicit playlist invalidation intent are now
   linked in both apps. Search still retains its DOM query-generation guard,
   and full snapshot success/error envelopes remain a later refinement.

### Explicitly frontend-local

Keep table/DOM rendering, virtualization, autosizing, focus restoration,
selection highlighting, scroll positioning, animation, native menu wiring,
window/settings adapters, and user-facing status wording in their respective
frontends. `DatabaseSidebarLoader` and the SB bridge/JS load lifecycle also
 remain separate only for loading copy, DOM/AppKit state, and rendering. Their
 stale-result ownership now uses the shared native catalog session contract;
 no new generic UI loader should be introduced.

QSF and miniQSF are no longer an app divergence: the shared VGMBoy format
requirement marks both as dependency-complete, so both frontends use the same
`.qsflib`-aware materialization path.

Current high-value CocoaSpice reference implementations:

- `CocoaSpice/Sources/CocoaSpice/App/PlaybackTimingPolicy.swift`
- `CocoaSpice/Sources/CocoaSpice/App/ZipArchiveSupport.swift`
- `CocoaSpice/Sources/CocoaSpice/App/DatabaseSidebarLoader.swift`
- `CocoaSpice/Sources/CocoaSpice/App/LibraryDatabase+ReadQueries.swift`
- `CocoaSpice/Sources/CocoaSpice/App/AppSessionPersistence.swift`
- `CocoaSpice/Sources/CocoaSpice/App/PlaybackRequestState.swift`
- `CocoaSpice/Sources/CocoaSpice/App/PlaybackFormatSupport.swift`

SPCBoyWK files are integration targets, not reference implementations:

- `SPCBoyWK/Sources/SPCBoyWK/WKNativeBridge.swift`
- `SPCBoyWK/Sources/SPCBoyWK/WKPlaybackBridge.swift`
- `SPCBoyWK/Sources/SPCBoyWK/Resources/app-playback.js`
- `SPCBoyWK/Sources/SPCBoyWK/Resources/app-ui.js`
- `SPCBoyWK/Sources/SPCBoyWK/Resources/app-core.js`
- `SPCBoyWK/Sources/SPCBoyWK/SPCBoyPreferencesSnapshot.swift`

## Standard extraction slice

Every component follows this exact sequence:

- [ ] Write the component contract and ownership boundary.
- [ ] Inventory the CocoaSpice implementation and its callers.
- [ ] Add characterization tests around current CocoaSpice behavior.
- [ ] Extract with the smallest mechanical semantic change possible.
- [ ] Link the extracted module back into CocoaSpice.
- [ ] Run CocoaSpice tests and build the actual CocoaSpice target.
- [ ] Verify the affected behavior at the CocoaSpice user boundary.
- [ ] Update current-state subsystem documentation.
- [ ] Commit the shared extraction and CocoaSpice wiring together.
- [ ] Port SPCBoyWK through the same typed contract.
- [ ] Run SPCBoyWK syntax/build/launch checks.
- [ ] Verify parity against CocoaSpice fixtures.
- [ ] Delete the replaced SPCBoyWK policy or bridge duplicate.
- [ ] Commit SPCBoyWK wiring separately.

No slice is complete while CocoaSpice is merely compiling but still using its
old implementation.

### Completed boundary slice — CS CatalogBrowserProjection adoption

- `CatalogBrowserProjection` is now the single source of truth for CS and SB
  game labels, duplicate-title disambiguation, stable ordering, and row-facing
  game identity.
- CocoaSpice's two read paths converge on the same projection: the normal
  `CatalogSidebarReader` path and the dirty-root direct SQLite path both emit
  `CatalogGameBucket` values and use the shared projection before adapting to
  `DatabaseGameItem`.
- `DatabaseSidebarPresentation` no longer owns a duplicate game-label policy;
  it remains responsible only for CS-native status text and search behavior.
- CocoaSpice's complete 42-test suite passes with the shared ordering and
  disambiguation characterization test.

## Remaining execution roadmap

The remaining work is divided into bounded slices after the already-completed
timing, catalog, cache, process, and entry-path work. They run in this order;
each slice ends with the standard CocoaSpice-first verification gate before the
next consumer is changed.

1. **3C — Extract archive tool adapters.** **Complete.** Move CocoaSpice’s exact ZIP, 7z,
   LHA, RSN, and TAR+Zstandard extraction/listing command contracts into the shared
   archive core. Keep executable discovery and error mapping explicit. Relink
   CocoaSpice and prove selected-entry, complete-set, manifest-read, and
   TAR+Zstandard behavior before touching SPCBoyWK.
2. **3D — Extract dependency closure.** **Complete.** The VGMBoy-owned materialization
   requirement contract, shared PSF closure, complete-set extraction, lazyUSF
   aliases, and TXTP cache-only aliases are now extracted. CocoaSpice uses the
   shared alias policies while retaining its cache adapter; SPCBoyWK now sends
   the VGMBoy requirement to the shared dependency-complete materializer. The
   CocoaSpice and SPCBoyWK now use the shared dependency preparation path.
3. **3E — Extract materialization orchestration.** **Complete.** Unify selected-entry versus
   complete-set planning, atomic staging, completion markers, cache identity,
   active-playback protection, release, and interrupted-work cleanup. Keep
   queue ordering and row presentation in each frontend. Verify cold/warm,
   cancellation, replacement, and cache-limit behavior in both apps. The
   archive cache identity, durable/disposable root selection, free-space gate,
   LRU enforcement, and cache-touch behavior are now in `ArchiveCacheCore` and
   CocoaSpice is linked back to that shared store. Cache-backed selected-entry,
   complete-set, and multi-entry staging is now shared, and both cache-lease
   activation and temporary-session release use shared core components. The
   7-Zip/TAR/RSN listing parsing and temporary manifest reads are now shared;
   LHA uses the same 7zz listing/extraction adapter as 7z.
   FrontendCore cold/warm, cancellation, and interrupted-work verification is
   passing. SPCBoyWK now uses the same cache-backed coordinator, shared lease,
   shared tool routing, and shared TZST-capable archive executor; its cache
   controls are native handlers rather than no-op bridge cases.
4. **3F — Unify the archive playback adapter.** **Complete.** Extract the remaining
   frontend-facing selected-entry/complete-set switch, playable-member return
   semantics, dependency preparation, output validation, cache preference
   binding, and release/clear behavior into
   `FrontendCore.ArchivePlaybackMaterializer`. CocoaSpice is relinked first;
   SPCBoyWK now uses the same adapter. The old SPCBoyWK cache materializer
   implementation is removed, and both apps pass the same selected-member /
   complete-set parity fixture. Tool executable overrides remain supported by
   the shared native materializer.
5. **4 — Extract the format/capability manifest.** **Complete.**
   `VGMBoyKit.FormatRegistry.playbackDescriptors` is now the only source for
   frontend extension admission, backend IDs, decoder family, Long Play,
   tempo, and natural-ending capability. CocoaSpice consumes the shared
   extension set and SPCBoyWK projects the same descriptor table into
   JavaScript; neither frontend rebuilds a backend list.
6. **5 — Extract shared playback preferences.** **Complete.**
   `VGMBoyKit.PlaybackPreferences` now owns validation and semantic defaults
   for Long Play, unknown-duration fallback, fade, EQ, volume, mono, and
   native tempo. CocoaSpice and SPCBoyWK retain only their persistence/JSON
   adapters and presentation state. The unknown-duration default remains
   distinct from Long Play; finite FLAC and other metadata-bearing audio never
   receives that cap.
7. **6 — Extract shared transport request state.** **In progress: native
   command boundary complete; frontend transition parity remains.**
   `FrontendCore.PlaybackRequestCore` now owns newest-request-wins lifecycle
   semantics and the serial command executor. CocoaSpice's existing VGMBoy
   queue is relinked through `PlaybackSerialExecutor`; SPCBoyWK's native
   bridge uses the same executor, closing the detached-request race without
   moving work onto the UI thread. JavaScript still owns WebKit transition
   ordering, stale DOM generation checks, random selection, and fade handoff;
   those must be characterized before any further removal. The ordinary
   natural-end repeat target is now extracted into
   `FrontendCore.PlaybackQueueCore.PlaybackRepeatMode` and
   `PlaybackQueueNavigation.completionTargetID`; CocoaSpice calls it directly
   and SPCBoyWK's native bridge exposes the same contract to WebKit. The
   remaining frontend policy is limited to random candidate selection, fade
   presentation, and generation/status handoff. Shared
   `FrontendCore.PlaybackTransportCore.PlaybackFadePolicy` now owns queued
   adjacent-track fade eligibility and duration; SPCBoyWK asks the native
   bridge for that result. SPCBoyWK pause/resume and seek
   now use the already-loaded VGMBoy session through the shared `play` and
   `seek` control commands rather than reloading a file.
8. **7 — Reduce SPCBoyWK to presentation and close parity.** Delete replaced
   JS/native policy duplicates, keep named intents plus typed snapshots/status,
   run representative archive/catalog/FLAC/SID/Long Play fixtures, and verify
   both real app boundaries. This is the final shell-reduction gate.

The next implementation pass is **Slice 6 frontend transition parity**. The
catalog boundary-adoption sweep is complete: CocoaSpice and SPCBoyWK now use
the same game projection, while CS retains only its native row adapter and
status/search presentation. The remaining comparison is the CocoaSpice and
SPCBoyWK replacement, pause/resume, seek, faded-skip, natural-end, and
stale-request handoffs against the same typed VGMBoy status contract.

The first transport finding is now corrected: SPCBoyWK's bridge had collapsed
a loaded paused VGMBoy session into `stopped`. The bridge now emits `paused`
for that state, leaving `VGMBoyKit.PlaybackController` as the shared command
owner and keeping only the JSON status projection in the WebKit adapter.

The current parity pass also removed a misleading SPCBoyWK boundary: partial
`setPlaybackSettings` calls were accepted and discarded by the native bridge.
Both frontends now use their typed persisted preference model, then send
Long Play/unknown-duration intent through the same `VGMBoyKit.PlaybackTimingRequest`
at playback start. The recent UI-specific boundary fixes are deliberately local
and now implemented: SPCBoyWK Enter activates the focused row, and CocoaSpice
explicitly restores the playlist table first responder after Enter so arrow
navigation retains the activated cursor. CocoaSpice disclosure also preserves
the viewport when expansion does not change selection. These still need live
user-boundary verification after the latest builds; they are not extraction
candidates.
The natural-end repeat decision is no longer a duplicated frontend policy,
SPCBoyWK no longer reloads on pause/resume or seek, and fade eligibility is
shared. Pending fades now cancel on seek and database playlist replacement,
restore the output envelope, and validate VGMBoy's native generation before a
delayed callback can advance. The remaining parity work is final runtime
fixture coverage for the WebKit-side stale-status and interrupted-fade cases.

Runtime evidence already passing: the VGMBoy live-controller fixture creates a
real temporary WAV session, preserves one native generation across start,
pause, seek, and resume, and exercises fade-down/fade-up restoration. The
focused test completed successfully in 2.403 seconds. The current production
SPCBoyWK bundle also rebuilt and launched successfully. The remaining evidence
gap is specifically an interactive WebKit sequence that queues a faded skip,
then interrupts it with seek or database replacement while a stale native
status callback is in flight. The real `app-playback.js` module now has a
narrow Node boundary harness at
`SPCBoyWK/Tests/SPCBoyWKTransport.test.js`; it verifies stale-generation
rejection and queued-fade cancellation against the production module. The
remaining evidence gap is only the live WebKit interaction sequence, not an
untested transport branch.

The opt-in FLAC fixture also passes against a real temporary FLAC: VGMBoy
reports its full natural duration, renders PCM, and seeks successfully. The
2:36 value is therefore the explicit unknown-duration safety window when no
natural duration is available, not the ordinary FLAC metadata path.
Only after that characterization should the remaining JavaScript transport
coordinator be reduced. No database hydration or playlist UI code belongs in
this transport slice.

## Slice 4 — Shared format descriptors

Status: **complete**

`FormatRegistry.playbackDescriptors` is derived from VGMBoy's decoder-family
registry in stable backend order. It carries the extension set and the
frontend-relevant timing capabilities. The VGMBoy descriptor test verifies
that every descriptor maps back to its family and that the union is complete.
CocoaSpice now consumes `FormatRegistry.playbackExtensions`; SPCBoyWK emits
the descriptors as a projection for its renderer.

## Slice 5 — Shared playback preferences

Status: **complete**

`PlaybackPreferences` normalizes the shared semantic values while each app
keeps its own UserDefaults or JSON keys. CocoaSpice preserves its legacy
stored-shape compatibility adapter; SPCBoyWK normalizes its JSON snapshot.
The shared test covers ten-band EQ normalization, volume clamping, tempo
normalization, fade, mono, and the independent unknown-duration setting.
Runtime CocoaSpice and SPCBoyWK audio configuration now also passes through
that same normalizer before reaching VGMBoy.

## Slice 6 — Shared transport boundary

Status: **native playback workflow complete; GUI transition policy remains**

`PlaybackSerialExecutor` is the exact low-level extraction of the native
single-session command queue: CocoaSpice uses it for the existing VGMBoy
worker and SPCBoyWK uses it around `WKPlaybackBridge`. `PlaybackRequestLifecycle`
is linked into CocoaSpice's pending-request state. The remaining work is not
to duplicate that code in JavaScript. SPCBoyWK's former playback coordinator,
split archive materialize/load/play task, preload no-ops, and dead metadata
hydration workers are removed. `nativePlaybackStart` now performs the complete
native start workflow and rejects superseded requests. The remaining work is
to characterize which WebKit queue/fade/repeat decisions can safely consume
the typed native status without making playlist hydration or ordinary UI
operations await playback.

### Transition comparison before further removal

The CocoaSpice reference has two distinct protections: `PlaybackRequestState`
invalidates a pending UI request before replacement, while
`VGMBoyPlaybackEngine` uses one serial worker and a latest-request token around
the typed core commands. Native status publication is observational and
natural-end handoff is decided from drained native output.

SPCBoyWK now sends one native playback-start intent; Swift owns archive
materialization, timing, stale-request rejection, load, seek, and play. The
remaining `app-playback.js` layer owns DOM-generation guards, pushed-status
presentation, faded-skip presentation, random selection, and status-driven
handoff. Ordinary repeat target selection is now shared through `PlaybackQueueCore`. The shared
`PlaybackSerialExecutor` closes the detached native-request race. The remaining
parity slice must characterize direct pause, stop, seek, faded-skip, and
natural-end paths before moving more lifecycle authority across the WebKit
boundary. A native request token must not turn a database lookup or ordinary UI
update into an awaited playback operation.

## Slice 0 — Baseline and parity fixtures

Status: **complete for the timing slice; maintained throughout the program**

Capture the behavior that must survive extraction:

- Database game selection hydrates playlist rows immediately from SQLite.
- Large libraries do not trigger a full playlist/UI rebuild.
- Sidebar path and file indicators remain intact.
- Archive-backed PSF, miniGSF, 2SF, and lazyUSF dependencies materialize as a
  complete playable set.
- FLAC uses decoder-reported duration and plays to its natural end.
- SID with no authored duration uses the configured unknown-duration policy.
- Long Play affects only families that support it.
- End fade, faded skip, seek, stop, replacement, and completion remain stable.
- EQ, mono, app volume, tempo, and status diagnostics remain unchanged.

Required fixture classes:

- Finite FLAC with a duration greater than 2:30.
- Metadata-less SID.
- Metadata-bearing libgme/libvgm track.
- Metadata-less loop-capable track where available.
- Archive-backed dependency set.
- Large catalog/database playlist activation.

## Slice 1 — Shared playback timing policy

Status: **complete**

Reference: CocoaSpice `PlaybackTimingPolicy`, CocoaSpice playback options, and
the existing VGMBoyKit `PlaybackTimingRequest`.

Extract into VGMBoyKit or a directly associated shared playback package:

- `PlaybackTimingPreferences`.
- `PlaybackTimingRequest`.
- `PlaybackTimingPreview`.
- Natural-duration, Long Play, fade, and unknown-duration rules.

The contract must distinguish:

- decoder-natural duration;
- explicit Long Play duration;
- explicit timed/faded-skip duration;
- configurable unknown-duration default.

The unknown-duration default is separate from Long Play. Its default remains
150 seconds, but it must be user-configurable. Metadata always wins. A normal
FLAC/WAV/MP3/M4A request must never receive this cap.

CocoaSpice work:

- Replace its local timing plan with the shared policy.
- Persist the new unknown-duration value through its native preferences.
- Keep the existing Long Play setting and semantics unchanged.
- Make the displayed effective duration match the actual core request.

SPCBoyWK work, only after CocoaSpice passes:

- Remove timing-mode selection from `app-playback.js`.
- Remove provisional manual-duration behavior for no-length rows.
- Receive the shared effective timing/readout from Swift/native playback state.
- Persist the same setting through the WK preferences snapshot.

Completed SPCBoyWK contract portion:

- Files-sidebar source selections now use shared `CatalogSourceSelection`
  projections rather than one bespoke root/path query per row.
- Folder-sidebar selections now use the shared root-path folder projection.
- The typed native playback request carries the shared unknown-duration value.
- SPCBoyWK persists and displays that value beside Long Play. It remains
  independent from the Long Play target and does not cap finite audio.
- JavaScript syntax checks passed; the production SPCBoyWK bundle rebuilt and
  was opened successfully.
- SPCBoyWK remains a presentation adapter: JSON carries shared Swift results,
  while DOM rendering and queue presentation stay local.

Acceptance criteria:

- SID set to 5:00 plays for 5:00 plus fade in both apps.
- FLAC remains its natural length regardless of that setting.
- Long Play and unknown-duration default can be changed independently.
- Both apps report the same effective duration and end at the same point.

Completed CocoaSpice portion:

- `PlaybackTimingPreferences`, `PlaybackTimingMetadata`, and
  `PlaybackTimingPlan` now live in VGMBoyKit.
- CocoaSpice's native timing policy is a thin adapter over the shared policy.
- CocoaSpice persists and displays the unknown-duration default beside Long Play.
- VGMBoy's typed request and controller accept the configured unknown-duration
  window without applying it to finite decoder-natural audio.
- VGMBoy tests: 50 passing. CocoaSpice tests: 41 passing.
- CocoaSpice production bundle rebuilt and relaunched successfully.
- VGMBoy commit: `3cbb0f1`.
- CocoaSpice commit: `56bd8e9`.

SPCBoyWK consumes this contract through `nativePlaybackStart`; JavaScript no
longer selects the native timing mode or performs a second metadata pass.

## Slice 2 — Catalog projection and hydration

Status: **complete**

Reference: CocoaSpice’s database-first native loading and cancellation flow.

Extract the reusable Swift layer around:

- database root/game/file snapshots;
- catalog playlist track projections;
- source/archive/member/subtrack identity;
- metadata and duration fields;
- generation cancellation and latest-request ownership;
- unchanged-result reuse.

Likely destination: `CatalogReader` plus a new narrow catalog-session target
only if the existing `CatalogBrowserCore` boundary cannot own the lifecycle.

CocoaSpice work:

- Move reusable query/projection logic out of `LibraryDatabase+ReadQueries.swift`.
- Keep CocoaSpice-specific row presentation and queue decisions local.
- Keep SQLite read-only and database-first.

Completed CocoaSpice portion:

- `CatalogReader` now owns exact source-selection, folder-descendant, and
  path-index playlist projections through one read-only boundary.
- `CatalogSourceSelection` preserves root ID plus source path as one stable
  selection identity; no filesystem inference is needed.
- CocoaSpice's local SQL for Files, folder, and path hydration was removed.
  Its remaining adapter creates native `TrackItem`, `TrackMetadata`, and
  column-width hints from shared `CatalogTrack` rows.
- CatalogReader tests cover all three projections; CocoaSpice's full 41-test
  suite passes after rewiring.
- `CatalogSessionCore` now owns the exact extracted `LatestTaskOwner` behavior
  and raw Games/Files bucket reads. CocoaSpice no longer contains its own task
  owner implementation and routes sidebar bucket access through the shared
  reader while retaining native row/tree projection.
- CatalogSessionCore lifecycle tests pass; CocoaSpice's full 41-test suite,
  debug build, production bundle build, and launch pass after relinking.

SPCBoyWK work:

- Make `WKNativeBridge` serialize the shared Swift projection rather than
  reconstructing its own response semantics.
- Adopt `CatalogSessionCore`'s shared sidebar read/lifecycle contract in the
  native bridge where its current asynchronous boundary can consume it without
  moving DOM presentation into Swift.
- Keep JSON as a transport format only.
- Leave DOM row rendering in JavaScript.
- The native bridge now returns the shared catalog rows directly; JavaScript
  retains only row mapping, selection, and DOM rendering. Dead preload and
  metadata-hydration workers were removed.

Acceptance criteria:

- Database playlist activation performs no source-path scan or decoder scan.
- Selection, archive identity, subtrack, duration, and path/file indicators
  match between both apps.
- Large catalogs do not synchronously rebuild the full WK or SwiftUI surface.

## Slice 3 — Archive materialization and cache foundations

Status: **process, entry-path, tool-routing, format-requirement, dependency, cache-identity, cache-backed orchestration, temporary-session, listing, and manifest-read boundaries extracted and wired**

Reference: CocoaSpice’s native `ZipArchiveSupport` behavior, not the WK shell.

Extract reusable foundations from the 1,489-line CocoaSpice implementation into
`ArchiveMaterializationCore`:

- atomic extraction/materialization;
- complete dependency-set resolution;
- archive-member identity;
- active playback lease;
- cache limits and summaries;
- stale/interrupted work cleanup;
- release/clear semantics;
- explicit hard failures.

Keep frontend-owned:

- queue ordering;
- which archive entries become playlist rows;
- app-specific cache presentation;
- local browser behavior.

Current bounded slice:

- `ArchiveCacheCore` owns exact cache-root recovery, disposable cleanup, and
  protected-root LRU pruning plus the thread-safe active-playback lease
  and cache-policy value model extracted from CocoaSpice. `ArchiveCacheStore`
  now also owns the exact archive identity key, root selection, free-space
  gate, policy enforcement, and cache-touch operations.
- `VGMBoyFormatCore.VGMArchiveMaterializationRequirement` and
  `VGMBoyKit.FormatRegistry.archiveMaterializationRequirement(for:)` now own
  the format decision about selected-entry versus complete-set preparation.
- `ArchiveMaterializationCore.ArchiveMaterializer` now consumes that typed
  requirement, owns selected-entry PSF dependency closure, complete-set
  extraction, and dependency-complete temporary directories through the shared
  `ArchiveMaterializationSession`.
- `ArchiveMaterializationCore.ArchiveDependencyPreparation` now owns the exact
  lazyUSF extensionless aliases and TXTP cache-only aliases extracted from
  CocoaSpice. CocoaSpice calls those shared policies directly.
- `ArchiveMaterializationCore.ArchiveProcessRunner` now owns the bounded
  process permit, cancellation/timeout wait, stdout capture, output limit, and
  stderr collection mechanics used by CocoaSpice. CocoaSpice retains its
  format-specific process topology, executable discovery, arguments, and
  error vocabulary.
- `ArchiveMaterializationCore.ArchiveEntryPath` now owns the exact shared
  archive-member normalization, traversal check, safe destination components,
  and BSD tar octal-display preservation used by CocoaSpice and the SPCBoyWK
  materializer.
- `ArchiveMaterializationCore.ArchiveCacheMaterializer` now owns shared
  cache-backed warm-hit, atomic staging, completion-marker, selected-entry
  identity, cache-limit, and cache-lease activation behavior. CocoaSpice keeps
  only its archive-tool closures and format-specific TAR pipeline.
- `ArchiveMaterializationCore.ArchiveListingParser` now owns bounded pure
  7-Zip/TAR/RSN listing parsing and reversible BSD-tar octal pathname
  rendering. `ArchiveManifestReader` owns temporary, non-cache manifest reads;
  CocoaSpice retains only process execution and tool selection.
- `ArchiveMaterializationCore.ArchiveContainerKind` and
  `ArchiveToolRouting` now own exact container detection and ZIP/7z/RSN/plain
  TAR/TAR+Zstandard command specifications. CocoaSpice executes those typed
  invocations through its native runner; SPCBoyWK's selected-entry materializer
  now uses the same routing for standard archive formats.
- CocoaSpice keeps archive format detection, process/tool execution, cache
  preference persistence, lease cleanup scheduling, and UI commands local
  until each remaining boundary is characterized independently.

Completed cache-lifecycle portion:

- `FrontendCore` tests cover abandoned-root recovery and protected/active-root
  LRU behavior.
- CocoaSpice's full 41-test suite, production bundle build, and launch pass
  after relinking to `ArchiveCacheCore`.
- No queue behavior was redesigned during these extractions. CocoaSpice still
  supplies its cache and UserDefaults adapters, but dependency preparation is
  now shared. SPCBoyWK no longer performs bridge-local dependency extraction;
  it passes the VGMBoy requirement to `ArchiveMaterializer`.
- The shared process runner is covered by output, file-output, non-zero-exit,
  and output-limit tests. CocoaSpice's native zstd/tar pipeline still uses its
  own format-specific connected-process wiring over the shared permit/wait
  primitives.
- The shared entry-path contract is covered by separator, traversal, dot-path,
  and BSD tar octal-name tests. CocoaSpice delegates its existing path helpers;
  SPCBoyWK consumes the same contract through `ArchiveMaterializer`.
- The shared routing contract is covered by container detection, exact 7z/RSN
  arguments, TAR pipeline arguments, and a real 7z materialization fixture.
  `ArchiveMaterializer.execute` now exposes the shared connected TZST executor
  to cache-backed consumers; CocoaSpice retains only its specialized listing
  and raw-name scan path where its existing behavior still needs a later
  parity fixture.

CocoaSpice calls the shared cache materializer for its cache-backed entry,
complete-set, and multi-entry paths without changing cold/warm behavior or
lease protection. SPCBoyWK now calls the same coordinator through
`SPCArchiveMaterialization`; `WKNativeBridge` routes cache configuration,
summary, location, and clear operations to that adapter. Archive-tool execution,
including the connected TZST pipeline, is delegated to the shared
`ArchiveMaterializer.execute` boundary, so WK does not grow a second extractor.
FrontendCore's explicit cold/warm, cancellation, and interrupted-work tests
pass; app-level parity fixtures remain the next verification gate.

## Slice 4 — Format and capability manifest

Status: **complete**

Make VGMBoy’s format registry the single capability source for both apps:

- extension admission;
- decoder family;
- Long Play support;
- tempo support;
- natural-ending behavior;
- playback versus dependency/admission role.

Remove CocoaSpice’s duplicated `PlaybackFormatRegistry` capability lists.
SPCBoyWK already receives a Swift-generated backend manifest and should consume
the complete shared descriptor without reinterpreting it in JavaScript.

Add registry coverage tests that compare every admitted extension and capability
across the core, CocoaSpice, and SPCBoyWK boundaries.

## Slice 5 — Shared playback preferences

Status: **complete**

Extract a pure Swift preference model covering:

- Long Play enabled and duration;
- unknown-duration default;
- end fade;
- EQ;
- volume and mono;
- libgme/libvgm tempo and speed settings.

CocoaSpice `AppSessionPersistence` and SPCBoyWK
`SPCBoyPreferencesSnapshot` become persistence adapters over the shared model.
App-specific UserDefaults keys and migration code remain local, but validation,
defaults, and semantic names become shared.

## Slice 6 — Shared transport request state

Status: **complete for native command state; frontend queue/status policy remains**

Reference: CocoaSpice’s native `PlaybackRequestState` and queue replacement
behavior.

Extract only frontend-independent request mechanics:

- generation tokens;
- cancellation;
- newest-request-wins replacement;
- resume position;
- status normalization;
- completion handoff.

Keep repeat, shuffle, queue membership, and database selection in each app.
SPCBoyWK's JavaScript playback coordinator has been removed. `nativePlaybackStart`
now performs materialization, timing normalization, stale-request rejection,
load, seek, and play through the shared serial native boundary. JavaScript still
owns queue choice, repeat, faded-skip presentation, and status rendering.

## Slice 7 — SPCBoyWK reduction to presentation

Status: **in progress; native playback task layer extracted**

After the shared Swift boundaries are proven in CocoaSpice, reduce SPCBoyWK so:

- JavaScript renders controls and rows.
- JavaScript sends named user intents.
- Swift returns typed/shared snapshots and status.
- JavaScript does not decide timing, decoder family, archive policy, catalog
  hydration, fallback duration, or metadata authority.

The former JavaScript coordinator, split archive playback workflow, preload
no-ops, and metadata-hydration workers are gone. Remaining JavaScript is the
WebKit presentation/interaction layer plus frontend queue policy and status
projection.

The WK bridge remains narrow and explicit. Missing resources and invalid
requests fail loudly.

## Validation gates

Every slice must pass all applicable gates:

- shared-package unit tests;
- CocoaSpice tests;
- CocoaSpice production build and launch;
- user-boundary verification in CocoaSpice;
- SPCBoyWK JavaScript syntax check;
- SPCBoyWK clean production rebuild through `launch.sh`;
- active-process verification;
- representative archive, catalog, FLAC, SID, and loop-format fixtures;
- `git diff --check` and clean scoped commit;
- no copied implementation left behind;
- current-state subsystem documentation updated.

## Current parity slice — shared preferences, cache, and AAC boundary

Status: **implementation complete; validation in progress**

FrontendCore now owns the typed preferences store/coordinator used by both
native frontends for animation flags, durations, column auto-size, and window
levels. Archive cache choices are canonicalized to 2, 4, 8, and 16 GB with a
2 GB default. CocoaSpice exposes a configurable End Fade duration while
VGMBoyKit remains the owner of timing policy and offline AAC conversion.
SPCBoyWK now uses the same cache choices, combines sidebar/playlist font
controls into one Interface Style surface, and reaches VGMBoyKit AAC export
through a thin asynchronous WK bridge that materializes archive members first.

## Commit discipline

Use separate commits for:

1. shared extraction plus CocoaSpice wiring;
2. CocoaSpice tests/documentation if they cannot remain atomic;
3. SPCBoyWK adapter migration;
4. deletion of obsolete WK policy code.

Do not mix unrelated UI changes, Electron work, scanner changes, vendor changes,
or cleanup of existing user state into extraction commits.

## Definition of done

The extraction program is complete when CocoaSpice and SPCBoyWK share the same
Swift contracts for playback timing, catalog projections, archive materialization,
 format capabilities, preferences, and native transport commands; CocoaSpice
 retains its native behavior; SPCBoyWK’s JavaScript contains presentation,
 event wiring, and explicitly frontend-owned queue policy only; and ScanSong continues to consume shared scanner/format inputs without
linking a player frontend.
