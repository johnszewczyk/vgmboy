# Display and controls

The display offers direct choices for 320×240, 512×384, 640×480, 800×600, and
1024×768 on one adaptive 8×16 grid. The selected profile sets text and
scanline density. The grid extends to the available window height in whole
16-pixel rows; WIDTH MODE FILL also extends its width in whole 8-pixel
columns. FRAME keeps the selected profile's 4:3 width. Text is never stretched
to fill unused space. Resolution choices spread evenly across their row; the
command toolbar expands its view blocks across the remaining width and keeps
transport controls at the right.

Each 8×16 glyph cell gives the raster its text capacity: columns are active
width ÷ 8, and complete text rows are floor(height ÷ 16). The selected profile
sets its cell scale from the 320×240 reference and the largest fitting even
device-pixel multiple. The viewport then adds whole glyph rows without changing
that scale. Every text row maps to a whole number of equally spaced beam passes,
so scan pitch remains integral as the window grows. Frame edges and glyph
baselines snap to the beam grid. At 800×600, the base profile has 100 columns
and 37 complete rows, with a centered four-pixel inset when no extra rows are
needed.

The window keeps an 8-pixel inset around the terminal, leaving a visible frame
inside the native macOS title-bar area. The layout uses 8-pixel columns and
16-pixel text rows. Its title, resolution choices, curses-style command bar,
library, playlist, and status line occupy explicit rows. The title row keeps
only grid, beam pitch, and clock readouts so the controls have room.
Labels and controls use the same cell-top baseline: the 10px cap ink is centered
inside its 16px row, with three source pixels above and below. The fixed-width
font keeps an 8px advance, with kerning and ligatures disabled. The baseline
snaps to the output device grid. During tree or playlist scrolling, native
WebKit scrolling stays live and row snapping is proximity-based. One fixed
scanline mask stays above the live interface for the entire interaction: the
WebGL overlay draws fully transparent beam rows and integer device-pixel black
gaps, never a snapshot of the text. It does not shade beam rows or glyph edges
with a grayscale spot profile. Scrolling moves continuously underneath the
same filter. The CSS mask provides the same fixed-gap fallback when WebGL2 is
unavailable.

Filled command buttons are separate blocks with one character cell between
buttons and a two-cell blank gap before transport. There is no visible divider
between the command and transport groups. The resolution profile row remains a
separate testing control row.

The playlist has a horizontal tab strip above its track headings. Selecting a
tab restores that playlist, its selected track, favorites filter, and scroll
position. The plus control or Command+T creates a copy of the current playlist;
each tab can be closed while at least one remains open. Command+1 through
Command+9 selects one of the first nine tabs. Tab state persists between native
app launches and in the browser preview's local storage. Native catalog rows
are reloaded lazily when a saved catalog-backed tab is selected; the app still
starts in sample mode without loading the full catalog.

One white selection block travels between the active top toolbar control and
the option-category tabs. DISPLAY can turn that motion off. The library starts
at one-third of the available character columns and keeps at least 20 columns
for its content pane. Its DISPLAY sidebar-width slider and draggable separator
use the same 8px character-column bounds and saved value; arrow keys change one
column at a time, Home restores the one-third default, and End sets the widest
allowed library pane. Brightness runs from 60% to 140% and remaps the monochrome
palette while leaving the pure-black scanline gaps unchanged. Brightness,
selector motion, and pane width persist with the display preferences.

Phosphor persistence is disabled to keep interaction responsive. OPTIONS opens
a two-column terminal settings view. DISPLAY contains WIDTH MODE (FILL or
FRAME), SCANLINES, BRIGHTNESS, SELECTOR FLOW, the active beam pitch, and a
native fullscreen toggle. CRT contains a THIN/NORMAL/WIDE beam-width control
and reports the active pitch. FILL and FRAME, scanline visibility, brightness,
selector motion, pane width, beam width, and the selected raster profile are
remembered. The native app provides standard macOS menus and
shortcuts: Command+O opens a file, Command+comma opens OPTIONS, Control+Command+F
toggles fullscreen, Command+M minimizes, Command+W closes the window, and
Command+Q quits. The Edit menu forwards standard text commands to WebKit.

The native app currently starts from the same small sample library as the
browser preview. `LIVE_CATALOG_ENABLED` is false in `index.html`, so startup
does not bootstrap the full shared catalog. Turning it on restores the native
CatalogBrowserCore search projection and lazy group loading. In sample mode,
Command+F searches the sample games; clearing the query restores the tree and
its prior selection. Selecting a game loads its sample tracks. F toggles local
sample favorites and FAV filters the current playlist. The native file picker
remains connected for opening a real local track; its playback uses the native
transport, while sample-track playback and track stepping stay local.
