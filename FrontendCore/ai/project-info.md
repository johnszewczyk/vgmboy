# Project Info

## Product

`FrontendCore` is the shared UI-neutral policy and service package used by the
CocoaSpice, SB2, and ViewBoy frontends. Retired SPCBoyWK remains a historical
consumer of these interfaces.

## Major Components

- Archive listing, process execution, materialization, cache, and lease cores.
- Archive playback materialization consumes the UAC wrapper API owned by
  `VGMMan/UACMan`.
- Local-file browser, favorite identity/store, playback-history store, and
  playlist identity cores.
- Typed frontend preference validation and storage coordination.
- Shared startup stages, progress state, and presentation timing.
- Playback request, queue, and native transport coordination.

## Task Routing

- Archive listing, extraction, materialization, cache, and lifetime:
  [archive-services.md](subsystem-agent/archive-services.md)
- Favorites, playlist identity, preferences, requests, queues, and transport:
  [frontend-policy.md](subsystem-agent/frontend-policy.md)
- Cross-frontend startup stage and progress contract:
  [startup-experience.md](subsystem-agent/startup-experience.md)

## Local Rules

- ScanSong is the only catalog writer and scanner owner.
- CatalogReader owns read-only schema-24 access and catalog projections.
- VGMBoy owns format admission, decoding, timing, output gain, and the audio
  device.
- Frontends own presentation, app-specific persistence keys, and user-facing
  policy not promoted into a shared typed contract.
- Shared targets do not import frontend UI frameworks or frontend models.

## Human Docs

- `README.md` is the package overview.
- This package has no direct user-facing subsystem notes.
