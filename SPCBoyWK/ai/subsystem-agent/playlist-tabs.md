# Playlist Tabs

## Scope

The WebKit frontend owns per-tab playlist presentation state and tab ordering.
The native host persists validated snapshots in the SPCBoyWK application
support directory.

## Invariants

- Keep tab count, active tab, per-tab playlist rows, selected row, and scroll
  offset presentation-local. They are not shared queue or catalog policy.
- Persist snapshots through the narrow `WKNativeBridge` capability and
  `PlaylistTabsStore`; do not add renderer filesystem access or a second store.
- Shared playback remains one VGMBoy session owned by its initiating tab. A
  tab switch changes playlist presentation, not the loaded native session.
- Command-1 through Command-9 are native menu accelerators routed to a
  zero-based tab index in the WebKit UI.
- Tab surfaces use the existing toolbar geometry, gap, control background, and
  corner-radius tokens. Flex items may shrink to zero width so labels truncate
  instead of forcing a horizontal overflow.
- Keep the tab toolbar's top inset aligned with the sidebar toolbar and use one
  inset between the tabs and playlist headers, so headers align with the first
  sidebar row when tabs are visible.
- Keep automatic empty-column visibility presentation-local. Persist only the
  user's manual visibility choices and column order; the `index` column remains
  a non-sortable row-position projection.

## Files

- `../../Sources/SPCBoyWK/main.swift`
- `../../Sources/SPCBoyWK/WKNativeBridge.swift`
- `../../Sources/SPCBoyWK/PlaylistTabsStore.swift`
- `../../Sources/SPCBoyWK/Resources/app-ui.js`
- `../../Sources/SPCBoyWK/Resources/styles.css`
