# Host and Bridge Architecture

## Scope

APPBOY's UIKit window/scene container, `WKWebView` content security boundary,
JavaScript-to-native bridge, and direct bridges to the VGMMan family's shared
catalog, frontend persistence, and archive modules.

## Ownership

- `APPBOYApp.swift` and `AppViewController.swift` own the UIKit `UIApplication`
  and `UIWindowScene` lifecycle, dark `#090b0f` host surfaces, status bar style,
  and `WKWebView` container configuration.
- `AppBoyResourceLocator.swift` and `AppBoyWebContentPolicy.swift` own bundled
  `WebUI/index.html` resolution and navigation/message origin verification.
- `AppBoyNativeBridge.swift` is the sole `WKScriptMessageHandler` (`appBoy`)
  between WebKit and native catalog, persistence, diagnostics, and playback
  services.
- `AppBoyModels.swift` and `AppBoyStore.swift` bridge APPBOY directly to shared
  family modules:
  - `CatalogReader` (`ReadOnlyCatalog`, `CatalogBrowserProjection`,
    `CatalogGalleryIndex`, `CatalogPlaylistReader`,
    `CatalogPlaylistPresentation`, `CatalogPlaylistSorting`)
  - `FrontendCore` (`FavoriteStore`, `FavoriteTrackIdentity`,
    `FavoriteListPresentation`, `PlaybackHistoryStore`,
    `FrontendPreferencesStore`, `FrontendPlaybackVolumeScale`,
    `FrontendAnimationTimings`, `PlaylistTabOrderReducer`)
  - `UACWrapperCore` and `VGMBoyEmbeddedCore` (`UACEmbeddedArchiveReader` for
    embedded UAC Title Snap extraction)

## Invariants

- Allow main-frame navigation and native script messages only when both the
  frame URL and active `WKWebView` URL match the standardized bundled
  `WebUI/index.html` file URL. Reject external links, subframes, and popups.
- Keep the HTML Content Security Policy closed (`default-src 'none';
  script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:;
  font-src 'self'; connect-src 'none'`). Perform any remote catalog fetches in
  native Swift rather than relaxing WebView CSP.
- Keep `webView.scrollView.contentInsetAdjustmentBehavior = .never` and
  `bounces = false` so `viewport-fit=cover`, `100dvh`, and CSS
  `env(safe-area-inset-*)` own safe-area geometry without double insets or
  whole-page rubber-banding.
- Keep interactive `<input>` and `<select>` controls at `16px` minimum rendered
  font size so iOS WebKit never triggers involuntary viewport zoom on focus.
- Persist favorites (`favorites.json`), playback history
  (`playback-history.json`), preferences (`preferences.json`), and playlist
  workspace (`workspace.json`) through `FrontendCore` stores under
  `Application Support/APPBOY/`.

## Lifecycle

- Inject `window.appBoy` and `window.APPBOY` user scripts at `.atDocumentStart`
  for the main frame only, before `index.html` scripts execute.
- On `sceneWillResignActive` and `sceneDidEnterBackground`, invoke
  `window.APPBOY?.flushPendingState?.()` via `callAsyncJavaScript` inside a
  short `UIApplication` background task so debounced tab or preference edits
  persist before iOS suspends the process.
- Validate incoming `appboy://` scene URLs against an allowlist of view,
  options (`database`, `gallery`, `interface`, `fonts`, `audio`, `diagnostics`,
  `playback`), play, and transport actions in
  `AppBoyNativeBridge.emitDeepLink(url:)`.

## Failure Boundaries

- Corrupt or missing JSON files in `Application Support/APPBOY/` fall back to
  normalized defaults without blocking startup; explicit write failures return
  structured bridge errors to JavaScript.
- Missing or unreachable remote catalog URLs surface an explicit status message
  while retaining local `catalog.sqlite` / `Documents/` or starter catalog
  availability.

## Files

- `Sources/APPBOY/APPBOYApp.swift`
- `Sources/APPBOY/AppViewController.swift`
- `Sources/APPBOY/AppBoyResourceLocator.swift`
- `Sources/APPBOY/AppBoyWebContentPolicy.swift`
- `Sources/APPBOY/AppBoyNativeBridge.swift`
- `Sources/APPBOY/AppBoyModels.swift`
- `Sources/APPBOY/AppBoyStore.swift`
