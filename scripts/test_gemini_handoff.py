#!/usr/bin/env python3
"""Regression tests for safe OpenCode -> Gemini fallback in ephemeral Actions."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HANDOFF = ROOT / "scripts" / "prepare_gemini_handoff.sh"
FALLBACK = (ROOT / "scripts" / "gemini_free_fallback.sh").read_text()


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args],
                          capture_output=True, text=True, check=True).stdout.strip()


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.email", "test@example.invalid")
        git(self.repo, "config", "user.name", "Unit Test")
        (self.repo / "app.py").write_text("original = True\n")
        git(self.repo, "add", "app.py")
        git(self.repo, "commit", "-qm", "baseline")
        self.sha = git(self.repo, "rev-parse", "HEAD")

    def handoff(self, sha=None):
        env = os.environ.copy()
        env["START_SHA"] = sha or self.sha
        return subprocess.run(["bash", str(HANDOFF)], cwd=self.repo,
                              env=env, text=True, capture_output=True)

    def test_partial_code_and_untracked_provider_files_rolled_back(self):
        (self.repo / "app.py").write_text("unsafe = True\n")
        (self.repo / "model-scratch.txt").write_text("discard me")
        (self.repo / "node_modules").mkdir()
        (self.repo / "node_modules" / "installed.js").write_text("reuse deps")
        result = self.handoff()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.repo / "app.py").read_text(), "original = True\n")
        self.assertFalse((self.repo / "model-scratch.txt").exists())
        self.assertTrue((self.repo / "node_modules" / "installed.js").exists())
        self.assertEqual(git(self.repo, "status", "--porcelain"), "")
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), self.sha)

    def test_cannot_reset_a_new_commit(self):
        (self.repo / "app.py").write_text("new = True\n")
        git(self.repo, "commit", "-qam", "external update")
        result = self.handoff()
        self.assertEqual(result.returncode, 2)
        self.assertEqual((self.repo / "app.py").read_text(), "new = True\n")

    def test_never_delete_unreviewed_credentials_or_cli_project_rules(self):
        for marker in (".env", ".gemini", ".mcp.json"):
            with self.subTest(marker=marker):
                p = self.repo / marker
                p.write_text("keep protected data")
                (self.repo / "app.py").write_text("dirty\n")
                result = self.handoff()
                self.assertEqual(result.returncode, 3)
                self.assertTrue(p.exists())
                self.assertEqual((self.repo / "app.py").read_text(), "dirty\n")
                p.unlink()
                git(self.repo, "restore", "app.py")

    def test_controller_is_called_before_gemini_or_provider_secret_use(self):
        self.assertIn('bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"', FALLBACK)
        self.assertLess(
            FALLBACK.index('bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"'),
            FALLBACK.index("npm install --cache"))
        self.assertIn('if ! bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"; then', FALLBACK)
        self.assertIn('git diff --check', FALLBACK)


if __name__ == "__main__":
    unittest.main()
