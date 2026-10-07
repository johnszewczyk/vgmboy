# Renderer and build boundaries

The HTML DOM owns all visible content, interaction, and native scrolling. A
transparent WebGL2 overlay draws only the stationary scanline mask: beam centers
stay clear, while beam edges and gaps darken the DOM beneath it. Never capture
or redraw text into a framebuffer. Keep the mask above the DOM during scrolling
and do not switch rendering paths when scroll starts or stops. When WebGL2 is
unavailable, use the fixed CSS mask with the same pitch and beam width. The
native WebKit host injects catalog and transport services through a narrow
message bridge; the browser preview falls back to sample data.

The selected raster profile uses the 320×240 reference to choose its largest
fitting even device-pixel multiple. Extend the viewport in whole 16-pixel text
rows at that scale; in FILL width mode, extend it in whole 8-pixel columns.
FRAME keeps the selected profile's 4:3 width. Never stretch glyphs to cover
remainder space. Map each text cell to an integer number of equal beam pitches;
keep the shader pitch integral even when the source-to-output scale is
fractional. Snap frame edges and glyph baselines to the beam grid; antialias
the beam edge in WebGL.

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
and beam width in local display preferences. The WebGL beam-radius uniform and
CSS fallback use the same THIN/NORMAL/WIDE setting. SCANLINES off exposes the
DOM without changing the grid. The resolution row and view toolbar must flex
with the active column count so controls use available width at each profile.
Route native fullscreen requests through the LineBoy bridge to the owning
NSWindow; the browser preview uses the document fullscreen API.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory and packages `.build/LineBoy.app`. `launch.sh` builds,
closes an existing LineBoy process, and opens the fresh app. The static preview
serves mock data; the WebKit app routes catalog, favorites, queue movement, and
playback to the shared VGMMan components.
