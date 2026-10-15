#!/usr/bin/env bash
# A green GitHub Actions run must never mean "all coding providers failed".
# The guarded worker records BATCH_READY only after it commits a validated diff.
set -euo pipefail

status="${AUTODEV_RUN_STATUS:-unknown}"
ready="${BATCH_READY:-false}"

if [[ "$status" == "success" && "$ready" == "true" ]]; then
  echo "Validated source batch committed; guarded push/PR step is a separate gate."
  exit 0
fi

echo "::error title=AutoDev produced no validated code::status=$status; BATCH_READY=$ready. This workflow must not count as a development success."
exit 1
