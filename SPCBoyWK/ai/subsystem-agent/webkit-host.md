# WebKit Host

## Scope

The native executable owns the application window, a single WKWebView, and
the `spcBoyWK` message bridge.

## Ownership

Swift owns native capabilities, catalog/playback bridges, persistent settings,
sidebar resolution, and favorite mutation. The web resources own DOM
presentation, CSS animation, and user-interaction forwarding.

Frontend settings cross the bridge as a JSON projection of the typed Swift
`SPCBoyPreferencesSnapshot` and are retained by native `UserDefaults`. Browser
`localStorage` and the retired favorites migration payload are not part of the
runtime persistence path.

There is one settings write path: `frontendSettingsSave` persists the complete
typed snapshot. The retired partial `setPlaybackSettings` request and its
change-event path are intentionally absent; they were no-op plumbing that made
Long Play appear to have a native settings interface while playback actually
read a different state. Long Play changes now persist through the snapshot and
cross the shared VGMBoy boundary at both `nativePlaybackStart` and
`nativePlaybackReconfigure`. The separate Options WebView relays timing fields
to the main WebView, which asks VGMBoyKit to reconfigure the loaded session
without losing position or paused state.

The shared `FrontendPreferencesCore` contract owns the validated animation
timing range, 200 ms defaults, and the eight-point-per-side playlist header
minimum padding. DOM font measurement, geometry, and CSS remain WebKit-owned
so SPCBoy keeps its rendering style; native Swift owns persistence and window
levels. The sizing value crosses the typed settings snapshot rather than
becoming a second per-column policy in JavaScript.

The accent color is a persisted CSS color in the typed settings projection.
`app-ui.js` applies it as the root `--accent` value, and both the sidebar and
playlist use the same moving accent capsule. Selected-row backgrounds remain
transparent so a second instantaneous paint cannot flash over the capsule.
Selection never changes sidebar or playlist text color: users choose accent
and text colors with the contrast they want. Active toolbar and option controls
use the same accent surface.

`FrontendOptionsManifest` provides the common Database, Interface, and Windows
organization through the bridge. `options-controller.js` applies that manifest
and `playlist-controller.js` reduces selection. `app-ui.js` remains the
renderer and event wiring layer rather than the owner of those policies.
Database Console → Game group disclosure and selection also pass through the
shared `CatalogBrowserGroupState` reducer through its direct
`CatalogBrowserGroupStateRequest` codec. The Swift bridge publishes the
shared natural group order, canonical game IDs, and each game's
`consoleGroupName`; WebKit maps those IDs into DOM rows and does not regroup or
sort console labels or rebuild native disclosure state. WebKit retains only DOM
rows, focus, scrolling, and persistence projection.

`CatalogPlaylistPresentationCore` supplies ordered catalog playlist rows with
their visible fallback text and non-pixel column-content hints. `WKNativeBridge`
serializes that projection, retains a bounded native sort session, and applies
its `CatalogPlaylistSorting` comparator only after an explicit user sort
gesture; `app-ui.js` sends that session ID and current row IDs, then applies the
returned identity order. WebKit keeps font measurement, column sizing,
animation, and DOM reordering only. It must
not rebuild archive-member filenames, metadata fallback text, duration labels,
an implicit default catalog sort, or a second catalog sort comparator.

The AppKit host owns Cmd-Q, Cmd-W, Cmd-M, Cmd-O, native file/folder selection, and menu dispatch. Shared semantic
shortcut names and default keys come from `FrontendCommandCore`; WebKit receives
the remaining frontend commands through the narrow `SPCBoyWK` dispatcher.

Transport regression coverage lives in
`Tests/SPCBoyWKTransport.test.js`. It executes the production
`Resources/app-playback.js` module and covers stale native-generation
rejection, restoration of output when a queued adjacent fade is cancelled,
dropping a natural-end finalizer after a newer replacement request, and
advancing after the completed native session is retired.
This is module-boundary coverage; a live WebKit interaction test remains a
separate app-boundary check.

The renderer suite reads CocoaSpice's canonical
`Tests/CocoaSpiceTests/cross-app-playlist-activation-v1.json` directly. It loads
the production selection controller, UI, and playback modules to exercise
focused-row activation through the native-start request, preserving the
native-supplied playable ID, archive member, and subtrack across metadata changes.
Native ID construction is checked by CocoaSpice's fixture consumer; the WK
test does not generate or validate native catalog projections.

Start, stop, initialization, and failed-start cleanup retain their captured
renderer generation across bridge awaits. Recheck it before sending the next
native command or publishing state: after fade/unload, power-save changes,
initialization/audio configuration, and failed-start close. An obsolete stop
must not clear the replacement's presentation; an obsolete close reply must
not reset its initialization flag. Current-start failures still close and
surface the original error. Shared native serialization cannot identify an
obsolete renderer intent sent as a new command.

