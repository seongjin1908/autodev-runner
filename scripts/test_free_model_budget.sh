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
