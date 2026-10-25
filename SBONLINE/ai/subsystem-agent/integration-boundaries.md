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
- Hosted source preparation uses VGMBoy's Linux `vgmboy-prepare` process bridge.
  MathBook's `accounts/vgmboy_prepare.py` passes the selected original
  archive/member, configured archive tools and request-owned scratch directory.
  The old independent UAC/ZIP/7z playback extractor has been removed. Missing
  runtimes and failed preparation are explicit failures; do not add a fallback.
- The manual `vgmboy-prepare-linux.yml` workflow builds on Ubuntu 24.04 x86_64.
  MathBook stages its `vgmboy-prepare-linux.tar.gz` artifact and installs immutable
  runtime versions under `/opt/precalc-admin/lib/vgmboy-prepare/`. The persistent
  wrapper `/opt/precalc-admin/bin/vgmboy-prepare` switches atomically. Source
  revision and artifact digest identify the installed package; no Swift compiler
  is installed on the production host. App deployments retain this runtime.
- Django owns authentication, catalog validation, quotas, HTTP streaming and
  AAC delivery. Its bounded adapter limits helper output and lifetime and
  reclaims nested tools/scratch on failure. The Linux PCM decoder remains in
  `private-admin/streaming/`; pinned upstream sources are recorded in
  `UPSTREAM.md`. Shared preparation does not imply a full native decoder port.
- ScanSong is the catalog writer. SBONLINE consumes only the published catalog.

## Invariants

- Keep SBONLINE separate from the SB2 macOS app and its WebKit host contract.
- Keep user accounts, passkeys, profiles, social posts, and private media in the
  authenticated MathBook site.
- Keep source music compressed on the server. Materialize a selected member
  only for a playback request and stream AAC directly to the browser; do not
  create per-track AAC files or an extracted playback tree.
- Archive preparation changes belong in VGMBoy and require a new Linux runtime
  artifact. Do not recreate an archive extractor inside the hosted adapter.
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
