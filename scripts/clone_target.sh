#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$ROOT_DIR/target"

gh repo clone "$REPOSITORY" "$ROOT_DIR/target" -- --filter=blob:none >/dev/null 2>&1
cd "$ROOT_DIR/target"

git fetch origin "$BASE_BRANCH" "$WORK_BRANCH" --prune >/dev/null 2>&1 || true
if git show-ref --verify --quiet "refs/remotes/origin/$WORK_BRANCH"; then
  git switch -C "$WORK_BRANCH" "origin/$WORK_BRANCH" >/dev/null 2>&1
else
  git switch -C "$WORK_BRANCH" "origin/$BASE_BRANCH" >/dev/null 2>&1
fi

START_SHA="$(git rev-parse HEAD)"
LAST_EPOCH="$(git log -1 --format=%ct)"
NOW_EPOCH="$(date +%s)"
GUARD="${RECENT_CHANGE_GUARD_MINUTES:-25}"
AGE_MINUTES="$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))"

echo "START_SHA=$START_SHA" >> "$GITHUB_ENV"
if (( AGE_MINUTES < GUARD )); then
  echo "SKIP_TARGET=true" >> "$GITHUB_ENV"
  echo "Target branch changed recently; skipped to avoid concurrent edits."
else
  echo "SKIP_TARGET=false" >> "$GITHUB_ENV"
  echo "Target branch is clear for a guarded batch."
fi

# Remove token-bearing process environment after this step. No target code runs here.
