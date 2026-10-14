# Artwork Gallery

The Gallery is an optional playlist tab that browses game artwork indexed from
Title Snap metadata in the shared ScanSong catalog.

## Open and browse

- Select the Gallery toolbar button or press Command-Shift-G. CocoaSpice opens
  the existing Gallery tab or creates one without changing the sidebar mode.
- The Gallery index loads after startup finishes and stays cached in memory while
  the catalog remains active, including when the Gallery tab is closed and
  reopened. Each visible tile requests its preview on demand; large PNGs are
  downsampled for display.
- While Gallery is active, the sidebar switches to a console-only list built
  from titles with indexed Title Snap artwork. Selecting a console filters the
  Gallery grid to that console; no game rows or sidebar thumbnails are shown.
- Select a tile to show its game and system in the status area. Double-click a
  tile or choose Play Now to open a playlist tab and start that game.
- Closing the Gallery tab hides its catalog projection. Opening it again
  creates or reuses the Gallery tab and reuses the loaded index; a catalog reload
  invalidates that index.

The Gallery uses only artwork locators already present in the published
catalog. It does not scan library folders or alter catalog data.
