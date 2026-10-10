#!/usr/bin/env bash
# Fail closed before any AI/model invocation when reviewed saju changes are backlogged.
set -euo pipefail

if [[ "${BRANCH_MODE:-}" != "run_scoped" || "${REPOSITORY:-}" != "seongjin1908/daangn-saju-autodev" ]]; then
  exit 0
fi
case "${WORK_BRANCH:-}" in
  autodev/saju-core/*) lane="saju-core" ;;
  autodev/saju-global/*) lane="saju-global" ;;
  *) exit 0 ;;
esac

MAX_PENDING="${MAX_PENDING_SAJU_PRS:-2}"
if ! [[ "$MAX_PENDING" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid MAX_PENDING_SAJU_PRS; no model run permitted." >&2
  exit 10
fi

if ! prs="$(gh pr list -R "$REPOSITORY" --state open --base "$BASE_BRANCH" --limit 100 --json headRefName)"; then
  echo "Could not read open PR backlog; skipping to avoid generating more duplicates." >&2
  exit 10
fi
if ! count="$(python3 -c '
import json,sys
prefix="autodev/"+sys.argv[1]+"/"
prs=json.load(sys.stdin)
assert isinstance(prs,list)
print(sum(isinstance(p,dict) and str(p.get("headRefName","")).startswith(prefix) for p in prs))
' "$lane" <<< "$prs")"; then
  echo "Could not parse open PR backlog; skipping for safety." >&2
  exit 10
fi
if (( count >= MAX_PENDING )); then
  echo "REVIEW BACKLOG HOLD: $lane has $count open PRs (limit $MAX_PENDING). Integrate/close stale PRs before generating another batch."
  exit 10
fi
echo "Review backlog clear for $lane ($count/$MAX_PENDING)."