Deferred-response tests exercise replacement and explicit stop during start
preparation, replacement during stop/fade/error cleanup, late native-start
success and failure, and an obsolete completion response containing a next-track
action. These tests control reply ordering rather than relying on elapsed sleeps.

Pause, resume, seek, and adjacent intents capture their renderer generation too.
A seek captures its requested offset before awaiting fade cancellation and starts
a new renderer generation, so a late earlier seek cannot rewind the same track.
Adjacent queue/fade replies are ignored after supersession. A queued-fade status
reply must still match both the original queued request object and its generation
before completion retirement or cancellation. The second-skip path awaits its
fade, stop, and native-selected queue handoff instead of detaching the operation.
Shared native code continues to select the target and compute fade policy.

`SPCBOY_TEST_PLAYBACK_SOURCE` lets the renderer tests run against an explicit
app-playback.js file, including the packaged resource. It changes only test input;
production resources and runtime routing do not read that environment variable.

Archive-backed playback must receive a clean path from
`FrontendCore.ArchivePlaybackMaterializer`. The required selected-entry or
complete-set preparation is a VGMBoy format capability; extraction, cache
identity, atomic staging, dependency preparation, output validation, lease
protection, and the connected TZST tool pipeline are shared with CocoaSpice.
ZIP, 7z, LHA, RSN, and TAR+Zstandard use the shared archive boundary. Amiga
members identified by UADE filename prefixes use complete-set preparation so
their player/sample companions remain available; an LHA member is not treated
as a standalone suffix-only file. MDX keeps a matching PDX bank as dependency
data and never exposes the PDX as a playlist row.
`SPCArchiveMaterialization` is only the WK preference/cache adapter, and
`WKPlaybackBridge` may request materialization only through that shared core;
it must not implement archive extraction or access decoder implementations
directly. The bridge's cache settings, summary, location, and clear commands
must remain native and functional rather than no-op placeholders.

`nativePlaybackStart` directly decodes `PlaybackTransportStartRequest`. The
request carries the renderer's stable track ID, source/archive reference,
timing, tempo, and seek offset; after any adapter-owned materialization,
`PlaybackTransportCore` performs the shared load/seek/play sequence. Do not
reconstruct `PlaybackControlPayload` from bridge dictionaries or use the cache
path as the transport's track identity.

Playback timing is resolved by the native bridge through the shared `VGMBoyKit.PlaybackTimingPolicy`
and `PlaybackTimingRequest` boundary used by CocoaSpice. JavaScript asks for and caches that plan
for the active track, then uses the same plan for its readout and native start request. JavaScript
forwards Long Play and deliberate faded-skip intent; it does not choose the core's standard/timed
duration policy. Ordinary finite audio therefore reaches VGMBoy with decoder-natural timing, while
Long Play is the only normal path that supplies a manual length.

`nativePlaybackTiming`, `nativePlaybackReconfigure`, and `nativePlaybackSetTempo` directly decode
the shared `PlaybackTimingPreviewRequest`, `PlaybackTransportReconfigurationRequest`, and
`PlaybackTransportTempoRequest` codecs. The contracts retain the established WebKit JSON keys but
own preview scaling, control-payload construction, and tempo normalization; the WK bridge must not
parse individual timing fields, calculate a multiplier, or build a `PlaybackControlPayload` itself.
Live Play Speed edits must refresh the timing preview and use `nativePlaybackReconfigure` with the
new plan and tempo. `nativePlaybackSetTempo` alone changes the decoder multiplier but leaves the
currently loaded timing cap unchanged.

`nativePlaybackAudioConfig` receives one object decoded as
`PlaybackTransportAudioConfigurationRequest` rather than positional arguments. The shared transport
normalizes and serializes the volume, EQ, and mono commands together. Both initial setup and option
changes send the complete snapshot, so a persisted mono choice is applied before the first track.
Timing and tempo settings carry both the renderer playback generation and a
settings-request revision across bridge awaits. A late timing plan, reconfigure
reply, or `set_tempo` status may not update a replacement track or supersede a
newer setting. This is a WebKit presentation-ordering guard only; the shared
transport remains the sole owner of the native timing and tempo mutation.
For a row without catalog timing, the shared plan uses the persisted unknown-duration fallback
when Long Play is off; the native standard request leaves the play length unset and VGMBoyKit
applies the same policy. An explicit Long Play value is passed through without the former
30-second/900-second renderer clamp; zero is the unbounded value and is represented as a zero
total in the timing contract. Native status remains the playback authority for position and end
state.

The bridge preserves the distinction between a loaded paused session and a
stopped session in its JSON status projection. It emits `paused` when VGMBoy
is not playing, has not naturally ended, and the bridge still owns a loaded
track, keeping WebKit diagnostics aligned with CocoaSpice's native status
model.

