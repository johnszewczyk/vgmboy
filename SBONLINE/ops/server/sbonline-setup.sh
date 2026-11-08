#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this setup script as root." >&2
  exit 1
fi

RELEASE_DIR="${1:?release directory required}"
APP_DIR="/opt/precalc-admin/app"
VENV_DIR="/opt/precalc-admin/venv"
DB_DIR="/var/lib/precalc-admin"
SPCBOY_MEDIA_DIR="$DB_DIR/media/spcboy"
STATIC_DIR="/var/www/precalc-admin-static"
ACME_WEBROOT="/var/www/letsencrypt"
CORE_BIN_DIR="/opt/precalc-admin/bin"
vgmboy_prepare_artifact="$RELEASE_DIR/SBONLINE/ops/server/artifacts/vgmboy-prepare-linux.tar.gz"

# Small hosts need compiler headroom while the existing player stays online.
# This reserves local disk only; it does not change the droplet's paid plan.
if [[ "$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)" -lt 1048576 ]]; then
  if [[ ! -e /var/swap.precalc ]]; then
    fallocate -l 512M /var/swap.precalc
    chmod 600 /var/swap.precalc
    mkswap /var/swap.precalc
  fi
  if ! swapon --show=NAME --noheadings | grep -Fxq /var/swap.precalc; then
    swapon /var/swap.precalc
  fi
  if ! grep -Eq '^/var/swap\.precalc[[:space:]]' /etc/fstab; then
    printf '/var/swap.precalc none swap sw 0 0\n' >> /etc/fstab
  fi
fi

if ! dpkg-query -W -f='${Status}\n' \
  vnstat python3-venv ffmpeg cmake build-essential zlib1g-dev libgme-dev pkg-config 7zip zstd 2>/dev/null \
  | awk '$0 == "install ok installed" { count++ } END { exit(count == 10 ? 0 : 1) }'; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    vnstat python3-venv ffmpeg cmake build-essential zlib1g-dev libgme-dev pkg-config 7zip zstd
fi

getent group precalc-admin >/dev/null || groupadd --system precalc-admin
id -u precalc-admin >/dev/null 2>&1 || useradd --system --gid precalc-admin --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin precalc-admin
usermod -aG vnstat precalc-admin

install -d -o root -g root -m 755 /opt/precalc-admin
install -d -o root -g root -m 755 "$CORE_BIN_DIR"
if [[ -f "$vgmboy_prepare_artifact" ]]; then
  runtime_digest="$(sha256sum "$vgmboy_prepare_artifact" | cut -d' ' -f1)"
  runtime_dir="/opt/precalc-admin/lib/vgmboy-prepare/$runtime_digest"
  install -d -o root -g root -m 755 "$runtime_dir"
  if [[ ! -x "$runtime_dir/bin/vgmboy-prepare" ]]; then
    tar -xzf "$vgmboy_prepare_artifact" -C "$runtime_dir"
    chmod 755 "$runtime_dir/bin/vgmboy-prepare"
  fi
  cat > "$CORE_BIN_DIR/vgmboy-prepare.new" <<PREPARE
#!/bin/sh
export LD_LIBRARY_PATH="$runtime_dir/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$runtime_dir/bin/vgmboy-prepare" "\$@"
PREPARE
  chmod 755 "$CORE_BIN_DIR/vgmboy-prepare.new"
  if "$CORE_BIN_DIR/vgmboy-prepare.new" >/dev/null 2>&1; then runtime_status=0; else runtime_status=$?; fi
  [[ "$runtime_status" -eq 2 ]] || { echo 'VGMBoy preparation runtime failed its launch check.' >&2; exit 1; }
  mv -f "$CORE_BIN_DIR/vgmboy-prepare.new" "$CORE_BIN_DIR/vgmboy-prepare"
fi
[[ -x "$CORE_BIN_DIR/vgmboy-prepare" ]] || { echo 'Install the VGMBoy Linux preparation runtime before deploying.' >&2; exit 1; }

install -d -o root -g root -m 755 "$APP_DIR"
# Keep the running decoder and CMake cache until their incremental replacement
# is ready. UI-only releases must not delete/recompile every emulator core.
rsync -a --delete --exclude='/streaming/build/' "$RELEASE_DIR/SBONLINE/server/" "$APP_DIR/"
chown -R root:root "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} +
find "$APP_DIR" -path "$APP_DIR/streaming/build" -prune -o -type f -exec chmod 644 {} +
install -m 644 "$RELEASE_DIR/SBONLINE/ops/server/private-admin.service" /etc/systemd/system/private-admin.service
install -m 755 "$RELEASE_DIR/SBONLINE/ops/server/precalc-admin-backup.py" /usr/local/sbin/precalc-admin-backup
install -m 644 "$RELEASE_DIR/SBONLINE/ops/server/private-admin-backup.service" /etc/systemd/system/private-admin-backup.service
install -m 644 "$RELEASE_DIR/SBONLINE/ops/server/private-admin-backup.timer" /etc/systemd/system/private-admin-backup.timer
install -d -o root -g root -m 755 /etc/nginx/sites-available /etc/nginx/sites-enabled
install -m 644 "$RELEASE_DIR/SBONLINE/ops/server/sbonline.nginx.conf" /etc/nginx/sites-available/sbonline
ln -sfn /etc/nginx/sites-available/sbonline /etc/nginx/sites-enabled/sbonline
if [[ -f /etc/nginx/sites-available/math-textbook ]]; then
  /usr/bin/python3 "$RELEASE_DIR/SBONLINE/ops/server/sbonline-migrate-nginx.py" /etc/nginx/sites-available/math-textbook
