# Home

- The top title strip shows SPCBOY, the current console and album, and CPU use.
- Window controls are rendered in the title strip; AppKit's native stoplights
  are hidden, and the strip remains draggable.
- Transport, library view, and fold controls share the sidebar toolbar. Search
  occupies the matching sidebar cell in the lower status strip; the catalog
  tree fills the remaining scrollable area.
- The footer aligns to the sidebar split and shows elapsed time, track length,
  and playlist length at right.
- Startup reads the shared CocoaSpice catalog through CatalogReader; ScanSong
  remains its writer.
- Options open in the playlist pane as a subpage and leave the title and footer
  visible. A separate Options window uses the same chrome.
- Playlist tab selection fades with the shared selection timing and easing;
  its active surface includes the close control and prevents text selection.
- Dense catalog rows keep zero vertical item padding with a 1px row gap. The
  pane divider is 1px, and toolbar action buttons share one compact size. The
  search field keeps a taller input surface inside the shared toolbar strip.
- Transport and sidebar icons use the existing icon symbols at a shared 1rem
  size; playlist tab controls fill their header row and keep the 2rem close cell.
