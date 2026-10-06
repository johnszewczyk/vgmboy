#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PORT="${LINEBOY_PORT:-8765}"

"$ROOT/build.sh"
printf 'Serving LineBoy at http://127.0.0.1:%s/\n' "$PORT"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT/.build/site"
