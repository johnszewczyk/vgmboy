# GUI Playlist Selection Operations

## Scope

- Native row selection behavior.
- Row multiselect.
- Drag reorder.
- Selection-driven queue operations.

## Current State

- Multi-selection follows native `Shift` and `Command` semantics.
- Right-click rows open queue-action menus.
- Drag reorder is supported for selected rows.
- One primary selected row and a multiselect set can both exist.
- Playlist and sidebar single-row selection share one configurable standard ease-in/ease-out capsule transition, defaulting to 200 ms, and the persisted Solid Playlist Selection Bar style. Multi-selection and programmatic selection synchronization update immediately; multi-selection stays filled.
- The browsing selection remains stable while playback starts, completes, or moves through previous/next media commands; the playing row is represented independently by current transport state.
- Playlist Link Mode is a persisted presentation preference. When enabled, a plain single click activates and plays its row; double-click does not dispatch a second activation. The pointing-hand cursor is limited to playlist row bounds. Selection remains the native row selection and Return activation remains available.

## Rules

- Keep Finder-style multiselect expectations.
- Keep selection separate from playback.
- Arrow-key movement is owned by the native playlist table; the following SwiftUI update must not overwrite the newly moved selection. Enter activates the table's current selected row, enabling arrow-key plus Enter seek/play workflows.
- The custom shape-layer highlight is non-interactive and stays below row content. Retarget its layer animation from its presentation position so repeated arrow-key navigation does not snap backward. Keep outline mode to a clear fill and accent stroke; do not add blur, backdrop sampling, or per-frame drawing.
- Recompute the selected capsule geometry after native playlist column resizing and automatic sizing; initial row geometry may be measured before the table reaches its final width, especially at startup or when returning from Gallery.
- If row activation behavior changes, update both selection semantics and playback-target semantics.

## Files

- [PlaylistTableView.swift](../../Sources/CocoaSpice/App/PlaylistTableView.swift)
- [PlayerViewModel.swift](../../Sources/CocoaSpice/App/PlayerViewModel.swift)
