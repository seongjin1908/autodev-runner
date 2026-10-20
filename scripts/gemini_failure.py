#!/usr/bin/env python3
"""Classify a private Gemini CLI run using fixed labels; never print raw logs."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

LABELS = frozenset({
    "ok", "workspace_untrusted", "configuration_failure", "authorization_failed",
    "quota_limited", "billing_blocked", "model_unavailable", "transport_failure",
    "timeout", "model_no_source_edit", "unknown_cli_failure",
})


def classify(log: str, exit_code: int) -> str:
    data = log[:131072].lower()
    if exit_code in (124, 137):
        return "timeout"
    if "fataluntrustedworkspaceerror" in data or "not running in a trusted directory" in data:
        return "workspace_untrusted"
    if re.search(r"\b402\b|payment required|billing (?:not enabled|required)|insufficient (?:funds|balance|credits?)", data):
        return "billing_blocked"
    if re.search(r"\b429\b|rate.?limit|resource.?exhausted|quota.{0,50}(?:exceed|reached|limit)|too many requests", data):
        return "quota_limited"
    if re.search(r"\b401\b|\b403\b|invalid api key|api key not valid|permission denied|unauthori[sz]ed|unauthenticated|please set an auth method|manual authorization is required|no authentication method selected|select.*authentication method", data):
        return "authorization_failed"
    if re.search(r"\b50[234]\b|connection reset|temporarily unavailable|upstream|overload|econnreset", data):
        return "transport_failure"
    if re.search(r"model.{0,45}(?:not found|not supported|not available)|no such model", data):
        return "model_unavailable"
    if re.search(r"invalid config|configuration error|malformed settings|unknown option|unknown arguments?|unrecognized arguments?|invalid argument", data) or exit_code in (42, 52):
        return "configuration_failure"
    if exit_code == 55:
        # Some versions use code 55 for headless workspace trust. No assumptions
        # about the unseen log are made if the explicit message was not found.
        return "configuration_failure"
    if exit_code == 0:
        return "ok"
    if exit_code == 53:
        return "model_no_source_edit"
    return "unknown_cli_failure"


def classify_structured_error(json_output: str, stderr: str, exit_code: int) -> str:
    """Classify only the JSON error object, never its response or model source."""
    try:
        payload = json.loads(json_output)
    except (ValueError, TypeError):
        payload = None
    if not isinstance(payload, dict) or payload.get("error") in (None, False):
        return classify(stderr, exit_code)
    error = payload["error"]
    if isinstance(error, dict):
        # Only documented, bounded diagnostic fields; exclude arbitrary model
        # response, tool calls, prompt and source entirely.
        parts = [str(error.get(key, ""))[:2048] for key in ("code", "status", "type", "message")]
        diagnostic = " ".join(parts)
    elif isinstance(error, str):
        diagnostic = error[:4096]
    else:
        diagnostic = ""
    if diagnostic:
        return classify(diagnostic + "\n" + stderr[:4096], exit_code)
    return classify(stderr, exit_code)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    req = sub.add_parser("classify")
    req.add_argument("--log", type=Path, required=True)
    req.add_argument("--exit-code", type=int, required=True)
    req.add_argument("--json-output", type=Path)
    args = parser.parse_args()
    try:
        data = args.log.read_text(encoding="utf-8", errors="replace")
    except OSError:
        data = ""
    if args.json_output is not None:
        try:
            response = args.json_output.read_text(encoding="utf-8", errors="replace")[:2_000_000]
        except OSError:
            response = ""
        print(classify_structured_error(response, data, args.exit_code))
    else:
        print(classify(data, args.exit_code))


if __name__ == "__main__":
    main()
