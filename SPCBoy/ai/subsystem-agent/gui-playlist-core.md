# GUI Playlist Core

## Scope

- Persistent playlist-tab collection and active playlist surface.
- Row activation.
- Current-row versus selected-row behavior.

## Ownership and Invariants

- The renderer owns a collection of playlist tabs. Each tab contains one playlist snapshot, its selected row, and its scroll position; the active tab is mirrored by `state.playlist` for the existing table renderer.
- Sidebar selection replaces the active tab's playlist. Queue appends to the active tab. Creating or switching tabs does not change the sidebar tree.
- The tab strip is hidden with zero or one tab; the New and active Close controls remain available. ⌘T creates a tab and ⌘W closes the active tab.
- Playlist-tab contents persist in the Electron user-data `playlist-tabs.json` file through the narrow preload bridge; renderer preferences remain in `localStorage`.
- Playback remains a single global VGMBoy session and carries an owning tab ID. Switching tabs does not stop it; previous, next, and natural-end advancement use the owning tab. Closing its owner stops that session.
- Closing the last tab is valid and persists an empty collection. A later sidebar load or New action can open a tab again.
- Each playlist data source contains supported files and playable archive members directly inside its selected folder, not recursive descendants.
- The playlist does not recurse into descendant folders.
- Multi-track libgme files appear as one row per internal track, with the stored track index carried into playback.
- Archive-backed playlist rows retain their archive source identity; selecting a row must not require the sidebar tree to rebuild.
- Every row uses the versioned, delimiter-safe `pt1` identity built from source
  path, optional archive member path, and zero-based subtrack index. Catalog
  display fields and raw-path structural timing never change that identity.
- Single click selects a row.
- Playlist rows are keyboard-focusable; clicking or focusing a row establishes playlist focus before Enter activation.
- Double click starts playback of that row.
- `Enter` plays the selected row.
- Enter activation resolves the focused playlist, folder/file, database-game, or database-console row before falling back to the current pane selection; it must not default to playlist row one.
- Selected row and current playing row are separate states.
- Current playing row may remain accented even if selection moves elsewhere.
- Previous and next wrap within the current playback-owner playlist; while stopped, transport uses the active tab.
- Database rows publish immediately from their catalog values. Raw-path rows
  may receive VGMBoy structural timing and subtrack count after materialization;
  they never receive decoder display tags or write anything to the MediaScanner
  catalog. Structural completion never changes the stable row identity.

## Critical Engineering Notes

- Keep tab titles source-derived and treat tabs as retained playlist views, not editable playlist files.
- Do not describe richer playlist-editing behavior as live unless the app actually exposes it.
- Keep row selection separate from playback state.

## Files

- [web/app-ui.js](../../web/app-ui.js)
- [web/app-playback.js](../../web/app-playback.js)
- [web/app-core.js](../../web/app-core.js)
- [electron/playlist-tabs-store.js](../../electron/playlist-tabs-store.js)
- [Cross-app playlist activation fixture](../../test/cross-app-playlist-activation-v1.json)
