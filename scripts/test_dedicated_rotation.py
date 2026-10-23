#!/usr/bin/env python3
"""Verify release-focus rotation, dedicated manual lane and Saju exclusion."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
cfg = json.loads((root / "config/projects.json").read_text(encoding="utf-8"))
projects = {p["alias"]: p for p in cfg["projects"]}
dedicated = {
    "creative-studio": (".github/workflows/creative-studio-fast-autodev.yml", "TARGET: creative-studio"),
}
paused_saju = {
    "saju-core": (".github/workflows/launch-sprint.yml", "target: [saju-core]"),
    "saju-global": (".github/workflows/saju-global-fast-autodev.yml", "TARGET: saju-global"),
}
selector = (root / "scripts/select_target.sh").read_text(encoding="utf-8")
assert "not p.get('dedicated_schedule_only', False)" in selector
for alias, (workflow_name, target_marker) in dedicated.items():
    p = projects[alias]
    assert p["auto_enabled"] is False and p["auto_weight"] == 0, alias
    assert p["dedicated_schedule_only"] is True, alias
    workflow = (root / workflow_name).read_text(encoding="utf-8")
    assert "cron:" in workflow and target_marker in workflow, alias
    assert "if: github.event_name == 'workflow_dispatch'" in workflow, alias

# Paused saju jobs must be inert on schedule AND manual dispatch; the separate
# user-owned development repo is never selected by the central controller.
for alias, (workflow_name, target_marker) in paused_saju.items():
    p = projects[alias]
    assert p["auto_enabled"] is False and p["auto_weight"] == 0, alias
    assert p["development_status"] == "hold", alias
    assert p["external_worker_lock"] is True, alias
    workflow = (root / workflow_name).read_text(encoding="utf-8")
    assert target_marker in workflow and "if: ${{ false }}" in workflow, alias
for alias in ("saju", "saju-design"):
    p = projects[alias]
    assert p["auto_enabled"] is False and p["development_status"] == "hold", alias

central = [
    p for p in projects.values()
    if p["auto_enabled"] and p["auto_weight"] > 0
    and not p.get("dedicated_schedule_only", False)
]
assert [p["alias"] for p in central] == ["restore-ai"]
assert central[0]["auto_weight"] == 1
assert not {p["alias"] for p in central}.intersection(dedicated)
worklink=(root / ".github/workflows/worklink-free-dispatch.yml").read_text(encoding="utf-8")
assert "github.event_name == 'workflow_dispatch'" in worklink
controller=(root / ".github/workflows/autodev.yml").read_text(encoding="utf-8")
assert "if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'" in controller

# Automatic selection excludes dedicated lanes, but explicit/manual selection
# still resolves them for their own cron workflows and user-directed dispatch.
env = os.environ.copy()
env.pop("GH_TOKEN", None)
env.pop("GITHUB_TOKEN", None)
for target in ("auto", *dedicated):
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as out:
        local_env = {**env, "TARGET": target, "GITHUB_OUTPUT": out.name}
        result = subprocess.run(
            ["bash", str(root / "scripts/select_target.sh")],
            cwd=root, env=local_env, text=True, capture_output=True, check=False
        )
        assert result.returncode == 0, (target, result.stderr)
        data = Path(out.name).read_text()
        alias = next(line.split("=", 1)[1] for line in data.splitlines() if line.startswith("alias="))
        if target == "auto":
            assert alias not in dedicated, alias
        else:
            assert alias == target, (alias, target)

for target in paused_saju:
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as out:
        result = subprocess.run(
            ["bash", str(root / "scripts/select_target.sh")],
            cwd=root, env={**env, "TARGET": target, "GITHUB_OUTPUT": out.name},
            text=True, capture_output=True, check=False
        )
        assert result.returncode != 0, target
        assert "Target is on HOLD:" in result.stderr, (target, result.stderr)

print("PASS: Saju locked, Restore scheduled sole coding lane, other scheduled feature writers held")
