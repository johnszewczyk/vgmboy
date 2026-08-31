# Project Info

## Product

- `CocoaSpice` is a native macOS game-music playlist frontend.
- It reads a schema-23 catalog published by ScanSong and bundles `VGMBoyKit` for playback.
- The product split is a read-only `Database` browser on the left and an editable `Playlist` on the right.

## Major Components

- Main shell and toolbar.
- Playlist and queue operations.
- Read-only database browsing and queue projections.
- Shared `CatalogReader`, `CatalogPlaylistCore`, and `CatalogBrowserCore`
  projections, adapted into native sidebar and playlist rows.
- Local-folder queue enumeration through shared `LocalFileBrowserCore`.
- VGMBoy playback controls, transport, timing, and equalizer presentation.
- Persistence and async task ownership.
- Focused preferences, favorites, local-browser, and playlist-queue state coordinators.
- Build and runtime packaging.

## Task Routing

Human-facing behavior:

- Main shell: [main-shell.md](subsystem-human/main-shell.md)
- Playlist: [playlist.md](subsystem-human/playlist.md)
- Playback: [playback.md](subsystem-human/playback.md)
- Supported formats: [supported-formats.md](subsystem-human/supported-formats.md)
- Database browser: [database-browser.md](subsystem-human/database-browser.md)
- Options: [options.md](subsystem-human/options.md)

Agent engineering notes:

- VGMBoy playback integration: [audio-playback-backend-routing.md](subsystem-agent/audio-playback-backend-routing.md)
- Skin-neutral Options control boundary: [frontend-control-surface.md](subsystem-agent/frontend-control-surface.md)
- Database ownership: [library-browser-database.md](subsystem-agent/library-browser-database.md), [shared-catalog-boundary.md](subsystem-agent/shared-catalog-boundary.md), [database-sidebar-presentation.md](subsystem-agent/database-sidebar-presentation.md)
- Playlist ownership and formats: [playlist-queue-core.md](subsystem-agent/playlist-queue-core.md), [playlist-file-formats.md](subsystem-agent/playlist-file-formats.md), [gui-playlist-columns.md](subsystem-agent/gui-playlist-columns.md), [gui-playlist-selection-operations.md](subsystem-agent/gui-playlist-selection-operations.md)
- App state and async work: [app-session-persistence.md](subsystem-agent/app-session-persistence.md), [async-task-ownership.md](subsystem-agent/async-task-ownership.md)
- Remaining engineering notes: [subsystem-agent/](subsystem-agent/)

## Local Rules

- Human subsystem notes describe only what users can see and do.
- Agent subsystem notes describe only current engineering constraints and ownership facts.
- CocoaSpice never writes, scans, migrates, or enriches the selected ScanSong catalog.
- Keep database browsing and queue construction separate from VGMBoy playback control.
- Format routing, decoder integration, timing, audio output, and scanner-plugin build ownership belong to VGMBoyKit/VGMBoy; CocoaSpice must not add decoder, audio-engine, or ScanSong plugin implementations.
- Keep the UI native and simple before inventing custom chrome.

## Human Docs

- `Docs/` is the human-side folder.
- `Docs/` is not default intake.
