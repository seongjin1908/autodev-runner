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
echo "SKIP_TARGET=false" >> "$GITHUB_ENV"

if (( AGE_MINUTES < GUARD )); then
  echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
  echo "AUTODEV_SKIP_REASON=recent_change" >> "$GITHUB_ENV"
  echo "Target branch changed $AGE_MINUTES minutes ago; skipped to avoid concurrent edits."
  exit 0
fi

if [[ -n "${GH_TOKEN:-}" ]]; then
  cd "$ROOT_DIR"
  bash scripts/autodev_state.sh read || true
  if [[ -f /tmp/autodev-state.env ]]; then
    # shellcheck disable=SC1091
    source /tmp/autodev-state.env
  fi
  if [[ "${AUTODEV_HOLD_ACTIVE:-false}" == "true" ]]; then
    echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
    echo "AUTODEV_SKIP_REASON=failure_hold" >> "$GITHUB_ENV"
    echo "Target is on automatic failure hold until ${AUTODEV_HOLD_UNTIL:-unknown}; model execution skipped."
    exit 0
  fi
fi

echo "AUTODEV_SKIP_REASON=none" >> "$GITHUB_ENV"
echo "Target branch is clear for a guarded batch."
