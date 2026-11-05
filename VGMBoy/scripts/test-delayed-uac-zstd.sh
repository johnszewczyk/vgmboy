#!/bin/bash
# Test-only zstd adapter: hold the first UAC payload frame, not its manifest.
set -euo pipefail
: "${VGMBOY_SLOW_UAC_SIGNAL:?Set a new signal path for this test run}"
: "${VGMBOY_TEST_REAL_ZSTD:?Set the real zstd executable path}"
case " $* " in
  *' --memory=64MB '*)
    if mkdir "${VGMBOY_SLOW_UAC_SIGNAL}.lock" 2>/dev/null; then
      touch "$VGMBOY_SLOW_UAC_SIGNAL"
      sleep "${VGMBOY_UAC_DELAY_SECONDS:-8}"
      if [[ -n "${VGMBOY_FAIL_UAC_FRAME:-}" ]]; then exit 1; fi
    fi
    ;;
esac
exec "$VGMBOY_TEST_REAL_ZSTD" "$@"
