# Options

Options fills the LCD with a vertical table of contents and one spacious content pane. The TOC has Display, Playback, Audio, Interface, and Library pages. Each pane pins its status footer to the bottom edge. Groups use section headers and outlined rows; checkboxes show `[•]` when enabled and `[]` when off. `[-]` and `[+]` adjust numeric values.

The in-screen spacing rules live in `yoga-app.js` as `UI_SPACING_DOTS`: two dots between controls, six between sections, four inside option groups, and six around the Options panes. Buttons use a font-derived height with two dots of padding on every side inside their one-dot outline. Compact playlist and system-tree rows keep their separate density.

- **Display** selects Micro 3×5 or Standard 5×7 bitmap text, the GameBoy or NightBoy four-tone palette, and standard or high-contrast ink. The palette sample shows the four screen tones.
- **Playback** provides Long Play, End Fade, Repeat Off/All/One, Random Off/Playlist/Library, track timing, and decoder speed. Long Play duration adjusts in 30-second steps from zero (open ended) to one hour; the unknown-length default adjusts from 30 seconds to one hour; fade duration adjusts from zero to 60 seconds. Separate libgme and libvgm speed controls enable native tempo support and adjust rates in 1/32 steps from 1/32× to 8×. The active track's backend is resolved from the native playback capability manifest; supported speed changes reconfigure the live track.
- **Audio** provides Mono Output, Volume, and ten full-width horizontal equalizer bars from 31 Hz to 16 kHz. Each band spans −12 to +12 dB in 0.5 dB steps (49 settings) and has a minimum width of 100 LCD dots before it expands to fill the pane. Gain, volume, and mono changes update the native audio path.
- **Interface** controls automatic column sizing, header-and-row resize motion and duration, track-selection slide timing, and Main Window on Top. Auto-sized metadata columns fit the longest value in the active table plus the heading and sort marker; the flexible Title column stays left-aligned. Headers and rows share measured widths and animate together.
- **Library** persists visibility for File, Game, Artist, Path, and Size. Right-click any playlist heading to open the same checkbox list in an LCD pop-up. Every enabled column remains in the table even when the screen is too narrow; the table clips to its pane and scrolls horizontally. Drag a header to reorder columns. The numbered `#` column stays first and cannot be moved. Library also reloads a fresh read from the catalog.

Command-comma opens Options. Command-1 through Command-9 select the corresponding playlist tab when it exists. Playback, interface, and column-visibility preferences use the typed native preference bridge. Theme, ink, font, and playlist column order use WebKit local storage when available. Playlist tabs and their track snapshots use a separate native `playlistTabsLoad` / `playlistTabsSave` bridge pair.

Selection, sidebar disclosure, and column-width animations use the shared easing curve and update at no more than 60 frames per second. Animation duration and enablement remain user-adjustable in Interface. Changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
