# Mobile UI

## Scope

User-visible layout, navigation, playback controls, gallery, and options
behavior in APPBOY across iPhone and iPad viewports.

## Shell and Chrome

- The top title strip spans the device safe area and displays `SPCBOY`, the
  active console badge, and the current album or playlist title without desktop
  window buttons or CPU meters.
- The bottom status strip spans the home-indicator safe area and displays
  library system/album totals on the left, playback state (`READY`, `PLAYING`,
  `PAUSED`, `STOPPED`, `ERROR`) with a status dot, and `elapsed / length / total`
  tabular time values on the right.
- Surfaces use SB2's dark obsidian (`#090b0f`), chrome (`#111419` / `#1a1c20`),
  button (`#15191f`), and cyan accent (`#38aaff`) palette with monospace tabular
  numerals and `1px` dividers.
- One shared animated selector highlights active mode buttons, tabs, and focused
  controls when selection motion is enabled.

## Responsive Layout

- On compact viewports (`< 768px`, iPhone portrait), a primary mode bar switches
  the workspace between `Library`, `Playlist`, `Gallery`, `Favorites`, `Recent`,
  and `Options` while keeping the docked Now Playing transport deck and status
  strip visible at the bottom.
- On regular viewports (`>= 768px`, iPad and wide landscape), the workspace
  displays SB2's two-pane split layout with the Library sidebar on the left, a
  `1px` vertical divider, and the active Playlist or Gallery pane on the right.
- Rotating the device or resizing iPad Split View switches between compact and
  two-pane layouts while preserving open tabs, search query, selection, and
  playback position.

## Library and Navigation

- The Library toolbar pairs a zoom-safe search input with an expand/collapse-all
  control (plus `Gallery`, `Recent`, and `Favorites` shortcuts in split view).
- Console rows expand or collapse their albums with disclosure markers and album
  counts.
- Each album row shows its title, track count, and an adjacent star button that
  favorites or unfavorites all tracks in the album without starting playback.
- Tapping an album loads its tracks into the active playlist tab; on compact
  viewports it switches to the `Playlist` view.

## Playlist and Gallery

- Playlist tabs appear in a horizontally scrollable strip above the track list,
  supporting tab switching, creating a new tab (`+`), and closing individual
  tabs when more than one tab is open.
- Compact track rows display track number, title with subtitle metadata,
  favorite star toggle, and tabular duration within the phone width; regular
  viewports add explicit `Album` and `System` columns.
- Active and selected playlist rows render SB2's `1px` bottom accent underline.
  When Link Mode is enabled (default on touch), tapping a track selects and
  starts playback immediately; when Link Mode is off, first tap selects and a
  second tap on the selected row plays.
- Gallery displays square framed album cards in a responsive grid. Tapping a
  card opens its album playlist and starts playback.

## Transport and Options

- The docked transport deck displays the active track title and system/album
  subtitle, a touch-scrubbable progress bar, and buttons for Previous, Stop,
  Play/Pause (switching to animated 4-bar playback meter while playing), Next,
  Repeat (`off` / `all` / `one`), Long Play, Speed toggle, and Volume popover.
- Options slides top-down between the persistent title strip and bottom status
  strip, organized into `Interface`, `Fonts`, `Gallery`, `Source`, and `Audio`
  sections, and closes via the header `×` button or `Escape`.

## Files

- `Sources/APPBOY/Resources/WebUI/index.html`
- `Sources/APPBOY/Resources/WebUI/styles.css`
- `Sources/APPBOY/Resources/WebUI/sb-presentation.css`
- `Sources/APPBOY/Resources/WebUI/sb-presentation.js`
- `Sources/APPBOY/Resources/WebUI/app-state.js`
- `Sources/APPBOY/Resources/WebUI/app-ui.js`
- `Sources/APPBOY/Resources/WebUI/app-playback.js`
- `Sources/APPBOY/Resources/WebUI/app.js`
