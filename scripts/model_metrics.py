#!/usr/bin/env python3
"""Write small, privacy-safe JSONL measurements of zero-budget model attempts.

Records only allowlisted model ID, fixed result label, timing and run number.
Never saves model responses, prompts, source, credentials, or private logs.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from free_model_pool import ALLOWLIST

RESULTS = frozenset({
    "attempt", "validated", "timeout", "rate_limited", "transport",
    "model_unavailable", "auth_block", "billing_block",
    "no_usable_edit", "validation_failed", "guard_rejected",
})


def make_record(model: str, result: str, seconds: int, exit_code: int) -> dict:
    if model not in ALLOWLIST:
        raise ValueError("Model not listed as free. No metric written.")
    if result not in RESULTS:
        raise ValueError("Unknown result. No metric written.")
    if not (0 <= seconds <= 3600 and -1 <= exit_code <= 255):
        raise ValueError("Invalid timing or process exit status.")
    return {
        "model": model,
        "result": result,
        "seconds": seconds,
        "exit_code": exit_code,
    }


def records(path: Path) -> list[dict]:
    if not path.exists():
        return []
    items = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue
        if (
            isinstance(data, dict)
            and set(data) == {"model", "result", "seconds", "exit_code"}
        ):
            try:
                items.append(make_record(
                    data["model"], data["result"], data["seconds"], data["exit_code"]
                ))
            except (ValueError, TypeError, KeyError):
                continue
    return items


def report(path: Path) -> str:
    items = records(path)
    attempted = [x for x in items if x["result"] == "attempt"]
    good = [x for x in items if x["result"] == "validated"]
    return (
        f"Free-model calls: {len(attempted)}; validated source batches: {len(good)}; "
        f"attempted wall seconds: {sum(x['seconds'] for x in attempted)}."
    )


def model_scorecard(path: Path) -> str:
    """Run-scoped outcome table; no prompts, private paths, or provider logs."""
    events = records(path)
    attempted = [x for x in events if x["result"] == "attempt"]
    validated = [x for x in events if x["result"] == "validated"]
    if not attempted:
        return "No free model call was recorded."
    names = sorted({x["model"] for x in attempted})
    lines = ["| Free model | Calls | Validated edits | Duration (s) |", "|---|---:|---:|---:|"]
    for name in names:
        trials = [x for x in attempted if x["model"] == name]
        successes = sum(1 for x in validated if x["model"] == name)
        seconds = sum(x["seconds"] for x in trials)
        lines.append(f"| `{name}` | {len(trials)} | {successes} | {seconds} |")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers(dest="command", required=True)
    p = subs.add_parser("record")
    p.add_argument("--file", type=Path, required=True)
    p.add_argument("--model", required=True)
    p.add_argument("--result", required=True)
    p.add_argument("--seconds", required=True, type=int)
    p.add_argument("--exit-code", required=True, type=int)
    q = subs.add_parser("summary")
    q.add_argument("--file", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "summary":
        print(report(args.file))
        print(model_scorecard(args.file))
        return
    entry = make_record(args.model, args.result, args.seconds, args.exit_code)
    with args.file.open("a", encoding="utf-8") as target:
        target.write(json.dumps(entry, ensure_ascii=True, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
