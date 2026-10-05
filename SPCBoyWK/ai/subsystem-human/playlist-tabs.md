# Playlist Tabs

SPCBoyWK keeps each open playlist in its own tab and restores open tabs on the
next launch. The tab strip appears when at least two playlists are open. Tabs
share the toolbar width, and long titles truncate with an ellipsis. The tab
highlight covers the full tab surface, including its close control; the
truncation ellipsis sits directly after the last visible title character. The
tab strip aligns with the sidebar toolbar; playlist headings align with the first
sidebar row beneath it. The playlist fills the available pane height, with the
position bar kept at the bottom whether the tab strip is shown or hidden.

Command-T duplicates the current playlist into a new tab. “Open in New
Playlist” in the sidebar opens that source in its own tab. Command-1 through
Command-9 selects the matching tab from left to right. Command-W or a tab's
close button closes it; closing the final tab closes the main window.

Command-Shift-H replaces the current playlist with the shared playback history,
newest play first. The sortable Date/Time column shows local timestamps as
`YYYY.MM.DD-HH.MM.SS.MS` and automatically hides when the displayed rows have no
history timestamp.

Playlist columns retain their saved order. Columns with no meaningful content
are hidden for the active playlist and reappear when content returns, while
manually hidden columns stay hidden. The `#` column always numbers visible rows
and never sorts the playlist.

## Files

- `Sources/SPCBoyWK/main.swift`
- `Sources/SPCBoyWK/Resources/app-ui.js`
- `Sources/SPCBoyWK/Resources/styles.css`
- `Sources/SPCBoyWK/PlaylistTabsStore.swift`
