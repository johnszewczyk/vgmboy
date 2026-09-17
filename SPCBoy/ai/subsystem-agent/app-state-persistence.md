# App State Persistence

## Scope

- Renderer-side source of truth.
- Persisted settings.
- Selection versus current playback semantics.

## Ownership and Invariants

- The active UI state lives in the renderer `state` object in `web/app-core.js`.
- Persisted settings are stored in browser `localStorage` under `spcboy-electron-settings`.
- Playlist tabs are persisted separately in the Electron user-data `playlist-tabs.json` file. The versioned snapshot contains tab IDs and titles, playlist rows, each tab's selected track and scroll position, and the active tab ID; playback itself is not resumed across launches.
- Persisted values include root path, selected folder, last selected track, timing settings, independent Sidebar/Playlist font size, color, and monospace settings, sidebar width, item spacing, console-tag source, underlying Folders/Database mode, collapsed console disclosure state, and column order. Search temporarily overrides the visible mode without changing that stored underlying selection.
- Play time is rounded to whole seconds and clamped to the 30-900 second range; entered values hold as typed.
- libgme and libvgm playback speeds persist as separate reduced `{ numerator, denominator }` rationals, not floating-point values. Their enable settings persist independently and are broadcast to the separate Options window before only a compatible active route is refreshed.
- Long Play enabled, manual play time, and fade duration persist and are broadcast to the separate Options window so the main playback window refreshes the active route with the same timing settings.
- Font size and sidebar width are clamped to safe UI ranges before storage.
- `selectedTrackId` is the row selection target.
- `currentTrackId` is the active playback row.
- `playbackTabId` identifies which tab owns the one active playback queue. It stays independent from `activePlaylistTabId` while the user views another tab.
- Selecting a row does not automatically start playback.
- Selecting a different folder in the sidebar does not automatically stop current playback.
- Closing the tab that owns the active playback session stops that session. Closing another tab leaves playback intact.
- Raw structural completion for an older playlist generation is ignored once a newer generation exists. It updates only the requesting generation and never persists decoder-derived display metadata.

## Critical Engineering Notes

- Treat renderer state as the active UI-state authority.
- Keep selection separate from current playback.
- Keep playlist contents out of `localStorage`; use only the validated main-process file bridge for tab snapshots.
- If settings move out of `localStorage`, update this file and `project-info.md`.

## Files

- [web/app-core.js](../../web/app-core.js)
- [web/app-ui.js](../../web/app-ui.js)
- [web/app-playback.js](../../web/app-playback.js)
- [electron/main.js](../../electron/main.js)
- [electron/preload.js](../../electron/preload.js)
- [electron/playlist-tabs-store.js](../../electron/playlist-tabs-store.js)
- [playlist tab store tests](../../test/playlist-tabs-store.test.js)
