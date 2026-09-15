# SPCBoy (WK)

Independent native macOS WebKit frontend for SPCBoy.

This project owns its native AppKit/WKWebView host and `spcBoyWK` bridge while
sharing the read-only catalog reader, catalog-browser behavior, and VGMBoy
playback core.

Playback command replies and asynchronous native playback events use the same
`FrontendCore.PlaybackTransportStatusPayload` projection. This keeps elapsed
position and decoder diagnostics identical across the two WebKit status paths;
the JavaScript layer only renders the returned status and interpolates between
authoritative native updates.

The current live native slice reads shared ScanSong catalog roots, games,
files, search results, and playlist rows, and routes loose-file playback through
VGMBoyKit. Explicitly opening a local folder uses the shared
`LocalFileBrowserCore` for shallow navigation and ordinary supported files;
archive-member browsing remains a later bridge milestone. The app does not
reopen a persisted local folder during startup.

Settings opens in a separate native `NSWindow` with its own `WKWebView`. The
window uses the same renderer resources in options mode, while the root window
continues to own the library and playback surface.

The library sidebar and playlist use matched toolbar/content insets. Playlist
column resizing is bidirectional and uses the shared configurable 200ms default CSS width
transition with easing. The resize gesture uses the Electron structure exactly:
matching header and body tables live inside one shared horizontal scroll surface,
and final widths are persisted on release.

Run `./launch.sh` to clean, rebuild, package, and launch a fresh release app.
