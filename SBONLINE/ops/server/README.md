# SBONLINE Host Release

SBONLINE source and release packaging live in this repository. The rented
`admin.pre-calc.com` webspace is only the deployment target.

## Deploy

From the VGMMan repository root, run:

```sh
bash SBONLINE/ops/server/sbonline-deploy.sh
```

The release builds the BOM site from the sibling `BOM/` checkout and therefore
requires `pandoc`. Override `BOM_REPO_ROOT` when the checkout is elsewhere.
SSH uses `REMOTE_USER`, `REMOTE_HOST`, and `SSH_KEY` defaults from the script;
keep the private key and host environment outside Git.

The script bundles `SBONLINE/server/`, the SBO Nginx virtual host, and setup
files, sends a temporary archive to the host, and invokes `sbonline-setup.sh`.
Setup replaces `/opt/precalc-admin/app/` from the VGMMan bundle with
`rsync --delete`, migrates the existing database, collects static files,
checks the Django deployment, and restarts the service. The extracted release
and upload archive are removed after setup. There is no retained app copy for
rollback. Persistent database, account media, and the host's existing runtime
remain outside the app tree.

## Playback runtime

`sbonline-setup.sh` installs the `vgmboy-prepare` Linux runtime. Its artifact
may be staged at
`SBONLINE/ops/server/artifacts/vgmboy-prepare-linux.tar.gz`; when present, the
deploy bundle installs it immutably. When absent, the existing host runtime is
used. The authoritative implementation and build workflow belong to VGMBoy.

The daily host recovery archive covers user data, not previous app files.
See [private-admin-backup-restore.md](private-admin-backup-restore.md) for the
data recovery procedure.
