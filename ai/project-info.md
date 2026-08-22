# Project Info

## Product

`SPCBoy (WK)` is an independent native macOS WebKit frontend for SPCBoy.

## Major Components

- AppKit window and WKWebView host.
- The current SPCBoy renderer skin, adapted for the native WebKit bridge.
- Shared `CatalogBrowserCore` sidebar behavior.
- Read-only `CatalogReader` integration.
- In-process VGMBoy playback integration, added behind the native bridge.
- Shared versioned VGMBoy endpoint capability map (`VGMBoyEndpointCore`).
- Shared VGMBoy tempo contract for libgme and libvgm playback settings.
- Shared selected-entry archive materialization through FrontendCore.
- Shared explicit local-folder navigation through `LocalFileBrowserCore`.
- Separate native Settings window with an independent options-mode WKWebView.

## Task Routing

Agent engineering notes:

- Shared sidebar behavior: [shared-sidebar-core.md](subsystem-agent/shared-sidebar-core.md)
- WebKit host boundary: [webkit-host.md](subsystem-agent/webkit-host.md)

## Local Rules

- Launch through `./launch.sh`; it performs a clean release rebuild first.
- Keep catalog access read-only and behind a narrow native bridge.
- The WK bridge is the only native capability boundary. Keep it typed by
  named requests and keep catalog access read-only.
- Keep playback ownership in VGMBoy; this project owns presentation and host integration.
- Keep local navigation in `LocalFileBrowserCore`; keep queue construction and archive-member handling in the frontend adapter.
- Do not add a private archive extractor; use `ArchiveMaterializationCore`.
- Keep Settings as a separate native window; do not restore the in-pane overlay
  as the root window's primary Settings surface.
- Do not add renderer-runtime dependencies or a second catalog implementation.

## Human Docs

- `Docs/` is the human-side folder and is not default engineering intake.
