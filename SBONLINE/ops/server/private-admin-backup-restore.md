# Private Admin Backup and Restore

The `private-admin-backup.timer` runs once each day. The backup job creates a root-only archive under `/var/backups/precalc-admin` and keeps the 3 newest successful archives. It includes:

- A consistent SQLite backup of `/var/lib/precalc-admin/db.sqlite3`.
- Profile and community images under `/var/lib/precalc-admin/media/`.
- SPCBOY's current catalog, saved catalog snapshots, and generated gallery thumbnails.
- `/etc/precalc-admin.env`, including Django's signing key.

The compressed game packages are intentionally excluded. The canonical UAC/source archives remain in the local Audio library and can be copied back after a restore; the database and catalog backup preserve member state and track metadata, while audio package payloads are reinstalled from those source archives. Temporary playback and import payloads are also excluded.

The Usage page shows the last successful run, retained count, and archive size to the owner. Run `sudo systemctl start private-admin-backup.service` to create an extra recovery point. Check the result with `sudo systemctl status private-admin-backup.service` and the Usage page; never print or copy the archive contents into a ticket or chat.

Archives are mode `0600` in a mode `0700` root-owned directory. The environment file inside includes secret key material. A verified copy of the October 11, 2026 archive is held at `~/Library/Application Support/PreCalc Admin Backups/` on the FileVault-protected Mac, in a mode `0700` directory with a mode `0600` file. Update that local copy after deliberately creating another recovery point; the server timer does not sync it. The configured job stores its rotating copies on the droplet, so those alone cannot recover the service after total droplet loss.

## Restore

Restoring an archive replaces account, passkey, sign-in, usage, and SPCBOY state with the selected point in time. Events and playback after that point will be lost. A restore is an SSH operation; there is no web restore control.

1. Select the archive whose timestamp is appropriate. Verify it with `sudo gzip -t /var/backups/precalc-admin/<archive>` and inspect its member names with `sudo tar -tzf /var/backups/precalc-admin/<archive>`.
2. Before replacing anything, make a separate copy of the current database, media tree, and environment file. Store that copy in a root-only recovery directory with enough free space.
3. Stop `private-admin.service` and `private-admin-backup.timer` so the app and timer cannot write during recovery.
4. Extract the selected archive into a new root-only staging directory. Restore `db.sqlite3`, the included `media/` state, and `/etc/precalc-admin.env` together; keep the environment file root-owned with mode `0640` and group `precalc-admin`, and restore the database/media ownership to `precalc-admin`.
5. Repopulate the compressed SPCBOY game packages from the local Audio source archives and rebuild the gallery cache if needed. Restart the timer and service, then verify the passkey portal, account directory, Usage page, SPCBOY catalog, and a stream before considering recovery complete. Keep the pre-restore copy until that verification succeeds.

The deployed application code and Nginx configuration remain sourced from Git and can be redeployed separately. A provider-level or offsite backup destination is still required for droplet-loss recovery.
