#!/usr/bin/env python3
"""Strict catalog and prompt wiring regression, no network or vendor installs."""
import importlib.util
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("oss_reuse", ROOT / "scripts/oss_reuse.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

data, config = module.catalog()
assert len(data["libraries"]) >= 12
assert len(data["projects"]) == len(config["projects"])
for row in config["projects"]:
    text = module.render(row["alias"])
    assert "RESEARCH CANDIDATE" in text
    assert "in-flight PRs" in text
    assert "actual checked-out code" in text
    assert "No" not in text[:5]  # CLI produces positive advisory, not a status error
    for source_id in data["projects"][row["alias"]]:
        lib = next(x for x in data["libraries"] if x["id"] == source_id)
        assert lib["url"] in text
    assert ("USER HOLD" in text) == (row.get("development_status") == "hold")

def reject(modify_catalog=None, modify_projects=None):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "config").mkdir()
        catalog = json.loads(json.dumps(data))
        projects = json.loads(json.dumps(config))
        if modify_catalog:
            modify_catalog(catalog)
        if modify_projects:
            modify_projects(projects)
        (root / "config/oss-reuse-catalog.json").write_text(json.dumps(catalog))
        (root / "config/projects.json").write_text(json.dumps(projects))
        try:
            module.catalog(root)
        except ValueError:
            return
        raise AssertionError("unsafe OSS catalog change was accepted")

reject(lambda x: x["libraries"][0].update(license="unreviewed"))
reject(lambda x: x["libraries"][0].update(url="https://evil.example.invalid/payload"))
reject(lambda x: x["libraries"].append(x["libraries"][0]))
reject(lambda x: x["projects"].pop("saju-core"))
reject(lambda x: x["projects"]["pricecam"].append("nonexistent"))
reject(lambda x: x["projects"].update({"unused": ["i18next"]}))
reject(modify_projects=lambda x: next(p for p in x["projects"] if p["alias"] == "tradepilot").update(auto_enabled=True))
print("PASS: OSS catalogue validated, all lanes covered, prohibited licenses/URLs/holds fail closed")
