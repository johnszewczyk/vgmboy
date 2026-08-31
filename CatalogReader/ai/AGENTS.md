# AGENTS

## Scope

Document current ownership and invariants only. Keep user-facing behavior in
the consuming application's human notes.

## Engineering Rules

- `CatalogReader` is query-only against ScanSong's published catalog.
- `CatalogBrowserCore` is UI-neutral browser behavior and must not import AppKit,
  SwiftUI, WebKit, Electron, or VGMBoy.
- Keep stable catalog identity rooted in catalog IDs and source paths, not display text.
- Preserve versioned tests for behavior shared by native and WebKit skins.
