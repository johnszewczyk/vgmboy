# Playlist Tabs

## Scope

Playlist-tab ordering, activation, and saved order.

## Ownership

- `PlayerViewModel` owns the ordered tab array and the active tab identity.
- `PlaylistTabReorderDropDelegate` moves a dragged tab when it enters a
  neighboring tab; `MainView` animates each move with the configured auto-size
  duration and ease-in-out curve.
- Reordering saves through the existing debounced playlist-tab snapshot.

## Invariants

- Reordering does not activate a different playlist or change the active tab
  identity.
- Favorites and History shortcuts activate their named tabs when present and
  create those tabs on first use.
- Tabs divide the available strip width equally, with a 76-point minimum width
  that enables horizontal scrolling when the full set no longer fits.
- Preserve each tab's title, queue, and selection while changing its position.
- Keep the persisted 64-tab limit and versioned snapshot format.

## Files

- `Sources/CocoaSpice/App/MainView.swift`
- `Sources/CocoaSpice/App/PlaylistTabReorderDropDelegate.swift`
- `Sources/CocoaSpice/App/PlayerViewModel.swift`
- `Sources/CocoaSpice/App/PlaylistTabs.swift`
