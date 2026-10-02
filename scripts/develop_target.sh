#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/target"

VALIDATION="$(python - "$VALIDATION_B64" <<'PY'
import base64,sys
print(base64.b64decode(sys.argv[1]).decode())
PY
)"

# Dependency install and all target code execute without the cross-repository token.
if [[ -f package-lock.json ]]; then
  npm ci >/tmp/autodev-install.log 2>&1
else
  npm install --no-package-lock --no-audit --no-fund >/tmp/autodev-install.log 2>&1
fi

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
  cat "$ROOT_DIR/$PROMPT_FILE"
  echo
  cat <<'RULES'
# Global execution rules
- Work only inside the checked-out target repository.
- If baseline validation failed, fix the actual root cause before adding features.
- Make a coherent batch, not a cosmetic one-line change.
- Prefer existing architecture, helpers, tests, and deterministic code.
- Do not modify .github workflows, secrets, credential files, or environment files.
- Do not add paid AI, paid APIs, billing, live production payment, or automatic production deploy.
- Do not auto-merge.
- Do not fabricate passing tests, live integration success, analytics, prices, or progress.
- Keep the batch small enough to review and large enough to create real user value.
RULES
  echo
  echo "# Baseline validation output"
  cat /tmp/autodev-baseline.log
} >/tmp/autodev-prompt.txt

PRIMARY_MODEL="${DDD_FREE_CODE_MODEL_PRIMARY:-opencode/mimo-v2.5-free}"
SECONDARY_MODEL="${DDD_FREE_CODE_MODEL_SECONDARY:-opencode/longcat-2.0-free}"
TERTIARY_MODEL="${DDD_FREE_CODE_MODEL_TERTIARY:-opencode/nemotron-3-ultra-free}"
QUATERNARY_MODEL="${DDD_FREE_CODE_MODEL_QUATERNARY:-opencode/north-mini-code-free}"
MODEL_TIMEOUT="${DDD_FREE_MODEL_TIMEOUT_SECONDS:-540}"

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

reset_generated_artifacts() {
  rm -rf node_modules dist coverage .astro
  find . -type d -name __pycache__ -prune -exec rm -rf {} + >/dev/null 2>&1 || true
  find . -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete >/dev/null 2>&1 || true
  git restore --worktree --staged -- dist coverage .astro 2>/dev/null || true
}

: >/tmp/autodev-selected-model
ATTEMPT=0
for model in "$PRIMARY_MODEL" "$SECONDARY_MODEL" "$TERTIARY_MODEL" "$QUATERNARY_MODEL"; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Free coding model attempt $ATTEMPT: $model"
  if timeout "$MODEL_TIMEOUT" opencode run --model "$model" --agent build "$(cat /tmp/autodev-prompt.txt)" >/tmp/autodev-model.log 2>&1; then
    if DURABLE_PATHS="$(has_durable_changes)"; then
      echo "$model" >/tmp/autodev-selected-model
      echo "Free coding model completed with durable source changes: $model"
      echo "Durable changed paths:"
      echo "$DURABLE_PATHS"
      break
    fi
    echo "Model exited successfully but produced only generated/build artifacts: $model"
    reset_generated_artifacts
    {
      echo
      echo "# Retry feedback"
      echo "The previous coding attempt exited successfully but did not change any durable source or test file."
      echo "Do not stop at analysis, build output, generated dist files, or status text."
      echo "Implement the highest incomplete target-specific P0/P1 blocker in real source code and add/update a regression test."
    } >> /tmp/autodev-prompt.txt
  else
    RC=$?
    echo "Free model attempt failed (exit $RC): $model"
    echo "---- model log tail ----"
    tail -n 40 /tmp/autodev-model.log || true
    echo "---- end model log tail ----"
  fi
done

