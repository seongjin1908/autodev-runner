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
assert core["auto_enabled"] and core["auto_weight"] > 0, "user-authorized parallel launch lane must be active"
assert core.get("external_worker_lock") is False, "separate Codex is a peer, not an exclusive lock"
assert core["work_branch"].startswith("autodev/saju-core/"), "must not write directly to release branch"
global_lane=next(p for p in config["projects"] if p["alias"]=="saju-global")
assert global_lane["auto_enabled"] and global_lane["auto_weight"] > 0
assert global_lane.get("external_worker_lock") is False
assert global_lane["base_branch"]==global_lane["source_branch"]=="autodev-v12"
assert global_lane["branch_mode"]=="run_scoped"
assert global_lane["work_branch"].startswith("autodev/saju-global/")
for held in ("jjin","motion-grid","tradepilot"):
    p=next(p for p in config["projects"] if p["alias"]==held)
    assert not p["auto_enabled"] and p.get("development_status")=="hold", f"{held} HOLD must remain intact"
assert "production-contract-check.mjs" in core["validation"]
assert "vite-release-test.mjs" in core["validation"]
assert core["recent_change_guard_minutes"]>=10
print("PASS: release lane current branch, parallel isolated PR ownership, conservative baseline")
PY
ROOT_DIR_OUTPUT="$(mktemp)"
trap 'rm -f "$ROOT_DIR_OUTPUT"' EXIT
TARGET=saju-core GITHUB_OUTPUT="$ROOT_DIR_OUTPUT" bash "$ROOT/scripts/select_target.sh" >/dev/null
grep -q '^base_branch=release/unkive-production-1791471961339$' "$ROOT_DIR_OUTPUT"
grep -q '^checkout_branch=release/unkive-production-1791471961339$' "$ROOT_DIR_OUTPUT"
echo 'PASS: current release target selection'
