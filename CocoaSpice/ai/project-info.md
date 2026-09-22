# Project Info

## Product

CocoaSpice is the native AppKit/SwiftUI player frontend for the VGMMan family.
It reads ScanSong’s schema-24 catalog, builds editable playlists, and bundles
VGMBoyKit through a host adapter.

## Major Components

- CocoaSpice owns native presentation, local UI state, and host adaptation.
- ScanSong is the only catalog writer; CatalogReader owns shared read-only
  access and browser projections.
- FrontendCore owns shared archive/cache, preference, queue, and transport
  policy.
- VGMBoy owns format admission, decoding, timing, and audio output.
- MetaMan owns native-format metadata. UACMan owns the UAC package contract.
- SPCBoyWK and ViewBoy are distinct active frontend siblings. Archived Electron
  SPCBoy is not a current feature target.

## Task Routing

Human-facing behavior:

- Main shell: [main-shell.md](subsystem-human/main-shell.md)
- Playlist and queue: [playlist.md](subsystem-human/playlist.md)
- Playback: [playback.md](subsystem-human/playback.md)
- Supported formats: [supported-formats.md](subsystem-human/supported-formats.md)
- Database browser: [database-browser.md](subsystem-human/database-browser.md)
- Options: [options.md](subsystem-human/options.md)

Engineering constraints:

- VGMBoy playback integration:
  [audio-playback-backend-routing.md](subsystem-agent/audio-playback-backend-routing.md)
- UAC member playback:
  [player-integration.md](../../UACMan/ai/subsystem-agent/player-integration.md)
- Skin-neutral Options controls:
  [frontend-control-surface.md](subsystem-agent/frontend-control-surface.md)
- Catalog ownership and browser projection:
  [shared-catalog-boundary.md](subsystem-agent/shared-catalog-boundary.md)
- Database loading and sidebar presentation:
  [library-browser-database.md](subsystem-agent/library-browser-database.md)
- Playlist queue, file formats, selection, and columns:
  [playlist-queue-core.md](subsystem-agent/playlist-queue-core.md),
  [playlist-file-formats.md](subsystem-agent/playlist-file-formats.md),
  [gui-playlist-columns.md](subsystem-agent/gui-playlist-columns.md),
  [gui-playlist-selection-operations.md](subsystem-agent/gui-playlist-selection-operations.md)
- Session persistence and asynchronous work:
  [app-session-persistence.md](subsystem-agent/app-session-persistence.md),
  [async-task-ownership.md](subsystem-agent/async-task-ownership.md)

## Local Rules

- Never scan, create, migrate, repair, or enrich the selected catalog from this
  app. ScanSong owns every catalog write.
- Keep catalog/playlist queries separate from decoder and audio work.
- Keep format routing, decoder integration, timing, output, and scanner-plugin
  builds in VGMBoy; do not add a second decoder/audio path here.
- UAC manifest and seek-table semantics belong to UACMan. The host may adapt
  bounded codec reads for playback; source member bytes remain preserved.
- User-facing behavior belongs in `subsystem-human/`; current engineering
  invariants belong in focused `subsystem-agent/` notes.

## Human Docs

`Docs/` holds reference material. The current Options control inventory is
[`Docs/options-template.md`](../Docs/options-template.md).

The unconfirmed MediaRemote heap-corruption incident evidence is retained at
[`Docs/investigations/MediaRemote-heap-corruption.md`](../Docs/investigations/MediaRemote-heap-corruption.md).
