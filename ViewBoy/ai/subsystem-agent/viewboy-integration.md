# ViewBoy Integration

## Scope

Keep the independent ViewBoy app identity attached to the shared VGMMan
packages without forking catalog or playback behavior.

## Ownership

- ViewBoy owns its AppKit host, WebKit surface, display resources, settings
  window, and preference namespace.
- CatalogReader owns catalog reads and browser projections.
- FrontendCore owns shared archive, queue, preferences, and transport policy.
- VGMBoy owns format admission, decoding, timing, and audio output.

## Invariants

- Package dependencies are relative siblings in the VGMMan tree.
- Bundle identifier is `com.john.viewboy`; deployment minimum agrees between
  `Package.swift` and `app-info.plist`.
- Keep the renderer dispatcher named `window.SPCBoyWK` until a deliberate
  bridge migration updates both native and renderer clients together.
- `PlaylistTabsStore` persists only ViewBoy playlist presentation in its own
  application-support directory. Tab switches leave the shared playback
  session and queue untouched.
- The app must not write catalogs, add a private archive extractor, or create
  another decoder/playback implementation.

## Build and Verification

- `./build.sh` cleans `.build`, builds the release executable, packages the app,
  and signs it.
- `./launch.sh` builds first and opens `.build/ViewBoy.app`.
- Run `node --test Tests/ViewBoyTransport.test.js` for the renderer and bridge
  contract; use the family verifier for package integration.

## Files

- `Package.swift`
- `build.sh`
- `launch.sh`
- `app-info.plist`
- `Sources/ViewBoy/PlaylistTabsStore.swift`
- `Sources/ViewBoy/Resources/viewboy-tabs.js`
