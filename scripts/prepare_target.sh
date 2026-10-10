#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

BRANCH_MODE="${BRANCH_MODE:-fixed}"
MAX_BRANCH_AHEAD="${MAX_BRANCH_AHEAD:-0}"

if [[ -n "${GH_TOKEN:-}" ]]; then
  gh auth setup-git >/dev/null 2>&1
fi
git fetch origin "$BASE_BRANCH" --prune >/dev/null 2>&1
BASE_REMOTE_SHA="$(git rev-parse "origin/$BASE_BRANCH")"
CHECKOUT_SHA="$(git rev-parse HEAD)"

if [[ "$BRANCH_MODE" == "run_scoped" ]]; then
  if [[ "$CHECKOUT_SHA" != "$BASE_REMOTE_SHA" ]]; then
    echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
    echo "AUTODEV_SKIP_REASON=source_ref_drift" >> "$GITHUB_ENV"
    echo "Run-scoped source moved before branch creation; skipping to avoid stale work."
    exit 0
  fi
  # Review queue guard applies only to saju-core/global; never starts AI when unresolved PRs accumulate.
  backlog_rc=0
  bash "$ROOT_DIR/scripts/review_backlog_guard.sh" || backlog_rc=$?
  if (( backlog_rc != 0 )); then
    echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
    echo "AUTODEV_SKIP_REASON=review_backlog_hold" >> "$GITHUB_ENV"
    echo "Model generation skipped pending consolidation (or safe backlog lookup)." 
    exit 0
  fi
  git switch -c "$WORK_BRANCH" >/dev/null
fi

START_SHA="$(git rev-parse HEAD)"
LAST_EPOCH="$(git log -1 --format=%ct)"
NOW_EPOCH="$(date +%s)"
GUARD="${RECENT_CHANGE_GUARD_MINUTES:-25}"
AGE_MINUTES="$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))"

echo "START_SHA=$START_SHA" >> "$GITHUB_ENV"
echo "SKIP_TARGET=false" >> "$GITHUB_ENV"

if [[ "$BRANCH_MODE" != "run_scoped" ]]; then
  read -r BEHIND_BY AHEAD_BY < <(git rev-list --left-right --count "origin/$BASE_BRANCH...HEAD")
  if (( BEHIND_BY > 0 )); then
    echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
    echo "AUTODEV_SKIP_REASON=branch_behind_base" >> "$GITHUB_ENV"
    echo "Fixed work branch is $BEHIND_BY commit(s) behind $BASE_BRANCH; autonomous edits are blocked until reconciliation."
    exit 0
  fi
  if [[ "$MAX_BRANCH_AHEAD" =~ ^[0-9]+$ ]] && (( MAX_BRANCH_AHEAD > 0 && AHEAD_BY > MAX_BRANCH_AHEAD )); then
    echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
    echo "AUTODEV_SKIP_REASON=long_lived_branch_limit" >> "$GITHUB_ENV"
    echo "Fixed work branch is $AHEAD_BY commit(s) ahead of $BASE_BRANCH, over limit $MAX_BRANCH_AHEAD; use a run-scoped branch."
    exit 0
  fi
fi

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
