#!/usr/bin/env bash
# Manual-only zero-priced OpenRouter agent fallback. No paid models, auto-merge or deployment.
# This step is separate from OpenCode and receives the API key only for this step.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${AUTODEV_OPENROUTER_FREE_ENABLED:-false}" != "true" ]]; then
  echo "OpenRouter free fallback is disabled; no OpenRouter API requests made."
  exit 0
fi
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "::warning::OpenRouter fallback was opted in but its secret is absent; skipping."
  exit 0
fi
if [[ "${BATCH_READY:-false}" == "true" || "${SKIP_TARGET:-false}" == "true" ]]; then
  echo "Skip fallback: existing code batch is already ready or target is on hold."
  exit 0
fi
if [[ -z "${START_SHA:-}" || -z "${VALIDATION_B64:-}" || -z "${MAX_CHANGED_FILES:-}" ]]; then
  echo "::error::OpenRouter fallback missing protected worker context; no API request made."
  exit 2
fi
# Explicit free-tier model only; do not accept arbitrary CLI/paid model overrides.
OPENROUTER_MODEL="${AUTODEV_OPENROUTER_FREE_MODEL:-openrouter/minimax/minimax-m3.1-flash:free}"
case "$OPENROUTER_MODEL" in
  openrouter/minimax/minimax-m3.1-flash:free|openrouter/cohere/north-mini-code:free|openrouter/qwen/qwen3-coder:free) ;;
  *) echo "::error::Unapproved OpenRouter model; refusing API request."; exit 2 ;;
esac
cd "$ROOT_DIR/target"
# Primary provider did not produce validated code. Before any OpenRouter request,
# safely restore the immutable start commit in this ephemeral Actions checkout.
# Unknown workspace policy/credential files or a different HEAD still fail closed.
if ! bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"; then
  echo "::warning::OpenRouter fallback blocked because handoff could not be validated."
  exit 0
fi
# A headless trust override is safe only if this target cannot supply
# workspace-level OpenRouter configuration, hooks, extensions, or MCP policies.
# Refuse instead of implicitly trusting unreviewed repository instructions.
if [[ -e .openrouter || -e .mcp.json || -e .env || -e "$ROOT_DIR/.openrouter" ]]; then
  echo "::warning::OpenRouter fallback blocked: project/parent OpenRouter config or local environment detected. No model request made."
  exit 0
fi
if [[ ! -s /tmp/autodev-prompt.txt ]]; then
  echo "::error::Missing validated worker prompt; refusing OpenRouter API request."
  exit 2
fi
# Already-installed OpenCode CLI, with provider credentials isolated from npm and baseline tests.
if ! command -v opencode >/dev/null 2>&1; then
  echo "::warning::OpenCode CLI unavailable; no free provider call."
  exit 0
fi
if [[ -e .opencode || -e opencode.json || -e opencode.jsonc || -e .agents || -e .env.local ]]; then
  echo "::warning::Unreviewed local agent/provider config detected; free model blocked."
  exit 0
fi
ORIGINAL_HOME="$HOME"
SAFE_HOME="$(mktemp -d)"
export HOME="$SAFE_HOME" XDG_DATA_HOME="$SAFE_HOME/data" XDG_CONFIG_HOME="$SAFE_HOME/config"
export OPENCODE_DISABLE_AUTOUPDATE=true
# Runtime inline permissions: local read/edit only, no shell, network or outside access.
export OPENCODE_CONFIG_CONTENT='{"permission":{"*":"deny","read":"allow","glob":"allow","grep":"allow","edit":"allow","bash":"deny","task":"deny","webfetch":"deny","websearch":"deny","external_directory":"deny"}}'
OPENROUTER_TIMEOUT_SECONDS=140
echo "Starting isolated OpenRouter $0-cost model: $OPENROUTER_MODEL (140s cap)."
set +e
timeout "$OPENROUTER_TIMEOUT_SECONDS" opencode run --model "$OPENROUTER_MODEL" --agent build "$(head -c 30000 /tmp/autodev-prompt.txt)" >/tmp/autodev-openrouter-run.log 2>&1
OPENROUTER_RC=$?
set -e
unset OPENROUTER_API_KEY OPENCODE_CONFIG_CONTENT
export HOME="$ORIGINAL_HOME"
rm -rf -- "$SAFE_HOME"
OPENROUTER_ISSUE="$(python3 "$ROOT_DIR/scripts/free_model_pool.py" classify --log /tmp/autodev-openrouter-run.log --exit-code "$OPENROUTER_RC")"
echo "OpenRouter free model finished (exit $OPENROUTER_RC; classified: $OPENROUTER_ISSUE). Private transcript withheld."
restore_clean() {
  git reset --hard "$START_SHA" >/dev/null
  git clean -fd -e node_modules/ >/dev/null
}
if [[ "$OPENROUTER_ISSUE" == auth_block || "$OPENROUTER_ISSUE" == billing_block ]]; then
  echo "::warning::Provider account unusable or billing blocked; refusing model edits."
  restore_clean
  exit 0
