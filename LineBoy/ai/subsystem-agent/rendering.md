# Renderer and build boundaries

The HTML DOM owns all visible content, interaction, and native scrolling. A
transparent WebGL2 overlay draws only the stationary scanline mask: bright beam
rows stay fully transparent and the remaining rows are pure black gaps. Never
shade beam rows or glyphs with a grayscale spot profile, and never capture or
redraw text into a framebuffer. Keep the mask above the DOM during scrolling
and do not switch rendering paths when scroll starts or stops. When WebGL2 is
unavailable, use the fixed CSS mask with the same integer beam-row count and
pitch. The native WebKit host injects catalog and transport services through a
narrow message bridge; the browser preview falls back to sample data.

The playlist-tab strip and snapshot payload belong to LineBoy's HTML. Persist
the version-1 `{version, activeID, tabs}` envelope through the shared
`PlaylistTabsJSONFileStore` in native mode and `localStorage` in preview mode.
Keep its tab-count and title limits aligned with the shared store. Snapshots
store the active playlist rows, source identity, selected track, favorites
filter, and scroll offset; do not include decoded audio or catalog databases.
Local-file rows store their path as identity and must be revalidated by the
native bridge before playback. Catalog-backed tabs retain root/system/game
identity and fetch their rows only when needed. Keep the full catalog bootstrap
disabled in normal visual testing.

The selected raster profile uses the 320×240 reference to choose its largest
fitting even device-pixel multiple. Extend the viewport in whole 16-pixel text
rows at that scale; in FILL width mode, extend it in whole 8-pixel columns.
FRAME keeps the selected profile's 4:3 width. Never stretch glyphs to cover
remainder space. Map each text cell to an integer number of equal beam pitches;
keep the shader pitch integral even when the source-to-output scale is
fractional. Snap frame edges and glyph baselines to the beam grid. Preserve the
font's fixed 8px advance with kerning and ligatures disabled. Quantize each beam
to an integer number of fully lit device rows and leave at least one pure-black
device row per pitch; do not fade glyph edges or use partial-alpha beam shading.

ModernDOS8x16 has a 10px cap height in a 16px cell. Keep every row on the exact
16px source advance and center labels inside their existing DOM line boxes. Do
not copy glyphs through Canvas2D or infer baselines from WebKit text ranges.
At 800×600, center 37 complete rows with a four-pixel source inset above and
below; do not place text on a half-height row.

Do not emulate phosphor persistence. Keep the WebGL mask anchored to the
terminal while the native DOM scrolls beneath it. Scrolling must not capture a
frame, pause a renderer, or switch between filters. Re-render the mask only
after raster, viewport, scanline, or beam-width changes; do not render on scroll
or text mutations and do not run a permanent animation loop. Keep row snapping
at proximity rather than mandatory. Load catalog group summaries during
bootstrap, fetch game rows only when a group expands, and remove their DOM rows
on collapse. Run catalog reads off the main actor.

Persist the selected raster profile, fill/frame width mode, scanline visibility,
beam width, palette brightness, selector motion, and library-pane width in local
display preferences. Brightness applies a gamma-style remap to the monochrome UI
palette only; retain the transparent beam rows and pure-black scanline gaps.
Keep the selector as one
terminal-level block beneath controls and above their backgrounds; position it
from the target's measured bounds divided by the current terminal zoom. Move it
between toolbar controls and option categories on pointer entry or focus, and
respect the saved motion switch plus `prefers-reduced-motion`. Snap the
resizable separator and DISPLAY width slider to the same 8px source-column
bounds, preserve at least 10 columns in the library and 20 in the content pane
where the raster allows, and default the library to one-third of the available
columns. Keep keyboard arrows in one-column steps, Home at the one-third default,
and End at the maximum width. SCANLINES off exposes the DOM
without changing the grid. The resolution row and view toolbar must flex with
the active column count so controls use available width at each profile.

Keep `LIVE_CATALOG_ENABLED` false for normal visual testing so native startup
uses the sample tree and never bootstraps the full catalog. When deliberately
enabled for integration work, keep search on the shared `CatalogBrowserCore`
game projection: build one `CatalogSearchIndex` from the bootstrap snapshot,
retain it behind the native bridge, and query it off the WebKit event path; do
not reopen SQLite for each keystroke or duplicate searchable-field
normalization in JavaScript. Debounce query updates, cap rendered results at
250, and preserve the tree DOM and its selection while the results scroller is
shown. The sample preview searches its local records. Keep the search input on
its own 16px row aligned to the playlist heading row. Toolbar blocks use a
one-cell internal gap and a two-cell gap before transport; retain the test
resolution row and do not add a visible group divider.

Route native fullscreen requests through the LineBoy bridge to the owning
NSWindow; the browser preview uses the document fullscreen API.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory and packages `.build/LineBoy.app`. `launch.sh` builds,
closes an existing LineBoy process, and opens the fresh app. The static preview
serves mock data. The WebKit host retains native catalog, favorites, queue, and
playback adapters, but visual testing leaves the catalog gate off and uses
local demo records; native file-open and window actions remain active.
