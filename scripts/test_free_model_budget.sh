#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/free_model_budget.sh"
[[ "$(model_attempt_timeout 300 1 180 90)" == 180 ]]
[[ "$(model_attempt_timeout 300 2 180 90)" == 90 ]]
[[ "$(model_attempt_timeout 300 6 180 90)" == 90 ]]
[[ "$(model_attempt_timeout 50 1 180 90)" == 50 ]]
[[ "$(model_attempt_timeout 50 2 180 90)" == 50 ]]
if model_attempt_timeout invalid 1 180 90 >/dev/null 2>&1; then exit 1; fi
if model_attempt_timeout 300 0 180 90 >/dev/null 2>&1; then exit 1; fi
if model_attempt_timeout 300 2 0 90 >/dev/null 2>&1; then exit 1; fi
echo "PASS: bounded free-model timeout and fallback cases"


# The selected model string must never be evaluated as a shell command when
# generating a Markdown summary (regression observed in run 38755270586).
if grep -Fq 'echo "Validated coding model: `' scripts/develop_target.sh; then
  echo "FAIL: model name is executed through backtick substitution in summary"
  exit 1
fi
grep -Fq "printf 'Validated coding model:" scripts/develop_target.sh || {
  echo "FAIL: selected model is missing from the summary"
  exit 1
}

# Keep the first code-model default aligned with observed valid free batches.
grep -Fq 'PRIMARY_MODEL="${DDD_FREE_CODE_MODEL_PRIMARY:-opencode/space-bunny-free}"' scripts/develop_target.sh
grep -Fq "opencode/space-bunny-free" .github/workflows/autodev.yml

# A provider outage can time out across several different free models.
# After 2 consecutive timeouts keep trying fallbacks, but cap waits to 25s.
[[ "$(model_timeout_after_stalls 180 0 2 25)" == 180 ]]
[[ "$(model_timeout_after_stalls 90 1 2 25)" == 90 ]]
[[ "$(model_timeout_after_stalls 90 2 2 25)" == 25 ]]
[[ "$(model_timeout_after_stalls 90 3 2 25)" == 25 ]]
[[ "$(model_timeout_after_stalls 15 3 2 25)" == 15 ]]
[[ "$(model_timeout_after_stalls 90 0 2 25)" == 90 ]]
if model_timeout_after_stalls invalid 2 2 25 >/dev/null 2>&1; then exit 1; fi
if model_timeout_after_stalls 90 invalid 2 25 >/dev/null 2>&1; then exit 1; fi
if model_timeout_after_stalls 90 2 0 25 >/dev/null 2>&1; then exit 1; fi
if model_timeout_after_stalls 90 2 2 0 >/dev/null 2>&1; then exit 1; fi

# Model failure text must not become next-model prompt content.
grep -Fq 'model_timeout_after_stalls "$ATTEMPT_TIMEOUT" "$CONSECUTIVE_TIMEOUTS" 2 25' scripts/develop_target.sh
grep -Fq 'Free model outcome: $MODEL_ISSUE' scripts/develop_target.sh
if grep -Fq 'append_feedback "model produced no durable source change' scripts/develop_target.sh; then
  echo 'FAIL: raw failed-provider log must not enter another free model prompt'
  exit 1
fi
echo 'PASS: adaptive model stall backoff and sanitized cross-model feedback'
