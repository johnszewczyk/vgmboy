# Options

Options opens inside the LCD canvas as grouped Display, Playback, Interface, and Library sections. Section bars, dividers, outlined choices, and pixel checkboxes keep the controls legible and consistent with the screen.

- **Font** selects the Micro 3×5 or Standard 5×7 bitmap glyphs. The choice is remembered in WebKit local storage when available.
- **Contrast** selects the current four-shade palette or High Contrast, which darkens the foreground while retaining the same four LCD shades.
- **Playback** groups Long Play, End Fade, Repeat Off/All/One, Mono Output, and a segmented Volume control. Playback options keep using the typed frontend-preference and VGMBoy bridges.
- **Interface** controls automatic column sizing, its motion toggle and duration, and the track-selection slide toggle and duration. The column header and row cells share the automatic resize timing preference.
- **Library** reloads a fresh read from the catalog.

The macOS Options menu opens the same in-screen page. Library and Queue remain available in the sidebar while Options is open; changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
