# Renderer and build boundaries

The HTML DOM owns semantic controls and input. Canvas2D captures the layout in
a 2D framebuffer, then a WebGL2 fragment pass draws beam bands with pure-black
gaps. When WebGL2 is unavailable, the visible DOM is the fallback. The native
WebKit host injects catalog and transport services through a narrow message
bridge; the browser preview falls back to sample data.

Each selected raster defines a fixed 8×16 grid; browser resizing may change
only the integer device-pixel scale. It must not alter cell count, line height,
or column placement. ModernDOS8x16 metrics are 12px ascender, 4px descender,
and 10px cap height. Place the baseline 13 source pixels from the row top so
visible capital ink has a three-pixel top and bottom margin, then snap to the
beam cadence. Do not use per-string ink bounds, which make descenders and
uppercase labels sit at different heights in equal highlight rows. At 800×600,
center 37 complete rows with a four-pixel inset above and below; do not place
text on a half-height row.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory and packages `.build/LineBoy.app`. `launch.sh` builds,
closes an existing LineBoy process, and opens the fresh app. The static preview
serves mock data; the WebKit app routes catalog, favorites, queue movement, and
playback to the shared VGMMan components.
