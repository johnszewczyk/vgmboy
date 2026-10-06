# Renderer and build boundaries

The HTML DOM owns semantic controls and input. Canvas2D captures the layout in
a 2D framebuffer, then a WebGL2 fragment pass draws beam bands with pure-black
gaps. When WebGL2 is unavailable, the visible DOM is the fallback. The native
WebKit host injects catalog and transport services through a narrow message
bridge; the browser preview falls back to sample data.

The 320×240 raster defines the physical 4:3 core. Choose its largest whole
device-pixel scale that fits the window, then keep that core frame fixed across
all raster modes. Higher modes use fractional source-pixel pitch; snap frame
edges and glyph baselines to output pixels and antialias the beam edge in
WebGL. The 320×240 mode remains pixel-exact. Show the current physical pitch.

ModernDOS8x16 has a 10px cap height in a 16px cell. Anchor the baseline to each
DOM cell's top at source row 13, then snap it to the output device grid. Do not
infer the baseline from a text range: WebKit's range box may sit high within a
highlighted cell and varies with inline layout. Keep every row on the exact
16px source advance. At 800×600, center 37 complete rows with a four-pixel
source inset above and below; do not place text on a half-height row.

The WebGL display keeps one previous frame as a screen-blended afterimage at
18% opacity, decaying over 240ms after UI changes. This is a first-pass
phosphor cue; omit curvature and overscan, and respect reduced-motion settings.

`build.sh` copies the runtime HTML and licensed font into the ignored
`.build/site` directory and packages `.build/LineBoy.app`. `launch.sh` builds,
closes an existing LineBoy process, and opens the fresh app. The static preview
serves mock data; the WebKit app routes catalog, favorites, queue movement, and
playback to the shared VGMMan components.
