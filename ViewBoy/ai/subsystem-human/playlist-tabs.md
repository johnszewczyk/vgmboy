# Playlist Tabs

ViewBoy keeps each open playlist in a tab and restores the tabs on launch. The
tab strip appears when at least two tabs are open. A tab keeps its rows,
selection, and scroll position while another tab is active. Choosing a library
game replaces the active tab's playlist.

Command-T duplicates the active playlist. Command-1 through Command-9 selects
tabs from left to right. Command-W or a tab's close button closes the tab;
closing the last tab closes the main window. Switching tabs does not start or
stop the current audio session.

## Files

- `Sources/ViewBoy/Resources/viewboy-tabs.js`
- `Sources/ViewBoy/Resources/index.html`
- `Sources/ViewBoy/PlaylistTabsStore.swift`
- `Sources/ViewBoy/main.swift`
