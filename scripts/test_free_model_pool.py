#!/usr/bin/env python3
"""Free-only model selection, quota exhaustion, reactivation regression tests."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("free_model_pool.py")
spec = importlib.util.spec_from_file_location("free_model_pool", SCRIPT)
pool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pool)


class FreeModelPoolTests(unittest.TestCase):
    def test_primary_fallback_and_automatic_recovery_on_next_run(self):
        choices = {"opencode/space-bunny-free", "opencode/longcat-2.5-preview-free",
                   "opencode/deepseek-v4.1-flash-free", "opencode/mimo-v2.5-free"}
        first = pool.choose_models({}, choices)
        second = pool.choose_models({}, choices)
        self.assertEqual(first, second)
        self.assertEqual(first[0], "opencode/space-bunny-free")
        self.assertEqual(first[1], "opencode/longcat-2.5-preview-free")
        self.assertIn("opencode/deepseek-v4.1-flash-free", first)
        self.assertEqual(len(first), len(set(first)))

    def test_no_paid_or_unlisted_model_ever_selected(self):
        names = pool.advertised_models(
            "opencode/space-bunny-free\nopencode/deepseek-v4.1-flash-free\n"
            "opencode/gpt-6-paid\nanthropic/claude\n"
            "WARNING installing extra models\n"
        )
        self.assertNotIn("opencode/gpt-6-paid", pool.choose_models({}, names))
        self.assertEqual(
            pool.choose_models({}, {"opencode/deepseek-v4.1-flash-free"}),
            ["opencode/deepseek-v4.1-flash-free"],
        )
        with self.assertRaises(ValueError):
            pool.choose_models({"DDD_FREE_CODE_MODEL_PRIMARY": "openai/gpt-6"}, None)
        with self.assertRaises(ValueError):
            pool.choose_models({"DDD_FREE_CODE_MODEL_PRIMARY": "opencode/some-other-free"}, None)

    def test_empty_successful_discovery_fails_closed(self):
        self.assertEqual(pool.choose_models({}, set()), [])
        self.assertEqual(len(pool.choose_models({}, None)), 16)

    def test_sanitized_failure_reason(self):
        cases = [
            ("429 too many requests", 1, "rate_limited"),
            ("quota exceeded", 1, "rate_limited"),
            ("401 invalid api key", 1, "auth_block"),
            ("402 payment required", 1, "billing_block"),
            ("model not found", 1, "model_unavailable"),
            ("503 upstream overloaded", 1, "transport"),
            ("not related to models", 124, "timeout"),
            ("private customer source: xyz", 1, "no_usable_edit"),
        ]
        for raw, code, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(pool.failure_type(raw, code), expected)

    def test_cli_filters_runtime_listing_and_only_emits_fixed_labels(self):
        with tempfile.TemporaryDirectory() as tmp:
            listing = Path(tmp) / "models.txt"
            listing.write_text(
                "opencode/longcat-2.5-preview-free\n"
                "opencode/deepseek-v4.1-flash-free\n"
                "opencode/non-free-model\n", encoding="utf-8")
            env = {k: v for k, v in os.environ.items() if not k.startswith("DDD_FREE_CODE_MODEL_")}
            completed = subprocess.run(
                [sys.executable, str(SCRIPT), "candidates", "--listing", str(listing)],
                env=env, capture_output=True, text=True, check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(completed.stdout.strip().splitlines(), [
                "opencode/longcat-2.5-preview-free",
                "opencode/deepseek-v4.1-flash-free",
            ])
            log = Path(tmp) / "model.log"
            log.write_text("ERROR 429 private-token-xyz", encoding="utf-8")
            classified = subprocess.run(
                [sys.executable, str(SCRIPT), "classify", "--log", str(log), "--exit-code", "1"],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(classified.stdout.strip(), "rate_limited")
            self.assertNotIn("private-token", classified.stdout)


if __name__ == "__main__":
    unittest.main()
