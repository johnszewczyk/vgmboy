# Display and controls

The display offers direct choices for 320×240, 512×384, 640×480, 800×600, and
1024×768 on one adaptive 8×16 grid. The selected profile sets text and
scanline density. The grid extends to the available window height in whole
16-pixel rows; WIDTH MODE FILL also extends its width in whole 8-pixel
columns. FRAME keeps the selected profile's 4:3 width. Text is never stretched
to fill unused space. Resolution choices spread evenly across the first row as
unlabeled blocks. The matching command toolbar gives its six view actions and
three transport actions equal widths.
New installations and Reset Display select the high-resolution 800×600 profile;
saved raster choices remain intact.

Each 8×16 glyph cell gives the raster its text capacity: columns are active
width ÷ 8, and complete text rows are floor(height ÷ 16). The selected profile
sets a target cell scale from the 320×240 reference, then rounds to a whole
number of device pixels per source font pixel. Adjacent profiles can share the
same scale when no intermediate whole-pixel step exists. The viewport then adds whole glyph rows without changing
that scale. Every text row maps to a whole number of equally spaced beam passes,
so scan pitch remains integral as the window grows. Frame edges and glyph
baselines snap to the beam grid. At 800×600, the base profile has 100 columns
and 37 complete rows, with a centered four-pixel inset when no extra rows are
needed.

The window keeps at least an 8-pixel inset around the terminal, leaving a visible frame
inside the native macOS title-bar area. The layout uses 8-pixel columns and
16-pixel text rows. The unlabeled resolution block toolbar leads, followed by
an 8-pixel gutter, the matching command toolbar, another 8-pixel gutter, the
library and playlist, and a two-line status footer. The gutters separate the
control bands without changing the text-row grid.
The footer contains the LineBoy name, grid, beam pitch, clock, current item and
playback state.
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

The resolution and command toolbars use the same square, filled color-block
buttons with one character cell between actions. Each toolbar label is centered
on its 16-pixel row; the active choice and hover or keyboard focus use the white
inverse selector. Library and playlist headers match; the search field and
framed tab toolbar share a two-row band below them. Track headings use light
text on a shaded bar, followed by dense 16px text rows. FILE, TITLE, GAME,
ARTIST, SYSTEM, PATH, and TIME are clickable sort headings. Sorting uses the
shared CatalogPlaylistPresentationCore policy, remembers direction per tab,
and retains the selected track and scroll position.

The playlist has a horizontal tab strip above its track headings. Selecting a
tab restores that playlist, its selected track, favorites filter, and scroll
position. The plus control or Command+T creates a copy of the current playlist;
each tab can be closed while at least one remains open. Command+1 through
Command+9 selects one of the first nine tabs. Tab state persists between native
app launches and in the browser preview's local storage. Native startup loads
the real catalog and filters stale sample tabs; saved catalog tabs restore
their system/game identity and reload tracks lazily. Top-level system groups
and counts use the shared catalog projection; expanding a group reveals its
cached game rows. Selecting a game loads its real playlist rows through the
shared indexed CatalogPlaylistReader query, using the same file, title, game,
artist, system, path, and length projection as CocoaSpice and SB2. Saved rows
stay visible while that read completes. The browser preview stays on sample
records.

One white selector block flows across the interactive controls throughout the
screen: resolution choices, view and transport buttons, search, library rows,
playlist tabs and tracks, option controls, and the sidebar resize handle. It
follows pointer hover and keyboard focus, then returns to the selected control
when the pointer leaves. It stays clipped to the visible scroll area as rows
move, and keyboard or programmatic selection takes over from stale pointer
hover. DISPLAY can turn selector motion off. The library starts at one-quarter
of the available character columns. High-resolution layouts of 64 columns or more
reserve at least 20 sidebar columns; smaller layouts retain a 10-column minimum.
The playlist keeps at least 20 columns. Tree disclosure occupies one column and
each unfold adds one column of indent. Full sample game names replace short aliases. Its DISPLAY sidebar-width slider and draggable
separator use the same 8px character-column bounds and saved value; arrow keys
change one column at a time, Home restores the one-quarter default, and End sets
the widest allowed library pane. Brightness runs from 60% to 140% and remaps the
monochrome palette while leaving the pure-black scanline gaps unchanged.
Brightness, selector motion, and pane width persist with the display
preferences. PLAYLIST controls automatic content sizing and its maximum column
width; column changes use the selector's 220ms easing and remain aligned to the
8px text grid. Both playlist sizing choices persist with the display
preferences. Playlist rows and headings share one two-axis scroll area; the
heading remains pinned while long playlists scroll. Track rows keep their exact
16px source height at every raster profile. Tabs use equal-width cells when they
fit, then scroll as a strip; their compact close icon stays centered in a fixed
trailing hit area.

