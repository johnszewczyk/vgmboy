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
- Playlist and sidebar single-row selection share one configurable standard ease-in/ease-out transition, defaulting to 200 ms, and the same capsule geometry. The playlist's primary row uses the accent capsule by default; the optional Glass Selector uses untinted AppKit `NSGlassEffectView`. The sidebar and multi-selection keep their accent capsules.
- The browsing selection remains stable while playback starts, completes, or moves through previous/next media commands; the playing row is represented independently by current transport state.

## Rules

- Keep Finder-style multiselect expectations.
- Keep selection separate from playback.
- Arrow-key movement is owned by the native playlist table; the following SwiftUI update must not overwrite the newly moved selection. Enter activates the table's current selected row, enabling arrow-key plus Enter seek/play workflows.
- Solid highlights are non-interactive and stay below row content. When Glass Selector is enabled for one primary playlist row, place the native AppKit `NSGlassEffectView` above row text so its system material samples and distorts the content beneath it; do not tint or draw a substitute glass treatment. Animate and retarget the glass view's AppKit frame with `NSAnimationContext`, using its presentation frame when interrupting a move. Do not animate the glass backing layer directly. Keep multi-selection and sidebar capsules below their row content.
- If row activation behavior changes, update both selection semantics and playback-target semantics.

## Files

- [PlaylistTableView.swift](../../Sources/CocoaSpice/App/PlaylistTableView.swift)
- [PlayerViewModel.swift](../../Sources/CocoaSpice/App/PlayerViewModel.swift)
