# Playlist

## Display

- Scope: each playlist tab holds one loaded folder, file, archive, or catalog selection. Supported files and playable archive members remain limited to the selected source; folders are not recursively expanded.
- Tabs: New Playlist Tab and ⌘T open an empty tab. Sidebar previews and activations replace the active tab's playlist; Queue appends to that tab. Switching tabs leaves the sidebar tree and ongoing playback alone.
- Tabs: playlist contents, tab names, selected row, and scroll position persist across app launches. Close a tab with its × button, the active-tab close button, or ⌘W. The tab strip is hidden while only one tab is open.
- Columns: `#`, `File`, `Title`, `Game`, `Artist`, `System`, `Path`, and `Length`.
- Columns: order is draggable and persisted.
- Columns: headers are centered, resizable, sortable, and support right-click show/hide controls.
- Columns: all visible columns snap to their longest content when a playlist loads; double-click a header seam to snap one column again.
- The `#` column shows the current visible line number. It does not assign track identity or create a playlist sort order.
- Sorting: filename ascending is the default.
- Metadata: catalog rows display the values published by MediaScanner. Raw DiskPath rows use only pathname labels; VGMBoy may supply subtrack count and playback timing, never display tags. SPCBoy never writes enrichment to the MediaScanner catalog.
- Multi-track NSF and GBS files: each internal song appears as its own playlist row for both loose and archived sources.

## Selection

- Selection: one row at a time.
- Selection: selected row and currently playing row remain separate.

## Activation

- Rows: double-click starts playback.
- Rows: Enter starts playback of the selected row.
- Rows: clicking a row gives the playlist focus, so Enter cannot be intercepted by the sidebar.
- Navigation: previous and next wrap within the playlist that owns the current playback session; when playback is stopped they use the active tab.

## Files

- [web/app-ui.js](../../web/app-ui.js)
- [web/app-playback.js](../../web/app-playback.js)
