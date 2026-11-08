# SBONLINE Integration Boundaries

## Scope

The hosted SPCBOY player, its production Django application, and its release to
the rented `admin.pre-calc.com` webspace.

## Ownership

- VGMMan is the sole source owner for SBONLINE. Production Django code,
  templates, browser assets, stream integration, and release scripts live under
  `SBONLINE/server/` and `SBONLINE/ops/server/`.
- MathBook is unrelated textbook content. It is not a source, build, or release
  dependency for SBONLINE. The rented webspace and its credentials are used only
  as the target for the VGMMan release.
- Persistent accounts, passkeys, preferences, SQLite databases, and media stay
  on the host under `/var/lib/precalc-admin/`; credentials stay in the host
  environment file. Never commit or export these to Git.
- VGMBoy owns shared playback admission, archive/member preparation, decoder
  source, and timing. Its `VGMBoyArchiveCore` accepts the source and selected
  member and prepares playable input.
- ScanSong owns catalog publication. SBONLINE reads the published catalog and
  does not write catalog state.

## Release and host state

- Run `bash SBONLINE/ops/server/sbonline-deploy.sh` from the VGMMan repository.
  The script builds the app bundle from this checkout, stages the separately
  owned BOM static site, and uploads a temporary release to the host.
- The setup script syncs `SBONLINE/server/` into `/opt/precalc-admin/app/` with
  `rsync --delete`. The temporary release is removed after setup. Do not keep
  old app files or app release directories for rollback.
- `/var/lib/precalc-admin/` contains persistent app data and its daily
  root-only recovery archives. Those archives protect user data, not old source
  files, and remain separate from app releases.
- `/etc/precalc-admin.env`, SSH credentials, and the service's existing host
  configuration remain outside this repository. Never print or commit them.
- The admin host's Nginx virtual host is `ops/server/sbonline.nginx.conf`; the
  MathBook Nginx config owns only `pre-calc.com` and its math content.
- The service name and host paths retain their legacy `precalc-admin` labels;
  they are deployment identifiers, not a MathBook ownership signal.
- `vgmboy-prepare-linux.yml` builds the Linux x86_64 source-preparation runtime.
  When a prepared archive is staged in `SBONLINE/ops/server/artifacts/`, the
  release installs it immutably under `/opt/precalc-admin/lib/`. Otherwise the
  host keeps its existing runtime.

## Playback boundary

- Hosted source preparation uses VGMBoy's Linux `vgmboy-prepare` process bridge.
  `server/accounts/vgmboy_prepare.py` passes the original source and selected
  member, configured archive tools, and request-owned scratch directory.
- Django owns authentication, catalog validation, quotas, HTTP streaming, and
  AAC delivery. Its bounded adapter limits helper output and lifetime and
  reclaims nested tools and scratch data on failure.
- The Linux PCM decoder remains in `server/streaming/`; pinned upstream sources
  and licenses are recorded in `server/streaming/UPSTREAM.md`. Shared source
  preparation is not a native decoder port.
- Keep source music compressed on the server. Materialize only the selected
  member for a playback request. Do not create per-track AAC files or extracted
  playback trees.
- Return hosted track IDs and display metadata to the browser. Keep source
  package paths and archive-member paths server-side.

## Files

- `server/accounts/`
- `server/templates/accounts/`
- `server/static/accounts/`
- `server/streaming/`
- `ops/server/sbonline-deploy.sh`
- `ops/server/sbonline-setup.sh`
- `ops/server/private-admin-backup-restore.md`
- [VGMBoy ownership route](../../../VGMBoy/AGENTS.md)
- [ScanSong ownership route](../../../ScanSong/AGENTS.md)
