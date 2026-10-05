# Project Info

ViewBoy is the VGMMan family's native macOS player with a screen-first Yoga pixel-grid front end. AppKit hosts one WKWebView. The web view paints a framebuffer into a two-color canvas with exact BG/PIXEL endpoints; native Swift retains the catalog, preferences, archive, and VGMBoy playback bridge.

## Routes

- Display and pixel scale: `subsystem-human/display.md`.
- Published LCD color and layout specification: [ViewBoy UI Design](../../VGMManDocs/Docs/md/ViewBoy/ui-design.md).
- In-screen settings: `subsystem-human/options.md`.
- Playback: `subsystem-human/playback.md`.
- Requested history playlist handoff: `reports/new-feature-report.md`.
- System and game sidebar: `subsystem-agent/shared-sidebar-core.md`.
- Native bridge and app packaging: `subsystem-agent/webkit-host.md` and `subsystem-agent/viewboy-integration.md`.
- Shared startup stages and LCD rendering: `subsystem-agent/startup-experience.md`.

## Boundaries

- ViewBoy owns layout, hit testing, the bitmap font, framebuffer, AppKit host, and its preference namespace.
- CatalogReader reads the ScanSong catalog. ViewBoy never writes it.
- FrontendCore owns shared queue, transport, and startup-progress policy;
  VGMBoy owns decoding, timing, and audio output.
- `launch.sh` builds, packages, signs, and opens the application.
