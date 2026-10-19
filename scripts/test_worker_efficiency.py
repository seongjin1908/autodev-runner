#!/usr/bin/env python3
"""Guard that public-runner cache/artifacts contain no private repository source."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
WORKFLOWS=(
    ".github/workflows/autodev.yml",
    ".github/workflows/launch-sprint.yml",
    ".github/workflows/saju-global-fast-autodev.yml",
    ".github/workflows/creative-studio-fast-autodev.yml",
)


class SafeWorkerArtifacts(unittest.TestCase):
    def test_only_isolated_public_cli_cache(self):
        for path in WORKFLOWS:
            with self.subTest(path=path):
                workflow=(ROOT/path).read_text(encoding="utf-8")
                self.assertEqual(workflow.count("uses: actions/cache@v4"),1)
                self.assertIn("path: ${{ runner.temp }}/autodev-public-cli-npm-cache",workflow)
                self.assertNotIn("path: ~/.npm",workflow)
                cache_section=workflow.split("      - name: Restore PUBLIC coding CLI download cache",1)[1]
                cache_section=cache_section.split("      - name: Prepare collision and failure-hold guard",1)[0]
                self.assertNotIn("path: target",cache_section)
                self.assertNotIn("~/.npm",cache_section.replace("# Critical: NEVER cache ~/.npm, target deps, or private source in this public controller.", ""))
                self.assertIn("key: public-cli-npm-v1-",workflow)

    def test_only_sanitized_data_in_short_retention_artifact(self):
        for path in WORKFLOWS:
            with self.subTest(path=path):
                workflow=(ROOT/path).read_text(encoding="utf-8")
                self.assertEqual(workflow.count("uses: actions/upload-artifact@v4"),1)
                self.assertIn("path: ${{ runner.temp }}/autodev-model-metrics.jsonl",workflow)
                self.assertIn("retention-days: 3",workflow)
                self.assertIn("if-no-files-found: ignore",workflow)
        for path in ("scripts/develop_target.sh","scripts/gemini_free_fallback.sh"):
            content=(ROOT/path).read_text(encoding="utf-8")
            self.assertIn('--cache "${RUNNER_TEMP:-/tmp}/autodev-public-cli-npm-cache"',content)

    def test_task_and_metrics_are_used_by_free_worker(self):
        content=(ROOT/"scripts/develop_target.sh").read_text(encoding="utf-8")
        self.assertIn("scripts/select_task_slice.py",content)
        self.assertIn("scripts/model_metrics.py",content)
        self.assertIn("autodev-model-metrics.jsonl",content)
        self.assertIn("--result validated",content)
        self.assertIn("--result attempt",content)


if __name__=="__main__":
    unittest.main()
