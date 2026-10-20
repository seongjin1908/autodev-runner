#!/usr/bin/env bash
# Optional independent Gemini CLI fallback. Never run on unverified/free-tier accounts.
# This step is separate from OpenCode and receives the API key only for this step.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${AUTODEV_GEMINI_FREE_ENABLED:-false}" != "true" ]]; then
  echo "Gemini free fallback is disabled; no Gemini API requests made."
  exit 0
fi
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "::warning::Gemini fallback was opted in but its secret is absent; skipping."
  exit 0
fi
if [[ "${BATCH_READY:-false}" == "true" || "${SKIP_TARGET:-false}" == "true" ]]; then
  echo "Skip fallback: existing code batch is already ready or target is on hold."
  exit 0
fi
if [[ -z "${START_SHA:-}" || -z "${VALIDATION_B64:-}" || -z "${MAX_CHANGED_FILES:-}" ]]; then
  echo "::error::Gemini fallback missing protected worker context; no API request made."
  exit 2
fi
# Explicit free-tier model only; do not accept arbitrary CLI/paid model overrides.
GEMINI_MODEL="${AUTODEV_GEMINI_FREE_MODEL:-gemini-2.5-flash}"
case "$GEMINI_MODEL" in
  gemini-2.5-flash|gemini-2.5-flash-lite) ;;
  *) echo "::error::Unapproved Gemini model; refusing API request."; exit 2 ;;
esac
cd "$ROOT_DIR/target"
# Primary provider did not produce validated code. Before any Gemini request,
# safely restore the immutable start commit in this ephemeral Actions checkout.
# Unknown workspace policy/credential files or a different HEAD still fail closed.
if ! bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"; then
  echo "::warning::Gemini fallback blocked because handoff could not be validated."
  exit 0
fi
# A headless trust override is safe only if this target cannot supply
# workspace-level Gemini configuration, hooks, extensions, or MCP policies.
# Refuse instead of implicitly trusting unreviewed repository instructions.
if [[ -e .gemini || -e .mcp.json || -e .env || -e "$ROOT_DIR/.gemini" ]]; then
  echo "::warning::Gemini fallback blocked: project/parent Gemini config or local environment detected. No model request made."
  exit 0
fi
if [[ ! -s /tmp/autodev-prompt.txt ]]; then
  echo "::error::Missing validated worker prompt; refusing Gemini API request."
  exit 2
fi
# Install from the trusted control plane, with the key removed from npm's environment.
cd "$ROOT_DIR"
if ! env -u GEMINI_API_KEY -u GOOGLE_API_KEY npm install --cache "${RUNNER_TEMP:-/tmp}/autodev-public-cli-npm-cache" -g @google/gemini-cli --no-audit --no-fund --ignore-scripts >/tmp/autodev-gemini-install.log 2>&1; then
  echo "::warning::Gemini CLI could not be installed; no source changes accepted."
  exit 0
fi
if ! command -v gemini >/dev/null 2>&1; then
  echo "::warning::Gemini binary unavailable after installation."
  exit 0
fi
# Separate clean HOME prevents reuse of ambient credentials/extensions. Allow only
# read/write operations, never CLI shell execution, MCP plugins, or blanket YOLO mode.
SAFE_HOME="$(mktemp -d)"
mkdir -p "$SAFE_HOME/.gemini"
cat > "$SAFE_HOME/.gemini/settings.json" <<'SETTINGS'
{
  "general": {"enableAutoUpdate": false},
  "security": {"folderTrust": {"enabled": true}, "disableYoloMode": true},
  "hooksConfig": {"enabled": false},
  "tools": {"core": ["read_file", "write_file", "replace", "list_directory", "glob", "grep_search"]}
}
SETTINGS
# Fail before sending private source or spending free API quota if this installed
# Gemini CLI cannot read the generated settings, options or clean HOME.
# Extension listing performs a local CLI configuration load and makes no model request.
if ! env -u GEMINI_API_KEY -u GOOGLE_API_KEY HOME="$SAFE_HOME" timeout 20s gemini \
  --skip-trust --extensions none --list-extensions \
  >/tmp/autodev-gemini-configcheck.log 2>&1; then
  CHECK_ISSUE="$(python3 "$ROOT_DIR/scripts/gemini_failure.py" classify --log /tmp/autodev-gemini-configcheck.log --exit-code 1)"
  rm -rf -- "$SAFE_HOME"
  echo "::warning::Gemini local CLI configuration check failed ($CHECK_ISSUE); no API request made."
  exit 0
