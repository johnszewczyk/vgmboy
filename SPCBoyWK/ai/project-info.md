# Project Info

## Product

`SPCBoy (WK)` is the native WebKit frontend component in the VGMMan monorepo.

## Major Components

- AppKit window and WKWebView host.
- The current SPCBoy renderer skin, adapted for the native WebKit bridge.
- Shared `CatalogBrowserCore` sidebar behavior.
- Read-only `CatalogReader` integration.
- In-process VGMBoy playback integration, added behind the native bridge.
- Shared versioned VGMBoy endpoint capability map (`VGMBoyEndpointCore`).
- Shared VGMBoy tempo contract for libgme and libvgm playback settings.
- Shared selected-entry or dependency-complete archive materialization through
  FrontendCore.
- Shared explicit local-folder navigation through `LocalFileBrowserCore`.
- Shared `PlaybackRequestCore` lifecycle and serial VGMBoy command execution.
- Shared `PlaybackTransportCore` native transport lifecycle and
  `PlaybackTransportStatusPayload` bridge projection.
- Shared `VGMBoyFormatCore` capability and archive-requirement projection,
  including complete-set handling for UADE/Amiga prefix-led modules and MDX/PDX
  dependencies.
- Separate native Settings window with an independent options-mode WKWebView.

The root library uses a shared two-row geometry: the sidebar toolbar and
playlist header row are each `2.65rem` tall, with `1.65rem` visible controls
centered inside them. Header items use a `0.25rem` gap, matching sidebar
controls; both content panes use the same `0.2rem` row padding and `1rem`
effective text inset. Playlist column resizing uses the shared configurable
`200ms` default CSS width transition. WK now uses the Electron client's proven structure: a
header table and body table with matching column widths inside one shared
horizontal scroll surface. Release persists the result and pointer capture
keeps the gesture alive after it leaves the narrow divider.

## Task Routing

Human-facing behavior:

- Options and settings window: [options.md](subsystem-human/options.md)
- Playback and transport: [playback.md](subsystem-human/playback.md)

Agent engineering notes:

- Shared sidebar behavior: [shared-sidebar-core.md](subsystem-agent/shared-sidebar-core.md)
- WebKit host boundary: [webkit-host.md](subsystem-agent/webkit-host.md)

## Local Rules

- Launch through `./launch.sh`; it performs a clean release rebuild first.
- Keep catalog access read-only and behind a narrow native bridge.
- The configurable playlist includes a Dumper column populated from the
  read-only ScanSong catalog projection; missing values display an em dash.
- The WK bridge is the only native capability boundary. Keep it typed by
  named requests and keep catalog access read-only.
- Keep playback ownership in VGMBoy; this project owns presentation and host integration.
- Do not add decoder, metadata-inspection, or format-admission implementations
  here; use VGMBoyKit/VGMBoyFormatCore and the packaged endpoint surface.
- Keep local navigation in `LocalFileBrowserCore`; keep queue construction and presentation in the frontend adapter, while archive-member materialization runs through the native bridge and shared `ArchiveMaterializationCore`.
- Do not add a private archive extractor; use `ArchiveMaterializationCore`.
- Keep Settings as a separate native window; do not restore the in-pane overlay
  as the root window's primary Settings surface.
- Do not add renderer-runtime dependencies or a second catalog implementation.

## Human Docs

- `Docs/` is the human-side folder and is not default engineering intake.
