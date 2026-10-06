# Display and controls

The display offers direct choices for 320×240, 512×384, 640×480, 800×600, and
1024×768. The active raster is shown in the header along with its text grid.
Resolution buttons remain visible in one text row. Changing one updates the
raster dimensions, row and column counts, grid divider, and scan pass together.

Each 8×16 glyph cell gives the raster its text capacity: columns are width ÷ 8,
and complete text rows are floor(height ÷ 16). The app selects the largest
supported integer beam scale that fits the available window; resizing changes
that scale, never the cell dimensions or the number of columns. The standard
320×240 mode is 40 columns by 15 rows. At 800×600, 100 columns fit 37 complete
rows, leaving a centered four-pixel blank inset above and below rather than
splitting text across a fractional row.

The layout uses 8-pixel columns and 16-pixel text rows. Its title, resolution
choices, command bar, library, playlist, and status line occupy explicit rows.
Labels and controls center within their row; the beam renderer snaps glyph
baselines to the same 16-pixel cadence. The library and playlist scroll one
text row at a time.

The sample library supports folder disclosure and selection. Selecting the
Chrono Trigger or Super Metroid entry loads that game's sample track list. The
Favorites control filters the current sample list; track selection, previous,
next, and play/pause update the local status display. File open remains a demo
placeholder and does not load audio.