fi
if [[ -z "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "OpenRouter fallback produced no file edits; do not mark as development."
  exit 0
fi
if ! python3 - "$MAX_CHANGED_FILES" <<'PY'
from pathlib import Path
import subprocess, sys
limit=int(sys.argv[1])
paths=set()
for args in (
    ["git","diff","--name-only","-z"],
    ["git","diff","--cached","--name-only","-z"],
    ["git","ls-files","--others","--exclude-standard","-z"],
):
    data=subprocess.check_output(args)
    paths.update(p.decode("utf-8","surrogateescape") for p in data.split(b"\x00") if p)
assert 0<len(paths)<=limit, "No durable changes or too many changed files"
code_exts={".js",".jsx",".ts",".tsx",".mjs",".cjs",".py",".go",".rs",".java",".kt",".swift",".vue",".svelte",".html",".css",".sql"}
def allowed(path):
    lower=path.lower()
    if path in (".mcp.json","opencode.json","opencode.jsonc") or path.startswith((".github/",".openrouter/",".opencode/",".agents/",".codex/")) or path.startswith(".env"):
        return False
    if "/.env" in path or "secret" in lower or lower.endswith((".pem",".key",".p12")):
        return False
    if path.startswith(("dist/","node_modules/","coverage/")):
        return False
    return True
assert all(allowed(p) for p in paths), "Sensitive files or generated files edited"
assert any(Path(p).suffix.lower() in code_exts
           and not p.startswith(("tests/","test/","docs/"))
           and not Path(p).name.startswith(("test_","spec_"))
           for p in paths), "No application code changes; reject docs/test-only PR"
print("OpenRouter candidate passed protected changed-file and source-code gate.")
PY
then
  echo "::warning::OpenRouter candidate was rejected by source-file safety gate."
  restore_clean
  exit 0
fi
if ! git diff --check >/tmp/autodev-openrouter-diffcheck.log 2>&1; then
  echo "::warning::OpenRouter diff failed whitespace check; discarding."
  restore_clean
  exit 0
fi
# Reinstall only if dependency manifest changed, without exposing the API key.
if ! git diff --quiet HEAD -- package.json package-lock.json pnpm-lock.yaml requirements.txt; then
  if [[ -f package-lock.json ]]; then
    if ! env -u OPENROUTER_API_KEY npm ci --no-audit --no-fund >/tmp/autodev-openrouter-deps.log 2>&1; then
      echo "::warning::Changed dependency manifest failed install."
      restore_clean
      exit 0
    fi
  fi
fi
VALIDATION="$(python3 - "$VALIDATION_B64" <<'PY'
import base64, sys
print(base64.b64decode(sys.argv[1],validate=True).decode("utf-8"))
PY
)"
if ! env -u OPENROUTER_API_KEY -u GEMINI_API_KEY -u GOOGLE_API_KEY bash -lc "$VALIDATION" >/tmp/autodev-openrouter-validation.log 2>&1; then
  echo "::warning::OpenRouter candidate failed existing product validation; discarding."
  restore_clean
  exit 0
fi
if ! git diff --check >/dev/null 2>&1; then
  restore_clean
  exit 0
fi
git config user.name "central-autodev-runner"
git config user.email "central-autodev-runner@users.noreply.github.com"
git add -A
git commit -m "autodev: validated OpenRouter free fallback for ${ALIAS:-target}" >/tmp/autodev-openrouter-commit.log 2>&1
echo "BATCH_READY=true" >> "$GITHUB_ENV"
echo "AUTODEV_RUN_STATUS=success" >> "$GITHUB_ENV"
echo "AUTODEV_FAILURE_REASON=none" >> "$GITHUB_ENV"
echo "OpenRouter free-tier fallback produced a validated source commit; PR push remains separately guarded."
