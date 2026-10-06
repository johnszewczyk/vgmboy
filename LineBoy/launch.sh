#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT/build.sh"
killall LineBoy 2>/dev/null || true
printf 'Launching fresh LineBoy app: %s\n' "$ROOT/.build/LineBoy.app"
if ! open -n "$ROOT/.build/LineBoy.app"; then
  printf 'Launch Services could not open the bundle; launching its executable directly.\n' >&2
  nohup "$ROOT/.build/LineBoy.app/Contents/MacOS/LineBoy" >/dev/null 2>&1 </dev/null &
fi
