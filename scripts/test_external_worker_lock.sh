#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GITHUB_OUTPUT="$tmp/output"
export GITHUB_ENV="$tmp/env"
: > "$GITHUB_OUTPUT"
: > "$GITHUB_ENV"

TARGET=saju-core GITHUB_RUN_ID=999 GITHUB_RUN_ATTEMPT=1 bash scripts/select_target.sh >/dev/null
grep -q '^external_worker_lock=true$' "$GITHUB_OUTPUT"
grep -q '^external_worker_owner=codex-separate-chat$' "$GITHUB_OUTPUT"

EXTERNAL_WORKER_LOCK=true \
EXTERNAL_WORKER_OWNER=codex-separate-chat \
EXTERNAL_WORKER_SCOPE='UNKIVE KR release hardening' \
BRANCH_MODE=run_scoped \
MAX_BRANCH_AHEAD=0 \
GH_TOKEN='' \
REPOSITORY=seongjin1908/daangn-saju-autodev \
BASE_BRANCH=release/unkive-production-1791471961339 \
WORK_BRANCH=autodev/test-lock \
RECENT_CHANGE_GUARD_MINUTES=15 \
FAILURE_HOLD_THRESHOLD=2 \
FAILURE_HOLD_MINUTES=45 \
bash scripts/prepare_target.sh >/tmp/external-lock.log 2>&1 || true

grep -q '^SKIP_TARGET=true$' "$GITHUB_ENV"
grep -q '^AUTODEV_SKIP_REASON=external_worker_lock$' "$GITHUB_ENV"
grep -q 'Target is owned by external worker' /tmp/external-lock.log

echo "PASS: external Codex single-writer lock blocks autonomous UNKIVE edits while preserving schedule entry"
