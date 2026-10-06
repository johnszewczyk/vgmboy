# Renderer and build boundaries

The HTML DOM owns semantic controls and input. Canvas2D captures the layout in
a 2D framebuffer, then a WebGL2 fragment pass draws beam bands with pure-black
gaps. When WebGL2 is unavailable, the visible DOM is the fallback. The native
WebKit host injects catalog and transport services through a narrow message
bridge; the browser preview falls back to sample data.

Each selected raster defines a fixed 8×16 grid; browser resizing may change
only the integer device-pixel scale. It must not alter cell count, line height,
or column placement. ModernDOS8x16 has a 10px cap height in a 16px cell. Anchor
the baseline to each DOM cell's top at source row 13, giving capitals three
source pixels above and below, then snap to the beam cadence. Do not infer the
baseline from a text range: WebKit's range box may sit high within a highlighted
cell and varies with inline layout. Keep every row on the exact 16px advance.
At 800×600, center 37 complete rows with a four-pixel inset above and below;
do not place text on a half-height row.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory and packages `.build/LineBoy.app`. `launch.sh` builds,
closes an existing LineBoy process, and opens the fresh app. The static preview
serves mock data; the WebKit app routes catalog, favorites, queue movement, and
playback to the shared VGMMan components.
