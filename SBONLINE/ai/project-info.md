# Project Info

## Product

SBONLINE is VGMMan's authenticated hosted SPCBOY web player at
`admin.pre-calc.com`. It is separate from SB2's macOS bundle and local player
state.

## Major Components

- `server/` owns the Django site, accounts, browser UI, player adapter, and AAC
  endpoint.
- `ops/server/` owns the deploy bundle and service setup for the rented host.
- `prototypes/mobile/` holds sample-only design concepts.
- VGMBoy owns shared playback admission, source preparation, and decoder source.
- ScanSong owns catalog writes and publication; SBONLINE reads the published
  catalog.

## Task Routing

- Product and route: `AGENTS.md` and this file.
- Hosted UI, app APIs, and account behavior: `server/` and
  [site-player.md](subsystem-human/site-player.md).
- Server/source boundaries, state, and deployment: [integration boundaries](subsystem-agent/integration-boundaries.md).
- Hosted release: `ops/server/sbonline-deploy.sh`.
- Shared archive preparation and decoding: [VGMBoy](../../VGMBoy/AGENTS.md).
- Catalog publication: [ScanSong](../../ScanSong/AGENTS.md).
- Family ownership: [family boundary](../../VGMBoy/ai/subsystem-agent/app-family-boundary.md).

## Local Rules

- Keep the app source and deploy package in this repository. The rented
  webspace is a hosting target only; do not source production files from
  MathBook or maintain an app copy there.
- Keep user accounts, passkeys, preferences, and media outside Git.
- Keep source music compressed on the host. Materialize only the selected
  member during a playback request and stream AAC directly.
- Catalog reads are read-only in SBONLINE; catalog writes belong to ScanSong.
- Do not recreate archive extraction or decoder policy inside the Django
  adapter; those boundaries belong to VGMBoy.
- `prototypes/mobile/` remains sample-only and is not playback evidence.

## Human Docs

- `subsystem-human/site-player.md` describes current hosted player behavior.
