# Renderer and build boundaries

The HTML DOM owns semantic controls and input. Canvas2D captures the layout in
a 2D framebuffer, then a WebGL2 fragment pass draws beam bands with pure-black
gaps. When WebGL2 is unavailable, the visible DOM is the fallback. The native
WebKit host injects catalog and transport services through a narrow message
bridge; the browser preview falls back to sample data.

The 320×240 raster defines the physical 4:3 core. Choose its largest fitting
even device-pixel scale, falling back to one only in a smaller window, then
keep that core frame fixed across raster modes. Higher modes use fractional
source-pixel pitch; snap frame edges and glyph baselines to output pixels and
antialias the beam edge in WebGL. Show the current physical pitch.

ModernDOS8x16 has a 10px cap height in a 16px cell. Anchor the baseline to each
DOM cell's top at source row 13, then snap it to the output device grid. Do not
infer the baseline from a text range: WebKit's range box may sit high within a
highlighted cell and varies with inline layout. Keep every row on the exact
16px source advance. At 800×600, center 37 complete rows with a four-pixel
source inset above and below; do not place text on a half-height row.

Do not emulate phosphor persistence. During tree or playlist scrolling, expose
the native DOM so WebKit can scroll with momentum; wait 160ms after the last
scroll event, then capture and shade one settled frame. Keep row snapping at
proximity rather than mandatory. Load catalog group summaries during bootstrap,
fetch game rows only when a group expands, and remove their DOM rows on collapse.
Run catalog reads off the main actor. Cull off-viewport descendants before
querying text geometry. Render on state changes; never run a permanent
animation loop.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory and packages `.build/LineBoy.app`. `launch.sh` builds,
closes an existing LineBoy process, and opens the fresh app. The static preview
serves mock data; the WebKit app routes catalog, favorites, queue movement, and
playback to the shared VGMMan components.
