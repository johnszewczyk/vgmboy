# Startup Experience

## Scope

SB2's startup progress contract and compact WebKit status card.

## Ownership

- `FrontendStartupCore` supplies the ordered shared stage labels and timing
  through `WKNativeBridge`.
- `app-ui.js` advances progress around workspace, library, sidebar, and
  playlist restoration; `index.html` and `styles.css` render the SB2 skin.
- Startup progress never owns catalog reads or session persistence.

## Invariants

- Keep the shared stage order and timing. A fast startup does not show a brief
  card; ready briefly confirms completion; failure stays visible.
- Keep the loading card out of the separate Options window.
- Restore the active playlist, then preload Games, Files, and Gallery metadata
  and search indexes before marking startup ready. Do not defer catalog work
  to the first tab switch, view selection, or search. Cache statistics remain
  outside the startup wait.
- Validate catalog location with its schema, never a full active-track count.
- Archive-cache configuration only saves policy. Read inventory when Options
  requests it; cache enumeration cannot hold up startup.
- Games and Files snapshots have explicit loaded flags (including empty results)
  and shared in-flight promises. Tab activation reuses them; explicit catalog
  reload invalidates all snapshots and rejects older generations.
- Gallery owns its independent projection and search; it must not load Games
  merely to populate its console sidebar.
- Preserve app-specific details and visual treatment in SB2 resources.

## Files

- `Sources/SB2/WKNativeBridge.swift`
- `Sources/SB2/Resources/app-ui.js`
- `Sources/SB2/Resources/index.html`
- `Sources/SB2/Resources/styles.css`
- `../../../FrontendCore/Sources/FrontendStartupCore/FrontendStartupCore.swift`
