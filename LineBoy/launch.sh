#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT/build.sh"
killall LineBoy 2>/dev/null || true
printf 'Launching fresh LineBoy app: %s\n' "$ROOT/.build/LineBoy.app"
exec open -n "$ROOT/.build/LineBoy.app"
