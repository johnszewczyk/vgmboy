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
- Options open in the playlist pane as a subpage and leave the title and footer
  visible. A separate Options window uses the same chrome.
- Playlist tab selection fades with the shared selection timing and easing;
  its active surface includes the close control and prevents text selection.
- Playlist row selection uses one animated, one-pixel underline at the row
  bottom. The previous solid-versus-outline selection option is retired.
- Sidebar selection remains available to navigation and activation but has no
  selected-row marker. Folder and console disclosure updates immediately.
- Dense catalog rows keep zero vertical item padding with a 1px row gap. The
  pane divider is 1px. The title strip, status strip, and toolbars share one
  2.5rem row height. Main action controls use a 1.5rem square and 1rem icons;
  the search field and playlist close control use the same 1.5rem control size.
- Playlist column headers use the same 1.5rem height, dark button surface, and
  corner size as the main action controls, with the header strip kept visually
  quiet around them.
