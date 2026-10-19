#!/usr/bin/env python3
"""Build a narrow, source-grounded task brief for an existing AutoDev project.

This is a deterministic prompt aid, not a claim to know product requirements.
Never reads tracked file content, calls networks, or selects unrelated projects.
"""
from __future__ import annotations

import argparse
from pathlib import PurePosixPath
import os
from pathlib import Path
import subprocess

SOURCE_SUFFIXES = {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".py", ".go", ".rs", ".java", ".kt", ".vue", ".svelte"}
EXCLUDE_PARTS = {"node_modules", "dist", "build", "coverage", "__pycache__", ".github", ".next", ".astro", "vendor"}
SOURCE_PREFIXES = ("src/", "app/", "apps/", "backend/", "server/", "api/", "lib/", "gateway/", "services/")
TEST_MARKERS = ("test", "spec", "__tests__", "tests")


def visible_paths(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    )
    paths = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        path = raw.decode("utf-8", "surrogateescape")
        parts = PurePosixPath(path).parts
        if any(p in EXCLUDE_PARTS or p.startswith(".env") for p in parts):
            continue
        paths.append(path)
    return paths


def is_test(path: str) -> bool:
    parts = PurePosixPath(path).parts
    base = parts[-1].lower()
    return any(part.lower() in {"tests", "test", "__tests__"} for part in parts[:-1]) or (
        "test." in base or ".spec." in base or base.startswith(("test_", "spec_"))
    )


def prioritized(paths: list[str], limit: int, include_tests: bool) -> list[str]:
    valid = [p for p in paths if PurePosixPath(p).suffix.lower() in SOURCE_SUFFIXES
             and not any(part in EXCLUDE_PARTS or part.startswith(".env") for part in PurePosixPath(p).parts)
             and is_test(p) == include_tests]
    valid.sort(key=lambda p: (not p.startswith(SOURCE_PREFIXES), p.count("/"), p))
    return valid[:limit]


def brief(paths: list[str], alias: str, baseline_failed: bool, slot: int) -> str:
    code = prioritized(paths, 5, False)
    tests = prioritized(paths, 3, True)
    lanes = [
        ("release-blocker", "Find the highest-impact incomplete RELEASE blocker that is actually evident in tracked code or its existing tests."),
        ("customer-journey", "Find a demonstrated broken user-facing end-to-end path or error recovery in the existing product flow; do not invent flows."),
        ("correctness", "Find a demonstrable correctness, security, validation, or reliability defect in the owned current implementation."),
    ]
    if baseline_failed:
        mode, goal = ("baseline-repair", "Fix the current baseline validation failure before any new feature work.")
    else:
        mode, goal = lanes[slot % len(lanes)]
    result = [
        "# Narrow development slice — evidence required",
        f"- Existing project: {alias}",
        f"- This run's focus: {mode}",
        f"- Target: {goal}",
        "- First inspect existing behavior, the target-specific development prompt and open work; choose ONE real incomplete defect or milestone, not three unrelated features.",
        "- Never use source path presence as evidence of a bug. If no demonstrable, authorized blocker exists, report no useful change instead of making cosmetic edits.",
        "- Keep changes as small as realistically possible: preferably one cohesive implementation plus regression tests. Existing security and release gates still apply.",
        "- Preserve product-specific priority: if the baseline is broken, correct it first. Never break auth, payment, privacy or safeguards to make tests green.",
        "- Do not produce a documentation-only, generated fixture, probe-only, or no-op batch.",
        "- Before declaring success run the existing target validation and explain the specific failing test or behavior fixed.",
    ]
    if code:
        result.append("- Source-entry breadcrumbs (verified tracked paths; NOT an instruction to edit them all): " + ", ".join(code))
    if tests:
        result.append("- Existing test breadcrumbs: " + ", ".join(tests))
    return "\n".join(result) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--alias", required=True)
    parser.add_argument("--baseline-rc", default="0")
    parser.add_argument("--run-number", default="0")
    args = parser.parse_args()
    slot = int(args.run_number) if args.run_number.isdecimal() else 0
    print(brief(visible_paths(args.root), args.alias, args.baseline_rc != "0", slot), end="")


if __name__ == "__main__":
    main()
