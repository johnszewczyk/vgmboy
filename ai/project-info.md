# Project Info

## Product

`SPCBoy (WK)` is the native macOS WebKit frontend track for SPCBoy. It is a
separate successor project, not a compatibility layer inside the Electron app.

## Major Components

- AppKit window and WKWebView host.
- The current SPCBoy renderer skin, staged from the Electron frontend.
- Shared `CatalogBrowserCore` sidebar behavior.
- Future `CatalogReader` and VGMBoy integration.

## Task Routing

Agent engineering notes:

- Shared sidebar behavior: [shared-sidebar-core.md](subsystem-agent/shared-sidebar-core.md)
- WebKit host boundary: [webkit-host.md](subsystem-agent/webkit-host.md)

## Local Rules

- Launch through `./launch.sh`; it performs a clean release rebuild first.
- Keep catalog access read-only and behind a narrow native bridge.
- The current WK bridge is a startup-only placeholder; do not treat empty
  catalog data as a working catalog integration.
- Keep playback ownership in VGMBoy; this project owns presentation and host integration.
- Do not expand the archived Electron implementation here.

## Human Docs

- `Docs/` is the human-side folder and is not default engineering intake.
