# Project Info

## Product

ViewBoy is a native macOS WebKit frontend in the VGMMan family. It shares
catalog, archive, queue, and playback services with the other frontends while
owning its app identity and phosphor display skin.

## Major Components

- AppKit window, WebKit renderer, and typed native bridge.
- ViewBoy-specific preferences and settings window.
- WebKit/CSS interface and a transparent Metal phosphor overlay.
- Shared CatalogReader catalog and browser projections.
- Shared FrontendCore queue, archive, preferences, and transport policy.
- Shared VGMBoy decoder, timing, and audio playback.

## Task Routing

Human-facing behavior:

- Display and phosphor treatment: `subsystem-human/display.md`.
- Settings and preferences: `subsystem-human/options.md`.
- Playback and transport: `subsystem-human/playback.md`.

Engineering constraints:

- Shared sidebar behavior: `subsystem-agent/shared-sidebar-core.md`.
- WebKit host and bridge: `subsystem-agent/webkit-host.md`.
- App identity, package links, and build boundary:
  `subsystem-agent/viewboy-integration.md`.

## Local Rules

- Build dependencies are sibling packages `../CatalogReader`, `../FrontendCore`,
  and `../VGMBoy`; keep those paths relative and do not copy shared behavior.
- Catalog access is read-only. ScanSong is the only catalog writer.
- Keep decoder selection, audio output, timing, and transport policy in VGMBoy
  and FrontendCore; this app owns presentation and bridge adaptation.
- Keep ViewBoy preference keys and bundle identity separate from SPCBoyWK.
- Keep the inherited `window.SPCBoyWK` dispatcher stable until a typed bridge
  migration is separately scoped.
- `launch.sh` performs a clean release build and opens the packaged app.

## Human Docs

Human-facing behavior is documented in the routed `subsystem-human/` notes.
