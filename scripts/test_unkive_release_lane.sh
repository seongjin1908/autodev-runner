#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT/config/projects.json" <<'PY'
import json,sys
config=json.load(open(sys.argv[1],encoding="utf-8"))
core=next(p for p in config["projects"] if p["alias"]=="saju-core")
assert core["base_branch"]==core["source_branch"]=="release/unkive-production-1791471961339"
assert core["prompt_file"]=="prompts/saju-launch.md"
assert core["branch_mode"]=="run_scoped"
assert not core["auto_enabled"] and core["auto_weight"]==0, "hourly launch sprint must be the single writer"
assert "production-contract-check.mjs" in core["validation"]
assert "vite-release-test.mjs" in core["validation"]
assert core["recent_change_guard_minutes"]>=10
print("PASS: release lane current branch, isolated hourly ownership, conservative baseline")
PY
ROOT_DIR_OUTPUT="$(mktemp)"
trap 'rm -f "$ROOT_DIR_OUTPUT"' EXIT
TARGET=saju-core GITHUB_OUTPUT="$ROOT_DIR_OUTPUT" bash "$ROOT/scripts/select_target.sh" >/dev/null
grep -q '^base_branch=release/unkive-production-1791471961339$' "$ROOT_DIR_OUTPUT"
grep -q '^checkout_branch=release/unkive-production-1791471961339$' "$ROOT_DIR_OUTPUT"
echo 'PASS: current release target selection'
