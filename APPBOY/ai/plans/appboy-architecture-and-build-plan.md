# APPBOY Overhauled Architecture & Instantiation Plan

## 1. Critique of Initial Draft Plan (Retired Assumptions)

Reviewing the initial `APPBOY` scaffold against `DocMan`, `VGMMan`, and `SB2`
exposed five structural defects that required an immediate overhaul before
writing source code:

1. **Contradictory Baseline ("Clone SBO" vs. "Copy Desktop SB2 Verbatim")**:
   - Treating APPBOY merely as a thin client around hosted SBO (`SBONLINE`)
     couples the app to Django account chrome, hosted session assumptions, or
     the generic navy rounded-card prototype (`SBONLINE/prototypes/mobile/`),
     abandoning SB2's visual identity and leaving the app dead offline.
   - Conversely, copying SB2's ~10,000 lines of desktop WebKit assets
     (`app-ui.js`, `styles.css`, `app-playback.js`) directly onto iOS imports
     macOS window stoplights, CPU meters, Finder file pickers, separate
     `NSWindow` Options, `23px` 10-button sidebar toolbars, pointer-captured
     splitters, and horizontal desktop `<colgroup>` tables that break mobile
     touch ergonomics.
   - **Resolution**: Build a clean, purpose-written responsive WebKit frontend
     that shares SB2's exact obsidian/charcoal/cyan design tokens, monospace
     tabular typography, `.sb2-selection-indicator` motion, `1px` active-row
     underline, top-down Options drawer, and canonical `sb-presentation.{css,js}`
     primitives, backed by a clean native Swift catalog/playback seam that works
     standalone out of the box and supports local files or configurable SBO
     remote endpoints.
2. **Inaccurate Native Bridge Contract & Missing Content Trust**:
   - The draft plan invented `window.webkit.messageHandlers.nativeBridge`,
     `window.__sb2NativeBridge`, and split script handlers (`NativeScriptBridge`
     + `NativePlaybackBridge`).
   - **Resolution**: Mirror SB2's proven single-gate architecture
     (`WKNativeBridge` + `SB2WebContentPolicy`): one `WKScriptMessageHandler`
     (`appBoy`) with correlation-ID Promises and named event streams injected
     at `.atDocumentStart` (`forMainFrameOnly: true`), guarded by
     `AppBoyWebContentPolicy` (allowing only the standardized bundled
     `index.html` URL) and a strict local CSP (`default-src 'none'`).
3. **Flawed Mobile Layout Strategy (Off-Canvas Hamburger Drawer + Desktop Table)**:
   - Hiding the primary Console/Game catalog behind an off-canvas drawer makes
     collection browsing clumsy on phones, while multi-column desktop tables and
     premature swipe-action complexity obscure core usability.
   - **Resolution**: Start with responsive fundamentals:
     - **Compact (`< 768px`, iPhone Portrait)**: Persistent safe-area SB2 title
       strip, thumb-sized mode bar (`Library`, `Playlist`, `Gallery`,
       `Favorites`, `Recent`, `Options`) with SB2's gliding selector, contextual
       search / playlist-tab sub-toolbar, full-width `44pt` touch rows keeping
       SB2's `1px` hairline density (no puffy cards), docked Now Playing +
       scrubber + transport deck, and safe-area bottom status strip.
     - **Regular (`>= 768px`, iPad & Landscape Max)**: Expands automatically
       into SB2's signature two-pane split workspace (`Library` sidebar + `1px`
       divider + `Playlist` / `Gallery` pane) without state loss.
4. **Missing Swift Package & Family Bundle Alignment**:
   - Sibling packages (`VGMBoy`, `CatalogReader`, `FrontendCore`) target
     `.macOS(.v26)` and link macOS Homebrew dylibs (`/opt/homebrew/opt/*`), so an
     iOS package cannot depend on them directly without violating package
     isolation. The draft also omitted `Package.swift`, `app-icon.png`, and SB2's
     `com.john.spcboy.*` bundle namespace.
   - **Resolution**: Establish a self-contained Swift 6 package
     (`APPBOY/Package.swift`, `.iOS(.v17)`) under bundle ID
     `com.john.spcboy.appboy`, an opaque 1024×1024 `app-icon.png` derived from
     SPCBOY's canonical artwork, and a `build.sh` pipeline cross-compiling both
     `iphoneos` (`.app` + sideload `.ipa`) and `iphonesimulator` (`.app`).
5. **DocMan Routing & Paradigm Drift**:
   - `APPBOY/AGENTS.md` had wrong depth to `DocMan` (`../DocMan` instead of
     `../../DocMan`), and `APPBOY/ai/project-info.md` listed five non-existent
     notes in backticks while leaking subsystem rules into `project-info.md`.
   - **Resolution**: Restore canonical DocMan links and author real current-state
     human and agent subsystem notes alongside verification evidence.

---

## 2. Architecture Overview (Pass 1 Baseline)

### A. Native iOS Container (`Sources/APPBOY/`)
- **`APPBOYApp.swift` & `AppViewController.swift`**:
  - UIKit `@main` `AppDelegate` + `SceneDelegate` managing a dark `#090b0f`
    `UIWindow` with `.lightContent` status bar styling.
  - Root `WKWebView` configured with `allowsInlineMediaPlayback = true`,
    `mediaTypesRequiringUserActionForPlayback = []`,
    `scrollView.contentInsetAdjustmentBehavior = .never`, and
    `scrollView.bounces = false` so CSS `100dvh` and `env(safe-area-inset-*)`
    govern viewport geometry cleanly without double-insetting.
  - Scene background transitions call `window.APPBOY?.flushPendingState?.()`
    through `callAsyncJavaScript`.
