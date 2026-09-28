# Project Info

ViewBoy is the VGMMan family's native macOS player with a screen-first Yoga LCD front end. AppKit hosts one WKWebView. The web view paints a four-shade framebuffer into a canvas; native Swift retains the catalog, preferences, archive, and VGMBoy playback bridge. The former DOM/CSS Game Boy interface was archived in `LocalRecovery/ViewBoy/ViewBoy-webkit-9a2048ed.zip` before its resources were removed.

## Routes

- Display and pixel scale: `subsystem-human/display.md`.
- In-screen settings: `subsystem-human/options.md`.
- Playback: `subsystem-human/playback.md`.
- Native bridge and app packaging: `subsystem-agent/webkit-host.md` and `subsystem-agent/viewboy-integration.md`.
- Source exploration and transition: `investigations/yoga-lcd-canvas-preview.md`.

## Boundaries

- ViewBoy owns layout, hit testing, the bitmap font, framebuffer, AppKit host, and its preference namespace.
- CatalogReader reads the ScanSong catalog. ViewBoy never writes it.
- FrontendCore owns shared queue and transport policy; VGMBoy owns decoding, timing, and audio output.
- `launch.sh` builds, packages, signs, and opens the application.
