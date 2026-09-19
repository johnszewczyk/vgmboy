# Playlist Tabs

SPCBoyWK keeps each open playlist in its own tab and restores open tabs on the
next launch. The tab strip appears when at least two playlists are open. Tabs
share the toolbar width, and long titles truncate with an ellipsis. The tab
strip aligns with the sidebar toolbar; playlist headings align with the first
sidebar row beneath it.

Command-T duplicates the current playlist into a new tab. “Open in New
Playlist” in the sidebar opens that source in its own tab. Command-1 through
Command-9 selects the matching tab from left to right. Command-W or a tab's
close button closes it; closing the final tab closes the main window.

Playlist columns retain their saved order. Columns with no meaningful content
are hidden for the active playlist and reappear when content returns, while
manually hidden columns stay hidden. The `#` column always numbers visible rows
and never sorts the playlist.

## Files

- `Sources/SPCBoyWK/main.swift`
- `Sources/SPCBoyWK/Resources/app-ui.js`
- `Sources/SPCBoyWK/Resources/styles.css`
- `Sources/SPCBoyWK/PlaylistTabsStore.swift`
