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
- Games, Files, their search indexes, and Gallery metadata are preloaded before
  startup reaches ready. Artwork bytes remain bounded, visible-tile requests.

## Invariants

- Keep startup stages monotonic. Readiness waits for Games, Files, and Gallery
  metadata so first interaction does not pay for deferred catalog work.
- Restore tabs and mode, then preload all three projections. Tab activation
  reuses loaded snapshots, including empty results. Search filters the selected
  mode and does not switch projections. Explicit reload preloads all views too.
- A failure remains visible with its message; a fast launch does not flash a
  loading screen.
- Keep SwiftUI presentation out of `FrontendStartupCore`.

## Files

- `Sources/CocoaSpice/App/PlayerViewModel.swift`
- `Sources/CocoaSpice/App/MainView.swift`
- `Sources/CocoaSpice/App/StartupExperienceView.swift`
- `../../../FrontendCore/Sources/FrontendStartupCore/FrontendStartupCore.swift`
