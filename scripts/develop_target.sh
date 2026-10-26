#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

# Emit only duration counters in the public workflow summary, never private source or logs.
RUN_STARTED_EPOCH="$(date +%s)"
INSTALL_SECONDS="not-run"
BASELINE_SECONDS="not-run"
OPENCODE_SECONDS="not-run"
print_worker_timings() {
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
  {
    echo
    echo "## AutoDev time spent (seconds)"
    printf "| Phase | Seconds |\n|---|---:|\n"
    printf "| Dependency setup | %s |\n" "$INSTALL_SECONDS"
    printf "| Baseline validation | %s |\n" "$BASELINE_SECONDS"
    printf "| OpenCode installation | %s |\n" "$OPENCODE_SECONDS"
    printf "| Total worker | %s |\n" "$(( $(date +%s) - RUN_STARTED_EPOCH ))"
    if [[ -n "${MODEL_METRICS_FILE:-}" && -f "$MODEL_METRICS_FILE" ]]; then
      echo
      echo "### Sanitized OpenCode model outcome"
      python3 "$ROOT_DIR/scripts/model_metrics.py" summary --file "$MODEL_METRICS_FILE" || true
    fi
  } >> "$GITHUB_STEP_SUMMARY"
}
trap print_worker_timings EXIT

VALIDATION="$(python - "$VALIDATION_B64" <<'PY'
import base64,sys
print(base64.b64decode(sys.argv[1]).decode())
PY
)"

PRIMARY_MODEL="${DDD_FREE_CODE_MODEL_PRIMARY:-opencode/space-bunny-free}"
SECONDARY_MODEL="${DDD_FREE_CODE_MODEL_SECONDARY:-opencode/longcat-2.5-preview-free}"
TERTIARY_MODEL="${DDD_FREE_CODE_MODEL_TERTIARY:-opencode/nemotron-3.5-lightning-free}"
QUATERNARY_MODEL="${DDD_FREE_CODE_MODEL_QUATERNARY:-opencode/ling-3.0-flash-fin-free}"
QUINARY_MODEL="${DDD_FREE_CODE_MODEL_QUINARY:-opencode/laguna-s-2.1-free}"
SENARY_MODEL="${DDD_FREE_CODE_MODEL_SENARY:-opencode/mimo-v2.6-flash-free}"
MODEL_TIMEOUT="${DDD_FREE_MODEL_TIMEOUT_SECONDS:-300}"
TRANSIENT_RETRIES="${DDD_FREE_MODEL_TRANSIENT_RETRIES:-0}"
# Do not spend five minutes on each unresponsive free provider. The first
# coding model has a longer opportunity; the remaining providers fail over
# quickly. Explicit lower timeout values continue to take precedence.
source "$ROOT_DIR/scripts/free_model_budget.sh"
MODEL_PRIMARY_CAP="${DDD_FREE_MODEL_PRIMARY_TIMEOUT_CAP_SECONDS:-180}"
MODEL_FALLBACK_CAP="${DDD_FREE_MODEL_FALLBACK_TIMEOUT_CAP_SECONDS:-90}"
MODEL_ATTEMPT_REPORT="${RUNNER_TEMP:-/tmp}/autodev-model-attempts.md"
MODEL_METRICS_FILE="${RUNNER_TEMP:-/tmp}/autodev-model-metrics.jsonl"
: > "$MODEL_METRICS_FILE"
printf '| Free model | Timeout | Actual seconds | Exit code | Result |\n|---|---:|---:|---:|---|\n' > "$MODEL_ATTEMPT_REPORT"

echo "BATCH_READY=false" >> "$GITHUB_ENV"
echo "AUTODEV_RUN_STATUS=running" >> "$GITHUB_ENV"

install_baseline_dependencies() {
  : > /tmp/autodev-install.log
  if [[ -f pnpm-lock.yaml ]]; then
    corepack enable >>/tmp/autodev-install.log 2>&1
    pnpm install --frozen-lockfile >>/tmp/autodev-install.log 2>&1
  elif [[ -f package-lock.json ]]; then
    npm ci --no-audit --no-fund >>/tmp/autodev-install.log 2>&1
  elif [[ -f package.json ]]; then
    npm install --no-package-lock --no-audit --no-fund >>/tmp/autodev-install.log 2>&1
  fi
  if [[ -f requirements.txt ]]; then
    python -m pip install -r requirements.txt >>/tmp/autodev-install.log 2>&1
  fi
  # FastBrowse contains desktop and browser API Python tests. Installing only a
  # top-level requirements.txt made its baseline fail before any repair agent ran.
  if [[ "${ALIAS:-}" == "fastbrowse" ]]; then
    python -m pip install -r requirements-dev.txt -r browser-api/requirements.txt >>/tmp/autodev-install.log 2>&1
  fi
}

