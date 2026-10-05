# GUI Sidebar Core

## Scope

- Left pane sidebar behavior.
- Shared sidebar search field placement.
- Database-browser role of the left pane.

## Current State

- The sidebar search field stays at the top of the left pane.
- The search field now sits tighter to the top chrome with the extra top gap removed.
- The left pane is the scanned persistent database browser. Arbitrary disk browsing is intentionally outside the sidebar boundary.
- The bottom sidebar mode switch has been removed.
- The primary sidebar view is a dense native list of database game rows. Options can enable `Group by Console`, stored internally as `sidebarSystemMode`, which renders expandable console rows with game leaves underneath.
- Sidebar search filters the database list instead of switching to a separate legacy result view.
- Right-clicking a sidebar row opens its context menu without changing sidebar selection.
- Favorites is not a sidebar mode. Command-Shift-F opens or switches to its
  playlist tab without changing the current catalog/sidebar view or its selection.
- Individual native navigation-toolbar items own the library-mode and
  fold/unfold controls beside the native sidebar disclosure button. They use
  the same regular toolbar-item sizing and borderless treatment as the native
  disclosure control; they must not be regrouped into a SwiftUI capsule.
  Playback controls remain in the separate main transport toolbar; do not
  place library controls in the sidebar column toolbar or transport group.
  The library-mode control cycles exactly `Console View` and `Path View`; it is
  not a dropdown.
- The View menu exposes those exact two library commands through `FrontendCommandCore`. The Favorites Playlist command uses Command-Shift-F and does not change the sidebar.

## Rules

- Keep the left pane as a source browser, not the active queue.
- Do not add an arbitrary disk browser to the sidebar. Direct file, folder, and supported archive drops belong to the playlist import path and must not read database metadata.
- Keep sidebar behavior separate from queue behavior.
- Keep catalog aggregation in the shared CatalogBrowserCore/CatalogReader boundary. Favorite membership and history live in FrontendCore's shared native sidecar and must not be written into the scan catalog.
- CocoaSpice reloads the shared favorites store when the app becomes active.
  The retired per-app favorites payload and rollback migration are no longer
  runtime state.
- Folder/leaf click, disclosure, repeated-click, and activation intent comes
  from `CatalogBrowserCore.SidebarRowInteraction`; SwiftUI still owns visuals.
- Return and double-click activation pass an explicit autoplay intent through
  the database queue loader. Enqueue appends tracks before starting the first
  track from the activated game, including when those tracks were already in
  the playlist.
- The shared capsule selection view must keep an in-flight movement animation
  when a nonanimated SwiftUI refresh syncs the same model destination; geometry
  changes still replace the animation target.
- Keep the two-view catalog command vocabulary shared while keeping SwiftUI row
  rendering and favorite storage native to this skin. Favorites playlist
  projection is a queue action, not a sidebar action.

## Files

- [MainView.swift](../../Sources/CocoaSpice/App/MainView.swift)
- [PlayerViewModel.swift](../../Sources/CocoaSpice/App/PlayerViewModel.swift)
- [NativeSearchField.swift](../../Sources/CocoaSpice/App/NativeSearchField.swift)
- [FavoriteTrackCore.swift](../../../FrontendCore/Sources/FavoriteTrackCore/FavoriteTrackCore.swift)
- [FavoriteStore.swift](../../../FrontendCore/Sources/FavoriteStoreCore/FavoriteStore.swift)
