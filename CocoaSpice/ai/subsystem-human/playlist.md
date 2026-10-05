# Playlist

## Display

- Display: file metadata in a headed table.
- Columns: favorite, index, file, title, game, author, system, path, and length. The favorite glyph is immediately before #; its filled state uses the configured playlist text color.
- Columns: missing metadata falls back to useful file or folder text.
- Metadata: catalog-backed queues display only the fields published in the selected catalog; incomplete fields remain incomplete until ScanSong republishes them.
- Directly opened files have no catalog metadata. Their title and game cells use filename and folder display fallbacks; author, system, and duration remain unknown.
- Columns: there is no row-level Play/Stop column; playback uses row activation and the main transport controls.
- Columns: visible columns auto-size after queue publication without changing the current row selection.
- History: Command-Shift-H opens or switches to the History tab, newest play first. Its sortable Date/Time column displays local time as `YYYY.MM.DD-HH.MM.SS.MS` and auto-hides when rows have no history timestamp.
- Columns: drag-and-drop resize.
- Columns: double-click a divider to auto-size to current content.
- Columns: the header menu can auto-size one column or all visible columns.
- Columns: Path shows the complete filesystem source path. Archive tracks retain their member provenance as `archive-path#member-path`.
- Font: an Interface preference can render all playlist text columns in a monospaced font.

## Selection

- Selection: standard Shift and Command multi-selection.
- Selection: selected rows can be dragged together.
- Selection: the primary single-row highlight is an accent capsule by default. The Interface > Animations > Glass Selector option switches the playlist highlight to untinted macOS Liquid Glass, which glides over the row text using the Selection Bar duration (200 ms by default). Sidebar and multi-selection highlights remain solid accent capsules.

## Activation

- Rows: double-click starts playback.
- Rows: Return starts playback of the primary selected row.
- Favorites: Command-D toggles the selected track; the favorite glyph toggles the clicked track directly.
- Favorites: Command-Shift-F opens or switches to the Favorites tab without changing the sidebar view.
- Queue: cut, paste, delete, move, and drag-reorder.
- Context menu: `Export AAC` renders the clicked playlist track through bundled VGMBoy into the
  configured AAC Export Folder. It uses the active Long Play/end-fade timing and does not interrupt
  current playback. The filename begins with the catalog track title, or the displayed playlist name
  when that title is absent.
- Files: Finder drops add supported files, folders, and supported archives, including UAC packages.
- Files: queueing a folder expands supported archive members and multi-track containers into playlist leaves.
- Playlists: dropping an `.m3u` appends its playable entries to the current queue.
- Playlists: `Open Playlist…` and opening an `.m3u` from Finder replace the current queue.

## Persistence

- Tabs: playlist tabs restore their queues, names, and selections on next launch.
- Tabs: drag a tab across its neighbors to reorder it; surrounding tabs ease into the new positions and the order persists for the next launch.
- Tabs: `Command-T` opens an empty tab; File > Close Current Playlist Tab (`Command-W`) closes the current tab; `Command-1` through `Command-9` select a tab.
- Tabs: the plus button opens an empty tab and each tab has its own close button. Closing the final tab leaves one empty Playlist tab and keeps the app window open.
- Playlists: save and load as `.m3u`.
- Playlists: preserve multi-track identity.

## Files

- [PlaylistTableView.swift](../../Sources/CocoaSpice/App/PlaylistTableView.swift)
- [PlaylistTabs.swift](../../Sources/CocoaSpice/App/PlaylistTabs.swift)
- [PlayerViewModel.swift](../../Sources/CocoaSpice/App/PlayerViewModel.swift)
