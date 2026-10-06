# Renderer and build boundaries

The HTML DOM owns semantic controls and input. The 2D framebuffer captures the
layout, while a WebGL2 fragment pass draws beam bands with pure-black gaps.
When WebGL2 is unavailable, the visible DOM is the fallback.

Each selected raster defines a fixed 8×16 grid; browser resizing may change
only the integer device-pixel scale. It must not alter cell count, line height,
or column placement. Glyph baselines snap to the beam cadence. At 800×600,
center 37 complete rows with a four-pixel inset above and below; do not place
text on a half-height row.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory. `launch.sh` builds first, then serves that directory
on loopback. No native bridge, catalog, or decoder is part of this package.
