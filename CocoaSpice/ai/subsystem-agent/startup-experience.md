# Startup Experience

## Scope

CocoaSpice startup stages and the native progress screen.

## Ownership

- `FrontendStartupCore` defines the four shared stages, progress state, and
  reveal and ready timing.
- `PlayerViewModel` advances that state around session restoration, catalog
  setup, sidebar loading, and playlist restoration.
- `DatabaseSidebarLoader` owns asynchronous sidebar reads, cached snapshots,
  and local errors. Games search indexes are constructed off the main actor.
- `MainView` owns the CocoaSpice-skinned overlay. It does not own catalog or
  session work.
- Gallery metadata and artwork are excluded from startup readiness. If Gallery
  is the restored active tab, its projection begins after startup reaches ready.

## Invariants

- Keep startup stages monotonic. Mark the restored workspace ready after
  catalog validation; sidebar data loads independently and cannot block reveal.
- Restore tabs and mode before requesting a sidebar. Gallery needs only its own
  projection; ordinary tabs reuse loaded Games/Files snapshots, including empty
  results. Search filters the selected mode and does not switch projections.
- A failure remains visible with its message; a fast launch does not flash a
  loading screen.
- Keep SwiftUI presentation out of `FrontendStartupCore`.

## Files

- `Sources/CocoaSpice/App/PlayerViewModel.swift`
- `Sources/CocoaSpice/App/MainView.swift`
- `Sources/CocoaSpice/App/StartupExperienceView.swift`
- `../../../FrontendCore/Sources/FrontendStartupCore/FrontendStartupCore.swift`
