# WebKit Host

`main.swift` creates the AppKit window and a single WKWebView loading bundled `index.html`. `WKNativeBridge.swift` injects `window.spcBoyWK` at document start and owns read-only catalog queries, typed preference persistence, local path intake, and VGMBoy transport requests. The Yoga canvas module defines `window.SPCBoyWK.dispatch` for supported macOS menu commands; it replaces the old injected dispatcher that targeted `SPCBoyApp`.

The active renderer is `Resources/yoga-app.js`. It reads game buckets and track rows from CatalogReader, forwards playback to the native bridge, and uses `playbackCompletionRetire` for natural-end queue decisions. Library rows and the current track table are view state only; playback continues when the user browses a different game. A chosen local file or folder is loaded as a table via `choosePath` and `selectFolder`.

The renderer uses a single canvas and Yoga's bundled WASM layout. `index.html` loads only `yoga-screen.css` and `yoga-app.js`. The old DOM UI and its transport scripts were archived and removed. The prior Metal optical overlay remains in Swift source for future adaptation but is not mounted by the current host.
