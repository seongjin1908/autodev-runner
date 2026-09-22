#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

START_SHA="$(git rev-parse HEAD)"
LAST_EPOCH="$(git log -1 --format=%ct)"
NOW_EPOCH="$(date +%s)"
GUARD="${RECENT_CHANGE_GUARD_MINUTES:-25}"
AGE_MINUTES="$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))"

echo "START_SHA=$START_SHA" >> "$GITHUB_ENV"
if (( AGE_MINUTES < GUARD )); then
  echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
  echo "Target branch changed $AGE_MINUTES minutes ago; skipped to avoid concurrent edits."
else
  echo "SKIP_TARGET=false" >> "$GITHUB_ENV"
  echo "Target branch is clear for a guarded batch."
fi