install_started="$(date +%s)"
install_baseline_dependencies
INSTALL_SECONDS="$(( $(date +%s) - install_started ))"

baseline_started="$(date +%s)"
set +e
bash -lc "$VALIDATION" >/tmp/autodev-baseline.log 2>&1
BASELINE_RC=$?
set -e
BASELINE_SECONDS="$(( $(date +%s) - baseline_started ))"
echo "$BASELINE_RC" > /tmp/autodev-baseline-rc
echo "Baseline validation completed (exit $BASELINE_RC)."

# Direct free API runs do not need OpenCode, model listing or REA initialization.
# Avoid global CLI installation and repeated provider timeouts on every 30-min job.
if [[ "${AUTODEV_DIRECT_FREE_ONLY:-false}" == "true" ]]; then
  if (( BASELINE_RC != 0 )) && [[ "${ALIAS:-}" != "fastbrowse" ]]; then
    echo "AUTODEV_RUN_STATUS=failed" >> "$GITHUB_ENV"
    echo "AUTODEV_FAILURE_REASON=baseline_failed" >> "$GITHUB_ENV"
    echo "::error::Baseline validation failed; do not generate unrelated code."
    exit 1
  fi
  if [[ ! -f "$ROOT_DIR/$PROMPT_FILE" ]]; then
    echo "::error::Review prompt missing."
    exit 2
  fi
  {
    printf 'Target: %s\n' "$ALIAS"
    cat "$ROOT_DIR/$PROMPT_FILE"
    if (( BASELINE_RC != 0 )) && [[ "${ALIAS:-}" == "fastbrowse" ]]; then
      printf '\n# P0: baseline test failure (repair the root cause before new features)\n'
      # Local runner file only: never echo source or full private traceback to public job output.
      tail -n 80 /tmp/autodev-baseline.log
    fi
    printf '\nDo not modify protected files or activate paid APIs.\n'
  } > /tmp/autodev-prompt.txt
  echo "AUTODEV_FAILURE_REASON=direct_provider_pending" >> "$GITHUB_ENV"
  echo "Direct-free-only path: baseline passed; skipped OpenCode installation, REA and model timeout loop."
  exit 0
fi
opencode_started="$(date +%s)"
npm install --cache "${RUNNER_TEMP:-/tmp}/autodev-public-cli-npm-cache" -g opencode-ai --no-audit --no-fund >/tmp/autodev-opencode-install.log 2>&1
OPENCODE_SECONDS="$(( $(date +%s) - opencode_started ))"

# REA is optional and only enabled after a verified OpenCode MCP handshake.
# A failed handshake never blocks validated product development.
source "$ROOT_DIR/scripts/prepare_rea_worker.sh"

# Discover installed candidates, then filter through the reviewed no-cost allowlist.
FREE_LISTING=/tmp/autodev-free-models.txt
DISCOVERY_ARGS=()
if timeout 25s opencode models opencode >"$FREE_LISTING" 2>/tmp/autodev-free-discovery.log; then
  DISCOVERY_ARGS=(--listing "$FREE_LISTING")
  echo "Model discovery succeeded; pricing safety enforced by code allowlist."
else
  echo "::warning::Model listing unavailable. Fallback is limited to historical free IDs."
fi
if ! MODEL_LINES="$(python3 "$ROOT_DIR/scripts/free_model_pool.py" candidates "${DISCOVERY_ARGS[@]}")"; then
  echo "::error::Paid, unknown, or unapproved model was rejected."
  exit 2
fi
MODEL_CANDIDATES=()
if [[ -n "$MODEL_LINES" ]]; then mapfile -t MODEL_CANDIDATES <<< "$MODEL_LINES"; fi
echo "Model candidates: ${#MODEL_CANDIDATES[@]} (preferred model is checked again next scheduled run)."
# When a separately authenticated free Gemini fallback is opted in, try it
# sooner instead of spending the full OpenCode pool time on repeated stalls.
# Without that explicit opt-in, preserve the historical 540-second window.
if [[ "${AUTODEV_GEMINI_FREE_ENABLED:-false}" == "true" ]]; then
  POOL_MAX_SECONDS="${DDD_FREE_MODEL_POOL_MAX_SECONDS:-270}"
else
  POOL_MAX_SECONDS="${DDD_FREE_MODEL_POOL_MAX_SECONDS:-540}"
