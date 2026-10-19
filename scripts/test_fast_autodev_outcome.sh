#!/usr/bin/env bash
# Prevent no-code green results and stale free-model defaults in specialized lanes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for name, alias in (
    ("creative-studio-fast-autodev.yml", "creative-studio"),
    ("saju-global-fast-autodev.yml", "saju-global"),
):
    text = (root / ".github" / "workflows" / name).read_text(encoding="utf-8")
    assert "TARGET: " + alias in text, name
    assert "DDD_FREE_CODE_MODEL_PRIMARY: ${{ vars.DDD_FREE_CODE_MODEL_PRIMARY || 'opencode/space-bunny-free' }}" in text, name
    assert "DDD_FREE_CODE_MODEL_SENARY: ${{ vars.DDD_FREE_CODE_MODEL_SENARY || 'opencode/mimo-v2.6-flash-free' }}" in text, name
    assert "DDD_FREE_MODEL_TRANSIENT_RETRIES: ${{ vars.DDD_FREE_MODEL_TRANSIENT_RETRIES || '0' }}" in text, name
    assert "Require configured repository token" in text, name
    assert "if: steps.token.outputs.configured != 'true'" in text, name
    marker = "      - name: Require validated code production"
    push = "      - name: Push validated batch and maintain PR"
    assert text.count(marker) == 1, name
    assert text.index(marker) < text.index(push), name
    assert "if: always() && steps.token.outputs.configured == 'true' && env.SKIP_TARGET != 'true'" in text, name
    assert text.count("run: bash scripts/require_production_batch.sh") == 1, name
    assert "env.BATCH_READY == 'true'" in text, name
    print(f"PASS: {alias} reports only validated coding, zero-cost fallback, guarded push")

# Keep the launch-critical saju-core job aligned with the central, tested,
# free-only model policy and the no-false-success contract.
launch = (root / ".github" / "workflows" / "launch-sprint.yml").read_text(encoding="utf-8")
assert "target: [saju-core]" in launch
assert "DDD_FREE_CODE_MODEL_PRIMARY: ${{ vars.DDD_FREE_CODE_MODEL_PRIMARY || 'opencode/space-bunny-free' }}" in launch
assert "DDD_FREE_CODE_MODEL_SENARY: ${{ vars.DDD_FREE_CODE_MODEL_SENARY || 'opencode/mimo-v2.6-flash-free' }}" in launch
assert "DDD_FREE_MODEL_TRANSIENT_RETRIES: ${{ vars.DDD_FREE_MODEL_TRANSIENT_RETRIES || '0' }}" in launch
assert "      - name: Require configured repository token" in launch
assert "if: steps.token.outputs.configured != 'true'" in launch
gate = "      - name: Require validated code production"
push = "      - name: Push validated launch batch and maintain PR"
assert launch.count(gate) == 1
assert launch.index(gate) < launch.index(push)
assert "if: always() && steps.token.outputs.configured == 'true' && env.SKIP_TARGET != 'true'" in launch
assert launch.count("run: bash scripts/require_production_batch.sh") == 1
assert "env.BATCH_READY == 'true'" in launch
print("PASS: saju-core launch sprint fails closed on no-code or missing token, keeping zero-cost defaults")

# Optimization contract: each isolated new PR may use shallow checkout,
# but fixed work branches must retain history for ahead/behind verification.
for path in (
    ".github/workflows/autodev.yml",
    ".github/workflows/launch-sprint.yml",
    ".github/workflows/saju-global-fast-autodev.yml",
    ".github/workflows/creative-studio-fast-autodev.yml",
):
    workflow = (root / path).read_text(encoding="utf-8")
    marker = "fetch-depth: ${{ steps.select.outputs.branch_mode == 'run_scoped' && 1 || 0 }}"
    assert workflow.count(marker) == 1, path
runner = (root / "scripts/develop_target.sh").read_text(encoding="utf-8")
assert runner.count("npm ci --no-audit --no-fund") >= 2
assert "npm install -g opencode-ai --no-audit --no-fund" in runner
assert "trap print_worker_timings EXIT" in runner
assert "MODEL_SECONDS" in runner and "Actual seconds" in runner
assert "AutoDev time spent (seconds)" in runner
print("PASS: cheap shallow checkouts, offline-safe network flags and duration measurements")
PY
