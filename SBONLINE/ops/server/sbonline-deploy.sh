#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SBONLINE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$SBONLINE_ROOT/.." && pwd)"
BOM_REPO_ROOT="${BOM_REPO_ROOT:-$(dirname "$REPO_ROOT")/BOM}"
REMOTE_USER="${REMOTE_USER:-john}"
REMOTE_HOST="${REMOTE_HOST:-68.183.113.4}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
REMOTE="${REMOTE_USER}@${REMOTE_HOST}"
BUNDLE="$(mktemp /tmp/sbonline.XXXXXX.tar.gz)"
BOM_STAGE="$(mktemp -d /tmp/precalc-bom-site.XXXXXX)"
REMOTE_BUNDLE="/tmp/sbonline-deploy.tar.gz"
vgmboy_prepare_artifact="$SBONLINE_ROOT/ops/server/artifacts/vgmboy-prepare-linux.tar.gz"

cleanup() { rm -f "$BUNDLE"; rm -rf "$BOM_STAGE"; }
trap cleanup EXIT

command -v pandoc >/dev/null || {
  echo "Pandoc is required to package BOM Notes. Install it with Homebrew: brew install pandoc" >&2
  exit 1
}

python3 "$SBONLINE_ROOT/ops/server/build_bom_site.py" \
  "$BOM_REPO_ROOT" "$BOM_STAGE/SBONLINE/server/bom_site"

bundle_paths=(
  SBONLINE/server
  SBONLINE/ops/server/private-admin.service
  SBONLINE/ops/server/precalc-admin-backup.py
  SBONLINE/ops/server/private-admin-backup.service
  SBONLINE/ops/server/private-admin-backup.timer
  SBONLINE/ops/server/sbonline-migrate-nginx.py
  SBONLINE/ops/server/sbonline.nginx.conf
  SBONLINE/ops/server/sbonline-setup.sh
)
if [[ -f "$vgmboy_prepare_artifact" ]]; then
  bundle_paths+=(SBONLINE/ops/server/artifacts/vgmboy-prepare-linux.tar.gz)
fi

COPYFILE_DISABLE=1 tar --no-xattrs \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  -czf "$BUNDLE" \
  -C "$REPO_ROOT" \
  "${bundle_paths[@]}" \
  -C "$BOM_STAGE" SBONLINE/server/bom_site

scp -i "$SSH_KEY" "$BUNDLE" "$REMOTE:$REMOTE_BUNDLE"
ssh -i "$SSH_KEY" "$REMOTE" "
  set -euo pipefail
  release=\$(mktemp -d /tmp/sbonline-release.XXXXXX)
  trap 'rm -rf \"\$release\"; rm -f \"$REMOTE_BUNDLE\"' EXIT
  tar -xzf '$REMOTE_BUNDLE' -C \"\$release\"
  sudo bash \"\$release/SBONLINE/ops/server/sbonline-setup.sh\" \"\$release\"
"

echo "SBONLINE deployment complete."
