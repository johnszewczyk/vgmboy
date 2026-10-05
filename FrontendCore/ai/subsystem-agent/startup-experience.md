# Startup Experience

## Scope

Shared startup stage names, progress transitions, and reveal timing for native
and WebKit frontends.

## Ownership

- `FrontendStartupCore` defines the ordered workspace, library, sidebar, and
  playlist stages and the UI-neutral progress state.
- Each frontend advances progress around its own session, catalog, sidebar,
  and playlist work. The package performs none of those operations.
- Each frontend renders the shared stages in its own visual language.

## Invariants

- Stage order is monotonic: restore workspace, connect library, prepare
  sidebar, restore playlists.
- Ready marks every stage complete. A failure remains attached to the active
  stage until the frontend presents recovery.
- The 350 ms reveal delay and 650 ms ready confirmation are shared policy;
  renderers may hide a screen that completes before its reveal delay.
- Keep SwiftUI, AppKit, WebKit, canvas drawing, timers, and app-specific
  catalog/session work out of this target.

## Files

- `Sources/FrontendStartupCore/FrontendStartupCore.swift`
