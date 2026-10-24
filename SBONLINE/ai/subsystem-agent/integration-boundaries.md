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
- VGMBoy now exposes an initial `vgmboy-prepare <archive> <member>` executable
  bridge that emits the selected prepared member on stdout. The executable
  builds on the local macOS host, but a Linux build/runtime package has not yet
  been verified.
- MathBook's source now has an adapter at `accounts/vgmboy_prepare.py` and
  calls it when the packaged executable is present. MathBook's deployment
  stages a Linux artifact at `ops/server/artifacts/vgmboy-prepare` and installs
  it at the persistent host path `/opt/precalc-admin/bin/vgmboy-prepare`,
  outside the app release tree. Until that artifact is built and installed,
  the existing selected-member/UAC extractor remains a compatibility fallback.
  The production site has not been deployed with this adapter. The adapter
  forwards configured `tar`, `zstd`, and `7z` tool paths to VGMBoy's host-tool
  settings. The site's `private-admin/streaming/` libvgm bridge is a deployment
  source copy whose upstream commit and mapping are recorded in `UPSTREAM.md`;
  it does not receive VGMBoy changes automatically.
- Keep the hosted integration limited to Django authentication, catalog
  metadata, quotas, HTTP streaming, and the Linux AAC/PCM host adapter. Before
  switching production, package and verify the VGMBoy executable for Linux,
  then have MathBook invoke it instead of maintaining archive behavior in
  parallel. Decoder parity remains a separate future boundary; the current
  Linux streamer still owns PCM decoding.
- ScanSong is the catalog writer. SBONLINE consumes only the published catalog.

## Invariants

- Keep SBONLINE separate from the SB2 macOS app and its WebKit host contract.
- Keep user accounts, passkeys, profiles, social posts, and private media in the
  authenticated MathBook site.
- Keep source music compressed on the server. Materialize a selected member
  only for a playback request and stream AAC directly to the browser; do not
  create per-track AAC files or an extracted playback tree.
- Do not extend MathBook's compatibility archive extractor or parallel decoder
  implementation for new VGMBoy behavior. Remove the extraction fallback after
  the Linux executable is packaged and production playback is verified.
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
