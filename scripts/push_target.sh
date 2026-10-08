#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

# Credentials are scoped to the push/PR step, after source validation.
gh auth setup-git >/dev/null 2>&1

# Resolve the actual remote ref. A missing tracking ref is not a collision.
REMOTE_REF="refs/heads/$WORK_BRANCH"
REMOTE_LINE="$(git ls-remote --heads origin "$REMOTE_REF")"
REMOTE_SHA=""
if [[ -n "$REMOTE_LINE" ]]; then
  REMOTE_SHA="${REMOTE_LINE%%$'\t'*}"
fi
if [[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$START_SHA" ]]; then
  echo "Remote work branch changed: expected $START_SHA, found $REMOTE_SHA. Push aborted." >&2
  exit 1
fi

LOCAL_SHA="$(git rev-parse HEAD)"
git push origin "HEAD:$REMOTE_REF" >/dev/null

# Never report a green job if the validated commit is absent remotely.
PUSHED_LINE="$(git ls-remote --heads origin "$REMOTE_REF")"
PUSHED_SHA="${PUSHED_LINE%%$'\t'*}"
if [[ "$PUSHED_SHA" != "$LOCAL_SHA" ]]; then
  echo "Push verification failed: expected $LOCAL_SHA, found ${PUSHED_SHA:-<absent>}." >&2
  exit 1
fi

existing="$(gh pr list -R "$REPOSITORY" --state open --head "$WORK_BRANCH" --base "$BASE_BRANCH" --json url --jq '.[0].url // empty')"
if [[ -n "$existing" ]]; then
  echo "Validated batch pushed to existing review PR."
else
  gh pr create -R "$REPOSITORY" --base "$BASE_BRANCH" --head "$WORK_BRANCH" \
    --title "autodev: $ALIAS development batch" \
    --body "Central zero-budget AutoDev batch.

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
