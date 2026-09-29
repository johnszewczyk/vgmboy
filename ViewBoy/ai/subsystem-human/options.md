# Options

Options fills the LCD with a vertical table of contents and one spacious content pane. The TOC has Display, Theme, Transport, Playback, Methods, Audio, Interface, and Library pages. Each pane pins its status footer to the bottom edge. Groups use section headers and outlined rows; checkboxes show `[x]` when enabled and `[ ]` when off. `[-]` and `[+]` adjust numeric values.

The Interface page exposes three independent spacing values in LCD dots: Control Padding changes text insets and vertical padding on controls, playlist rows, and system-tree rows; UI Gutter sets shared item gaps, group insets, and pane padding; Playlist Gap sets spacing between playlist tabs and table columns. Each value ranges from one to eight dots and defaults to four. The LCD content stays eight dots inside the app border, and the surrounding shell has an eight-CSS-pixel outer gap.

- **Display** selects Micro 3×5 or Standard 5×7 bitmap text.
- **Theme** selects the GameBoy or NightBoy four-tone palette and standard or high-contrast ink. The palette sample shows the four screen tones.
- **Transport** selects Words or Symbols for the Previous, Play/Pause, Next, and Stop buttons. The symbol set uses authored bitmap glyphs.
- **Playback** provides Long Play, End Fade, Repeat Off/All/One, Random Off/Playlist/Library, and track timing. Long Play duration adjusts in 30-second steps from zero (open ended) to one hour; the unknown-length default adjusts from 30 seconds to one hour; fade duration adjusts from zero to 60 seconds.
- **Methods** provides separate libgme and libvgm speed controls. Each enables native tempo support and adjusts rates in 1/32 steps from 1/32× to 8×. The active track's backend is resolved from the native playback capability manifest; supported speed changes reconfigure the live track.
- **Audio** provides Mono Output, Volume, and ten full-width horizontal equalizer bars from 31 Hz to 16 kHz. Each band spans flat 0 to +12 dB in 0.5 dB steps (25 settings) and has a minimum width of 100 LCD dots before it expands to fill the pane. Gain changes ease with the shared animation timing, easing curve, and 60-frame-per-second limit. Gain, volume, and mono changes update the native audio path.
- **Interface** controls automatic column sizing, header-and-row resize motion and duration, track-selection slide timing, and Main Window on Top. Auto-sized metadata columns fit the longest value in the active table plus the heading and sort marker; the flexible Title column stays left-aligned. Headers and rows share measured widths and animate together.
- **Library** persists visibility for File, Game, Artist, Path, and Size. Right-click any playlist heading to open the same checkbox list in an LCD pop-up. Every enabled column remains in the table even when the screen is too narrow; the table clips to its pane and scrolls horizontally. Drag a header to reorder columns. The numbered `#` column stays first and cannot be moved. Library also reloads a fresh read from the catalog.

Command-comma opens Options. Command-1 through Command-9 select the corresponding playlist tab when it exists. Playback, interface, and column-visibility preferences use the typed native preference bridge. Theme, ink, font, spacing, transport label style, and playlist column order use WebKit local storage when available. Playlist tabs and their track snapshots use a separate native `playlistTabsLoad` / `playlistTabsSave` bridge pair.

Selection, sidebar disclosure, column-width, and equalizer-gain animations use the shared easing curve and update at no more than 60 frames per second. Animation duration and enablement remain user-adjustable in Interface. Changing display settings does not stop playback.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/ViewBoyPreferencesSnapshot.swift`
