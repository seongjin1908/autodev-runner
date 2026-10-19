#!/usr/bin/env python3
"""Offline regression tests for disabled-by-default Gemini free-tier fallback."""
from pathlib import Path
import base64
import os
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/gemini_free_fallback.sh"
WORKFLOWS = (
    ".github/workflows/autodev.yml",
    ".github/workflows/launch-sprint.yml",
    ".github/workflows/saju-global-fast-autodev.yml",
    ".github/workflows/creative-studio-fast-autodev.yml",
)


class GeminiFallbackTests(unittest.TestCase):
    def test_never_shares_secret_with_primary_dev_or_baseline(self):
        for path in WORKFLOWS:
            with self.subTest(path=path):
                workflow = (ROOT / path).read_text(encoding="utf-8")
                self.assertEqual(workflow.count("run: bash scripts/gemini_free_fallback.sh"), 1)
                self.assertEqual(workflow.count(
                    "GEMINI_API_KEY: ${{ secrets.AUTODEV_GEMINI_FREE_API_KEY }}"), 1)
                self.assertIn("vars.AUTODEV_GEMINI_FREE_ENABLED == 'true'", workflow)
                self.assertIn("env.BATCH_READY != 'true'", workflow)
                self.assertIn("env.SKIP_TARGET != 'true'", workflow)
                self.assertLess(
                    workflow.index("run: bash scripts/develop_target.sh"),
                    workflow.index("run: bash scripts/gemini_free_fallback.sh"),
                )
                self.assertLess(
                    workflow.index("run: bash scripts/gemini_free_fallback.sh"),
                    workflow.index("run: bash scripts/require_production_batch.sh"),
                )
                self.assertNotIn("GEMINI_API_KEY:", workflow.split("      - name: Optional independent Gemini free-tier coding fallback")[0])

    def run_script(self, enabled, key="", model=None):
        env = {k: v for k, v in os.environ.items()
               if not k.startswith("AUTODEV_GEMINI_") and k != "GEMINI_API_KEY"}
        env["AUTODEV_GEMINI_FREE_ENABLED"] = enabled
        if key:
            env["GEMINI_API_KEY"] = key
        if model:
            env["AUTODEV_GEMINI_FREE_MODEL"] = model
        env["START_SHA"] = "0" * 40
        env["VALIDATION_B64"] = base64.b64encode(b"node --version").decode("ascii")
        env["MAX_CHANGED_FILES"] = "10"
        return subprocess.run(
            ["bash", str(SCRIPT)], cwd=ROOT, env=env,
            capture_output=True, text=True, check=False, timeout=5
        )

    def test_disabled_and_missing_key_never_invokes_gemini(self):
        disabled = self.run_script("false", "synthetic-not-real-key")
        self.assertEqual(disabled.returncode, 0, disabled.stderr)
        self.assertIn("disabled", disabled.stdout)
        absent = self.run_script("true")
        self.assertEqual(absent.returncode, 0, absent.stderr)
        self.assertIn("secret is absent", absent.stdout)

    def test_any_unapproved_model_fails_before_network_and_checkout(self):
        invalid = self.run_script("true", "synthetic-not-real-key", "gemini-4-paid")
        self.assertEqual(invalid.returncode, 2)
        self.assertIn("Unapproved Gemini model", invalid.stdout)

    def test_only_safe_edit_tool_mode_and_validation(self):
        s = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("--approval-mode auto_edit", s)
        self.assertIn("--extensions none", s)
        self.assertIn("GEMINI_TIMEOUT_SECONDS=180", s)
        self.assertNotIn("--yolo", s)
        self.assertNotIn("--approval-mode yolo", s)
        self.assertIn("env -u GEMINI_API_KEY -u GOOGLE_API_KEY npm install", s)
        self.assertIn("unset GEMINI_API_KEY", s)
        self.assertIn("git diff --check", s)
        self.assertIn("VALIDATION_B64", s)
        self.assertIn("GITHUB_ENV", s)
        self.assertIn("BATCH_READY=true", s)
        self.assertIn("restore_clean", s)
        self.assertIn("code_exts", s)


if __name__ == "__main__":
    unittest.main()