Phosphor persistence is disabled to keep interaction responsive. OPTIONS opens
a two-column terminal settings view with inset square framed sections, visible
space between cards, shaded section headers, and the same filled block controls
as the toolbars. The added padding uses whole 8px and 16px grid units. Option
rows and equalizer labels remain centered on the same 16px line grid. DISPLAY contains
WIDTH MODE (FILL or FRAME), SCANLINES, BRIGHTNESS, SELECTOR FLOW, the active
beam pitch, and a native fullscreen toggle. CRT contains a THIN/NORMAL/WIDE beam-width control
and reports the active pitch. PLAYLIST contains AUTO SIZE and MAX WIDTH.
PLAYBACK contains Long Play duration, the unknown-duration default, fade
settings, and independent libgme/libvgm speed controls. AUDIO contains output
volume, mono, and a ten-band equalizer with per-band gain and reset-flat
control. These native playback settings persist across restarts. Volume uses
the shared 20-detent scale; audio controls apply through VGMBoy, and timing or
speed changes use its shared transport policy. The browser preview disables
playback-only settings. FILL and FRAME, scanline visibility, brightness,
selector motion, pane width, beam width, and the selected raster profile are
remembered. The native app provides standard macOS menus and
shortcuts: Command+O opens a file, Command+comma opens OPTIONS, Control+Command+F
toggles fullscreen, Command+M minimizes, Command+W closes the window, and
Command+Q quits. The Edit menu forwards standard text commands to WebKit.

The native app bootstraps the shared catalog through CatalogBrowserCore, loads
game rows lazily when a system is unfolded, and searches its shared game
projection. The browser preview remains on the small sample library. In sample
mode, Command+F searches the sample games; clearing the query restores the tree
and its prior selection. Selecting a game loads its sample tracks. F toggles
local sample favorites and FAV filters the current playlist. In the native
player, FAV opens FavoriteStoreCore's app-wide list and RECENT opens
PlaybackHistoryCore's shared playback list. Command+Shift+F and Command+Shift+H
open the same views; LIST or selecting a library game returns to a regular
playlist tab. The native file picker remains connected for opening a real local
track; native catalog and local-file playback use VGMBoy transport.

Saved playlist rows paint from the tab snapshot while native catalog tracks
rehydrate in the background. First-time game reads must not block the WebKit
event loop; the native bridge caches the eight most recently requested game
playlists. Keep the current playlist visible until a new game's indexed rows
arrive, then replace the heading and rows together. Tab changes invalidate
pending UI updates, so late results cannot replace the playlist the user
selected.

Playlist tabs use ViewBoy-style square outlines and an independent close cell.
They share the available width, retain an 18-character basis and
12-character minimum, then scroll instead of collapsing to unreadable fragments.
A two-source-pixel gap separates tabs. The active frame stays bright while hover
moves elsewhere. Close uses the same minimal five-dot X, empty ring and square
outline as ViewBoy, centered in an eight-pixel icon slot inside a three-character
hit cell. The [+] button remains outside the scroller. Vertical wheel scrolling
moves an overflowing strip and active-tab selection reveals the tab. Labels,
close actions and track rows expose full titles on hover. Selector motion uses
cubic-bezier(.2, 0, 0, 1).

Every source font pixel uses a whole device-pixel scale, not merely a whole character-cell advance. Scanlines use an integral physical pitch, with no fractional mask scaling. The mask and layout use the actual display device ratio, including values above 2. This preserves the existing stationary mask and native DOM text path.

Display options use square framed groups, shaded section headers, left labels,
and centered block controls on the right. Clicking the sidebar separator focuses
it for keyboard resizing; cancelling a drag restores its starting width without
saving.

The scanline layer is outside the scaled text surface and maps one mask pixel
to one physical display pixel. Its CSS fallback uses the same physical pitch.
Terminal centering snaps the origin as well as the dimensions, avoiding
half-pixel placement and alternating-width bands.
