# ViewBoy Integration

ViewBoy owns its AppKit host, Yoga canvas renderer, bitmap fonts, framebuffer, in-screen options, and preference namespace. The app loads `Resources/index.html` in one WKWebView. Keep screen content in the canvas; HTML and CSS provide the canvas host and three flat membrane outlines.

## Data and Playback

The injected `window.viewBoy` bridge supplies read-only CatalogReader projections, shared favorite operations, frontend preferences, local-path selection, and VGMBoy transport. `window.ViewBoy.dispatch` is the macOS menu command boundary. Both names are local to ViewBoy. Long Play, Repeat One, and the `randomMode` (`off`, `playlist`, or `library`) preference are stored in `ViewBoyPreferencesSnapshot`; random shuffle history and per-cycle seen-track state stay in the renderer. Playlist Random chooses from the active queue without replacement until a cycle ends. Library Random weights catalog game groups by `trackCount`, queries only the selected game's tracks, and avoids immediately replaying the current track when another song is available. Previous and Next in either random mode use a renderer history capped at 256 track entries; Library Random history retains only each selected track rather than previously fetched game playlists.

Catalog and favorite state belongs to the native/shared cores. JavaScript owns the visible tree, current view, table layout, sorting, font and contrast preferences, and hit testing. It must not scan source paths or write the catalog. Track activation sends the native playback fields supplied by the bridge, including archive path and entry.

JavaScript owns the in-memory playlist-tab projection; native `playlistTabsLoad` and `playlistTabsSave` store snapshots under a dedicated UserDefaults key. Snapshots contain up to 64 tabs, each with its title, catalog key, track projections, selection, and scroll position. Saving validates the tab count, list size, and encoded payload before persistence. Loading restored snapshots must not overwrite them while the initial catalog view is being hydrated.

## Rendering and Lifecycle

- `yoga-app.js` paints the full UI as four integer framebuffer shades and authored bitmap glyphs. GameBoy and NightBoy are palettes for the same framebuffer; High Contrast changes shade 0 only. Keep browser text, gradients, or selection overlays out of the screen.
- One LCD dot occupies a 3×3 device-pixel cell. The 2×2 face uses one of four palette entries; its edge always uses the background shade.
- Resize events recreate canvas buffers and then render synchronously. Auto-sized table columns interpolate their widths with the shared auto-resize duration; header cells and track cells use the same widths. Track selection paints from the cached base framebuffer without rebuilding the Yoga tree and follows the shared selection duration. Sidebar disclosure follows the shared auto-resize duration. Each animation gates framebuffer updates to no more than 60 Hz while using requestAnimationFrame timestamps for elapsed time. Page teardown cancels pending selection, sidebar, and column animation frames.
- The Micro and Standard glyph tables, theme, ink contrast choice, control padding, UI gap, playlist gap, transport label style, and playlist column order are presentation preferences stored in WebKit local storage. Read legacy `uiGutterDots` as the initial `uiGapDots` value for existing installs. Playback and playlist-column visibility preferences remain in `ViewBoyPreferencesSnapshot`.
- Playlist tab snapshots are stored through the native `playlistTabsLoad` / `playlistTabsSave` bridge, separately from display and playback preferences. Each tab retains its title, track projection, selection, and scroll position; the active tab changes the visible list and queue.
- The playlist table keeps every enabled column in one clipped horizontal viewport. Trackpad `deltaX`, Shift+wheel, the bottom scrollbar, and Shift+Left/Right scroll it; header dragging reorders movable columns while `#` remains pinned first.
- Center panel titles and playlist headings. The sidebar starts with its pixel-rendered Search Library field, then compact Library, Queue, Favorites, Open Path, Sync, and Options actions and the catalog tree. Search filters game and system names in the current catalog projection; keep it in the canvas and handle text input through the canvas key handler. The playlist pane puts its single-frame tab strip above the table headings. Sidebar, playlist, and Options panes use the shared bottom status-bar style; keep counts and page names in those footers.
- Right-clicking any playlist heading opens an in-canvas LCD menu for File, Game, Artist, Path, and Size. Keep visibility changes on the typed frontend-preference bridge and retain `[x]`/`[]` as a direct shared-favorite toggle.
- `yoga-screen.css` owns only the narrow shell around the canvas. Its `data-theme="NIGHTBOY"` palette uses a dark-purple shell and silver bevels; keep interface text and selection UI in the framebuffer.
- Display spacing in `yoga-app.js` is saved as local presentation state. Control padding changes text inset, standard control height, and vertical breathing room for playlist and system-tree rows; UI gap drives shared gaps and proportional group/pane insets, including tab-strip spacing and the gap before playlist headings; playlist gap sets shared column-heading and track-cell spacing. Clamp each spacing value to one through eight dots. The app border remains eight dots. `controlRow`, `panelTitle`, and `statusBar` provide shared row treatments, with each pane footer anchored after a flex spacer.
- Options uses a vertical TOC and one full-width content pane with Display, Theme, Transport, Playback, Methods, Audio, Interface, and Library pages. Transport label style (`WORDS` or `SYMBOLS`) is local presentation state and must preserve accessible hit-target names. Playback owns timing and repeat/random behavior; Methods owns backend tempo settings. Audio draws ten directly clickable horizontal gain bars, each with a 100-dot minimum width and a 25-value range (0 to +12 dB in 0.5 dB steps). Bar clicks quantize to the nearest step, animate through the shared easing/timing policy, and save `equalizerBandGains` through `setPreference`; audio edits call `nativePlaybackAudioConfig`.
- On the main screen, center transport and playback-mode toolbars inside a wrapper exactly half the available screen width. Buttons in each row share the row width equally; keep Options in the sidebar action row. Options has only its Back action at the top and removes both main-screen toolbar rows.
- Command-comma opens Options. Command-1 through Command-9 select available playlist tabs. Keep the shortcuts in the canvas key handler and preserve unmodified numeric shortcuts for Library, Queue, and Options.
- Playback Options persist Long Play duration, unknown-length duration, fade duration, per-backend libgme/libvgm tempo, volume, mono output, and all ten equalizer gains through `ViewBoyPreferencesSnapshot`. Resolve a track's speed support from the native playback-backend manifest instead of duplicating the format-extension table in JavaScript. Timing and speed edits reconfigure the active playback request.
- The browser canvas without the injected native bridge cannot query the catalog or control playback. Real catalog and transport checks must run in the packaged app.

## Build and Verification

`./build.sh` clean-builds and packages ViewBoy. `./launch.sh` closes the prior ViewBoy process, builds, signs, and opens the package. Validate the packaged screen and native bridge after changing the WebKit host or resource files; JavaScript syntax and Swift compilation alone do not prove live catalog or transport behavior.

## Files

- `Sources/ViewBoy/Resources/index.html`
- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/Resources/yoga-screen.css`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `Sources/ViewBoy/WKPlaybackBridge.swift`
- `Sources/ViewBoy/main.swift`
