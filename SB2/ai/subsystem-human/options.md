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
- SPCBOY owns Database, Gallery, UI Chrome, UI Fonts, and Windows settings.
  VGMBoy owns Audio, Diagnostics, Playback, and Routing settings; the
  navigation keeps these groups separate.
- Pages stay alphabetical within their owner groups: Database, Gallery, UI
  Chrome, UI Fonts, Windows; then Audio, Diagnostics, Playback, Routing.
  Section groups within pages are alphabetical.
- Command-W dismisses the in-page Options overlay before it closes a playlist
  tab. In the separate Options window, Command-W closes that window.
- The options sidebar groups SPCBOY-owned frontend settings separately from
  VGMBoy-owned playback-core settings. Keep that ownership split when adding
  settings. Owner headings use the underlined text-heading style from the
  Options pages; category items reuse the common toolbar button surface and
  selected state. Navigation controls and owner groups use the same shared gap
  and inset as the home toolbars, playlist tabs, and column headers.
- Playback volume uses twenty 5% steps in Options and in the compact Volume
  popup on the home toolbar. The home popup stays behind the Options layer.
- Option pages use a readable system font and a 65-character content width.
  Section headings are underlined; setting rows use whitespace without
  divider lines. UI Chrome and UI Fonts are separate SPCBOY pages. UI Fonts
  exposes playlist-header styling and titlebar font color and bold controls.
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
  as well. Playlist and sidebar text sizes remain independent.
- Action buttons across the home screen and Options use the same surface,
  corner radius, hover colors, selected colors, and height. Text buttons keep
  natural width except where a grouped action row gives them equal widths.
  Setting fields share the control height and a fixed 24ch width, scaling
  together to 16ch on narrow windows. CSS color fields are 20ch wide so
  the longest named color fits without oversized controls. Database path
  readouts keep that height and use the available row width.
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
- Drag playlist headings to reorder them. Neighboring headings slide aside
  using the interface motion preference; Escape cancels the reorder. The open
  star heading matches the hosted player. Play shows animated bars while
  playing, with a static indicator when motion is disabled.