fi
echo "Gemini CLI local configuration check passed (no API call)."
# The model needs enough time for useful edits but must never consume all CI time.
GEMINI_TIMEOUT_SECONDS=180
echo "Starting opt-in Gemini free-tier fallback: $GEMINI_MODEL (bounded to ${GEMINI_TIMEOUT_SECONDS}s)."
cd "$ROOT_DIR/target"
set +e
HOME="$SAFE_HOME" timeout "$GEMINI_TIMEOUT_SECONDS" gemini \
  --skip-trust \
  --model "$GEMINI_MODEL" \
  --approval-mode auto_edit \
  --extensions none \
  --prompt "$(head -c 30000 /tmp/autodev-prompt.txt)" \
  >/tmp/autodev-gemini-run.log 2>&1
GEMINI_RC=$?
set -e
unset GEMINI_API_KEY
rm -rf -- "$SAFE_HOME"
GEMINI_ISSUE="$(python3 "$ROOT_DIR/scripts/gemini_failure.py" classify --log /tmp/autodev-gemini-run.log --exit-code "$GEMINI_RC")"
echo "Gemini command finished (exit $GEMINI_RC; classified: $GEMINI_ISSUE). Private model transcript not published."
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf "\n### Gemini free fallback\n- Exit status: %s\n- Fixed diagnostic: %s\n" "$GEMINI_RC" "$GEMINI_ISSUE" >> "$GITHUB_STEP_SUMMARY"
fi
# The key is no longer in the worker environment for all validation/build steps.
restore_clean() {
  git reset --hard "$START_SHA" >/dev/null
  git clean -fd -e node_modules/ >/dev/null
}
if [[ -z "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "Gemini fallback produced no file edits; do not mark as development."
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
    if path.startswith(".github/") or path.startswith(".gemini/") or path.startswith(".env"):
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
print("Gemini candidate passed protected changed-file and source-code gate.")
PY
then
  echo "::warning::Gemini candidate was rejected by source-file safety gate."
  restore_clean
  exit 0
fi
if ! git diff --check >/tmp/autodev-gemini-diffcheck.log 2>&1; then
  echo "::warning::Gemini diff failed whitespace check; discarding."
  restore_clean
  exit 0
fi
# Reinstall only if dependency manifest changed, without exposing the API key.
if ! git diff --quiet HEAD -- package.json package-lock.json pnpm-lock.yaml requirements.txt; then
  if [[ -f package-lock.json ]]; then
    if ! npm ci --no-audit --no-fund >/tmp/autodev-gemini-deps.log 2>&1; then
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
if ! env -u GEMINI_API_KEY -u GOOGLE_API_KEY bash -lc "$VALIDATION" >/tmp/autodev-gemini-validation.log 2>&1; then
  echo "::warning::Gemini candidate failed existing product validation; discarding."
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
git commit -m "autodev: validated Gemini free fallback for ${ALIAS:-target}" >/tmp/autodev-gemini-commit.log 2>&1
echo "BATCH_READY=true" >> "$GITHUB_ENV"
echo "AUTODEV_RUN_STATUS=success" >> "$GITHUB_ENV"
echo "AUTODEV_FAILURE_REASON=none" >> "$GITHUB_ENV"
echo "Gemini free-tier fallback produced a validated source commit; PR push remains separately guarded."
