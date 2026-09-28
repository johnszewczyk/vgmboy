# Options

Options opens inside the LCD canvas. The screen controls the bitmap font size and LCD contrast, along with the playback preferences owned by ViewBoy.

- **Font Glyphs** switches between independently authored Micro 3×5 and Standard 5×7 fonts. The choice is remembered in WebKit local storage when available.
- **LCD Contrast** switches between the current four-shade palette and High Contrast. High Contrast changes only the darkest foreground shade; the screen still uses four discrete colors.
- **Long Play**, **End Fade**, **Repeat**, **Mono**, and **Volume** keep using the typed frontend-preference and VGMBoy playback bridges.
- **Reload Library** requests a fresh read from the catalog.

The macOS Options menu opens the same in-screen page. Library and Queue remain available in the sidebar while Options is open; changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
