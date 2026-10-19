#!/usr/bin/env python3
"""Test that performance measurements reveal no private prompt/source/logs."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("model_metrics.py")
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location("model_metrics", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ModelMetricTests(unittest.TestCase):
    def test_only_known_free_model_and_fixed_outcome(self):
        record = module.make_record("opencode/space-bunny-free", "attempt", 28, 124)
        self.assertEqual(set(record), {"model", "result", "seconds", "exit_code"})
        self.assertNotIn("prompt", record)
        with self.assertRaises(ValueError):
            module.make_record("openai/gpt-6", "validated", 1, 0)
        with self.assertRaises(ValueError):
            module.make_record("opencode/space-bunny-free", "secret-token-1234", 1, 0)
        with self.assertRaises(ValueError):
            module.make_record("opencode/space-bunny-free", "validated", -1, 0)

    def test_jsonl_run_and_summary(self):
        model = "opencode/space-bunny-free"
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "models.jsonl"
            for status in ["attempt", "validated"]:
                p = subprocess.run(
                    [sys.executable, str(SCRIPT), "record", "--file", str(file),
                     "--model", model, "--result", status, "--seconds", "24", "--exit-code", "0"],
                    capture_output=True, text=True,
                )
                self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(module.report(file),
                             "Free-model calls: 1; validated source batches: 1; attempted wall seconds: 24.")
            self.assertEqual(len(module.records(file)), 2)
            self.assertIn("| `opencode/space-bunny-free` | 1 | 1 | 24 |", module.model_scorecard(file))
            self.assertNotIn("SECRET", file.read_text())

    def test_corrupt_record_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "models.jsonl"
            file.write_text(
                '{"model":"opencode/space-bunny-free","result":"attempt","seconds":1,"exit_code":0}\n'
                '{"model":"openai/paid","result":"validated","seconds":1,"exit_code":0}\n'
                'broken\n', encoding="utf-8",
            )
            self.assertEqual(len(module.records(file)), 1)


if __name__ == "__main__":
    unittest.main()
