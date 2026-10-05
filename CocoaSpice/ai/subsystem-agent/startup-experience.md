# Startup Experience

## Scope

CocoaSpice startup stages and the native progress screen.

## Ownership

- `FrontendStartupCore` defines the four shared stages, progress state, and
  reveal and ready timing.
- `PlayerViewModel` advances that state around session restoration, catalog
  setup, sidebar loading, and playlist restoration.
- `DatabaseSidebarLoader` owns the asynchronous initial sidebar read; its
  completion or failure settles startup progress.
- `MainView` owns the CocoaSpice-skinned overlay. It does not own catalog or
  session work.

## Invariants

- Keep startup stage order monotonic and mark ready only after the initial
  sidebar read completes.
- A failure remains visible with its message; a fast launch does not flash a
  loading screen.
- Keep SwiftUI presentation out of `FrontendStartupCore`.

## Files

- `Sources/CocoaSpice/App/PlayerViewModel.swift`
- `Sources/CocoaSpice/App/MainView.swift`
- `Sources/CocoaSpice/App/StartupExperienceView.swift`
- `../../../FrontendCore/Sources/FrontendStartupCore/FrontendStartupCore.swift`
