# Options

- Options slide down over the main content from the Options toolbar button or
  Command-comma (⌘,). Command-comma toggles the page; Escape, the visible Close
  Options button, and clicking outside the page dismiss it.
- Close Options is a square icon button using the standard straight-line X mark
  from SB2's toolbar icon set.
  The Options layer covers home controls and floating popovers while leaving
  the app title and status bars visible.
- Opening Options moves keyboard focus to Close Options; closing returns focus
  to the control that opened it.
- SPCBOY owns Database, Gallery, UI Chrome, UI Fonts, Windows, and Options
  layout settings. VGMBoy owns Audio, Diagnostics, Playback, and Routing
  settings. The four visible pages group these by use while keeping each
  setting's existing persistence and owner logic intact: Gallery; Interface
  (UI Chrome, UI Fonts, Windows, and layout); Sound (Audio and Playback); and
  System (Database, Diagnostics, and Routing).
- Audio > Equalizer has ten numbered profiles. Selecting a profile loads its
  enabled state and ten band gains; the ten numbered profile slots select a
  profile and Save stores the current curve in that slot. Editing a curve
  marks it unsaved. Older settings migrate into Profile 1.
- Command-W dismisses the in-page Options overlay before it closes a playlist
  tab. In the separate Options window, Command-W closes that window.
- Options uses four equal-width top tabs. Each page lays its setting cards out
  left to right, then wraps to the next row. The minimum card width defaults to
  60ch and is adjustable from Interface > Layout (40–100ch); that choice is
  saved in native SB2 preferences. Keep the card order in source order and the
  ownership split described above when adding settings. Card headings use the
  accent color. The close button sits at the right edge of the tab bar.
- Gallery artwork fit uses Crop/Pad buttons. Archive cache size is entered in
  GB; the configured cache cap snaps to the nearest supported size (2, 4, 8,
  or 16 GB).
- Playback volume uses twenty 5% steps in Options and in the compact Volume
  popup on the home toolbar. The home popup stays behind the Options layer.
- One playback speed setting applies to every format whose decoder supports
  native tempo. Its value commits only when Enter is pressed, snaps to 1/32
  increments from 1/32× through 8×, displays reduced fractions, and uses a
  compact eight-character field. The Speed toolbar toggle enables or disables
  that configured rate while preserving its saved value.
  AAC export captures the enabled speed when export begins and uses the same
  format-specific speed limits as playback.
- Option pages use the readable SB2 interface font and the available window
  width. Body text and controls use a .9rem baseline; card headings use 1.1rem.
  The title row is removed, and the close button sits at the right edge of the
  tab bar. Cards in one grid row stretch to the same height. Setting rows use a
  60/40 label/control split with controls centered vertically, .5rem vertical
  padding, and dividers between rows. Bottom padding at the final row matches
  the spacing at a row divider. The Equalizer card spans the full row and keeps
  all ten gain sliders in one vertical column. Options uses a shared 1rem
  spacing token for the page inset, tab/content and card gutters, and card
  padding; keep gaps inside grouped controls compact and tab gaps compact on
  narrow screens. UI Chrome and UI Fonts share the Interface
  page; UI Fonts exposes playlist-header styling and titlebar font color and
  bold controls.
  The Gallery page controls crop-to-square or pad-to-square artwork fit, frame
  size, gap, and corner radius. Each card keeps inset square artwork with a
  separate one-line title nametag. Titles use the Sidebar + Playlist font size
  and end with an ellipsis when they do not fit. Frame gap also pads the grid's
  outer edges. Gallery settings are stored with native SB2 preferences and
  restored on launch.
  The same page layout and title/footer chrome appear in the optional
  standalone Options window.
- UI Chrome Font Size scales toolbar rows, buttons, icons, and setting-field
  heights together. At 10pt, controls and header blocks are 1.75rem high, icon
  buttons are 1.75rem square, and icons are 1rem. Floating toolbar rows are
  2.25rem high with a 0.25rem inset on all sides; adjacent controls and bars
  keep matching gaps. The title and bottom status strips remain continuous
  chrome. These proportions stay
  constant as the font size changes. Rem-based chrome spacing scales with it
  as well. Playlist and sidebar row typography uses the shared Sidebar +
  Playlist Font Size setting; Row Gap likewise controls vertical spacing in
  both panes.
- Action buttons across the home screen and Options use the same surface,
  corner radius, hover colors, selected colors, and height. Buttons in grouped
  actions share their card width equally. Setting fields use the control half
  of each row; CSS color fields and database path readouts can use their full
  available control width.
- Sidebar folders and console groups open and close immediately.
- UI Chrome > Animations controls the shared selector motion across interface
  hovers, keyboard focus, and selected rows. Turning it off sets the transition
  duration to zero; custom slider fills and thumbs use the same duration and
  easing, and reduced-motion preferences remove their motion. This applies in
  the main window and the standalone Options window.
- Reload Library refreshes the read-only catalog projections used by the
  sidebar. ScanSong remains the catalog writer.

Settings updates persist only the fields changed by that window, preserving
other windows’ independent edits. Receiving a settings update does not save an
older full snapshot back over newer values.

- Row Gap uses whole pixels (0–32), defaults to 0 px, and applies equally to
  sidebar and playlist rows. Saved positive rem spacing migrates to equivalent
  pixels; the previous zero/unset default stays 0 px. Font sizes do not scale
  the saved gap. Both lists fade over their bottom 1 rem (0%, 50%, 75% background coverage) and retain scroll room
  to reveal the final row.
- Sidebar + Playlist Font Size is one saved content-size setting. It controls
  both panes' row text and line height; the shared Row Gap setting controls
  vertical spacing in both panes. Older separate sidebar and playlist size
  values are read for migration, then normalized to the shared value.
- UI Chrome > Playlist Options includes Link Mode. It is off by default; when
  enabled, a plain single click on a playlist row selects and starts that track.
  Modifier-clicks remain selection gestures, and favorite buttons still only
  toggle Favorites. The preference persists across launches.
- Options checkboxes use aligned square controls: an outlined square when off
  and an accent-filled square with a check when on. The playback-speed input is
  independent of its enable checkbox; editing it never toggles Speed.
- Drag playlist headings to reorder them. Neighboring headings slide aside
  using the interface motion preference; Escape cancels the reorder. The open
  star heading matches the hosted player. Play shows animated bars while
  playing, with a static indicator when motion is disabled.
