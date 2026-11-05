#!/bin/bash
# Test-only zstd adapter: hold the first selected UAC frame.
set -euo pipefail
: "${VGMBOY_SLOW_UAC_SIGNAL:?Set a new signal path for this test run}"
: "${VGMBOY_TEST_REAL_ZSTD:?Set the real zstd executable path}"
case "${VGMBOY_UAC_DELAY_STAGE:-payload}" in
  payload) marker=' --memory=64MB ' ;;
  manifest) marker=' --memory=32MB ' ;;
  *) echo 'Unsupported UAC delay stage' >&2; exit 2 ;;
esac
if [[ " $* " == *"$marker"* ]] && mkdir "${VGMBOY_SLOW_UAC_SIGNAL}.lock" 2>/dev/null; then
  touch "$VGMBOY_SLOW_UAC_SIGNAL"
  sleep "${VGMBOY_UAC_DELAY_SECONDS:-8}"
  if [[ -n "${VGMBOY_FAIL_UAC_FRAME:-}" ]]; then exit 1; fi
fi
exec "$VGMBOY_TEST_REAL_ZSTD" "$@"
