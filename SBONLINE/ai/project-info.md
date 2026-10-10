# Project Info

## Product

SBONLINE is the hosted SPCBOY web player associated with the private
`admin.pre-calc.com` site. It is a browser product and does not share SB2's
macOS app bundle or local presentation state.

## Major Components

- `prototypes/mobile/` contains the standalone mobile interface concept.
- MathBook `private-admin/` contains the current production site integration,
  including the browser player, account/social pages, AAC stream endpoint, and
  deployment setup.
- VGMBoy owns the authoritative playback decoder sources; ScanSong owns catalog
  writing and publication.

## Task Routing

- SBONLINE identity and project intake: `AGENTS.md` and this file.
- Standalone interface concept: `prototypes/mobile/index.html`.
- Current production site behavior: [MathBook private-admin human note](../../../MathBook/ai/subsystem-human/private-admin.md).
- Current production source ownership and deployment: [MathBook private-admin agent note](../../../MathBook/ai/subsystem-agent/private-admin.md).
- Shared decoding and playback: [VGMBoy](../../VGMBoy/AGENTS.md) and its routed notes.
- Catalog creation and publication: [ScanSong](../../ScanSong/AGENTS.md).
- Cross-family ownership: [VGMMan family boundary](../../VGMBoy/ai/subsystem-agent/app-family-boundary.md).

## Local Rules

- Keep the prototype clearly identified as sample-only; it is not the hosted
  player or a playback test.
- The browser receives a stream for a selected hosted track. Do not export a
  collection of pre-encoded songs or expand source archives in advance.
- Catalog reads are read-only in the player; catalog writes belong to ScanSong.
- Do not create a second copy of the production Django implementation here.
  Until its integration and deployment source move together, production changes
  follow MathBook's private-admin route.
- Do not add site accounts, passkeys, private catalogs, or user media to Git.

## Human Docs

- `subsystem-human/site-player.md` describes the current hosted player workflow
  and identifies the standalone concept's limits.
