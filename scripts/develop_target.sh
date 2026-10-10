#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

VALIDATION="$(python - "$VALIDATION_B64" <<'PY'
import base64,sys
print(base64.b64decode(sys.argv[1]).decode())
PY
)"

PRIMARY_MODEL="${DDD_FREE_CODE_MODEL_PRIMARY:-opencode/mimo-v2.6-flash-free}"
SECONDARY_MODEL="${DDD_FREE_CODE_MODEL_SECONDARY:-opencode/longcat-2.5-preview-free}"
TERTIARY_MODEL="${DDD_FREE_CODE_MODEL_TERTIARY:-opencode/nemotron-3.5-lightning-free}"
QUATERNARY_MODEL="${DDD_FREE_CODE_MODEL_QUATERNARY:-opencode/ling-3.0-flash-fin-free}"
QUINARY_MODEL="${DDD_FREE_CODE_MODEL_QUINARY:-opencode/laguna-s-2.1-free}"
SENARY_MODEL="${DDD_FREE_CODE_MODEL_SENARY:-opencode/space-bunny-free}"
MODEL_TIMEOUT="${DDD_FREE_MODEL_TIMEOUT_SECONDS:-300}"
TRANSIENT_RETRIES="${DDD_FREE_MODEL_TRANSIENT_RETRIES:-1}"

echo "BATCH_READY=false" >> "$GITHUB_ENV"
echo "AUTODEV_RUN_STATUS=running" >> "$GITHUB_ENV"

install_baseline_dependencies() {
  if [[ -f package-lock.json ]]; then
    npm ci >/tmp/autodev-install.log 2>&1
  elif [[ -f package.json ]]; then
    npm install --no-package-lock --no-audit --no-fund >/tmp/autodev-install.log 2>&1
  fi
}

install_baseline_dependencies

set +e
bash -lc "$VALIDATION" >/tmp/autodev-baseline.log 2>&1
BASELINE_RC=$?
set -e
echo "$BASELINE_RC" > /tmp/autodev-baseline-rc
echo "Baseline validation completed (exit $BASELINE_RC)."

npm install -g opencode-ai >/tmp/autodev-opencode-install.log 2>&1

{
  echo "You are a zero-budget autonomous coding worker."
  echo
  if [[ "$PROMPT_FILE" == *-design.md ]]; then
    cat "$ROOT_DIR/prompts/DESIGN_STANDARD_2026.md"
    echo
  fi
  cat "$ROOT_DIR/$PROMPT_FILE"
  echo
  cat <<'RULES'
# Global execution rules
- Work only inside the checked-out target repository.
- If baseline validation failed, fix the actual root cause before adding features.
- Security and release integrity come before feature expansion: repair auth, authorization, payment, secrets, input validation, privacy/data exposure, idempotency, abuse/rate limits, and failing CI before adding lower-priority features.
- Build for global markets without assuming language equals market. Keep locale, market, currency, tax/payment/provider, legal copy, consent, data-retention/data-residency, and feature availability separately configurable where the product can expand internationally.
- Never silently enable a country, payment rail, regulated workflow, or personal-data use merely because a translation exists.
- Preserve a safe fallback for unsupported markets and fail closed for money, identity, access, regulated, or privacy-sensitive operations.
- Make a coherent batch, not a cosmetic one-line change.
- Prefer existing architecture, helpers, tests, and deterministic code.
- Do not modify .github workflows, secrets, credential files, or environment files.
- Do not add paid AI, paid APIs, billing, live production payment, or automatic production deploy.
- Do not auto-merge.
- Do not fabricate passing tests, live integration success, analytics, prices, or progress.
- Keep the batch small enough to review and large enough to create real user value.
- A failed previous attempt has been rolled back. Work from the clean repository state currently on disk.
RULES
  echo
  echo "# Baseline validation output"
  cat /tmp/autodev-baseline.log
} >/tmp/autodev-prompt.txt

