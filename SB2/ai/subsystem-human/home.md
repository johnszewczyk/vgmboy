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
- If startup lasts beyond a short reveal delay, a compact status card shows
  workspace restore, library connection, sidebar preparation, playlist restore,
  and elapsed time. It briefly confirms readiness or remains visible with the
  startup error.
- Command-Shift-F opens or switches to Favorites; Command-Shift-H opens or
  switches to Playback History.
- Options open in the playlist pane as a subpage and leave the title and footer
  visible. A separate Options window uses the same chrome.
- Playlist tab selection fades with the shared selection timing and easing;
  its active surface includes the close control and prevents text selection.
- Playlist row selection uses one animated, one-pixel underline at the row
  bottom. The previous solid-versus-outline selection option is retired.
- Sidebar selection remains available to navigation and activation but has no
  selected-row marker. Folder and console disclosure updates immediately.
- Dense catalog rows keep zero vertical item padding with a 1px row gap. The
  pane divider is 1px. Toolbar buttons share a 1.5rem square and icons share a
  1rem size; the search field uses the same 1.5rem control height. Playlist tab
  controls fill their header row, with a matching 1.5rem close control.
