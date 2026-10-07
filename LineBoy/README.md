# LineBoy

LineBoy is a monochrome DOS-style player interface experiment. It lays every
control, label, sidebar item, and track row onto an 8×16 character-cell grid,
then paints it with full-intensity beam rows and crisp, integer-pixel black
gaps. The filter preserves the font's fixed character advance. The native
WebKit host reads the shared VGMMan catalog, persists favorites through
FrontendCore, and routes playback through the shared transport and VGMBoy
decoder. The browser build remains a sample-data preview without native
services.

## Display grid

Resolution buttons stay visible on the second screen row. Each choice changes
the fixed raster and the number of text columns and rows; the interface does
not reflow to fit the browser window.

| Raster | Text grid | Beam scale steps |
| --- | --- | --- |
| 320×240 | 40×15 | 6, 4, 2 device pixels per source pixel |
| 512×384 | 64×24 | 4, 3, 2, 1 |
| 640×480 | 80×30 | 3, 2, 1 |
| 800×600 | 100×37½ | 2, 1 |
| 1024×768 | 128×48 | 2, 1 |

The 800×600 layout centers 37 complete text rows with a four-pixel inset at
both edges. All controls and text stay on 16-pixel rows; the half-line is blank
screen space.

## Build and launch

Run `./build.sh` to build the native app at `.build/LineBoy.app` and the static
preview under `.build/site`. Run `./launch.sh` to rebuild, close any running
LineBoy instance, and open a fresh native app. To inspect the sample-only
browser preview, serve `.build/site` on loopback with Python's HTTP server.

The native host owns catalog and transport adapters; the HTML owns the shared
8×16 grid, keyboard interaction, and a persistent WebGL2 scanline mask above
the live DOM. Scrolling stays beneath that one fixed filter. Both hosts use the
same interface, while only the native host has access to CatalogReader,
FrontendCore, and VGMBoy. The native app also supplies standard macOS app,
File, Edit, View, and Window menus, including Command+O, Command+comma,
Control+Command+F, Command+W, and Command+Q.

The font `assets/ModernDOS8x16.ttf` is Modern DOS 8×16 by Jayvee Enaguas,
dedicated under CC0 1.0. The included `assets/CC0-1.0.txt` preserves its
license.
