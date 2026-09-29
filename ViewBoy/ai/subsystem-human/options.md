# Options

Options opens inside the LCD canvas and has four in-screen pages: Display, Playback, Interface, and Library. Each page groups controls in two padded columns. Page tabs, choices, and adjusters use the same one-dot horizontal text inset; option columns begin one active-font character inside their frame. Bracket controls use `[-]` and `[+]` labels.

- **Display** selects the Micro 3×5 or Standard 5×7 bitmap font, the GameBoy or NightBoy four-tone palette, and standard or high-contrast ink. The palette sample shows the four screen tones.
- **Playback** provides Long Play, End Fade, Repeat Off/All/One, Random Off/Playlist/Library, Mono Output, Volume, and the ten-band equalizer. Long Play duration adjusts in 30-second steps from zero (open ended) to one hour; the unknown-length default adjusts from 30 seconds to one hour; fade duration adjusts from zero to 60 seconds. The equalizer has ten fixed bands from 31 Hz to 16 kHz with 0.5 dB steps over −12 to +12 dB. Timing changes reconfigure a loaded track; volume, mono, and equalizer changes update the native audio path.
- **Interface** controls automatic column sizing, header-and-row resize motion and duration, and the track-selection slide toggle and duration. Auto-sized metadata columns fit the longest value in the active table plus the heading and sort marker; the flexible Title column stays left-aligned. Headers and rows share measured widths and animate together.
- **Library** persists visibility for File, Game, Artist, Path, and Size. Right-click any playlist heading to open the same `[x]`/`[ ]` visibility list in an LCD pop-up. Every enabled column remains in the table even when the screen is too narrow; the table clips to its pane and scrolls horizontally. Drag a header to reorder columns. The numbered `#` column stays first and cannot be moved. Library also reloads a fresh read from the catalog.

Selection, sidebar disclosure, and column-width animations use the shared easing curve and update at no more than 60 frames per second. Animation duration and enablement remain user-adjustable in Interface.

Theme, ink, font, and playlist column order are remembered in WebKit local storage when available. Playback, interface, and column-visibility preferences continue through the typed frontend-preference bridge.

The macOS Options menu opens the same in-screen page. Library and Queue remain available in the sidebar while Options is open; changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
