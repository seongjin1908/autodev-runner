#!/usr/bin/env python3
"""Offline release-focus tests: preserve cadence and skip duplicate PR/model work."""
from pathlib import Path
import base64
import json
import os
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
PROJECTS=json.loads((ROOT/"config/projects.json").read_text())["projects"]

class ReleaseFocusTests(unittest.TestCase):
    def test_release_focus_preserves_all_targets_and_saju_lock(self):
        enabled=[p for p in PROJECTS if p.get("auto_enabled") and int(p.get("auto_weight",0))>0
                 and not p.get("dedicated_schedule_only",False)]
        focus=sum(p["auto_weight"] for p in enabled if p["alias"] in {"pricecam","fault-intel"})
        total=sum(p["auto_weight"] for p in enabled)
        self.assertGreaterEqual(focus/total,0.7)
        self.assertEqual(sum(p.get("auto_enabled",False) for p in PROJECTS),13)
        for p in PROJECTS:
            if p["repository"]=="seongjin1908/daangn-saju-autodev":
                self.assertFalse(p["auto_enabled"])
                self.assertTrue(p.get("external_worker_lock"))
        wf=(ROOT/".github/workflows/autodev.yml").read_text()
        self.assertIn("cron: '17,47 * * * *'",wf)

    def test_selection_skips_existing_generated_prs(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp=Path(directory)
            mock=tmp/"gh"
            mock.write_text("""#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "list" ]]; then
  repo=""
  while (( $# > 0 )); do
    if [[ "$1" == "-R" ]]; then repo="$2"; break; fi
    shift
  done
  case "$repo" in
    seongjin1908/pricecam-autodev) echo '[{"headRefName":"autodev/pricecam/pending"}]' ;;
    seongjin1908/fault-intelligence) echo '[{"headRefName":"autodev/fault-intel/pending"}]' ;;
    *) echo '[]' ;;
  esac
  exit 0
fi
if [[ "$1" == "api" ]]; then
  case "$2" in
    repos/*/commits/*) echo '2025-01-01T00:00:00Z'; exit 0 ;;
    repos/*/git/ref/*) echo '0123456789abcdef0123456789abcdef01234567'; exit 0 ;;
    repos/*) echo 'true'; exit 0 ;;
  esac
fi
exit 6
""")
            mock.chmod(0o700)
            output=tmp/"out"
            env=dict(os.environ,GH_TOKEN="synthetic-gh-test-no-network",
                     TARGET="auto",GITHUB_OUTPUT=str(output),
                     PATH=str(tmp)+":"+os.environ["PATH"],
                     GITHUB_RUN_ID="1234",GITHUB_RUN_ATTEMPT="1")
            p=subprocess.run(["bash",str(ROOT/"scripts/select_target.sh")],
                             cwd=ROOT,env=env,text=True,capture_output=True,timeout=20)
            self.assertEqual(p.returncode,0,p.stderr[-1200:])
            self.assertNotIn("Selected target: pricecam",p.stdout)
            self.assertNotIn("Selected target: fault-intel",p.stdout)
            self.assertNotIn("Selected target: saju",p.stdout)
            self.assertIn("alias=",output.read_text())

    def test_direct_fast_path_skips_expensive_opencode(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp=Path(directory)
            dest=ROOT/"target"
            self.assertFalse(dest.exists(),"Cannot overwrite preexisting checkout in CI")
            dest.mkdir()
            try:
                env=dict(os.environ,
                         GITHUB_ENV=str(tmp/"env"),
                         GITHUB_STEP_SUMMARY=str(tmp/"summary"),
                         RUNNER_TEMP=str(tmp),
                         ALIAS="pricecam",
                         VALIDATION_B64=base64.b64encode(b"true").decode("ascii"),
                         PROMPT_FILE="prompts/pricecam.md",
                         AUTODEV_DIRECT_FREE_ONLY="true")
                p=subprocess.run(["bash",str(ROOT/"scripts/develop_target.sh")],
                                 cwd=ROOT,env=env,text=True,capture_output=True,timeout=15)
                self.assertEqual(p.returncode,0,p.stderr[-1200:]+p.stdout[-1200:])
                self.assertIn("skipped OpenCode installation",p.stdout)
                self.assertIn("AUTODEV_FAILURE_REASON=direct_provider_pending",(tmp/"env").read_text())
                self.assertTrue((Path("/tmp")/"autodev-prompt.txt").exists())
            finally:
                dest.rmdir()

if __name__=="__main__":
    unittest.main()
