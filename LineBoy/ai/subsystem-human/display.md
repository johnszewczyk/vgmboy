# Display and controls

The display offers direct choices for 320×240, 512×384, 640×480, 800×600, and
1024×768. The active raster is shown in the header along with its text grid.
Resolution buttons remain visible in one text row. Changing one updates the
raster dimensions, row and column counts, grid divider, and scan pass together.

Each 8×16 glyph cell gives the raster its text capacity: columns are width ÷ 8,
and complete text rows are floor(height ÷ 16). The 320×240 mode defines the
physical 4:3 frame, scaled by the largest whole device-pixel multiple that fits
the window. Other resolutions keep that frame and increase raster fineness;
their source pixels map fractionally onto the output grid. Frame edges and glyph
baselines snap to output pixels, and the shader smooths the beam edge. The
header reports the physical pitch. At 800×600, 100 columns fit 37 complete
rows, leaving a centered four-pixel source inset above and below.

The layout uses 8-pixel columns and 16-pixel text rows. Its title, resolution
choices, command bar, library, playlist, and status line occupy explicit rows.
Labels and controls use the same cell-top baseline: the 10px cap ink is centered
inside its 16px row, with three source pixels above and below. The baseline
snaps to the output device grid. The library and playlist scroll one text row
at a time.

The scanline renderer briefly adds the previous frame at low opacity when
content changes, then fades it over 240ms. This is a first phosphor-persistence
experiment; there is no curvature or overscan.

In the native app, the library tree is populated from the shared catalog.
Selecting a game loads its tracks, F on a selected track toggles shared
Favorites, and FAV filters the current playlist. Previous and next use the
shared queue rules and start the adjacent track. PLAY pauses or resumes;
double-clicking a row starts it. FILE opens a supported local file through the
native picker. The browser preview keeps its sample library and local-only
transport behavior.
