#!/usr/bin/env bash
set -euo pipefail

BASELINE_RC="$(cat /tmp/autodev-baseline-rc 2>/dev/null || echo unknown)"
FINAL_RC="$(cat /tmp/autodev-final-rc 2>/dev/null || echo unknown)"
NO_CHANGE="${AUTODEV_NO_DURABLE_CHANGE:-false}"

if [[ "$BASELINE_RC" == "0" && "$FINAL_RC" == "0" && "$NO_CHANGE" != "true" ]]; then exit 0; fi
if [[ "$BASELINE_RC" == "unknown" && "$FINAL_RC" == "unknown" ]]; then exit 0; fi

pr_url="$(gh pr list -R "$REPOSITORY" --state open --head "$WORK_BRANCH" --base "$BASE_BRANCH" --json url --jq '.[0].url // empty')"
if [[ -z "$pr_url" ]]; then exit 0; fi

summary_file="/tmp/autodev-private-diagnostic.txt"
{
  echo "### Central launch runner diagnostic"
  echo
  echo "- target: $ALIAS"
  echo "- baseline validation exit: $BASELINE_RC"
  echo "- final validation exit: $FINAL_RC"
  if [[ "$NO_CHANGE" == "true" ]]; then echo "- durable source change: no"; else echo "- durable source change: yes/unknown"; fi
  if [[ "$BASELINE_RC" != "0" && -f /tmp/autodev-baseline.log ]]; then
    echo
    echo "Sanitized baseline failure signals:"
    echo "~~~~"
    grep -Ei "VALIDATION_FAILED|AssertionError|SyntaxError|Error:|npm ERR!|failed|FAIL|not found|missing|exit code|tests? " /tmp/autodev-baseline.log | tail -n 60 | sed -E "s/([A-Z0-9_]*(KEY|TOKEN|SECRET)[A-Z0-9_]*)=[^[:space:]]+/\\1=***REDACTED***/g; s/(gh[pousr]_[A-Za-z0-9_]+)/***REDACTED***/g" || true
    echo "~~~~"
  fi
  if [[ "$FINAL_RC" != "0" && -f /tmp/autodev-final-validation.log ]]; then
    echo
    echo "Sanitized final validation failure signals:"
    echo "~~~~"
    grep -Ei "VALIDATION_FAILED|AssertionError|SyntaxError|Error:|npm ERR!|failed|FAIL|not found|missing|exit code|tests? " /tmp/autodev-final-validation.log | tail -n 60 | sed -E "s/([A-Z0-9_]*(KEY|TOKEN|SECRET)[A-Z0-9_]*)=[^[:space:]]+/\\1=***REDACTED***/g; s/(gh[pousr]_[A-Za-z0-9_]+)/***REDACTED***/g" || true
    echo "~~~~"
  fi
  if [[ "$NO_CHANGE" == "true" ]]; then
    echo
    echo "The free coding worker completed but produced no durable source change after cleanup. Do not count this run as development progress."
  fi
} > "$summary_file"

gh pr comment "$pr_url" --body-file "$summary_file" >/dev/null
echo "Private diagnostic posted to target PR."
