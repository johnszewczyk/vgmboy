# Display and controls

The display offers direct choices for 320×240, 512×384, 640×480, 800×600, and
1024×768. The selected profile sets text and scanline density. The grid extends
to the available window height in whole 16-pixel rows; WIDTH MODE FILL also
extends its width in whole 8-pixel columns. FRAME keeps the selected profile's
4:3 width. Text is never stretched to fill unused space. The header shows the
active grid, selected profile, and beam pitch. Resolution buttons stay in one
text row.

Each 8×16 glyph cell gives the raster its text capacity: columns are active
width ÷ 8, and complete text rows are floor(height ÷ 16). The selected profile
sets its cell scale from the 320×240 reference and the largest fitting even
device-pixel multiple. The viewport then adds whole glyph rows without changing
that scale. Every text row maps to a whole number of equally spaced beam passes,
so scan pitch remains integral as the window grows. Frame edges and glyph
baselines snap to the beam grid. At 800×600, the base profile has 100 columns
and 37 complete rows, with a centered four-pixel inset when no extra rows are
needed.

The layout uses 8-pixel columns and 16-pixel text rows. Its title, resolution
choices, command bar, library, playlist, and status line occupy explicit rows.
Labels and controls use the same cell-top baseline: the 10px cap ink is centered
inside its 16px row, with three source pixels above and below. The baseline
snaps to the output device grid. During tree or playlist scrolling, native
WebKit scrolling stays live and row snapping is proximity-based; the scanline
pass returns after 160ms without scroll input.

Phosphor persistence is disabled to keep interaction responsive. OPTIONS opens
a two-column terminal settings view with WIDTH MODE (FILL or FRAME), SCANLINES,
the active beam pitch, and a native fullscreen toggle. FILL and FRAME, the
scanline setting, and the selected raster profile are remembered. The window can
also enter fullscreen from its standard window control.

In the native app, the library tree loads group counts from the shared catalog
and fetches a group's game rows when it expands. Selecting a game loads its
tracks, F on a selected track toggles shared
Favorites, and FAV filters the current playlist. Previous and next use the
shared queue rules and start the adjacent track. PLAY pauses or resumes;
double-clicking a row starts it. FILE opens a supported local file through the
native picker. The browser preview keeps its sample library and local-only
transport behavior.
