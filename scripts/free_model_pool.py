#!/usr/bin/env python3
"""Fail-closed OpenCode free-model selection and sanitized error classification.

A new scheduled run always retries the preferred free model, detecting recovery.
No paid model IDs, payment flows or cloud billing actions are permitted.
"""
import argparse
import os
from pathlib import Path
import re
import sys

DEFAULT_MODELS = (
    "opencode/space-bunny-free",
    "opencode/longcat-2.5-preview-free",
    "opencode/nemotron-3.5-lightning-free",
    "opencode/ling-3.0-flash-fin-free",
    "opencode/laguna-s-2.1-free",
    "opencode/mimo-v2.6-flash-free",
)
# Curated known-free models, never blindly select an arbitrary provider/model.
# Candidate must also be advertised in installed OpenCode model listing.
EXTRA_MODELS = (
    "opencode/deepseek-v4.1-flash-free",
    "opencode/mimo-v2.5-free",
    "opencode/exo-free",
    "opencode/nemotron-3-ultra-free",
    "opencode/glm-5.3-flash-free",
    "opencode/minimax-m3.1-flash-free",
    "opencode/ling-3.1-flash-free",
    "opencode/beam-free",
    "opencode/ll-alpha-free",
    "opencode/jev-1.13-free",
)
ALLOWLIST = frozenset((*DEFAULT_MODELS, *EXTRA_MODELS))
VARIABLES = (
    "DDD_FREE_CODE_MODEL_PRIMARY",
    "DDD_FREE_CODE_MODEL_SECONDARY",
    "DDD_FREE_CODE_MODEL_TERTIARY",
    "DDD_FREE_CODE_MODEL_QUATERNARY",
    "DDD_FREE_CODE_MODEL_QUINARY",
    "DDD_FREE_CODE_MODEL_SENARY",
)


def advertised_models(output: str) -> set[str]:
    return {line.strip() for line in output.splitlines()
            if re.fullmatch(r"opencode/[a-z0-9][a-z0-9._-]*", line.strip())}


def choose_models(env: dict[str, str], available: set[str] | None) -> list[str]:
    configured = [env.get(name) or default
                  for name, default in zip(VARIABLES, DEFAULT_MODELS)]
    if any(model not in ALLOWLIST for model in configured):
        raise ValueError("Only explicitly allowlisted no-cost models are accepted")
    candidates = [*configured[:2], *EXTRA_MODELS, *configured[2:]]
    selected = []
    for model in candidates:
        if model in ALLOWLIST and model not in selected and (
                available is None or model in available):
            selected.append(model)
    return selected


def failure_type(raw: str, exit_code: int) -> str:
    if exit_code in (124, 137):
        return "timeout"
    log = raw[:65536].lower()
    if re.search(r"\b402\b|payment required|insufficient (?:credits?|balance)|billing disabled|billing account required", log):
        return "billing_block"
    if re.search(r"\b401\b|unauthori[sz]ed|invalid api key|missing api key|authentication required|invalid credentials", log):
        return "auth_block"
    if re.search(r"\b429\b|rate.?limit|quota.{0,30}(?:exceed|reached|limit)|resource.exhausted|too many requests", log):
        return "rate_limited"
    if re.search(r"model.{0,40}(?:not found|unknown|unavailable|not supported)|no such model|unknown model", log):
        return "model_unavailable"
    if re.search(r"\b50[234]\b|connection reset|upstream|overload|service unavailable|temporarily unavailable", log):
        return "transport"
    return "no_usable_edit"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True)
    cand = subs.add_parser("candidates")
    cand.add_argument("--listing", type=Path, default=None)
    cls = subs.add_parser("classify")
    cls.add_argument("--log", type=Path, required=True)
    cls.add_argument("--exit-code", type=int, required=True)
    args = parser.parse_args()
    if args.command == "candidates":
        available = None
        if args.listing is not None:
            try:
                available = advertised_models(args.listing.read_text(encoding="utf-8", errors="replace"))
            except OSError:
                available = set()
        try:
            models = choose_models(os.environ, available)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        for model in models:
            print(model)
        return 0
    try:
        log = args.log.read_text(encoding="utf-8", errors="replace")
    except OSError:
        log = ""
    print(failure_type(log, args.exit_code))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