fi
cmake -S "$APP_DIR/streaming" -B "$APP_DIR/streaming/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$APP_DIR/streaming/build" --parallel 1

install -d -o root -g precalc-admin -m 750 /etc/precalc-admin
if [[ ! -e /etc/precalc-admin.env ]]; then
  /usr/bin/python3 - <<'PY'
import grp
import os
import secrets

target = "/etc/precalc-admin.env"
group_id = grp.getgrnam("precalc-admin").gr_gid
content = (
    "DJANGO_SECRET_KEY=" + secrets.token_urlsafe(64) + "\n"
    "DJANGO_DB_PATH=/var/lib/precalc-admin/db.sqlite3\n"
    "DJANGO_STATIC_ROOT=/var/www/precalc-admin-static\n"
)
descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o640)
os.write(descriptor, content.encode("ascii"))
os.fchown(descriptor, 0, group_id)
os.close(descriptor)
PY
fi
chown root:precalc-admin /etc/precalc-admin.env
chmod 640 /etc/precalc-admin.env

install -d -o precalc-admin -g precalc-admin -m 750 "$DB_DIR"
install -d -o precalc-admin -g precalc-admin -m 750 "$SPCBOY_MEDIA_DIR"
install -d -o root -g www-data -m 750 "$STATIC_DIR"
install -d -o root -g www-data -m 755 "$ACME_WEBROOT/.well-known/acme-challenge"
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --upgrade -r "$APP_DIR/requirements.txt"

systemctl enable --now vnstat
if ! vnstat --dbiflist 2>/dev/null | grep -Eq '(^|[[:space:]])eth0([[:space:]]|$)'; then
  vnstat --add -i eth0
fi
systemctl restart vnstat

set -a
# shellcheck disable=SC1091
source /etc/precalc-admin.env
set +a
cd "$APP_DIR"
"$VENV_DIR/bin/python" manage.py migrate --noinput
"$VENV_DIR/bin/python" manage.py build_spcboy_search_index
"$VENV_DIR/bin/python" manage.py build_spcboy_gallery_cache
"$VENV_DIR/bin/python" manage.py collectstatic --noinput
"$VENV_DIR/bin/python" manage.py check --deploy

chown -R precalc-admin:precalc-admin "$DB_DIR"
# SQLite owns its live sidecars; they may disappear between find and chmod.
# The private data directory and service umask already protect those files.
find "$DB_DIR" -ignore_readdir_race -type f \
  ! -name '*.sqlite3-journal' ! -name '*.sqlite3-wal' ! -name '*.sqlite3-shm' \
  -exec chmod 600 {} +
install -d -o root -g precalc-admin -m 750 "$DB_DIR/backup-status"
if [[ ! -e "$DB_DIR/backup-status/status.json" ]]; then
  printf '{"state":"waiting"}\n' > "$DB_DIR/backup-status/status.json"
fi
chown root:precalc-admin "$DB_DIR/backup-status/status.json"
chmod 640 "$DB_DIR/backup-status/status.json"
install -d -o root -g root -m 700 /var/backups/precalc-admin
systemd-analyze verify /etc/systemd/system/private-admin-backup.service /etc/systemd/system/private-admin-backup.timer
chown -R root:www-data "$STATIC_DIR"
find "$STATIC_DIR" -type d -exec chmod 750 {} +
find "$STATIC_DIR" -type f -exec chmod 640 {} +

systemctl daemon-reload
nginx -t
systemctl reload nginx
systemctl enable --now private-admin.service
systemctl enable private-admin-backup.timer
systemctl restart private-admin.service
if ! /usr/bin/python3 - <<'PY'
import json
from pathlib import Path

try:
    status = json.loads(Path("/var/lib/precalc-admin/backup-status/status.json").read_text(encoding="utf-8"))
except (OSError, ValueError):
    status = {}
if status.get("state") == "success" and status.get("last_success_at"):
    raise SystemExit(0)
raise SystemExit(1)
PY
then
  systemctl start private-admin-backup.service
fi
systemctl start private-admin-backup.timer
runuser -u precalc-admin -- /usr/bin/vnstat -i eth0 --json m 12 >/dev/null
systemctl is-active --quiet vnstat.service
systemctl is-active --quiet private-admin.service
systemctl is-active --quiet private-admin-backup.timer
/usr/bin/python3 - <<'PY'
import json

with open("/var/lib/precalc-admin/backup-status/status.json", encoding="utf-8") as stream:
    status = json.load(stream)
if status.get("state") != "success" or not status.get("last_success_at"):
    raise SystemExit("Private admin backup did not complete successfully.")
PY
echo "Private admin application installed; HTTPS activation awaits the admin DNS record."
