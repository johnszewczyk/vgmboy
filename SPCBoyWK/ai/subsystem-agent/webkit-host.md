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
timing range and 200 ms defaults. DOM geometry and CSS remain WebKit-owned so
SPCBoy keeps its rendering style; native Swift owns persistence and window
levels.

The accent color is a persisted CSS color in the typed settings projection.
`app-ui.js` applies it as the root `--accent` value, and both the sidebar and
playlist use the same moving accent capsule. Selected-row backgrounds remain
transparent so a second instantaneous paint cannot flash over the capsule;
selected text transitions to the shared dark accent ink. Active toolbar and
option controls use the same accent surface.

`FrontendOptionsManifest` provides the common Database, Interface, and Windows
organization through the bridge. `options-controller.js` applies that manifest,
`playlist-controller.js` reduces selection, and `sidebar-controller.js` forwards
browser-tree row gestures to the native shared reducer. `database-view-utils.js`
owns pure sidebar-view and catalog-search projections. `playlist-table-utils.js`
owns pure playlist path, cell-value, and sort projections, while
`playlist-columns.js` owns column state, header rendering, resizing, and
auto-sizing. `playlist-rows.js` owns playlist row rendering, selection state,
virtualized rendering, and row refresh. `app-ui.js` remains the broader DOM
event wiring layer and delegates these playlist surfaces through explicit
module callbacks.
Database Console → Game group disclosure and selection also pass through the
shared `CatalogBrowserGroupState` reducer. WebKit retains only DOM rows, focus,
scrolling, and persistence projection.

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

Playback timing is resolved by the native bridge through the shared `VGMBoyKit.PlaybackTimingPolicy`
and `PlaybackTimingRequest` boundary used by CocoaSpice. JavaScript asks for and caches that plan
for the active track, then uses the same plan for its readout and native start request. JavaScript
forwards Long Play and deliberate faded-skip intent; it does not choose the core's standard/timed
duration policy. Ordinary finite audio therefore reaches VGMBoy with decoder-natural timing, while
Long Play is the only normal path that supplies a manual length.
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

Database search uses the shared `CatalogBrowserCore.CatalogSearchIndex` matching
policy over the already-published native game projection. WebKit maintains a
transient renderer-local index with the same all-terms fields (`name`, system,
root, and display name), so each keypress filters immediately without a bridge
round-trip or debounce. Native remains responsible for publishing and
refreshing the authoritative game projection; WebKit does not scan paths or
decode metadata to answer search input.

Database Files are native-owned in the same way:
`CatalogBrowserCore.CatalogFileTreeIndex.nodes()` supplies the complete nested
folder/file projection through `databaseFileTree`. JavaScript maps those
records into its existing DOM node shape and owns only renderer-local browser
paths, disclosure, focus, scroll, and context-menu behavior. The former
`buildCatalogFileTree` graph constructor must not return.

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
The bridge projects the JSON envelope into the shared
`PlaybackContinuationRequest` value before invoking it, so CocoaSpice and
SPCBoyWK submit the same lifecycle input.
`WKNativeBridge` parses the JSON envelope, then delegates the typed retirement
operation through `WKPlaybackBridge`; it does not retain a second
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

The WebKit adjacent-track path asks the native bridge for the shared
`PlaybackTransportCore.PlaybackFadePolicy` result. It must not duplicate fade
eligibility or remaining-window calculations in JavaScript; only the timer,
queue intent, and DOM status presentation remain local.

Every delayed fade stores both the WebKit playback generation and VGMBoy's
native diagnostics generation. A callback that observes either generation has
changed is discarded; cancellation restores output gain before seek or queue
replacement continues.

Queue identity policy is shared with CocoaSpice through
`FrontendCore.PlaybackQueueCore`. `PlaybackQueueState` is now the value-only
transition contract for current/selected/pending identity, replacement,
transport navigation, and natural completion. The WebKit renderer still asks
the single native `playbackQueueTransition` snapshot/intent bridge for those
transitions, so it does not carry a second queue policy in JavaScript.

Indexed database-game selection is a non-autoplay playlist preview. It replaces
the renderer's queue while preserving the active native track and its timing;
only an explicit Play Now/double-click sends a new playback start. A database
lookup must never call the stop path merely because the playlist view changed.

Playlist hydration is shared at the data/policy boundary: the bridge uses
`CatalogPlaylistReader` and `PlaybackQueueCore`, matching CocoaSpice.
The JSON-to-track mapping remains WebKit-local because its fields are not the
native metadata cache or column-width model. Playlist column order, widths, and
visibility are persisted in the WebKit settings projection; every displayed
column, including File and the favorite marker, can be hidden, while the
renderer keeps at least one column visible.

Catalog snapshot loading now uses independent native Games, Files, and playlist
session scopes through `CatalogSessionCore.CatalogSessionCoordinator`. Detached
work from an older generation receives an explicit `{ "stale": true }` envelope
and cannot publish rows. WebKit still owns its loading copy, DOM snapshot
application, and browser-selection ordering guard; those presentation concerns
remain intentionally local.

Catalog playlist rows also carry the optional ScanSong `dumper` value through
the native bridge. The renderer exposes it as a configurable Dumper column and
uses an em dash when a row has no authored value.

## Failure Boundaries

Missing packaged resources are fatal. The host must not silently fall back to
raw filesystem scanning or a second catalog implementation.

## Files

- [main.swift](../../Sources/SPCBoyWK/main.swift)
- [WKNativeBridge.swift](../../Sources/SPCBoyWK/WKNativeBridge.swift)
- [WKPlaybackBridge.swift](../../Sources/SPCBoyWK/WKPlaybackBridge.swift)
- [Package.swift](../../Package.swift)
- [app-playback.js](../../Sources/SPCBoyWK/Resources/app-playback.js)
- [app-ui.js](../../Sources/SPCBoyWK/Resources/app-ui.js)
- [database-view-utils.js](../../Sources/SPCBoyWK/Resources/database-view-utils.js)
- [playlist-table-utils.js](../../Sources/SPCBoyWK/Resources/playlist-table-utils.js)
- [playlist-columns.js](../../Sources/SPCBoyWK/Resources/playlist-columns.js)
- [playlist-rows.js](../../Sources/SPCBoyWK/Resources/playlist-rows.js)
- [options-controller.js](../../Sources/SPCBoyWK/Resources/options-controller.js)
- [playlist-controller.js](../../Sources/SPCBoyWK/Resources/playlist-controller.js)
- [sidebar-controller.js](../../Sources/SPCBoyWK/Resources/sidebar-controller.js)
- [PlaybackQueueNavigation.swift](../../../FrontendCore/Sources/PlaybackQueueCore/PlaybackQueueNavigation.swift)
