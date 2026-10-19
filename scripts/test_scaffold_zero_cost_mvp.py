#!/usr/bin/env python3
"""Regression tests for the zero-cost, overwrite-safe browser MVP generator."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("scaffold_zero_cost_mvp.py")


class ScaffoldTests(unittest.TestCase):
    def run_generator(self, title, destination):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--name", title, "--destination", str(destination)],
            check=False, capture_output=True, text=True,
        )

    def test_generates_functioning_local_mvp_without_dependencies(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "mvp"
            result = self.run_generator("Jeju Test", dest)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual({p.name for p in dest.iterdir()}, {"index.html", "README.md"})
            page = (dest / "index.html").read_text(encoding="utf-8")
            self.assertIn("Jeju Test", page)
            self.assertIn('localStorage.getItem(key)', page)
            self.assertIn('label.textContent = item.label', page)
            self.assertIn('form.addEventListener("submit"', page)
            self.assertNotIn("https://", page)
            readme = (dest / "README.md").read_text(encoding="utf-8")
            self.assertIn("NOT a production SaaS", readme)
            self.assertIn("no authentication", readme)

    def test_html_escapes_untrusted_project_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "mvp"
            result = self.run_generator('<img src=x onerror="oops">', dest)
            self.assertEqual(result.returncode, 0, result.stderr)
            page = (dest / "index.html").read_text(encoding="utf-8")
            self.assertIn("&lt;img", page)
            self.assertNotIn('<img src=x onerror=', page)

    def test_existing_directory_never_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "existing"
            dest.mkdir()
            original = dest / "index.html"
            original.write_text("ORIGINAL", encoding="utf-8")
            result = self.run_generator("Demo", dest)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(original.read_text(encoding="utf-8"), "ORIGINAL")

    def test_blank_or_overlong_title_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            for title, suffix in [(" ", "a"), ("X" * 81, "b")]:
                dest = base / suffix
                result = self.run_generator(title, dest)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(dest.exists())


if __name__ == "__main__":
    unittest.main()
