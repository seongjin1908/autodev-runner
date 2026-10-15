#!/usr/bin/env python3
"""Read-only, versioned OSS reuse recommendations for existing coding workers.

This file NEVER downloads, imports, installs, copies or executes vendor code.
It only adds a narrow preflight to each product's normal coding prompt.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LICENSES = {
    "MIT", "MIT-code-only", "MIT-core-only", "MIT-CE-only",
    "Apache-2.0", "BSD-3-Clause", "LGPL-2.1+-build-dependent",
}
GITHUB_URL = re.compile(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?$")


def catalog(root: Path = ROOT) -> tuple[dict, dict]:
    projects = json.loads((root / "config/projects.json").read_text(encoding="utf-8"))
    data = json.loads((root / "config/oss-reuse-catalog.json").read_text(encoding="utf-8"))
    if data.get("version") != 1 or data.get("status") != "research-candidates-only":
        raise ValueError("OSS catalog must be non-activated research candidates")
    sources = data["libraries"]
    allowed = data["projects"]
    aliases = {p["alias"] for p in projects["projects"]}
    if set(allowed) != aliases:
        raise ValueError(f"OSS catalog alias drift: extra={sorted(set(allowed)-aliases)}, missing={sorted(aliases-set(allowed))}")
    ids: set[str] = set()
    for item in sources:
        if item["id"] in ids or not re.fullmatch(r"[a-z][a-z0-9-]+", item["id"]):
            raise ValueError("duplicate or invalid library ID")
        ids.add(item["id"])
        if item["license"] not in LICENSES:
            raise ValueError(f"{item['id']}: unreviewed license")
        if not GITHUB_URL.fullmatch(item["url"]):
            raise ValueError(f"{item['id']}: project URL is not an approved Github repository")
        if not all(isinstance(item.get(k), str) and item[k].strip() for k in ["name", "focus", "caveat"]):
            raise ValueError(f"{item['id']}: missing usage scope or caveat")
    for alias, candidates in allowed.items():
        if (not isinstance(candidates, list) or not 1 <= len(candidates) <= 3 or
                len(set(candidates)) != len(candidates) or
                any(x not in ids for x in candidates)):
            raise ValueError(f"{alias}: invalid reuse candidates")
    for p in projects["projects"]:
        if p.get("development_status") == "hold" and p.get("auto_enabled"):
            raise ValueError(f"{p['alias']}: user HOLD must never activate")
    return data, projects


def render(alias: str, root: Path = ROOT) -> str:
    data, projects = catalog(root)
    selected = next((p for p in projects["projects"] if p["alias"] == alias), None)
    if selected is None:
        raise ValueError(f"unknown product alias: {alias}")
    # Even if manually invoked for a HOLD project, these are analysis notes,
    # not permission to start coding or override its registry setting.
    held = selected.get("development_status") == "hold"
    source = {x["id"]: x for x in data["libraries"]}
    rows = [
        "# Candidate OSS reuse preflight (advisory, not an instruction to install)",
        "- Inspect actual checked-out code, existing dependencies and in-flight PRs FIRST.",
        "- Only if the current highest-priority launch blocker actually needs it, prefer a permissively licensed reusable component over writing equivalent code.",
        "- Library entry = RESEARCH CANDIDATE, not proof of integration, legal clearance, current version compatibility or feature completion.",
        "- Before importing any version, inspect exact source LICENSE/NOTICE, transitive dependencies, model weights, assets, hosted APIs, data rights, security advisories, license obligations and total operating cost.",
        "- Integrate one narrowly scoped verified capability with executable tests; do not replace working architecture, clone entire apps, download unknown binaries, copy private competitor sources, or add paid/production side effects.",
        "- If existing code already handles the capability or an open PR owns it, DO NOT introduce another dependency.",
    ]
    if held:
        rows.append("- USER HOLD: do not make any code changes or activate this project.")
    for key in data["projects"][alias]:
        item = source[key]
        rows.append(
            f"- {item['name']} [{item['license']}] {item['url']} — "
            f"candidate: {item['focus']}; review: {item['caveat']}"
        )
    return "\n".join(rows) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--alias")
    arguments = parser.parse_args()
    if arguments.validate:
        data, projects = catalog()
        print(f"PASS: {len(data['libraries'])} OSS candidates covering {len(projects['projects'])} existing lanes; no new enabled targets")
        return
    if not arguments.alias:
        parser.error("pass --validate or --alias")
    print(render(arguments.alias), end="")


if __name__ == "__main__":
    main()
