#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

# Token exists only in this push/PR step; target build/model code is already finished.
gh auth setup-git >/dev/null 2>&1
git fetch origin "$WORK_BRANCH" --prune >/dev/null 2>&1 || true
REMOTE_SHA="$(git rev-parse "origin/$WORK_BRANCH" 2>/dev/null || true)"
if [[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$START_SHA" ]]; then
  echo "Remote branch advanced during the run. Push aborted to prevent collision."
  exit 0
fi

git push origin "HEAD:$WORK_BRANCH" >/dev/null 2>&1

existing="$(gh pr list -R "$REPOSITORY" --state open --head "$WORK_BRANCH" --base "$BASE_BRANCH" --json url --jq '.[0].url // empty')"
if [[ -n "$existing" ]]; then
  echo "Validated batch pushed to existing review PR."
else
  gh pr create -R "$REPOSITORY" --base "$BASE_BRANCH" --head "$WORK_BRANCH"     --title "autodev: $ALIAS development batch"     --body "Central zero-budget AutoDev batch.

- Baseline checked
- Final validation passed
- Workflow/secret guard passed
- Paid fallback disabled
- Auto-merge disabled
- Production deploy not performed" >/dev/null
  echo "Validated review PR created."
fi