has_durable_changes() {
  python - <<'PY'
import subprocess,sys
generated_prefixes=('node_modules/','dist/','coverage/','.astro/','__pycache__/')
generated_names={'.DS_Store'}
lines=subprocess.check_output(['git','status','--porcelain'], text=True).splitlines()
durable=[]
for line in lines:
    p=line[3:]
    if ' -> ' in p:
        p=p.split(' -> ',1)[1]
    p=p.strip()
    if not p:
        continue
    if p in generated_names or any(p.startswith(prefix) for prefix in generated_prefixes):
        continue
    if '/__pycache__/' in p or p.endswith('.pyc') or p.endswith('.pyo'):
        continue
    durable.append(p)
print('\n'.join(durable))
sys.exit(0 if durable else 1)
PY
}

manifest_changed() {
  git status --porcelain -- package.json package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock | grep -q .
}

restore_attempt_baseline() {
  local reinstall=false
  if manifest_changed; then reinstall=true; fi
  git reset --hard "$START_SHA" >/dev/null
  git clean -fd -e node_modules/ >/dev/null
  rm -rf dist coverage .astro
  find . -type d -name __pycache__ -prune -exec rm -rf {} + >/dev/null 2>&1 || true
  find . -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete >/dev/null 2>&1 || true
  if [[ "$reinstall" == "true" ]]; then
    install_baseline_dependencies
  fi
}

guard_changes() {
  python - "$MAX_CHANGED_FILES" <<'PY'
import subprocess,sys
limit=int(sys.argv[1])
lines=subprocess.check_output(['git','status','--porcelain'], text=True).splitlines()
paths=[]
for line in lines:
    p=line[3:]
    if ' -> ' in p:
        p=p.split(' -> ',1)[1]
    p=p.strip()
    if p:
        paths.append(p)
blocked=[]
for p in paths:
    low=p.lower()
    if p.startswith('.github/') or p.startswith('.env') or '/.env' in p or low.endswith('.pem') or low.endswith('.key') or 'secret' in low:
        blocked.append(p)
    # Reject disposable snapshots/probe scripts generated by the saju bot.
    # These produced redundant non-shippable PRs #100, #103, #106 and #109.
    if __import__('os').environ.get('ALIAS','').startswith('saju') and (
        p.startswith('.tmp') or p.startswith('scripts/tmp/') or
        p.startswith('backend/.consumer-') or p.startswith('backend/.generic-')
    ):
        blocked.append(p)
if blocked:
    print('Guard blocked sensitive/workflow changes: ' + ', '.join(blocked))
    raise SystemExit(2)
if len(paths) > limit:
    print(f'Guard blocked oversized batch: {len(paths)} files > {limit}.')
    raise SystemExit(3)
print(f'Guard passed: {len(paths)} changed files.')
PY
}

sanitize_tail() {
  local file="$1"
  local lines="${2:-100}"
  if [[ ! -f "$file" ]]; then return 0; fi
  tail -n "$lines" "$file" |
    sed -E "s/([A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*)=[^[:space:]]+/\\1=***REDACTED***/g; s/(gh[pousr]_[A-Za-z0-9_]+)/***REDACTED***/g"
}

append_feedback() {
  local title="$1"
  local file="$2"
  {
    echo
    echo "# Retry feedback: $title"
    echo "The previous attempt was discarded and the repository was restored to the original START_SHA."
    echo "Fix the root cause shown below; do not repeat the same ineffective edit."
    echo '~~~~'
    sanitize_tail "$file" 100
    echo '~~~~'
  } >> /tmp/autodev-prompt.txt
}

is_transient_model_error() {
  local file="$1"
  grep -Eqi "Unexpected server error|rate.?limit|HTTP[^0-9]*(429|500|502|503|504)|temporar|service unavailable|connection reset|upstream|overloaded" "$file" 2>/dev/null
}

