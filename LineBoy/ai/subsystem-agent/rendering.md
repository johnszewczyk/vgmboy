# Renderer and build boundaries

The HTML DOM owns semantic controls and input. Canvas2D captures the layout in
a 2D framebuffer, then a WebGL2 fragment pass draws beam bands with pure-black
gaps. When WebGL2 is unavailable, the visible DOM is the fallback.

Each selected raster defines a fixed 8×16 grid; browser resizing may change
only the integer device-pixel scale. It must not alter cell count, line height,
or column placement. Derive every text baseline from the shared font ascent and
descent, center that font cell within its line, then snap the baseline to the
beam cadence. Do not use per-string ink bounds, which make descenders and
uppercase labels sit at different heights in equal highlight rows. At 800×600,
center 37 complete rows with a four-pixel inset above and below; do not place
text on a half-height row.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory. `launch.sh` builds first, then serves that directory
on loopback. No native bridge, catalog, or decoder is part of this package.
