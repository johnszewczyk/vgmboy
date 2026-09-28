# Display

ViewBoy uses one responsive LCD canvas for its library, track list, settings, and playback status. Yoga lays out the screen; a four-shade framebuffer paints every border, selection, and bitmap glyph. The window adds only a narrow plastic surround around the screen.

The top row contains Options and the four transport controls. Library, Current Queue, Favorites, and Open Path live in the sidebar. The sidebar groups catalog games by system; selecting a system folds or unfolds its games, and selecting a game loads its tracks from the read-only catalog bridge. System disclosure follows the shared auto-resize motion setting. Current Queue shows the active playback list, or the browsed game's tracks before playback starts. Favorites comes from the shared favorite store. The table can show favorite, index, file, title, game, artist, system, path, length, and size columns as the screen width and column preferences allow. Options can hide or restore File, Game, Artist, Path, and Size; available columns fit when space permits. When Auto-size Columns is enabled, metadata widths fit their headings and available values within their column caps. Header and row widths ease together when the set changes. Column headers sort the rows, and the favorite cell toggles a track in the shared favorite store.

Track selection moves with the shared selection animation setting. The canvas uses small pixel rows, 1-pixel outlines, and vertically centered column headings. The Micro 3×5 and Standard 5×7 bitmap fonts are independently authored and switchable in Options. The current LCD palette preserves the four established shades; High Contrast darkens the foreground shade while retaining the same four-level framebuffer.

Each logical dot occupies a 3×3 device-pixel cell with a 2×2 shaded face and an unlit LCD seam. The grid scales with the available display and device-pixel ratio; it does not imitate the Game Boy's 160×144 resolution.

Click a sidebar row to change views, open or close a system group, or select a game. Click a track to select it, double-click to play it, and click a header to sort. Arrow keys move selection, Enter plays, Space toggles playback, and keys 1–3 open Library, Queue, and Options. The macOS menus and playback commands use the same native bridge.

## Files

- `Sources/ViewBoy/Resources/index.html`
- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/Resources/yoga-screen.css`
