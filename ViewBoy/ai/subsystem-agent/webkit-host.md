# WebKit Host

`main.swift` creates the AppKit window and a single WKWebView loading `viewboy://app/index.html`. `ViewBoyResourceSchemeHandler.swift` serves only the allowlisted bundled HTML, CSS, and JavaScript files so ES module imports work without exposing a `file://` directory. `WKNativeBridge.swift` injects ViewBoy's `window.viewBoy` bridge at document start and owns read-only catalog queries, shared favorite operations, typed preference persistence, local path intake, and VGMBoy transport requests. The Yoga canvas defines `window.ViewBoy.dispatch` for supported macOS menu commands. These bridge names are local to ViewBoy.

`Resources/yoga-app.js` loads catalog games and tracks, reduces system-group disclosure and game selection through CatalogBrowserCore, and forwards playback to the native bridge. The canvas keeps its selected game visible while Library, Queue, Favorites, or Options is open. A chosen local file or folder is loaded through `choosePath` and `selectFolder`.

`index.html` loads only `yoga-screen.css` and `yoga-app.js`. The HTML and CSS provide one canvas and a narrow plastic surround. All screen text, controls, borders, and selection treatment are framebuffer pixels. The four-shade LCD renderer runs in WebKit.
