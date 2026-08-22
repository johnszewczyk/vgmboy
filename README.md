# SPCBoy (WK)

Independent native macOS WebKit frontend for SPCBoy.

This project owns its native AppKit/WKWebView host and `spcBoyWK` bridge while
sharing the read-only catalog reader, catalog-browser behavior, and VGMBoy
playback core.

The current live native slice reads shared MediaScanner catalog roots, games,
files, search results, and playlist rows, and routes loose-file playback through
VGMBoyKit. Archive members are materialized through the native host; direct
filesystem browsing remains the next bridge milestone.

Run `./launch.sh` to clean, rebuild, package, and launch a fresh release app.
