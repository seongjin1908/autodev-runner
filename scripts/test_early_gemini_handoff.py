#!/usr/bin/env python3
"""Offline test: prioritize Gemini on explicit free opt-in, preserve safe fallback."""
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
DEV = (ROOT / "scripts/develop_target.sh").read_text(encoding="utf-8")
WORKFLOWS = [
    ".github/workflows/autodev.yml",
    ".github/workflows/launch-sprint.yml",
    ".github/workflows/saju-global-fast-autodev.yml",
    ".github/workflows/creative-studio-fast-autodev.yml",
]


class EarlyGeminiHandoffTests(unittest.TestCase):
    def test_budget_is_270_only_on_explicit_optin(self):
        match = re.search(
            r'(if \[\[ "\$\{AUTODEV_GEMINI_FREE_ENABLED:-false\}" == "true" \]\]; then\n'
            r'.*?\nfi)', DEV, flags=re.S,
        )
        self.assertIsNotNone(match, "Budget selection code missing")
        for enabled, override, expected in [
            ("true", None, "270"),
            ("false", None, "540"),
            ("", None, "540"),
            ("true", "360", "360"),
            ("false", "120", "120"),
        ]:
            with self.subTest(enabled=enabled, override=override):
                env = {k: v for k, v in os.environ.items() if k not in (
                    "DDD_FREE_MODEL_POOL_MAX_SECONDS", "AUTODEV_GEMINI_FREE_ENABLED")}
                env["AUTODEV_GEMINI_FREE_ENABLED"] = enabled
                if override is not None:
                    env["DDD_FREE_MODEL_POOL_MAX_SECONDS"] = override
                script = match.group(1) + '\nprintf "%s" "$POOL_MAX_SECONDS"\n'
                run = subprocess.run(["bash", "-c", script], env=env,
                                     text=True, capture_output=True, check=True)
                self.assertEqual(run.stdout.strip(), expected)

    def test_workflows_only_expose_the_optin_bit_not_secret(self):
        for path in WORKFLOWS:
            with self.subTest(path=path):
                src = (ROOT / path).read_text(encoding="utf-8")
                self.assertEqual(src.count(
                    "AUTODEV_GEMINI_FREE_ENABLED: ${{ vars.AUTODEV_GEMINI_FREE_ENABLED || 'false' }}"), 1)
                self.assertIn("vars.AUTODEV_GEMINI_FREE_ENABLED == 'true'", src)
                self.assertEqual(src.count(
                    "GEMINI_API_KEY: ${{ secrets.AUTODEV_GEMINI_FREE_API_KEY }}"), 1)
                self.assertLess(
                    src.index('run: bash scripts/develop_target.sh'),
                    src.index('run: bash scripts/gemini_free_fallback.sh'),
                )

    def test_git_diff_and_production_gates_still_enforced(self):
        self.assertIn('if [[ -z "$SELECTED_MODEL" ]]; then', DEV)
        self.assertIn("AUTODEV_RUN_STATUS=provider_unavailable", DEV)
        self.assertIn("BATCH_READY=true", DEV)
        self.assertIn("MODEL_CANDIDATES", DEV)
        self.assertIn("POOL_MAX_ATTEMPTS", DEV)


if __name__ == "__main__":
    unittest.main()
