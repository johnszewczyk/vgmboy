# Home

- The top title strip shows SPCBOY, the current console and album, and CPU use.
- Window controls are rendered in the title strip; AppKit's native stoplights
  are hidden, and the strip remains draggable.
- Nine playback, audio, and Options controls share the first sidebar toolbar at
  equal widths. The Volume control opens a 100px popup slider in 5% steps.
  Search shares the next toolbar with square library-view, History, Favorites,
  and fold controls; it shrinks to leave room for all five buttons. The catalog
  tree fills the remaining scrollable area.
- The sidebar status bar shows compact game and system totals when the library
  is ready. Loading, error, and empty-result messages appear there instead of
  taking over the catalog tree; full details are available in its tooltip.
- The footer aligns to the sidebar split and shows elapsed time, track length,
  and playlist length at right.
- Startup reads the shared CocoaSpice catalog through CatalogReader; ScanSong
  remains its writer.
- Development runs can select an isolated catalog with
  `SPCBOY_SB2_CATALOG_PATH`; normal launches keep using the shared default.
- If startup lasts beyond a short reveal delay, a compact status card shows
  workspace restore, library connection, sidebar preparation, playlist restore,
  and elapsed time. It briefly confirms readiness or remains visible with the
  startup error.
- Command-Shift-F opens or switches to Favorites; Command-Shift-H opens or
  switches to Playback History; Command-Shift-G or View > Gallery opens or
  switches to Gallery.
- Gallery is a playlist tab with an artwork-only grid. Its sidebar preserves
  Console and Path views while filtering both to games/sources with a ScanSong
  `Title Snap` value. Gallery tiles use square, centered cover crops and show
  title and system as an image overlay. Zero gap and square corners create a
  continuous tile grid by default; tile size, gap, and corner radius live in
  Options > UI Chrome > Gallery Tiles.
- Options slide down over the main content and leave the title and footer
  visible. Command-comma (⌘,) toggles Options; the visible Close Options control and
  Escape dismiss the page. A separate Options window uses the same chrome.
- One animated selector follows pointer hover and keyboard focus across the
  title controls, transport and library toolbars, sidebar rows, playlist tabs
  and rows, and controls on both Options presentations. Programmatic playlist
  and sidebar selections move it too. The selector uses the configurable
  selection duration; scrolling and resizing keep it attached to the visible
  target.
- Playlist tab selection retains its close control and prevents text
  selection. Playlist row selection also retains its separate one-pixel
  underline.
- Playlist row selection uses one animated, one-pixel underline at the row
  bottom. The previous solid-versus-outline selection option is retired.
- Sidebar selection remains available to navigation and activation. Hover,
  focus, and current selection use the transient shared selector rather than a
  pinned selected-row fill. Folder and console disclosure updates immediately.
- Non-expandable file and catalog-game rows have no bullet; each uses exactly a
  two-character indent from its parent label. Expandable folders and consoles
  retain their disclosure markers.
- Dense catalog rows keep zero vertical item padding with a 1px row gap. The
  pane divider is 1px. UI Chrome Font Size scales the title strip, status strip,
  toolbars, and option controls together. At 10pt, control and header blocks are
  1.75rem high; icon buttons are square at that size, and icons are 1rem. A
  floating toolbar row is 2.25rem high including its 0.25rem inset on all
  sides. Matching gaps separate floating controls and adjacent toolbar blocks.
  The title and bottom status bars remain continuous chrome rather than
  floating blocks.
  Sidebar and playlist text sizes remain independent of this chrome scale.
- All SB2 buttons use the same dark surface, radius, hover ink, and selected
  treatment. Buttons match the 1.75rem control height. The nine first-row
  controls share the available width equally; Search shares a row with five
  square library-view, History, Favorites, and fold controls. The pane enforces
  enough minimum width to keep the first row intact. Text bars use the same
  height and 0.25rem inline padding; glyph buttons center their icons.
  Playlist tabs are separate rounded blocks with a visible gap and the same
  height as square buttons; their width follows the label. Column headers use
  that same block height and state colors. Setting inputs may use the full
  control height; they are fields rather than action buttons.
