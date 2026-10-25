# Home

- The top title strip shows SPCBOY, the current console and album, and CPU use.
- Window controls are rendered in the title strip; AppKit's native stoplights
  are hidden, and the strip remains draggable.
- Nine playback, audio, and Options controls share the first sidebar toolbar at
  equal widths. The Volume control opens a 220px popup slider with twenty 5%
  detents and visible tick marks.
  Search shares the next toolbar with five square buttons for Console/Path
  view, Gallery, Recent, Favorites, and expand/collapse; the search field
  shrinks to make room.
  The catalog tree fills the remaining scrollable area.
- The sidebar status bar shows compact game and system totals when the library
  is ready. Loading, error, and empty-result messages appear there instead of
  taking over the catalog tree; full details are available in its tooltip.
- The footer aligns to the sidebar split and shows elapsed time, track length,
  and playlist length at right. Library totals, playback status, and time values
  share a centered text baseline.
- Startup reads the shared CocoaSpice catalog through CatalogReader; ScanSong
  remains its writer.
- Startup loads Games, Paths, Gallery metadata, and search indexes before
  reporting ready. Tabs and view switches reuse those snapshots, including empty
  results; search filters the current view without reloading the catalog.
- Development runs can select an isolated catalog with
  `SPCBOY_SB2_CATALOG_PATH`; normal launches keep using the shared default.
- If startup lasts beyond a short reveal delay, a compact status card shows
  workspace restore, library connection, sidebar preparation, playlist restore,
  and elapsed time. It briefly confirms readiness or remains visible with the
  startup error.
- Command-Shift-F opens or switches to Favorites; Command-Shift-H opens or
  switches to Recent; Command-Shift-G or the Gallery toolbar button
  opens or switches to Gallery.
- Gallery is a playlist tab with an artwork-only grid. Its own sidebar toolbar
  button opens Gallery. The sidebar automatically uses Console View and shows
  only consoles with indexed `Title Snap` artwork. Console rows use the normal
  sidebar spacing, font, and leaf marker; selecting one fills the Gallery grid
  with its artwork, without unfolding game rows or showing sidebar thumbnails.
  Console/Path switching is disabled while Gallery is active. A single Gallery
  card click selects an artwork title; Enter or double-click opens a playlist
  tab and starts playback, leaving the Gallery tab intact. Gallery cards use a
  bordered square artwork frame and a separate nametag below it. Artwork can
  crop to fill the square or pad to show the complete image. Frame size, gap,
  corner radius, fit, and compact nametag titles live in Options > Gallery. The
  frame gap also pads the grid edges; zero gap and square corners create a
  continuous grid by default.
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
- In Path View, a single click on a playable file loads its playlist preview
  without starting playback. Enter or double-click activates it; folder clicks
  continue to expand or collapse the folder.
- The expand/collapse toggle collapses every console group or non-root folder
  if any is already open; it expands all only when those items are folded.
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
  square Console/Path, Gallery, Recent, Favorites, and expand/collapse controls. The
  pane enforces enough minimum width to keep the first row intact and can be
  resized through an even 50/50 split. Text bars
  use the same height and 0.25rem inline padding; glyph buttons center their icons.
  Playlist tabs are separate rounded blocks with a visible gap and the same
  height as square buttons; their width follows the label. Column headers use
  that same block height and state colors. Column auto-size fits the complete
  playlist content and keeps each header aligned with its column, including in
  long virtualized playlists, and reruns when columns are shown or hidden. Each
  tab retains its own title and tracks; async
  sidebar loads and sorts only update the tab and playlist they started from.
  Closing a tab targets its current stable tab ID; a stale close target cannot
  close the last remaining window. Column resizing follows display frames while
  dragging and resumes configured easing after release. Setting inputs may use
  the full control height; they are fields rather than action buttons.

Tab changes are saved during use. Closing a window or quitting waits for pending
workspace and preference writes; a failed save leaves the window open.
