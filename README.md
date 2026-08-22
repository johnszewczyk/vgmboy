# SPCBoy (WK)

Independent native macOS WebKit frontend for SPCBoy.

This project owns its native AppKit/WKWebView host and `spcBoyWK` bridge while
sharing the read-only catalog reader, catalog-browser behavior, and VGMBoy
playback core.

The current live native slice reads shared MediaScanner catalog roots, games,
files, search results, and playlist rows, and routes loose-file playback through
VGMBoyKit. Direct filesystem browsing and archive materialization remain the
next bridge milestones.

Run `./launch.sh` to clean, rebuild, package, and launch a fresh release app.
