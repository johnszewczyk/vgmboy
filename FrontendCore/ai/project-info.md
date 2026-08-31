# Project Info

## Product

`FrontendCore` is the shared UI-neutral policy and service package used by the
native CocoaSpice and SPCBoyWK frontends.

## Major Components

- Archive listing, process execution, materialization, cache, and lease cores.
- Local-file browser, favorite identity/store, and playlist identity cores.
- Typed frontend preference validation and storage coordination.
- Playback request, queue, and native transport coordination.

## Task Routing

- Archive listing, extraction, materialization, cache, and lifetime:
  [archive-services.md](subsystem-agent/archive-services.md)
- Favorites, playlist identity, preferences, requests, queues, and transport:
  [frontend-policy.md](subsystem-agent/frontend-policy.md)

## Local Rules

- ScanSong is the only catalog writer and scanner owner.
- CatalogReader owns read-only schema-23 access and catalog projections.
- VGMBoy owns format admission, decoding, timing, output gain, and the audio
  device.
- Frontends own presentation, app-specific persistence keys, and user-facing
  policy not promoted into a shared typed contract.
- Shared targets do not import frontend UI frameworks or frontend models.

## Human Docs

- `README.md` is the package overview.
- This package has no direct user-facing subsystem notes.
