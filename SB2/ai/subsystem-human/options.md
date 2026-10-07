# Options

- Options open as a subpage in the playlist pane.
- SPCBOY owns Database, UI Chrome, UI Fonts, and Windows settings. VGMBoy owns Playback,
  Routing, Audio, and Diagnostics settings; the navigation keeps these groups
  separate.
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
- Setting fields share one 2.5rem control height and 24ch width, with the width
  scaling together on narrow windows. Database path readouts keep the same
  height and use the available row width.
- Sidebar folders and console groups open and close immediately.
- Reload Library refreshes the read-only catalog projections used by the
  sidebar. ScanSong remains the catalog writer.
