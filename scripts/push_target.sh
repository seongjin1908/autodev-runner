#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

# Token exists only in this push/PR step; target build/model code is already finished.
gh auth setup-git >/dev/null 2>&1
# A new run-scoped branch normally has no remote ref. Plain `git rev-parse`
# prints an unresolved ref name to stdout, which previously produced false
# "remote branch advanced" reports and silently discarded every validated batch.
REMOTE_SHA="$(git ls-remote --heads origin "refs/heads/$WORK_BRANCH" | awk '{print $1}')"
if [[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$START_SHA" ]]; then
  echo "::error::Remote branch advanced during the run. Push aborted to prevent collision."
  exit 1
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

bash "$ROOT_DIR/scripts/autodev_state.sh" success || true
echo "AutoDev failure state reset after validated push."
