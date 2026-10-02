#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BASELINE_RC="$(cat /tmp/autodev-baseline-rc 2>/dev/null || echo unknown)"
FINAL_RC="$(cat /tmp/autodev-final-rc 2>/dev/null || echo unknown)"
NO_CHANGE="${AUTODEV_NO_DURABLE_CHANGE:-false}"
RUN_STATUS="${AUTODEV_RUN_STATUS:-failed}"
FAILURE_REASON="${AUTODEV_FAILURE_REASON:-unknown}"

if [[ "$RUN_STATUS" == "success" ]]; then
  exit 0
fi

if [[ "$RUN_STATUS" == "failed" ]]; then
  bash "$ROOT_DIR/scripts/autodev_state.sh" failure || true
fi

pr_url="$(gh pr list -R "$REPOSITORY" --state open --head "$WORK_BRANCH" --base "$BASE_BRANCH" --json url --jq '.[0].url // empty')"
if [[ -z "$pr_url" ]]; then
  exit 0
fi

summary_file="/tmp/autodev-private-diagnostic.txt"
{
  echo "### Central AutoDev diagnostic"
  echo
  echo "- target: $ALIAS"
  echo "- run status: $RUN_STATUS"
  echo "- failure reason: $FAILURE_REASON"
  echo "- baseline validation exit: $BASELINE_RC"
  echo "- final validation exit: $FINAL_RC"
  if [[ "$NO_CHANGE" == "true" ]]; then
    echo "- durable source change: no"
  else
    echo "- durable source change: yes/unknown"
  fi
  if [[ -f /tmp/autodev-selected-model ]]; then
    echo "- selected model: $(cat /tmp/autodev-selected-model)"
  fi

  if [[ "$BASELINE_RC" != "0" && -f /tmp/autodev-baseline.log ]]; then
    echo
    echo "Sanitized baseline failure signals:"
    echo "~~~~"
    grep -Ei "VALIDATION_FAILED|RELEASE_GATE_FAILED|AssertionError|SyntaxError|Error:|npm ERR!|failed|FAIL|not found|missing|exit code|tests? " /tmp/autodev-baseline.log | tail -n 60 |
      sed -E "s/([A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*)=[^[:space:]]+/\\1=***REDACTED***/g; s/(gh[pousr]_[A-Za-z0-9_]+)/***REDACTED***/g" || true
    echo "~~~~"
  fi

  if [[ "$FINAL_RC" != "0" && -f /tmp/autodev-final-validation.log ]]; then
    echo
    echo "Sanitized final validation failure signals:"
    echo "~~~~"
    grep -Ei "VALIDATION_FAILED|RELEASE_GATE_FAILED|AssertionError|SyntaxError|Error:|npm ERR!|failed|FAIL|not found|missing|exit code|tests? " /tmp/autodev-final-validation.log | tail -n 60 |
      sed -E "s/([A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*)=[^[:space:]]+/\\1=***REDACTED***/g; s/(gh[pousr]_[A-Za-z0-9_]+)/***REDACTED***/g" || true
    echo "~~~~"
  fi

  if [[ "$RUN_STATUS" == "failed" && -f /tmp/autodev-model.log ]]; then
    echo
    echo "Last model failure signals:"
    echo "~~~~"
    tail -n 40 /tmp/autodev-model.log |
      sed -E "s/([A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*)=[^[:space:]]+/\\1=***REDACTED***/g; s/(gh[pousr]_[A-Za-z0-9_]+)/***REDACTED***/g" || true
    echo "~~~~"
  fi

  if [[ "$NO_CHANGE" == "true" ]]; then
    echo
    echo "No durable source change was produced; this run is not counted as development progress."
  fi

  if [[ -f /tmp/autodev-state.env ]]; then
    # shellcheck disable=SC1091
    source /tmp/autodev-state.env
    echo
    echo "- consecutive failures: ${AUTODEV_FAILURE_COUNT:-0}"
    echo "- automatic hold until: ${AUTODEV_HOLD_UNTIL:-none}"
  fi
} > "$summary_file"

gh pr comment "$pr_url" --body-file "$summary_file" >/dev/null
echo "Private diagnostic posted to target PR."
