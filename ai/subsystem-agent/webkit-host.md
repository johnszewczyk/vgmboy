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

`FrontendOptionsManifest` provides the common Database, Interface, and Windows
organization through the bridge. `options-controller.js` applies that manifest,
`playlist-controller.js` reduces selection, and `sidebar-controller.js` forwards
browser-tree row gestures to the native shared reducer. `app-ui.js` remains the
renderer and event wiring layer rather than the owner of those policies.
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
For a row without catalog timing, the shared plan uses the persisted unknown-duration safety
window when Long Play is off; the native standard request leaves the play length unset and
VGMBoyKit applies the same policy. Native status remains the playback authority for position and
end state.

The bridge preserves the distinction between a loaded paused session and a
stopped session in its JSON status projection. It emits `paused` when VGMBoy
is not playing, has not naturally ended, and the bridge still owns a loaded
track, keeping WebKit diagnostics aligned with CocoaSpice's native status
model.

The native bridge projects `VGMBoyKit.FormatRegistry.playbackDescriptors` into the WebKit backend
manifest; JavaScript only indexes and displays that projection. `SPCBoyPreferencesSnapshot`
normalizes timing, fade, EQ, volume, mono, and native-tempo values through
`VGMBoyKit.PlaybackPreferences` before persisting the frontend JSON shape.

Database search is also native-owned: `CatalogBrowserCore.CatalogSearchIndex`
provides the matching policy through `CatalogBrowserProjection.search`, and
WebKit waits for that indexed read instead of maintaining a second immediate
JavaScript filter with potentially different semantics.

Database Files are native-owned in the same way:
`CatalogBrowserCore.CatalogFileTreeIndex.nodes()` supplies the complete nested
folder/file projection through `databaseFileTree`. JavaScript maps those
records into its existing DOM node shape and owns only renderer-local browser
paths, disclosure, focus, scroll, and context-menu behavior. The former
`buildCatalogFileTree` graph constructor must not return.

All typed VGMBoy commands sent through `WKPlaybackBridge` are serialized by
the shared `FrontendCore.PlaybackTransportCore.PlaybackTransportCoordinator`,
which also exposes one generation-checked natural-end event for queue
continuation.
The bridge no longer owns a `PlaybackController`, serial executor, or native
request-generation lock. The remaining JavaScript queue/status layer owns only
WebKit interaction ordering and stale UI generation checks; the shared native
coordinator is the non-UI safety boundary that prevents concurrent detached
bridge requests from racing one playback session.

The former JavaScript playback coordinator and split materialize/load/play
workflow are removed. `nativePlaybackStart` now accepts one typed playback
intent, performs archive materialization, shared timing normalization, stale
request rejection, VGMBoy load/seek/play, and returns one native status
snapshot. JavaScript retains only queue choice, user-intent forwarding, and
DOM/status projection. Database rows are returned by the native catalog
bridge; there are no JavaScript preload or metadata-hydration workers.

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
`FrontendCore.PlaybackQueueCore`. The WebKit renderer asks the native bridge
for replacement state, transport targets, and adjacent IDs; it does not
reimplement the CocoaSpice queue transition rules locally.

Indexed database-game selection is a non-autoplay playlist preview. It replaces
the renderer's queue while preserving the active native track and its timing;
only an explicit Play Now/double-click sends a new playback start. A database
lookup must never call the stop path merely because the playlist view changed.

Playlist hydration is shared at the data/policy boundary: the bridge uses
`CatalogPlaylistReader` and `PlaybackQueueNavigation`, matching CocoaSpice.
The JSON-to-track mapping remains WebKit-local because its fields are not the
native metadata cache or column-width model.

Catalog snapshot loading is not yet identical: CocoaSpice has separate native
Games/Files `LatestTaskOwner` sessions and complete-snapshot publication,
while WebKit currently keeps one renderer loading flag and a search-only
generation guard. The next extraction must establish request generation and
stale-result rejection at the native bridge before attempting to share loading
copy or DOM state.

## Failure Boundaries

Missing packaged resources are fatal. The host must not silently fall back to
raw filesystem scanning or a second catalog implementation.

## Files

- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/main.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/WKNativeBridge.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/WKPlaybackBridge.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Package.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/app-playback.js`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/app-ui.js`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/options-controller.js`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/playlist-controller.js`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/sidebar-controller.js`
- `/Users/john/Downloads/Code/VGMMan/FrontendCore/Sources/PlaybackQueueCore/PlaybackQueueNavigation.swift`
