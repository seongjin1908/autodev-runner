#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/config/projects.json"

if [[ -z "${AUTODEV_REPO_TOKEN:-}" ]]; then
  echo "AUTODEV_REPO_TOKEN is not configured. Runner stays safely idle."
  exit 0
fi

TARGET="${TARGET:-auto}"
PROJECT_COUNT="$(python - "$CONFIG" <<'PY'
import json,sys
print(len(json.load(open(sys.argv[1], encoding='utf-8'))['projects']))
PY
)"

if [[ "$TARGET" == "auto" ]]; then
  INDEX="$((10#$(date -u +%H) % PROJECT_COUNT))"
  TARGET="$(python - "$CONFIG" "$INDEX" <<'PY'
import json,sys
data=json.load(open(sys.argv[1], encoding='utf-8'))['projects']
print(data[int(sys.argv[2])]['alias'])
PY
)"
fi

project_json="$(python - "$CONFIG" "$TARGET" <<'PY'
import json,sys
projects=json.load(open(sys.argv[1], encoding='utf-8'))['projects']
for p in projects:
    if p['alias'] == sys.argv[2]:
        print(json.dumps(p))
        break
else:
    raise SystemExit(f"Unknown target: {sys.argv[2]}")
PY
)"

eval "$(PROJECT_JSON="$project_json" python - <<'PY'
import json,os,shlex
p=json.loads(os.environ['PROJECT_JSON'])
for key in ['alias','repository','work_branch','base_branch','validation','prompt_file','recent_change_guard_minutes','max_changed_files']:
    print(f"{key.upper()}={shlex.quote(str(p[key]))}")
PY
)"

echo "Selected target: $ALIAS"
echo "Repository: $REPOSITORY"
echo "Work branch: $WORK_BRANCH -> $BASE_BRANCH"

export GH_TOKEN="$AUTODEV_REPO_TOKEN"
gh auth setup-git >/dev/null

rm -rf "$ROOT_DIR/target"
gh repo clone "$REPOSITORY" "$ROOT_DIR/target" -- --filter=blob:none
cd "$ROOT_DIR/target"

git fetch origin "$BASE_BRANCH" "$WORK_BRANCH" --prune
if git show-ref --verify --quiet "refs/remotes/origin/$WORK_BRANCH"; then
  git switch -C "$WORK_BRANCH" "origin/$WORK_BRANCH"
else
  git switch -C "$WORK_BRANCH" "origin/$BASE_BRANCH"
fi

START_SHA="$(git rev-parse HEAD)"
LAST_EPOCH="$(git log -1 --format=%ct)"
NOW_EPOCH="$(date +%s)"
AGE_MINUTES="$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))"
if (( AGE_MINUTES < RECENT_CHANGE_GUARD_MINUTES )); then
  echo "Branch changed $AGE_MINUTES minutes ago; skip to avoid colliding with another worker."
  exit 0
fi

if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install --no-package-lock --no-audit --no-fund
fi

set +e
bash -lc "$VALIDATION" > /tmp/autodev-baseline.log 2>&1
BASELINE_RC=$?
set -e

echo "Baseline validation exit code: $BASELINE_RC"

npm install -g opencode-ai

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
} > /tmp/autodev-prompt.txt

PRIMARY_MODEL="${DDD_FREE_CODE_MODEL_PRIMARY:-opencode/north-mini-code-free}"
SECONDARY_MODEL="${DDD_FREE_CODE_MODEL_SECONDARY:-opencode/deepseek-v4-flash-free}"
TERTIARY_MODEL="${DDD_FREE_CODE_MODEL_TERTIARY:-opencode/big-pickle}"

: > /tmp/autodev-selected-model
for model in "$PRIMARY_MODEL" "$SECONDARY_MODEL" "$TERTIARY_MODEL"; do
  echo "Trying free model: $model"
  if timeout 1500 opencode run --model "$model" --agent build "$(cat /tmp/autodev-prompt.txt)"; then
    echo "$model" > /tmp/autodev-selected-model
    break
  fi
done

if [[ ! -s /tmp/autodev-selected-model ]]; then
  echo "No free model completed. Paid fallback is disabled."
  exit 0
fi

python - "$MAX_CHANGED_FILES" <<'PY'
from pathlib import Path
import subprocess, sys
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
    raise SystemExit('Blocked sensitive/workflow changes: ' + ', '.join(blocked))
if len(paths) > limit:
    raise SystemExit(f'Too many changed files: {len(paths)} > {limit}')
print(f'Guard passed for {len(paths)} changed files.')
PY

git diff --check

if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install --no-package-lock --no-audit --no-fund
fi
bash -lc "$VALIDATION"
git diff --check

rm -rf node_modules dist coverage .astro
find . -type d -name __pycache__ -prune -exec rm -rf {} + || true
find . -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete || true

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Validated but no source changes were produced."
  exit 0
fi

git fetch origin "$WORK_BRANCH" --prune || true
REMOTE_SHA="$(git rev-parse "origin/$WORK_BRANCH" 2>/dev/null || true)"
if [[ -n "$REMOTE_SHA" && "$REMOTE_SHA" != "$START_SHA" ]]; then
  echo "Remote branch advanced during this run. Abort push to avoid overwriting concurrent work."
  exit 0
fi

git config user.name "central-autodev-runner"
git config user.email "central-autodev-runner@users.noreply.github.com"
git add -A
git commit -m "autodev: complete $ALIAS batch"
git push origin "HEAD:$WORK_BRANCH"

existing="$(gh pr list -R "$REPOSITORY" --state open --head "$WORK_BRANCH" --base "$BASE_BRANCH" --json url --jq '.[0].url // empty')"
if [[ -n "$existing" ]]; then
  echo "Updated existing PR: $existing"
else
  model="$(cat /tmp/autodev-selected-model)"
  gh pr create -R "$REPOSITORY" --base "$BASE_BRANCH" --head "$WORK_BRANCH"     --title "autodev: $ALIAS development batch"     --body "Central zero-budget AutoDev batch.

- Free model: $model
- Baseline checked
- Final validation passed
- Protected workflow/secret guard passed
- Paid fallback: disabled
- Auto-merge: disabled
- Production deploy: not performed"
fi

echo "AutoDev batch completed for $ALIAS."
