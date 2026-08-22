# SPCBoy (WK)

Native macOS WebKit frontend track for SPCBoy.

This project is intentionally separate from the archived Electron frontend.
It now launches the current SPCBoy renderer skin inside a native AppKit/
WKWebView host. Catalog reading and playback are still startup-only bridge
stubs; full native integration is added behind their respective narrow
boundaries.

Run `./launch.sh` to clean, rebuild, package, and launch a fresh release app.
