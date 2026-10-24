# SBONLINE Integration Boundaries

## Scope

The hosted SPCBOY web-player product and its relationship to the VGMMan
playback family and MathBook private site.

## Ownership

- This folder is the VGMMan family intake for SBONLINE and holds its standalone
  interface concept.
- MathBook currently owns the live Django app, browser player assets, account
  and community integration, audio HTTP endpoint, and production deployment.
  The specific paths are listed below; edit and deploy them through MathBook
  until their source and release packaging move as a unit.
- VGMBoy owns shared playback admission, archive/source preparation, decoder
  source, and timing. Its `VGMBoyArchiveCore` accepts the original source plus
  selected member and prepares playable input in the core.
- MathBook's production player has not yet been wired to
  `VGMBoyArchiveCore`: `accounts/spcboy_uac.py` and `accounts/views.py` still
  implement selected-member/UAC preparation independently. Its
  `private-admin/streaming/` libvgm bridge is a deployment source copy whose
  upstream commit and mapping are recorded in `UPSTREAM.md`; these copies do
  not receive VGMBoy changes automatically.
- Keep the hosted integration limited to Django authentication, catalog
  metadata, quotas, HTTP streaming, and the Linux AAC/PCM host adapter. Before
  claiming core parity, expose and verify a Linux-buildable VGMBoy interface
  for source preparation and playback, then have MathBook call it instead of
  maintaining archive and decoder behavior in parallel.
- ScanSong is the catalog writer. SBONLINE consumes only the published catalog.

## Invariants

- Keep SBONLINE separate from the SB2 macOS app and its WebKit host contract.
- Keep user accounts, passkeys, profiles, social posts, and private media in the
  authenticated MathBook site.
- Keep source music compressed on the server. Materialize a selected member
  only for a playback request and stream AAC directly to the browser; do not
  create per-track AAC files or an extracted playback tree.
- Do not extend MathBook's parallel archive/decoder implementation for new
  VGMBoy behavior. Core updates reach SBONLINE only after the hosted Linux
  adapter is built against or invokes that shared core.
- Return hosted track identifiers and display metadata to the browser; keep
  package paths and archive member paths server-side.
- Do not copy the production implementation into this folder while MathBook
  remains its deployment source. A source move must update the release bundle
  in the same reviewed change.

## Files

- `prototypes/mobile/index.html`
- [MathBook player and navigation scripts](../../../../MathBook/private-admin/static/accounts/)
- [MathBook player template](../../../../MathBook/private-admin/templates/accounts/base.html)
- [MathBook streaming bridge](../../../../MathBook/private-admin/streaming/)
- [MathBook deployment entry](../../../../MathBook/ops/server/private-admin-deploy.sh)
- [VGMBoy ownership route](../../../VGMBoy/AGENTS.md)
- [ScanSong ownership route](../../../ScanSong/AGENTS.md)
