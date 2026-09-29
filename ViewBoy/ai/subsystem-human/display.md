# Display

ViewBoy uses one responsive LCD canvas for its library, track list, settings, and playback status. Yoga lays out the screen; a four-shade framebuffer paints every border, selection, and bitmap glyph. The window adds only a narrow plastic surround around the screen.

The top row contains Options and the four transport controls. The sidebar begins with compact Library, Queue, Favorites, Open, and Sync actions, then groups catalog games by system. Selecting a system folds or unfolds its games, and selecting a game loads its tracks from the read-only catalog bridge. System disclosure follows the shared auto-resize motion setting. Current Queue shows the active playback list, or the browsed game's tracks before playback starts. Favorites comes from the shared favorite store.

The track pane starts with its centered column headers; it has no separate catalog or queue title row. The table can show the numbered `#`, favorite, file, title, game, artist, system, path, length, and size columns. The first `#` column is fixed, numbered to fit the list, and numbers each displayed row. The favorite column is labeled `FAV` and shows `[x]` or `[ ]`; clicking its cell updates the shared favorite store. Right-click any table header to show or hide File, Game, Artist, Path, and Size. Options exposes the same visibility controls. Every enabled column remains present in a horizontally scrollable viewport; trackpad horizontal scroll, Shift+wheel, Shift+Left/Right, and the bottom scrollbar move it. Drag header cells to reorder columns; `#` remains pinned. Column order is remembered in local display preferences. When Auto-size Columns is enabled, metadata widths fit their headings and available values within their column caps. Header and row widths ease together when the set changes. Column headers sort the rows.

Track selection moves with the shared selection animation setting. The canvas uses small pixel rows, 1-pixel outlines, and centered panel and column headings. Outlined buttons and checkbox rows use a shared font-derived height with two LCD dots between text and each border. Table rows reserve two dots of vertical space above and below the glyph. The Micro 3×5 and Standard 5×7 bitmap fonts are independently authored and switchable in Options. GameBoy and NightBoy palettes both map the same four framebuffer shades; High Contrast replaces tone 0 (`#333333` for GameBoy, brighter silver for NightBoy) without adding a fifth display value. NightBoy also changes the narrow plastic surround to a dark-purple shell with silver bevel details. Both panes end in the same compact status bar.

Each logical dot occupies a 3×3 device-pixel cell with a 2×2 shaded face and an unlit LCD seam. The grid scales with the available display and device-pixel ratio; it does not imitate the Game Boy's 160×144 resolution.

The renderer models the visible dot matrix and four quantized LCD tones, not the Game Boy's controller or electrical drive circuitry. Circuit-level simulation would not improve this app's screen output. Future authenticity work should focus on measurable optical traits such as the dot aperture, cell edge, subtle viewing-angle shading, and restrained pixel response/ghosting. Keep any response effect frame-delta based and optional so static text remains crisp and canvas redraws stay inexpensive.

Click the sidebar toolbar to change views, open a path, or reload the catalog; click a tree row to open or close a system group or select a game. Click a track to select it, double-click to play it, and click a header to sort. Right-click a header to open the LCD column visibility menu. Auto-sized headings reserve space for the sort marker; heading and row cells use the same animated width. Arrow keys move selection, Enter plays, Space toggles playback, and keys 1–3 open Library, Queue, and Options. The macOS menus and playback commands use the same native bridge.

## Files

- `Sources/ViewBoy/Resources/index.html`
- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/Resources/yoga-screen.css`
