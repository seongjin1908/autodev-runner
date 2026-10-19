#!/usr/bin/env python3
"""Verify dedicated workflows are scheduled but excluded from central auto rotation."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
cfg = json.loads((root / "config/projects.json").read_text(encoding="utf-8"))
projects = {p["alias"]: p for p in cfg["projects"]}
dedicated = {
    "saju-core": (".github/workflows/launch-sprint.yml", "target: [saju-core]"),
    "saju-global": (".github/workflows/saju-global-fast-autodev.yml", "TARGET: saju-global"),
    "creative-studio": (".github/workflows/creative-studio-fast-autodev.yml", "TARGET: creative-studio"),
}
selector = (root / "scripts/select_target.sh").read_text(encoding="utf-8")
assert "not p.get('dedicated_schedule_only', False)" in selector
for alias, (workflow_name, target_marker) in dedicated.items():
    p = projects[alias]
    assert p["auto_enabled"] is True and p["auto_weight"] > 0, alias
    assert p["dedicated_schedule_only"] is True, alias
    workflow = (root / workflow_name).read_text(encoding="utf-8")
    assert "cron:" in workflow and target_marker in workflow, alias

central = [
    p for p in projects.values()
    if p["auto_enabled"] and p["auto_weight"] > 0
    and not p.get("dedicated_schedule_only", False)
]
assert central and len(central) >= 10
assert not {p["alias"] for p in central}.intersection(dedicated)
assert sum(p["auto_weight"] for p in central) == 49

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

print("PASS: dedicated jobs stay active and explicit while 49-weight central rotation avoids duplicate work")
