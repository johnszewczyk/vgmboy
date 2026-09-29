# ViewBoy Integration

ViewBoy owns its AppKit host, Yoga canvas renderer, bitmap fonts, framebuffer, in-screen options, and preference namespace. The app loads `Resources/index.html` in one WKWebView. Keep screen content in the canvas; HTML and CSS provide only the canvas host and its narrow plastic surround.

## Data and Playback

The injected `window.viewBoy` bridge supplies read-only CatalogReader projections, shared favorite operations, frontend preferences, local-path selection, and VGMBoy transport. `window.ViewBoy.dispatch` is the macOS menu command boundary. Both names are local to ViewBoy. Long Play, Repeat One, and the `randomMode` (`off`, `playlist`, or `library`) preference are stored in `ViewBoyPreferencesSnapshot`; random shuffle history and per-cycle seen-track state stay in the renderer. Playlist Random chooses from the active queue without replacement until a cycle ends. Library Random weights catalog game groups by `trackCount`, queries only the selected game's tracks, and avoids immediately replaying the current track when another song is available. Previous and Next in either random mode use a renderer history capped at 256 track entries; Library Random history retains only each selected track rather than previously fetched game playlists.

Catalog and favorite state belongs to the native/shared cores. JavaScript owns the visible tree, current view, table layout, sorting, font and contrast preferences, and hit testing. It must not scan source paths or write the catalog. Track activation sends the native playback fields supplied by the bridge, including archive path and entry.

## Rendering and Lifecycle

- `yoga-app.js` paints the full UI as four integer framebuffer shades and authored bitmap glyphs. GameBoy and NightBoy are palettes for the same framebuffer; High Contrast changes shade 0 only. Keep browser text, gradients, or selection overlays out of the screen.
- One LCD dot occupies a 3×3 device-pixel cell. The 2×2 face uses one of four palette entries; its edge always uses the background shade.
- Resize events recreate canvas buffers and then render synchronously. Auto-sized table columns interpolate their widths with the shared auto-resize duration; header cells and track cells use the same widths. Track selection paints from the cached base framebuffer without rebuilding the Yoga tree and follows the shared selection duration. Sidebar disclosure follows the shared auto-resize duration. Each animation gates framebuffer updates to no more than 60 Hz while using requestAnimationFrame timestamps for elapsed time. Page teardown cancels pending selection, sidebar, and column animation frames.
- The Micro and Standard glyph tables, theme, ink contrast choice, and playlist column order are presentation preferences stored in WebKit local storage. Playback and playlist-column visibility preferences remain in `ViewBoyPreferencesSnapshot`.
- The playlist table keeps every enabled column in one clipped horizontal viewport. Trackpad `deltaX`, Shift+wheel, the bottom scrollbar, and Shift+Left/Right scroll it; header dragging reorders movable columns while `#` remains pinned first.
- Center panel titles and playlist headings. The sidebar begins with Library, Queue, Favorites, Open Path, and catalog reload actions; the table begins directly at its header row and shares a compact status bar with the sidebar.
- Right-clicking any playlist heading opens an in-canvas LCD menu for File, Game, Artist, Path, and Size. Keep visibility changes on the typed frontend-preference bridge and retain `[x]`/`[ ]` as a direct shared-favorite toggle.
- `yoga-screen.css` owns only the narrow shell around the canvas. Its `data-theme="NIGHTBOY"` palette uses a dark-purple shell and silver bevels; keep interface text and selection UI in the framebuffer.
- Outline buttons share a font-derived height that leaves two display dots between text and each one-dot border. Button text has a consistent one-dot minimum inset on both sides. Options columns indent by one active-font character. Playlist rows use two vertical dots of space above and below their text.
- Playback Options persist Long Play duration, unknown-length duration, fade duration, volume, mono output, and all ten equalizer gains through `ViewBoyPreferencesSnapshot`. Timing edits reconfigure the active playback request; audio edits call `nativePlaybackAudioConfig`.
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
