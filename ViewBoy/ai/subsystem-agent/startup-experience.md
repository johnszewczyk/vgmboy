# Startup Experience

## Scope

ViewBoy's LCD presentation of the shared startup progress contract.

## Ownership

- `FrontendStartupCore` supplies the ordered stage labels and shared reveal and
  ready timing through the native bridge.
- The renderer owns its LCD startup screen and advances the shared stages
  around preference, catalog, sidebar, and playlist restoration.
- The native bridge continues to own catalog reads and playlist persistence.

## Invariants

- Paint the startup screen in the framebuffer; keep browser DOM text and
  overlays out of the LCD surface.
- A failure remains visible with its message. A startup that finishes before
  the reveal delay does not flash the screen.
- The startup view has no hit targets while it is visible.

## Files

- `Sources/ViewBoy/Resources/yoga-app.js`
- `Sources/ViewBoy/WKNativeBridge.swift`
- `../../../FrontendCore/Sources/FrontendStartupCore/FrontendStartupCore.swift`
