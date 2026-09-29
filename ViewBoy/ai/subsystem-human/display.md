# Display

ViewBoy uses one responsive LCD canvas for the library, playlist, options, and playback status. Yoga lays out the screen; a four-shade framebuffer paints every border, selection, control, and bitmap glyph. Three flat grey Game Boy membrane lines frame the LCD.

The top toolbar holds Options and the transport controls. The sidebar starts with compact Library, Queue, Favorites, Open, and Sync actions, then groups catalog games by system. Selecting a system folds or unfolds its games, and selecting a game loads tracks from the read-only catalog bridge. System disclosure follows the shared auto-resize motion setting. Current Queue shows the active playback list, or the browsed game's tracks before playback starts. Favorites comes from the shared favorite store.

The track pane begins with playlist tabs, followed by centered column headings. It has no separate catalog or queue title row. Selecting a game in the sidebar opens or reuses a named tab containing that game's tracks. Selecting a tab makes its list the visible playlist and active queue. `[+]` duplicates the selected playlist in a new tab; `[x]` closes a tab. One empty playlist remains available, and up to 64 playlist snapshots persist through ViewBoy's native preference store. The Favorites view uses the shared favorite projection and hides playlist tabs.

The table can show the numbered `#`, favorite, file, title, game, artist, system, path, length, and size columns. The first `#` column is fixed, numbered to fit the list, and numbers each displayed row. The favorite column is labeled `FAV` and shows `[x]` or `[]`; clicking its cell updates the shared favorite store. Right-click any table header to show or hide File, Game, Artist, Path, and Size. Options exposes the same visibility controls. Every enabled column remains present in a horizontally scrollable viewport; trackpad horizontal scroll, Shift+wheel, Shift+Left/Right, and the bottom scrollbar move it. Drag header cells to reorder columns; `#` remains pinned. Column order is remembered in local display preferences. When Auto-size Columns is enabled, metadata widths fit their headings and available values within their column caps. Header and row widths ease together when the set changes.

Buttons, outlined choices, option rows, and pane headings share a font-derived row height. Buttons leave two LCD dots between glyphs and the one-dot outline on all sides. `UI_SPACING_DOTS` centralizes the minimum two-dot control gap, six-dot section gap, four-dot group inset, and six-dot Options pane inset. The system tree and playlist keep compact row heights for browsing density. Sidebar, playlist, and Options footers use a shared status bar pinned to the bottom of each pane. Sidebar and playlist section headings use the same roomier canonical row height.

The Options screen uses a vertical table of contents and one large content pane. It contains Display, Playback, Audio, Interface, and Library pages. Audio presents ten horizontal equalizer bars, each at least 100 LCD dots wide and otherwise filling the pane. Each bar selects one of 49 gain values from −12 to +12 dB in 0.5 dB increments and sends changes through the native audio preference path.

The Micro 3×5 and Standard 5×7 bitmap fonts are independently authored and switchable in Options. GameBoy and NightBoy palettes both map the same four framebuffer shades; High Contrast changes tone 0 (`#333333` for GameBoy and brighter silver for NightBoy) without adding a fifth display value. NightBoy also changes the narrow membrane lines to a dark-purple surround with silver details.

Each logical dot occupies a 3×3 device-pixel cell with a 2×2 shaded face and an unlit LCD seam. The grid scales with available space and device-pixel ratio, independent of the Game Boy's native 160×144 resolution. Selection, disclosure, and column-width animation frames are capped at 60 updates per second.

The renderer models the visible dot matrix and four quantized LCD tones, not the Game Boy's controller or electrical drive circuitry. Circuit-level simulation would not improve this app's screen output. Future authenticity work should focus on measurable optical traits such as dot aperture, cell edge, subtle viewing-angle shading, and restrained pixel response or ghosting. Keep any response effect frame-delta based and optional so static text remains crisp and canvas redraws stay inexpensive.

Click the sidebar toolbar to change views, open a path, or reload the catalog; click a tree row to open or close a system group or select a game. Click a track to select it, double-click to play it, and click a header to sort. Right-click a header to open the LCD column visibility menu. Command-1 through Command-9 select playlist tabs; Command-comma opens Options. Arrow keys move selection, Enter plays, Space toggles playback, and unmodified 1–3 open Library, Queue, and Options. The macOS menus and playback commands use the same native bridge.

## Files

- `Sources/ViewBoy/Resources/index.html`
- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/Resources/yoga-screen.css`