- **`AppBoyWebContentPolicy.swift` & `AppBoyResourceLocator.swift`**:
  - Resolves bundled `WebUI/index.html` across SwiftPM `Bundle.module` and flat
    iOS `.app` layouts; blocks any non-bundled navigation, subframe navigation,
    or popup creation.
- **`AppBoyNativeBridge.swift`**:
  - Single `WKScriptMessageHandler` (`appBoy`) handling request/reply Promises
    (`bootstrap`, `catalogSnapshot`, `gameTracks`, `searchCatalog`,
    `favoritesToggle`, `favoritesAlbumToggle`, `favoritesList`, `historyList`,
    `playlistTabsSave`, `settingsSave`, `reloadCatalog`, and playback transport
    calls) and pushing `nativePlaybackState`, `nativePlaybackEnded`,
    `settingsChanged`, and `remoteCommand` events.
- **`AppBoyModels.swift` & `AppBoyStore.swift`**:
  - Persists preferences, favorites, recent history, and open playlist tabs as
    atomic JSON snapshots under `Application Support/APPBOY/`.
  - Provides a clean catalog seam: discovers user-supplied local catalog/audio
    files under `Documents/` (Files app / iTunes File Sharing enabled), supports
    an optional remote SBO catalog JSON URL in Options, and ships with a built-in
    curated VGM starter catalog so every view and control works immediately on
    first launch.
- **`AppBoyPlaybackCoordinator.swift` & `AppBoyChiptuneSynth.swift`**:
  - Configures `AVAudioSession` (`.playback`, `.longFormAudio`), observes audio
    interruptions and route changes (e.g., headphone disconnect), drives
    generation-fenced `AVPlayer` playback for local `file://`, remote `https://`
    AAC streams, and built-in synthesized chiptune preview WAVs (`synth://`),
    and synchronizes `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`
    (Play, Pause, Toggle, Next, Previous, Seek).

### B. Responsive SB2-Themed WebKit Presentation (`Resources/WebUI/`)
- **Portable SB2 Core**: Uses canonical `sb-presentation.css` and
  `sb-presentation.js` (`SBPresentation.measureText`, `.sb-scroll-fade`,
  `.sb-playing-bars`).
- **SB2 Visual System (`styles.css`)**:
  - Preserves `#090b0f` pane surfaces, `#111419` status/header chrome, `#1a1c20`
    title strip, `#15191f`/`#202633`/`#102b3f` button states, `#38aaff` accent,
    `tabular-nums` monospace hierarchy, shared `.sb2-selection-indicator`,
    `1px` active/selected playlist underline, and top-down Options drawer.
  - Prevents iOS WKWebView auto-zoom on text inputs while keeping compact chrome
    proportions and >= `44×44pt` touch hit zones.
- **Focused Modules**:
  - `app-state.js`: Normalized state, theme CSS variable applier, and pending
    settings patch echo-filter.
  - `app-ui.js`: Responsive compact/split workspace, Console/Album library tree
    with search and album-favorite stars, multi-tab playlist renderer, square
    artwork Gallery, animated selector, and top-down Options sheet.
  - `app-playback.js`: Generation-aware transport requests, touch progress
    scrubber, Repeat / Long Play / Speed / Volume controls, and queue advance.
  - `app.js`: Bootstrap, DOM/keyboard/touch wiring, breakpoint sync, and
    background state flush.

---

## 3. Phased Roadmap

### Pass 1: Core Instantiation & Responsive Basics (Current Pass)
- [x] Overhaul DocMan/VGMMan/APPBOY routing, subsystem notes, and setup plan.
- [x] Create `APPBOY/Package.swift` (Swift 6, iOS 17.0+), `app-info.plist`,
      opaque `app-icon.png`, and `build.sh` (`iphoneos` `.app` + `.ipa` and
      `iphonesimulator` `.app`).
- [x] Implement UIKit/WKWebView host, `AppBoyWebContentPolicy`, single `appBoy`
      script bridge, atomic JSON store, and starter/local/remote catalog seam.
- [x] Implement `AppBoyPlaybackCoordinator` (`AVAudioSession` `.playback`,
      `AVPlayer`, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, interruption
      and route-change handling, built-in chiptune preview synthesis).
- [x] Implement responsive SB2-styled mobile/tablet WebKit UI (safe-area title &
      status chrome, compact mode-switched layout `< 768px`, two-pane split
      layout `>= 768px`, Library tree + search + album stars, Playlist tabs +
      track rows, Gallery grid, Transport + scrubber deck, top-down Options).
- [x] Verify `iphoneos` `.ipa` and `iphonesimulator` `.app` builds, code
      signatures, JS syntax, and DocMan link/paradigm checks.

### Pass 2: Authenticated SBO Streaming & Offline Caching (Next)
- [ ] Add Keychain-backed SBO token/passkey session handoff in native Swift so
      authenticated AAC stream URLs resolve natively without exposing cookies to
      WebKit.
- [ ] Add bounded LRU offline audio/artwork cache under `Caches/APPBOY/` with
      storage controls in Options > Source.
- [ ] Add virtualized viewport windowing for 10,000+ track playlists on mobile
      and lock-screen artwork rendering in `MPNowPlayingInfoCenter`.

### Pass 3: Device Polish & Gestures (Future)
- [ ] Verify live touch ergonomics, Dynamic Island / Lock Screen scrubbing, and
      background audio longevity on physical sideloaded iPhone and iPad hardware.
- [ ] Evaluate optional swipe-to-favorite / queue gestures and iPad hardware
      keyboard shortcuts once baseline touch flows are field-tested.