validate_attempt() {
  local logfile="$1"
  if manifest_changed; then
    if [[ -f package-lock.json ]]; then
      npm ci >/tmp/autodev-attempt-install.log 2>&1
    elif [[ -f package.json ]]; then
      npm install --no-package-lock --no-audit --no-fund >/tmp/autodev-attempt-install.log 2>&1
    fi
  fi
  set +e
  bash -lc "$VALIDATION" >"$logfile" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

SELECTED_MODEL=""
ATTEMPT=0

for model in "$PRIMARY_MODEL" "$SECONDARY_MODEL" "$TERTIARY_MODEL" "$QUATERNARY_MODEL" "$QUINARY_MODEL" "$SENARY_MODEL"; do
  provider_try=0
  while (( provider_try <= TRANSIENT_RETRIES )); do
    provider_try=$((provider_try + 1))
    ATTEMPT=$((ATTEMPT + 1))
    restore_attempt_baseline
    echo "Free coding model attempt $ATTEMPT: $model (provider try $provider_try)"

    set +e
    timeout "$MODEL_TIMEOUT" opencode run --model "$model" --agent build "$(cat /tmp/autodev-prompt.txt)" >/tmp/autodev-model.log 2>&1
    MODEL_RC=$?
    set -e

    if ! DURABLE_PATHS="$(has_durable_changes)"; then
      # A timed-out worker already used its entire budget. Move to the next
      # provider rather than spending another five minutes on the same stall.
      if [[ "$MODEL_RC" -ne 0 && "$MODEL_RC" -ne 124 && "$MODEL_RC" -ne 137 ]] && is_transient_model_error /tmp/autodev-model.log && (( provider_try <= TRANSIENT_RETRIES )); then
        echo "Transient provider failure; retrying same model once."
        sleep 3
        continue
      fi
      append_feedback "model produced no durable source change (exit $MODEL_RC)" /tmp/autodev-model.log
      break
    fi

    echo "Durable changed paths:"
    echo "$DURABLE_PATHS"

    set +e
    guard_changes >/tmp/autodev-guard.log 2>&1
    GUARD_RC=$?
    set -e
    if [[ "$GUARD_RC" -ne 0 ]]; then
      append_feedback "change guard rejected the batch" /tmp/autodev-guard.log
      break
    fi

    VALIDATION_LOG="/tmp/autodev-attempt-validation-$ATTEMPT.log"
    if validate_attempt "$VALIDATION_LOG"; then
      SELECTED_MODEL="$model"
      if [[ "$MODEL_RC" -ne 0 ]]; then
        SELECTED_MODEL="salvaged:$model"
      fi
      cp "$VALIDATION_LOG" /tmp/autodev-final-validation.log
      echo "0" > /tmp/autodev-final-rc
      echo "Validated model batch accepted: $SELECTED_MODEL"
      break 2
    else
      FINAL_RC=$?
      echo "$FINAL_RC" > /tmp/autodev-final-rc
      cp "$VALIDATION_LOG" /tmp/autodev-final-validation.log
      append_feedback "validation failed after model $model" "$VALIDATION_LOG"
      echo "Validation failed for $model; rolling back before the next model."
      break
    fi
  done
done

if [[ -z "$SELECTED_MODEL" ]]; then
  restore_attempt_baseline
  echo "All free model attempts were exhausted without a validated batch."
  echo "BATCH_READY=false" >> "$GITHUB_ENV"
  echo "AUTODEV_RUN_STATUS=failed" >> "$GITHUB_ENV"
  echo "AUTODEV_FAILURE_REASON=model_pool_exhausted" >> "$GITHUB_ENV"
  exit 1
fi

echo "$SELECTED_MODEL" >/tmp/autodev-selected-model

git diff --check >/tmp/autodev-final-diffcheck.log 2>&1

rm -rf node_modules dist coverage .astro
find . -type d -name __pycache__ -prune -exec rm -rf {} + >/dev/null 2>&1 || true
find . -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete >/dev/null 2>&1 || true

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Validated successfully; no durable source changes were produced."
  echo "BATCH_READY=false" >> "$GITHUB_ENV"
  echo "AUTODEV_NO_DURABLE_CHANGE=true" >> "$GITHUB_ENV"
  echo "AUTODEV_RUN_STATUS=no_change" >> "$GITHUB_ENV"
  exit 0
fi

git config user.name "central-autodev-runner"
git config user.email "central-autodev-runner@users.noreply.github.com"
git add -A
git commit -m "autodev: complete $ALIAS batch" >/tmp/autodev-commit.log 2>&1

echo "BATCH_READY=true" >> "$GITHUB_ENV"
echo "AUTODEV_RUN_STATUS=success" >> "$GITHUB_ENV"
echo "AUTODEV_FAILURE_REASON=none" >> "$GITHUB_ENV"
echo "Validated batch is ready for guarded push."
