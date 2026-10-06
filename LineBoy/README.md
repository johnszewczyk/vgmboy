# LineBoy

LineBoy is a monochrome DOS-style player interface experiment. It lays every
control, label, sidebar item, and track row onto an 8×16 character-cell grid,
then paints the grid through a CRT beam pass. Its local sample library,
favorites, tree, playlist, and transport controls are interactive mock data;
catalog and audio playback are not connected.

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

Run `./build.sh` to assemble the static app under `.build/site`. Run
`./launch.sh` to serve that build at `http://127.0.0.1:8765/`. Set
`LINEBOY_PORT` to use a different loopback port.

The font `assets/ModernDOS8x16.ttf` is Modern DOS 8×16 by Jayvee Enaguas,
dedicated under CC0 1.0. The included `assets/CC0-1.0.txt` preserves its
license.
