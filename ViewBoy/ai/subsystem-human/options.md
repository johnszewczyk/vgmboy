# Options

Options opens inside the LCD canvas and has five in-screen pages: Display, Playback, Audio, Interface, and Library. Each page groups controls in two padded columns, and every page ends in the shared bottom status strip. Page tabs, choices, and adjusters use the same one-dot horizontal text inset; option columns begin one active-font character inside their frame. Checkboxes use `[x]` and `[]`; bracket controls use `[-]` and `[+]`.

- **Display** selects the Micro 3×5 or Standard 5×7 bitmap font, the GameBoy or NightBoy four-tone palette, and standard or high-contrast ink. The palette sample shows the four screen tones.
- **Playback** provides Long Play, End Fade, Repeat Off/All/One, Random Off/Playlist/Library, track timing, and decoder speed. Long Play duration adjusts in 30-second steps from zero (open ended) to one hour; the unknown-length default adjusts from 30 seconds to one hour; fade duration adjusts from zero to 60 seconds. Separate libgme and libvgm speed controls enable their native tempo support and adjust rates in 1/32 steps from 1/32× to 8×. The active track's backend is resolved from the native playback capability manifest; supported speed changes reconfigure the live track.
- **Audio** provides Mono Output, Volume, and the ten-band equalizer. The equalizer has fixed bands from 31 Hz to 16 kHz with 0.5 dB steps over −12 to +12 dB. Volume, mono, and equalizer changes update the native audio path.
- **Interface** controls automatic column sizing, header-and-row resize motion and duration, track-selection slide timing, and Main Window on Top. Auto-sized metadata columns fit the longest value in the active table plus the heading and sort marker; the flexible Title column stays left-aligned. Headers and rows share measured widths and animate together.
- **Library** persists visibility for File, Game, Artist, Path, and Size. Right-click any playlist heading to open the same `[x]`/`[]` visibility list in an LCD pop-up. Every enabled column remains in the table even when the screen is too narrow; the table clips to its pane and scrolls horizontally. Drag a header to reorder columns. The numbered `#` column stays first and cannot be moved. Library also reloads a fresh read from the catalog.

Selection, sidebar disclosure, and column-width animations use the shared easing curve and update at no more than 60 frames per second. Animation duration and enablement remain user-adjustable in Interface.

Theme, ink, font, and playlist column order are remembered in WebKit local storage when available. Playback, interface, and column-visibility preferences use the typed native preference bridge. Playlist tabs and their track snapshots use a separate native `playlistTabsLoad` / `playlistTabsSave` bridge pair.

The macOS Options menu opens the same in-screen page. Library and Queue remain available in the sidebar while Options is open; changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
