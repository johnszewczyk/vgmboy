# LineBoy prototype

Standalone visual mockup for a monochrome DOS-style ViewBoy sibling. It uses a
compact CP437-inspired screen font, black and gray surfaces, reverse-video
command blocks, and a simulated monochrome CRT raster. Track and toolbar
controls are local presentation interactions only; this prototype is not wired
to the catalog or playback bridge.

The standard mode is a 320×240 source raster: 40 eight-pixel columns by 15
sixteen-pixel rows. One 8×16 Modern DOS font drives every control and text
line. Command names, tree entries, playlist rows, column starts, and separators
use that same cell grid; the standard screen has no function-key labels or
boxed button row. The CRT pass resolves each font-row pixel to a six-device-
pixel beam interval at the normal high-DPI viewport, centered on the glyph
raster with pure-black gaps between illuminated bands.

The resolution control in the top status row opens direct choices for 320×240,
512×384, 640×480, 800×600, and 1024×768. The selected source raster remains
fixed while its device scale steps down in integers to fit the available view.
The standard 320×240 raster prefers six-device-pixel scan rows, then four or
two; the larger rasters use two or one. Text glyph tops snap to the same cadence
as the beam.

Top command and transport controls share one reverse-video button style: a
single glyph-row gray block with black text. Sidebar entries use full 16-pixel
rows for hit targets and inverse-video hover, focus, and selection states. The
library list supports single selection and Up/Down, Home, and End keyboard
navigation.

A WebGL2 fragment shader draws the framebuffer through a beam profile. Its
spot width changes slightly with brightness; pixels outside each spot are
emitted as pure black. Nearest-neighbor texture sampling keeps source pixels
sharp, and text glyph tops snap to the same row cadence as the beam. The pass
runs after content, layout, scroll, or pointer changes. This is a compact
monochrome CRT model, not a complete analog display simulation: it omits color
phosphor masks, NTSC artifacts, curvature, and beam flicker. The browser keeps
the semantic interface available as a fallback when WebGL2 or framebuffer
rendering is unavailable.

`assets/ModernDOS8x16.ttf` is Modern DOS 8x16 by Jayvee Enaguas. It is based on
IBM VGA and Verite PC fonts and is dedicated under CC0 1.0. The font and a copy
of its license are included in `assets/`. Source: [original project](https://notabug.org/HarvettFox96/ttf-moderndos), [read-only mirror](https://github.com/notpeter/ttf-moderndos).

Open `index.html` in a browser, or serve this directory locally with:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory ViewBoy/Prototypes/LineBoy
```
