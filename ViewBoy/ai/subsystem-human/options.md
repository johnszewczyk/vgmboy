# Options

Options opens inside the LCD canvas and has four in-screen pages: Display, Playback, Interface, and Library. Each page organizes its controls into two equally sized, padded, bordered columns with centered section bars and outlined choices. The page navigation is split into two aligned toolbars, one above each options column. Checkbox rows are clickable across their outline, show `[x]` when enabled and `[ ]` when disabled, and fill with the active LCD selection shade. Repeat and Random remain segmented choices. Outline buttons and checkbox rows share one height derived from the active bitmap font, with two LCD dots between the glyph and each border edge.

- **Font** selects the Micro 3×5 or Standard 5×7 bitmap glyphs.
- **Theme** selects GameBoy's green four-tone palette or NightBoy's dark-purple field and silvery ink. Both themes use the same four framebuffer values and dot rendering.
- **Ink** selects the theme's standard darkest tone or its high-contrast tone. GameBoy high contrast uses `#333333`; NightBoy high contrast uses brighter silver. This changes palette tone 0, which is used by bitmap text and other darkest UI marks, while preserving exactly four LCD tones.
- **Playback** groups Long Play, End Fade, Repeat Off/All/One, Random Off/Playlist/Library, Mono Output, and a segmented Volume control. Random modes are mutually exclusive and match the `LP`, `R1`, `P-RND`, and `L-RND` quick toggles in the main toolbar. Playback options keep using the typed frontend-preference and VGMBoy bridges; volume and Mono Output also reconfigure audio.
- **Interface** controls automatic column sizing, header-and-row resize motion and duration, and the track-selection slide toggle and duration. Auto-sized metadata columns fit the longest value in the active table plus the heading and sort marker; the flexible Title column stays left-aligned. Headers and rows share measured widths and animate together.
- **Playlist Columns** persists visibility for File, Game, Artist, Path, and Size. Right-click any playlist heading to open the same `[x]`/`[ ]` visibility list in an LCD pop-up. Every enabled column remains in the table even when the screen is too narrow; the table clips to its pane and scrolls horizontally. Drag a header to reorder columns. The numbered `#` column stays first and cannot be moved.
- **Library** reloads a fresh read from the catalog.

Theme, ink, font, and playlist column order are remembered in WebKit local storage when available. Playback, interface, and column-visibility preferences continue through the typed frontend-preference bridge.

The macOS Options menu opens the same in-screen page. Library and Queue remain available in the sidebar while Options is open; changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
