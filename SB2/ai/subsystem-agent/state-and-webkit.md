# State persistence and WebKit boundary

SB2 owns this host adaptation and presentation persistence. Shared catalog,
playlist validation, preference normalization and playback policy retain their
existing owners.

## Playback timing preview

Timing and speed preference changes invalidate per-track timing plans. SB2
refreshes the stopped track preview through the shared timing bridge, accepting
its reply only while settings, playback and displayed-track identity still match.
If settings change during start preparation, SB2 replans before native start;
if they change during native start, it reconfigures the accepted session. A
newer playback generation cancels either path.
Late timing replies from older settings cannot repopulate the plan cache.

## Playback completion

After native completion retirement returns, advance only while the same track,
frontend playback generation and native generation remain current.

## Preferences

`settings-persistence.js` tracks the last observed snapshot and pending local
fields in each WebView. Send changed fields only. Filter old echoes against
pending edits and preserve uncommitted local previews. Receiving appearance
changes must not write the same settings back to native storage. Appearance
edits use the same canonical patch path rather than an additional full-appearance
broadcast. Identical echoes do not trigger a render. After applying an incoming
patch, observe its normalized UI values so float conversion does not create
spurious edits on the next save.

The native bridge merges patches into the current typed snapshot under one
recursive lock, shared with snapshot loads and EQ patch writes. Broadcast only
the normalized fields that changed. Preserve explicit nulls when clearing an
optional field. Consumers must not default absent fields in a patch.

## Workspace lifetime

Keep normal tab snapshots debounced by 500ms. `flushPlaylistTabs` cancels that
timer, awaits the shared tab transition chain, captures current tab state and
waits for the native file-write acknowledgement. Do not save initial empty
playlists before restoration has completed.

`flushPendingState` drains settings writes, then flushes the workspace. Native
window close and application quit await this promise through
`callAsyncJavaScript`. A failure or eight-second timeout keeps the app/window
open and reports the failure; never silently approve a failed save. Quit uses
AppKit's deferred termination reply. Page hide is only a best-effort fallback.

## Virtual playlist rendering

A full model render validates IDs, reconciles selection, computes visibility and
sizes columns. Scrolling calls `renderPlaylistViewport` directly: calculate the
visible range and retain overlapping rows, without rebuilding all playlist IDs
or recomputing column visibility. Selection membership sets are cached by the
immutable selected-ID array, so Select All does not add a full-list scan to each
visible row update. Replace selected-ID arrays rather than mutating them.

Column sizing uses the complete CatalogReader content hints, mapping their
projection field names (`fileText`, `titleText`, `authorText`, and related
fields) to SB2 column IDs. Playlists without hints measure every row; do not
estimate width from a sample. Keep an ordered `<colgroup>` on both header and
body tables so virtual-row spacer cells cannot change body column widths.
Invalidate auto-size when column visibility changes so newly shown content is
measured before it is displayed.
Copy Year and Dumper from the native playlist-row projection into the track
model; hints alone can keep an empty column visible without rendering values.
Measure Path from its displayed root-relative values and do not stretch it to
fill unused pane width. `SBPresentation.measureText(s)` owns rendered typography
measurement for both SB2 and SBO, including transforms and font features. Its
cache is bounded and invalidates on font load; no-hint playlists use batches of
at most 256 probe nodes. Do not substitute canvas-only metrics for cell text.

## Trusted web content

`SB2WebContentPolicy` allows only the bundled index document as a main-frame
navigation or response. Bridge requests must come from that main frame while
the WebView itself displays the trusted document. File identity uses resolved,
standardized local paths. Reject new-window and subframe navigation.

The index CSP permits bundled scripts/styles/fonts and bundled or data-URL
artwork. It denies network connections, frames, objects, form submissions, base
URL changes and inline/eval script. Dynamic presentation styles remain allowed.
Do not weaken this policy to accommodate arbitrary external documents.

[Verification and limits](../verification/state-and-webkit.md).