Native playback status remains authoritative for elapsed position, pause, seek,
tempo, and end state. While transport is playing, WebKit projects a small
monotonic clock between native status anchors so the visible readout moves
smoothly between the shared coordinator's status broadcasts. The projection is
cancelled on pause, stop, replacement, and natural end; it never polls the
decoder or advances playback itself.

Every shared status reply and broadcast also carries a monotonic
`status_sequence`. The renderer retains the newest sequence and discards a
delayed older event before it can clear an active clock or regress transport
state. Generation still protects track identity; the sequence protects event
ordering within one track.

The native bridge projects `VGMBoyKit.FormatRegistry.playbackDescriptors` into the WebKit backend
manifest; JavaScript only indexes and displays that projection. `SPCBoyPreferencesSnapshot`
normalizes timing, fade, EQ, volume, mono, and native-tempo values through
`VGMBoyKit.PlaybackPreferences` before persisting the frontend JSON shape.

AAC export is a native offline task: `WKPlaybackBridge` forwards VGMBoy frame
progress and terminal events to both the main and Options windows. The WebKit
surface only renders those events and can request cancellation; VGMBoy removes
the temporary partial file rather than exposing an incomplete `.aac` result.
`nativeExportAAC` and `nativeExportAACCancel` decode the shared typed export
and cancellation contracts. The WK adapter may materialize/release an archive
member and report progress, but it must not parse export fields or construct
the `AACExportRequest` consumed by the shared transport.

Database search uses the shared `CatalogBrowserCore.CatalogSearchIndex` matching
policy over the already-published native game projection. The projection carries
the complete normalized search text; WebKit maintains only a transient index
over that field rather than rebuilding the all-terms fields (`name`, system,
root, and display name), so each keypress filters immediately without a bridge
round-trip or debounce. Native remains responsible for publishing and
refreshing the authoritative game projection; WebKit does not scan paths or
decode metadata to answer search input.

SPCBoyWK is database-only with two catalog projections: Console View and a
read-only Path View. The maintained sidebar does not expose a local folder
browser or an Open Path flow. ScanSong remains responsible for scanning and
publishing the catalog; SPCBoyWK reads it and sends playable identities to
VGMBoy.

The shared catalog order is the initial playlist order. WebKit does not sort a
catalog projection merely because it measures columns or renders a header; a
header click explicitly enables the shared presentation sort. Legacy
stored sort columns predate that opt-in flag and therefore do not reorder a
newly loaded catalog projection.

Catalog playlist replacement invalidation is native-owned through
`CatalogSessionCore.CatalogSessionCoordinator`. WebKit sends the named
`catalogSessionInvalidate("playlist")` intent before replacing or reading
playlist rows; a detached request from an older playlist generation receives
`{ "stale": true }` and cannot publish rows. The remaining
`browserSelectionGeneration` protects DOM focus/selection ordering only.

All typed VGMBoy commands sent through `WKPlaybackBridge` are serialized by
the shared `FrontendCore.PlaybackTransportCore.PlaybackTransportCoordinator`,
which also exposes one generation-checked natural-end event for queue
continuation.
Synchronous bridge replies and pushed playback events both derive from that
same `PlaybackTransportStatus` snapshot and its shared
`PlaybackTransportStatusPayload` projection; the WK layer must not re-query or
independently reconstruct VGMBoy diagnostics.
The bridge no longer owns a `PlaybackController`, serial executor, or native
request-generation lock. The remaining JavaScript layer owns WebKit interaction
ordering, the renderer playback-generation guard, bounded clock interpolation,
queued-fade timers, and the final presentation handoff; it does not own decoder,
queue-target, repeat, completion-claim, or session-retirement policy. The shared
native coordinator is the non-UI safety boundary that prevents concurrent
detached bridge requests from racing one playback session.

Natural-end completion claiming, repeat/advance decision, and retirement of
the completed native session also live on that shared transport coordinator.
`WKNativeBridge` directly decodes the JSON envelope as
`PlaybackContinuationRequest`, delegates it through `WKPlaybackBridge`, and
encodes the resulting `PlaybackContinuationResponse`; it does not reconstruct
field dictionaries or retain a second
`PlaybackContinuationCoordinator`. Completion retirement releases the active
archive materialization in that serialized boundary, so there is no second
JavaScript release request. WebKit then performs the intentionally UI-local
renderer handoff: clear its presentation state and forward the typed result's
chosen track or adjacent intent. It does not choose repeat policy or retire
the native session.

`WKPlaybackBridge` callback slots are lock-protected because handlers are
installed by the AppKit host while status, natural-end, and AAC progress events
arrive from transport or export queues. The bridge must copy a handler under
the lock and invoke it after releasing the lock.

