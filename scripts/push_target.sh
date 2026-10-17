#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

# Token exists only in this push/PR step; target build/model code is already finished.
gh auth setup-git >/dev/null 2>&1
# A new run-scoped branch normally has no remote ref. Plain `git rev-parse`
# prints an unresolved ref name to stdout, which previously produced false
# "remote branch advanced" reports and silently discarded every validated batch.
# GitHub API uses the already-verified repository token and avoids an
# unauthenticated git ls-remote failure before we have tried to push.
# Match exactly: GitHub's matching-refs endpoint can return prefix matches.
if ! gh api "repos/$REPOSITORY/git/matching-refs/heads/$WORK_BRANCH" > /tmp/autodev-remote-refs.json; then
  echo "::error::Unable to inspect remote work branch; no push attempted."
  exit 1
fi
REMOTE_SHA="$(python3 - "$WORK_BRANCH" <<'PY'
import json,sys
target="refs/heads/"+sys.argv[1]
data=json.load(open("/tmp/autodev-remote-refs.json",encoding="utf-8"))
matches=[r.get("object",{}).get("sha","") for r in data if r.get("ref")==target]
if len(matches)>1:
    raise SystemExit("Duplicate exact work refs")
print(matches[0] if matches else "")
PY
)"
if [[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$START_SHA" ]]; then
  echo "::error::Remote branch advanced during the run. Push aborted to prevent collision."
  exit 1
fi

if ! git push origin "HEAD:$WORK_BRANCH" > /tmp/autodev-push.stdout 2> /tmp/autodev-push.stderr; then
  # Never print credentials or provider responses. Preserve a redacted
  # diagnostic so an actual Git push 128 is not silent.
  sed -E 's#(https?://)[^/@[:space:]]+@#\\1***@#g; s#gh[pousr]_[A-Za-z0-9_]+#***REDACTED***#g' /tmp/autodev-push.stderr >&2
  echo "::error::Validated batch could not be pushed to $REPOSITORY/$WORK_BRANCH. Check repository token Contents write and Git auth."
  exit 128
fi

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
