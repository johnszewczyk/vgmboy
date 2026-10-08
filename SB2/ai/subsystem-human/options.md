# Options

- Options slide down over the main content from the Options toolbar button or
  Command-comma (⌘,). Command-comma toggles the page; Escape, the visible Close
  Options button, and clicking outside the page dismiss it.
- Opening Options moves keyboard focus to Close Options; closing returns focus
  to the control that opened it.
- SPCBOY owns Database, UI Chrome, UI Fonts, and Windows settings. VGMBoy owns
  Audio, Diagnostics, Playback, and Routing settings; the navigation keeps
  these groups separate.
- Pages stay alphabetical within their owner groups: Database, UI Chrome,
  UI Fonts, Windows; then Audio, Diagnostics, Playback, Routing. Section groups
  within pages are alphabetical.
- The options sidebar groups SPCBOY-owned frontend settings separately from
  VGMBoy-owned playback-core settings. Keep that ownership split when adding
  settings.
- Option pages use a readable system font and a 65-character content width.
  Section headings are underlined; setting rows use whitespace without
  divider lines. UI Chrome and UI Fonts are separate SPCBOY pages. UI Fonts
  exposes playlist-header styling and titlebar font color and bold controls.
  UI Chrome > Gallery Tiles controls tile size, gap, and corner radius; artwork
  uses a centered cover crop so non-square images fill square tiles.
  The same page layout and title/footer chrome appear in the optional
  standalone Options window.
- UI Chrome Font Size scales toolbar rows, square buttons, icons, and option
  control heights together. At 10pt, toolbar rows are 2.5rem, square buttons
  are 1.5rem, and icons are 1rem; these proportions stay constant as the font
  size changes. Rem-based chrome spacing scales with it as well. Playlist and
  sidebar text sizes remain independent.
- Setting fields share the toolbar row height and a 24ch width, with the width
  scaling together on narrow windows. Database path readouts keep the same
  height and use the available row width.
- Sidebar folders and console groups open and close immediately.
- UI Chrome > Animations controls the shared selector motion across interface
  hovers, keyboard focus, and selected rows. Turning it off sets the transition
  duration to zero; reduced-motion preferences also remove the motion. This
  applies in the main window and the standalone Options window.
- Reload Library refreshes the read-only catalog projections used by the
  sidebar. ScanSong remains the catalog writer.
