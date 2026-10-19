#!/usr/bin/env python3
"""No-network tests for grounded task slices. Only synthetic pathnames."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("select_task_slice.py")
spec = importlib.util.spec_from_file_location("select_task_slice", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


class TaskSliceTests(unittest.TestCase):
    def setUp(self):
        self.files = [
            "src/App.tsx", "src/lib/payments.ts", "server/core.mjs",
            "tests/payment.test.mjs", "tests/core.spec.ts",
            "docs/README.md", ".github/workflows/secret.yml",
            "dist/bundle.js", "node_modules/a.js",
        ]

    def test_grounded_paths_and_bounded_output(self):
        result = mod.brief(self.files, "worklink", False, 0)
        self.assertIn("release-blocker", result)
        self.assertIn("src/App.tsx", result)
        self.assertIn("tests/payment.test.mjs", result)
        self.assertNotIn(".github", result)
        self.assertNotIn("dist/bundle.js", result)
        self.assertNotIn("node_modules", result)
        self.assertIn("ONE real incomplete defect", result)
        self.assertIn("no useful change instead", result)
        self.assertNotIn("fix payment bug", result.lower())

    def test_baseline_failure_overrides_regular_cycle(self):
        for slot in range(7):
            result = mod.brief(self.files, "saju-core", True, slot)
            self.assertIn("baseline-repair", result)
        self.assertIn("customer-journey", mod.brief(self.files, "worklink", False, 1))
        self.assertIn("correctness", mod.brief(self.files, "worklink", False, 2))

    def test_empty_repo_no_imaginary_source(self):
        result = mod.brief(["README.md", "docs/plan.md"], "unknown", False, 0)
        self.assertNotIn("Source-entry breadcrumbs", result)
        self.assertIn("no useful change", result)

    def test_real_git_paths_without_file_contents(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / "src").mkdir()
            (root / "src" / "app.py").write_text("SECRET_DO_NOT_PUBLISH")
            subprocess.run(["git", "-C", str(root), "add", "src/app.py"], check=True)
            p = mod.visible_paths(root)
            self.assertEqual(p, ["src/app.py"])
            result = mod.brief(p, "sample", False, 0)
            self.assertNotIn("SECRET_DO_NOT_PUBLISH", result)


if __name__ == "__main__":
    unittest.main()