fi
echo "OpenCode model time budget: ${POOL_MAX_SECONDS}s (independent free Gemini opt-in: ${AUTODEV_GEMINI_FREE_ENABLED:-false})."
POOL_MAX_ATTEMPTS="${DDD_FREE_MODEL_MAX_ATTEMPTS:-10}"
if ! [[ "$POOL_MAX_SECONDS" =~ ^[1-9][0-9]*$ && "$POOL_MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "::error::Model time and attempt limits must be positive integers."
  exit 2
fi

{
  echo "You are a zero-budget autonomous coding worker."
  echo
  if [[ "$PROMPT_FILE" == *-design.md ]]; then
    cat "$ROOT_DIR/prompts/DESIGN_STANDARD_2026.md"
    echo
  fi
  cat "$ROOT_DIR/$PROMPT_FILE"
  echo
  # Reuse research is scoped to the selected existing target. This reads
  # reviewed candidate metadata only: never installs packages or downloads
  # unapproved model weights and never overrides the launch priority.
  python3 "$ROOT_DIR/scripts/oss_reuse.py" --alias "$ALIAS"
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
- REA connection in this worker is controlled by the verified runtime handshake below; a .codex/.agents registration is NOT proof of REA availability or actual tool use.
- Never claim REA was used from repository configuration alone. Use reviewed REA findings only when their evidence, authorization scope, and reproducible observations are present.
- Competitor public behavior may inform requirements, but never copy protected source, assets, private APIs, or restricted designs.
- Finish-mode: choose one highest-impact incomplete release milestone and close it end-to-end before starting another feature family.
- Inspect current code and open work first; never create a duplicate implementation for a feature already present or already under review.
- Do not use a docs-only, TODO-only, placeholder-only, mock-only, or cosmetic-only batch as primary progress.
- Keep the batch reviewable but large enough to remove a real release blocker in one pass.
- A failed previous attempt has been rolled back. Work from the clean repository state currently on disk.
RULES
  echo
  echo "# Runtime REA evidence"
  if [[ "${REA_MCP_CONNECTED:-false}" == "true" ]]; then
    echo "- OpenCode REA MCP handshake: CONNECTED in this runner. This is NOT proof of a REA analysis invocation."
    echo "- Use REA only when it materially accelerates a high-priority blocker and only on OWNED or explicitly authorized local software. For competitors inspect public UI behavior without reverse engineering protected implementations."
    echo "- Do at most one tightly scoped REA analysis per batch. If invoked, report exact owned target, MCP tool, observed evidence and limitations; otherwise say REA was not used."
  else
    echo "- REA MCP handshake: UNAVAILABLE in this runner; proceed with normal source-based implementation and tests. Never claim REA use."
  fi
  echo
  echo "# Baseline validation output"
  cat /tmp/autodev-baseline.log
} >/tmp/autodev-prompt.txt

# Scope a single source-grounded task per batch instead of broad repo rewrites.
# The helper is deterministic, offline, and never prints source contents.
python3 "$ROOT_DIR/scripts/select_task_slice.py" --root "$PWD" \
  --alias "$ALIAS" --baseline-rc "$BASELINE_RC" \
  --run-number "${GITHUB_RUN_NUMBER:-0}" >> /tmp/autodev-prompt.txt
echo "Grounded small-task brief added to the existing project prompt."

clean_disposable_saju_artifacts() {
  if [[ "${ALIAS:-}" != saju* ]]; then
    return 0
  fi
  while IFS= read -r -d '' p; do
    case "$p" in
      .tmp*|scripts/tmp/*|backend/.consumer-*|backend/.generic-*|probe-*|scripts/probe-*|scripts/probe_*|scripts/_probe*|scripts/tmp-*)
        rm -rf -- "$p"
        ;;
    esac
  done < <(git ls-files --others --exclude-standard -z)
}

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
  git status --porcelain -- package.json package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock requirements.txt pyproject.toml poetry.lock | grep -q .
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
lines=subprocess.check_output(['git','status','--porcelain','--untracked-files=all'], text=True).splitlines()
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
        p.startswith('backend/.consumer-') or p.startswith('backend/.generic-') or
        p.startswith('probe-') or p.startswith('scripts/probe-') or
        p.startswith('scripts/_probe') or p.startswith('scripts/probe_') or
        p.startswith('scripts/tmp-')
    ):
        blocked.append(p)
    # WORLD PATCH edits are scoped to the isolated original-series module.
    if __import__('os').environ.get('ALIAS','') == 'world-patch' and not p.startswith('brands/world-patch/'):
        blocked.append(p)
    # COSTON Partner Hub is a separate, high-risk financial ledger workstream.
    # The free model cannot edit unrelated DDD core, workflows, manifests or payment secrets.
    if __import__('os').environ.get('ALIAS','') == 'coston-partner-hub' and not p.startswith((
        'partner-hub/src/', 'partner-hub/integrations/',
        'partner-hub/tests/', 'partner-hub/public/', 'partner-hub/docs/',
    )):
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
      npm ci --no-audit --no-fund >/tmp/autodev-attempt-install.log 2>&1
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
POOL_STARTED_EPOCH="$(date +%s)"
CONSECUTIVE_TIMEOUTS=0

for model in "${MODEL_CANDIDATES[@]}"; do
  if (( ATTEMPT >= POOL_MAX_ATTEMPTS )); then
    echo "Free-model attempt cap reached; no paid fallback."
    break
  fi
  remaining="$(( POOL_MAX_SECONDS - ($(date +%s) - POOL_STARTED_EPOCH) ))"
  if (( remaining < 10 )); then
    echo "Free model time budget reached; retry next scheduled run."
    break
  fi
  provider_try=0
  while (( provider_try <= TRANSIENT_RETRIES )); do
    provider_try=$((provider_try + 1))
    ATTEMPT=$((ATTEMPT + 1))
    restore_attempt_baseline
    ATTEMPT_TIMEOUT="$(model_attempt_timeout "$MODEL_TIMEOUT" "$ATTEMPT" "$MODEL_PRIMARY_CAP" "$MODEL_FALLBACK_CAP")"
    ATTEMPT_TIMEOUT="$(model_timeout_after_stalls "$ATTEMPT_TIMEOUT" "$CONSECUTIVE_TIMEOUTS" 2 25)"
    remaining="$(( POOL_MAX_SECONDS - ($(date +%s) - POOL_STARTED_EPOCH) ))"
    if (( remaining < 10 )); then
      echo "Total free-model time budget exhausted."
      break 2
    fi
    if (( ATTEMPT_TIMEOUT > remaining )); then ATTEMPT_TIMEOUT="$remaining"; fi
    echo "Free coding model attempt $ATTEMPT: $model (provider try $provider_try; bounded to ${ATTEMPT_TIMEOUT}s)"

    model_started="$(date +%s)"
    set +e
    timeout "$ATTEMPT_TIMEOUT" opencode run --model "$model" --agent build "$(cat /tmp/autodev-prompt.txt)" >/tmp/autodev-model.log 2>&1
    MODEL_RC=$?
    set -e
    MODEL_SECONDS="$(( $(date +%s) - model_started ))"

    MODEL_ISSUE="$(python3 "$ROOT_DIR/scripts/free_model_pool.py" classify --log /tmp/autodev-model.log --exit-code "$MODEL_RC")"
    python3 "$ROOT_DIR/scripts/model_metrics.py" record --file "$MODEL_METRICS_FILE" --model "$model" --result attempt --seconds "$MODEL_SECONDS" --exit-code "$MODEL_RC"
    if [[ "$MODEL_ISSUE" == timeout ]]; then
      CONSECUTIVE_TIMEOUTS=$((CONSECUTIVE_TIMEOUTS + 1))
    else
      CONSECUTIVE_TIMEOUTS=0
    fi
    # Publish only fixed, sanitized classifications and elapsed time, never provider logs.
    echo "Free model outcome: $MODEL_ISSUE (exit $MODEL_RC, ${MODEL_SECONDS}s). Consecutive timeouts: $CONSECUTIVE_TIMEOUTS."
    clean_disposable_saju_artifacts
    # Never include provider's raw response: it could contain sensitive context.
    if has_durable_changes >/dev/null; then
      ATTEMPT_RESULT="source edits produced; validation pending"
    elif [[ "$MODEL_RC" -eq 124 || "$MODEL_RC" -eq 137 ]]; then
      ATTEMPT_RESULT="timeout; no durable edit"
    else
      ATTEMPT_RESULT="$MODEL_ISSUE; no durable edit"
    fi
    printf '| `%s` | %ss | %ss | %s | %s |\n' "$model" "$ATTEMPT_TIMEOUT" "$MODEL_SECONDS" "$MODEL_RC" "$ATTEMPT_RESULT" >> "$MODEL_ATTEMPT_REPORT"

    if ! DURABLE_PATHS="$(has_durable_changes)"; then
      if [[ "$MODEL_ISSUE" == auth_block || "$MODEL_ISSUE" == billing_block ]]; then
        echo "::warning::Shared OpenCode provider authentication or billing blocked; no paid fallback is allowed."
        break 2
      fi
      if [[ "$MODEL_ISSUE" == rate_limited || "$MODEL_ISSUE" == model_unavailable ]]; then
        echo "Quota-limited or unavailable free model; switching to next allowlisted free model."
        printf "\n# Previous free-model failure: %s (sanitized)\n" "$MODEL_ISSUE" >> /tmp/autodev-prompt.txt
        break
      fi
      # A timed-out worker already used its entire budget. Move to the next
      # provider rather than spending another five minutes on the same stall.
      if [[ "$MODEL_RC" -ne 0 && "$MODEL_RC" -ne 124 && "$MODEL_RC" -ne 137 ]] && is_transient_model_error /tmp/autodev-model.log && (( provider_try <= TRANSIENT_RETRIES )); then
        echo "Transient provider failure; retrying same model once."
        sleep 3
        continue
      fi
      # Provider failure transcripts are not appropriate prompts for the next
      # free model. Avoid token bloat and accidental cross-session data leakage.
      printf "\n# Previous provider result: %s, exit %s, without a code change.\n" "$MODEL_ISSUE" "$MODEL_RC" >> /tmp/autodev-prompt.txt
      break
    fi

    echo "Durable changed paths:"
    echo "$DURABLE_PATHS"

    set +e
    guard_changes >/tmp/autodev-guard.log 2>&1
    GUARD_RC=$?
    set -e
    if [[ "$GUARD_RC" -ne 0 ]]; then
      python3 "$ROOT_DIR/scripts/model_metrics.py" record --file "$MODEL_METRICS_FILE" --model "$model" --result guard_rejected --seconds "$MODEL_SECONDS" --exit-code "$MODEL_RC"
      append_feedback "change guard rejected the batch" /tmp/autodev-guard.log
      break
    fi

    VALIDATION_LOG="/tmp/autodev-attempt-validation-$ATTEMPT.log"
    if validate_attempt "$VALIDATION_LOG"; then
      clean_disposable_saju_artifacts
      SELECTED_MODEL="$model"
      if [[ "$MODEL_RC" -ne 0 ]]; then
        SELECTED_MODEL="salvaged:$model"
      fi
      cp "$VALIDATION_LOG" /tmp/autodev-final-validation.log
      echo "0" > /tmp/autodev-final-rc
      python3 "$ROOT_DIR/scripts/model_metrics.py" record --file "$MODEL_METRICS_FILE" --model "$model" --result validated --seconds "$MODEL_SECONDS" --exit-code "$MODEL_RC"
      echo "Validated model batch accepted: $SELECTED_MODEL"
      break 2
    else
      FINAL_RC=$?
      echo "$FINAL_RC" > /tmp/autodev-final-rc
      cp "$VALIDATION_LOG" /tmp/autodev-final-validation.log
      python3 "$ROOT_DIR/scripts/model_metrics.py" record --file "$MODEL_METRICS_FILE" --model "$model" --result validation_failed --seconds "$MODEL_SECONDS" --exit-code "$MODEL_RC"
      append_feedback "validation failed after model $model" "$VALIDATION_LOG"
      echo "Validation failed for $model; rolling back before the next model."
      break
    fi
  done
done

if [[ -z "$SELECTED_MODEL" ]]; then
  restore_attempt_baseline
  echo "All free model attempts were exhausted without a validated batch."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo '## Free-model development attempts — no accepted code change'
      cat "$MODEL_ATTEMPT_REPORT"
      echo
      echo 'Workflow success (with a healthy baseline) does not imply code generation.'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  echo "BATCH_READY=false" >> "$GITHUB_ENV"
  echo "AUTODEV_FAILURE_REASON=model_pool_exhausted" >> "$GITHUB_ENV"
  if [[ "$BASELINE_RC" -ne 0 ]]; then
    echo "AUTODEV_RUN_STATUS=failed" >> "$GITHUB_ENV"
    echo "Baseline was already failing, so provider exhaustion remains a hard failure."
    exit 1
  fi
  echo "AUTODEV_RUN_STATUS=provider_unavailable" >> "$GITHUB_ENV"
  echo "::warning::Free coding providers were unavailable; baseline remains healthy and no source change was accepted."
  {
    echo "## Provider unavailable — baseline healthy"
    echo ""
    echo "All free coding providers failed or timed out. The target baseline still validates, partial edits were discarded, and no production change was made."
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

echo "$SELECTED_MODEL" >/tmp/autodev-selected-model
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '## Free-model development attempts — validated candidate'
    cat "$MODEL_ATTEMPT_REPORT"
    echo
    printf 'Validated coding model: `%s`. Push/PR is a separate release gate.\n' "$SELECTED_MODEL"
  } >> "$GITHUB_STEP_SUMMARY"
fi

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
