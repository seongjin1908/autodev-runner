#!/usr/bin/env python3
"""Offline regression tests for headless Gemini trust failure classification."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "scripts/gemini_failure.py"
spec = importlib.util.spec_from_file_location("gemini_failure", MODULE)
gemini = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gemini)
SHELL = (ROOT / "scripts/gemini_free_fallback.sh").read_text(encoding="utf-8")


class GeminiHeadlessRecoveryTests(unittest.TestCase):
    def test_trust_failure_is_detected_without_source_disclosure(self):
        failures = [
            ("FatalUntrustedWorkspaceError: directory not trusted", 55, "workspace_untrusted"),
            ("Gemini CLI is not running in a trusted directory", 55, "workspace_untrusted"),
            ("WARNING private-data and 55", 55, "configuration_failure"),
            ("429 RESOURCE_EXHAUSTED private-key-secret", 1, "quota_limited"),
            ("401 API key not valid private-key-secret", 1, "authorization_failed"),
            ("invalid config", 52, "configuration_failure"),
            ("Payment Required 402", 1, "billing_blocked"),
            ("", 124, "timeout"),
            ("", 0, "ok"),
        ]
        for line, code, expected in failures:
            with self.subTest(line=line):
                self.assertEqual(gemini.classify(line, code), expected)
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / "private.log"
            file.write_text("FatalUntrustedWorkspaceError secret=private-123")
            run = subprocess.run(
                [sys.executable, str(MODULE), "classify", "--log", str(file),
                 "--exit-code", "55"],
                capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 0)
            self.assertEqual(run.stdout.strip(), "workspace_untrusted")
            self.assertNotIn("private-123", run.stdout)

    def test_no_untrusted_project_config_is_silently_overridden(self):
        self.assertIn("--skip-trust", SHELL)
        self.assertIn('[[ -e .gemini || -e .mcp.json || -e .env || -e "$ROOT_DIR/.gemini" ]]', SHELL)
        self.assertIn('"disableYoloMode": true', SHELL)
        self.assertIn('"hooks": {"enabled": false}', SHELL)
        self.assertIn('"tools": {"core": ["read_file", "write_file", "replace", "list_directory", "glob", "grep_search"]}', SHELL)
        self.assertNotIn("--approval-mode yolo", SHELL)
        self.assertIn('GEMINI_ISSUE="$(python3 "$ROOT_DIR/scripts/gemini_failure.py" classify', SHELL)
        self.assertIn("Private model transcript not published", SHELL)
        self.assertIn("git diff --check", SHELL)
        self.assertIn("BATCH_READY=true", SHELL)

    def test_existing_zero_cost_secret_and_validation_gates_remain(self):
        self.assertIn('AUTODEV_GEMINI_FREE_ENABLED:-false', SHELL)
        self.assertIn('GEMINI_API_KEY:-', SHELL)
        self.assertIn('gemini-2.5-flash|gemini-2.5-flash-lite', SHELL)
        self.assertIn("env -u GEMINI_API_KEY -u GOOGLE_API_KEY npm install", SHELL)
        self.assertIn("--approval-mode auto_edit", SHELL)
        self.assertIn("--extensions none", SHELL)
        self.assertIn('bash -lc "$VALIDATION"', SHELL)
        self.assertIn('bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"', SHELL)
        protected = (ROOT / "scripts/prepare_gemini_handoff.sh").read_text(encoding="utf-8")
        self.assertIn('if [[ "$original" != "$START_SHA" ]]; then', protected)


if __name__ == "__main__":
    unittest.main()
