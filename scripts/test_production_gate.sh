#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

expect_failure() {
  if env BATCH_READY="$1" AUTODEV_RUN_STATUS="$2" bash scripts/require_production_batch.sh >/dev/null 2>&1; then
    echo "FAIL: false production success for BATCH_READY=$1 status=$2"
    exit 1
  fi
}
env BATCH_READY=true AUTODEV_RUN_STATUS=success bash scripts/require_production_batch.sh >/dev/null
expect_failure false success
expect_failure true provider_unavailable
expect_failure false provider_unavailable
expect_failure false no_change
expect_failure true running
expect_failure false failed
echo "PASS: AutoDev success requires validated committed source; zero-code exits nonzero."