The former JavaScript playback coordinator and split materialize/load/play
workflow are removed. `nativePlaybackStart` now accepts one typed playback
intent, performs archive materialization, shared timing normalization, stale
request rejection, VGMBoy load/seek/play, and returns one native status
snapshot. JavaScript retains only queue choice, user-intent forwarding, and
DOM/status projection. Database rows are returned by the native catalog
bridge; there are no JavaScript preload or metadata-hydration workers.
Natural completion is delivered to the page through `nativePlaybackEnded`; the
shared native transport also publishes complete `nativePlaybackState`
snapshots at most four times per second while audio is playing. The AppKit host
broadcasts each snapshot to both the main and separate Options WebViews, so the
elapsed readout and Diagnostics page describe the same native session. The
WebKit skin renders those events and does not run a status-poll loop or infer
end from elapsed time.

Once a track is loaded, pause/resume and seek use the existing VGMBoy session
through `nativePlaybackPause`, `nativePlaybackResume`, and `nativePlaybackSeek`.
Those transitions must not call `nativePlaybackStart`; reloading would create
avoidable decoder/archive work and could reset the authoritative timing window.
Seek and output-ramp commands decode the named shared
`PlaybackTransportSeekRequest` and `PlaybackTransportRampGainRequest` codecs;
the WebKit client must not restore positional scalar bridge calls.

The WebKit adjacent-track path asks the native bridge for the shared
`PlaybackQueuedSkipFadeRequest` result. The same typed FrontendCore request is
used by CocoaSpice, and replaces the former seven positional WebKit arguments.
JavaScript must not duplicate fade eligibility or remaining-window calculations;
only the timer, queue intent, and DOM status presentation remain local.

Every delayed fade stores both the WebKit playback generation and VGMBoy's
native diagnostics generation. A callback that observes either generation has
changed is discarded; cancellation restores output gain before seek or queue
replacement continues.

Queue identity policy is shared with CocoaSpice through
`FrontendCore.PlaybackQueueCore`. `PlaybackQueueState` is now the value-only
transition contract for current/selected/pending identity, replacement,
transport navigation, and natural completion. The WebKit renderer still asks
the narrow native `playbackQueueAdjacent` bridge for an explicit skip. It
serializes `PlaybackQueueAdjacentRequest` and receives
`PlaybackQueueAdjacentResponse`, so it does not carry a second queue policy or
reconstruct a queue state in JavaScript.

Indexed database-game selection is a non-autoplay playlist preview. It replaces
the renderer's queue while preserving the active native track and its timing;
only an explicit Play Now/double-click sends a new playback start. A database
lookup must never call the stop path merely because the playlist view changed.
Sidebar-derived preview replacements clear visible playlist selection, so no
old row or coincident track ID leaves a residual selection capsule. The
no-selection state hides the capsule immediately rather than fading it at the
previous row.

Playlist hydration is shared at the data/policy boundary: the bridge uses
`CatalogPlaylistReader` and `PlaybackQueueCore`, matching CocoaSpice.
The JSON-to-track mapping remains WebKit-local because its fields are not the
native metadata cache or column-width model. `FrontendPlaylistColumnSchema`
normalizes the persisted column order, visibility, and explicit sort request
before the WebKit settings projection is returned; every displayed column,
including File and the favorite marker, can be hidden. The renderer owns only
its percentage widths, labels, drag behavior, and DOM presentation.

Explicit playlist sorting never compares values in JavaScript. Catalog rows use
a retained native presentation session; local, mixed, and Favorites rows use a
typed `CatalogPlaylistSortRequest` and receive the shared comparator's ordered
IDs. WebKit applies that identity order before rendering.

Catalog snapshot loading now uses independent native Games, Files, and playlist
session scopes through `CatalogSessionCore.CatalogSessionCoordinator`. Detached
work from an older generation receives an explicit `{ "stale": true }` envelope
and cannot publish rows. WebKit still owns its loading copy, DOM snapshot
application, and browser-selection ordering guard; those presentation concerns
remain intentionally local.

## Failure Boundaries

Missing packaged resources are fatal. The host must not silently fall back to
raw filesystem scanning or a second catalog implementation.

## Files

- `../../Sources/SPCBoyWK/main.swift`
- `../../Sources/SPCBoyWK/WKNativeBridge.swift`
- `../../Sources/SPCBoyWK/WKPlaybackBridge.swift`
- `../../Package.swift`
- `../../Sources/SPCBoyWK/Resources/app-playback.js`
- `../../Sources/SPCBoyWK/Resources/app-ui.js`
- `../../Sources/SPCBoyWK/Resources/options-controller.js`
- `../../Sources/SPCBoyWK/Resources/playlist-controller.js`
- `../../../FrontendCore/Sources/PlaybackQueueCore/PlaybackQueueNavigation.swift`
