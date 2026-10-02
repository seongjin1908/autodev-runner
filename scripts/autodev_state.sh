#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-read}"
THRESHOLD="${FAILURE_HOLD_THRESHOLD:-3}"
HOLD_MINUTES="${FAILURE_HOLD_MINUTES:-120}"
RUN_ID="${GITHUB_RUN_ID:-local}"

if [[ -z "${GH_TOKEN:-}" || -z "${REPOSITORY:-}" || -z "${WORK_BRANCH:-}" || -z "${BASE_BRANCH:-}" ]]; then
  echo "AutoDev state unavailable: missing GitHub context."
  exit 0
fi

PR_JSON="$(gh pr list -R "$REPOSITORY" --state open --head "$WORK_BRANCH" --base "$BASE_BRANCH" --json number,url --limit 1)"
PR_NUMBER="$(python - "$PR_JSON" <<'PY'
import json,sys
items=json.loads(sys.argv[1] or '[]')
print(items[0]['number'] if items else '')
PY
)"

if [[ -z "$PR_NUMBER" ]]; then
  echo "AutoDev state unavailable: no open PR for $WORK_BRANCH -> $BASE_BRANCH."
  exit 0
fi

COMMENTS_JSON="$(gh api "repos/$REPOSITORY/issues/$PR_NUMBER/comments?per_page=100")"
STATE_TSV="$(python - "$COMMENTS_JSON" <<'PY'
import json,re,sys
comments=json.loads(sys.argv[1] or '[]')
marker='<!-- autodev-state-v1 -->'
state=None
for c in comments:
    body=c.get('body') or ''
    if marker in body:
        state=c
if not state:
    print("none\t0\tnone\tnone\tunknown")
    raise SystemExit
body=state.get('body') or ''
def grab(name, default=''):
    m=re.search(rf'^- {re.escape(name)}:\s*(.+)$', body, re.M)
    return m.group(1).strip() if m else default
print("\t".join([
    str(state.get('id') or ''),
    grab('consecutive_failures','0'),
    grab('hold_until','none'),
    grab('last_run_id',''),
    grab('status','unknown'),
]))
PY
)"

IFS=$'\t' read -r COMMENT_ID FAILURE_COUNT HOLD_UNTIL LAST_RUN_ID LAST_STATUS <<<"$STATE_TSV"
if [[ "${COMMENT_ID:-}" == "none" ]]; then COMMENT_ID=""; fi
FAILURE_COUNT="${FAILURE_COUNT:-0}"
HOLD_UNTIL="${HOLD_UNTIL:-none}"
LAST_RUN_ID="${LAST_RUN_ID:-none}"
LAST_STATUS="${LAST_STATUS:-unknown}"

hold_active() {
  python - "$HOLD_UNTIL" <<'PY'
from datetime import datetime, timezone
import sys
value=sys.argv[1]
if not value or value == 'none':
    raise SystemExit(1)
try:
    dt=datetime.fromisoformat(value.replace('Z','+00:00'))
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if dt > datetime.now(timezone.utc) else 1)
PY
}

write_env() {
  local active=false
  if hold_active; then active=true; fi
  {
    echo "AUTODEV_FAILURE_COUNT=$FAILURE_COUNT"
    echo "AUTODEV_HOLD_UNTIL=$HOLD_UNTIL"
    echo "AUTODEV_STATE_PR_NUMBER=$PR_NUMBER"
    echo "AUTODEV_HOLD_ACTIVE=$active"
  } > /tmp/autodev-state.env
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    cat /tmp/autodev-state.env >> "$GITHUB_ENV"
  fi
}

if [[ "$ACTION" == "read" ]]; then
  write_env
  echo "AutoDev state: status=$LAST_STATUS failures=$FAILURE_COUNT hold_until=$HOLD_UNTIL"
  exit 0
fi

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATUS="$LAST_STATUS"

if [[ "$ACTION" == "failure" ]]; then
  STATUS="failed"
  if [[ "$LAST_RUN_ID" != "$RUN_ID" ]]; then
    FAILURE_COUNT="$((FAILURE_COUNT + 1))"
  fi
  if (( FAILURE_COUNT >= THRESHOLD )); then
    HOLD_UNTIL="$(python - "$HOLD_MINUTES" <<'PY'
from datetime import datetime, timedelta, timezone
import sys
minutes=int(sys.argv[1])
print((datetime.now(timezone.utc)+timedelta(minutes=minutes)).isoformat(timespec='seconds').replace('+00:00','Z'))
PY
)"
  fi
elif [[ "$ACTION" == "success" ]]; then
  STATUS="success"
  FAILURE_COUNT=0
  HOLD_UNTIL="none"
else
  echo "Unknown AutoDev state action: $ACTION" >&2
  exit 2
fi

BODY="$(cat <<EOF
<!-- autodev-state-v1 -->
### AutoDev state
- status: $STATUS
- consecutive_failures: $FAILURE_COUNT
- hold_until: $HOLD_UNTIL
- updated_at: $NOW
- last_run_id: $RUN_ID
EOF
)"

if [[ -n "$COMMENT_ID" ]]; then
  gh api --method PATCH "repos/$REPOSITORY/issues/comments/$COMMENT_ID" -f body="$BODY" >/dev/null
else
  gh api --method POST "repos/$REPOSITORY/issues/$PR_NUMBER/comments" -f body="$BODY" >/dev/null
fi

write_env
echo "AutoDev state updated: status=$STATUS failures=$FAILURE_COUNT hold_until=$HOLD_UNTIL"