if [[ ! -s /tmp/autodev-selected-model ]]; then
  if DURABLE_PATHS="$(has_durable_changes)"; then
    echo "All free model processes failed or timed out, but durable source changes remain."
    echo "Attempting one salvage validation before discarding the batch."
    set +e
    bash -lc "$VALIDATION" >/tmp/autodev-salvage-validation.log 2>&1
    SALVAGE_RC=$?
    set -e
    if [[ "$SALVAGE_RC" -eq 0 ]]; then
      echo "salvaged-free-model" >/tmp/autodev-selected-model
      echo "Salvage validation passed; preserving durable changes."
      echo "$DURABLE_PATHS"
    else
      echo "Salvage validation failed; no branch push will occur."
      tail -n 80 /tmp/autodev-salvage-validation.log || true
      echo "BATCH_READY=false" >> "$GITHUB_ENV"
      echo "AUTODEV_MODEL_BLOCKED=true" >> "$GITHUB_ENV"
      exit 1
    fi
  else
    echo "No free model produced durable source changes. Paid fallback is disabled; next scheduled run will retry."
    echo "BATCH_READY=false" >> "$GITHUB_ENV"
    echo "AUTODEV_MODEL_BLOCKED=true" >> "$GITHUB_ENV"
    exit 1
  fi
fi

python - "$MAX_CHANGED_FILES" <<'PY'
import subprocess,sys
limit=int(sys.argv[1])
lines=subprocess.check_output(['git','status','--porcelain'], text=True).splitlines()
paths=[]
for line in lines:
    p=line[3:]
    if ' -> ' in p:
        p=p.split(' -> ',1)[1]
    paths.append(p)
blocked=[]
for p in paths:
    low=p.lower()
    if p.startswith('.github/') or p.startswith('.env') or '/.env' in p or low.endswith('.pem') or low.endswith('.key') or 'secret' in low:
        blocked.append(p)
if blocked:
    raise SystemExit('Guard blocked sensitive/workflow changes.')
if len(paths) > limit:
    raise SystemExit(f'Guard blocked oversized batch: {len(paths)} files > {limit}.')
print(f'Guard passed: {len(paths)} changed files.')
PY

git diff --check >/tmp/autodev-diffcheck.log 2>&1

if git diff --name-only -- package.json package-lock.json | grep -q .; then
  if [[ -f package-lock.json ]]; then
    npm ci >/tmp/autodev-reinstall.log 2>&1
  else
    npm install --no-package-lock --no-audit --no-fund >/tmp/autodev-reinstall.log 2>&1
  fi
else
  echo "Dependency manifests unchanged; reuse installed dependencies." >/tmp/autodev-reinstall.log
fi

set +e
bash -lc "$VALIDATION" >/tmp/autodev-final-validation.log 2>&1
FINAL_RC=$?
set -e
echo "$FINAL_RC" > /tmp/autodev-final-rc
if [[ "$FINAL_RC" -ne 0 ]]; then
  echo "Final validation failed. No private branch push will occur."
  echo "BATCH_READY=false" >> "$GITHUB_ENV"
  echo "AUTODEV_FAILED=true" >> "$GITHUB_ENV"
  exit 1
fi

git diff --check >/tmp/autodev-final-diffcheck.log 2>&1

rm -rf node_modules dist coverage .astro
find . -type d -name __pycache__ -prune -exec rm -rf {} + >/dev/null 2>&1 || true
find . -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete >/dev/null 2>&1 || true

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Validated successfully; no durable source changes were produced."
  echo "BATCH_READY=false" >> "$GITHUB_ENV"
  echo "AUTODEV_NO_DURABLE_CHANGE=true" >> "$GITHUB_ENV"
  exit 0
fi

git config user.name "central-autodev-runner"
git config user.email "central-autodev-runner@users.noreply.github.com"
git add -A
git commit -m "autodev: complete $ALIAS batch" >/tmp/autodev-commit.log 2>&1
echo "BATCH_READY=true" >> "$GITHUB_ENV"
echo "Validated batch is ready for guarded push."
