# Options

Options opens inside the LCD canvas and has four in-screen pages: Display, Playback, Interface, and Library. Each page organizes its controls into two equally sized, padded, bordered columns with section bars and outlined choices. Toggles are clickable across their row and use a font-height bitmap marker: `[ X ]` when enabled and `[   ]` when disabled.

- **Font** selects the Micro 3×5 or Standard 5×7 bitmap glyphs.
- **Theme** selects GameBoy's green four-tone palette or NightBoy's dark-purple field and silvery ink. Both themes use the same four framebuffer values and dot rendering.
- **Ink** selects the theme's standard darkest tone or its high-contrast tone. GameBoy high contrast uses `#333333`; NightBoy high contrast uses brighter silver. This changes palette tone 0, which is used by bitmap text and other darkest UI marks, while preserving exactly four LCD tones.
- **Playback** groups Long Play, End Fade, Repeat Off/All/One, Random Off/Playlist/Library, Mono Output, and a segmented Volume control. Random modes are mutually exclusive and match the `LP`, `R1`, `P-RND`, and `L-RND` quick toggles in the main toolbar. Playback options keep using the typed frontend-preference and VGMBoy bridges; volume and Mono Output also reconfigure audio.
- **Interface** controls automatic column sizing, header-and-row resize motion and duration, and the track-selection slide toggle and duration. Sorted column headings reserve an arrow cell; headers and rows share the same measured column widths and resize timing.
- **Playlist Columns** persists visibility for File, Game, Artist, Path, and Size. Enabled fields appear when the current screen has enough room; disabling a field immediately gives its space back to the other columns.
- **Library** reloads a fresh read from the catalog.

Theme, ink, and font choices are remembered in WebKit local storage when available. Playback and interface preferences continue through the typed frontend-preference bridge.

The macOS Options menu opens the same in-screen page. Library and Queue remain available in the sidebar while Options is open; changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
