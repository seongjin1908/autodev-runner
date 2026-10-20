#!/usr/bin/env python3
"""Offline checks for manually opted-in zero-priced OpenRouter coding lane."""
from pathlib import Path
import os
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=(ROOT/"scripts/openrouter_free_fallback.sh").read_text(encoding="utf-8")
WF=(ROOT/".github/workflows/autodev.yml").read_text(encoding="utf-8")

class OpenRouterNoCostTests(unittest.TestCase):
    def invoke(self, enabled, key="", model=None):
        env={k:v for k,v in os.environ.items()
             if k not in ("OPENROUTER_API_KEY","AUTODEV_OPENROUTER_FREE_MODEL","AUTODEV_OPENROUTER_FREE_ENABLED")}
        env["AUTODEV_OPENROUTER_FREE_ENABLED"]=enabled
        if key: env["OPENROUTER_API_KEY"]=key
        if model: env["AUTODEV_OPENROUTER_FREE_MODEL"]=model
        return subprocess.run(["bash",str(ROOT/"scripts/openrouter_free_fallback.sh")],
                              cwd=ROOT,env=env,capture_output=True,text=True,timeout=4)

    def test_disabled_or_key_absent_never_calls_provider(self):
        a=self.invoke("false","dummy-not-real-key")
        self.assertEqual(a.returncode,0,a.stderr)
        self.assertIn("disabled",a.stdout)
        b=self.invoke("true")
        self.assertEqual(b.returncode,0,b.stderr)
        self.assertIn("secret is absent",b.stdout)

    def test_paid_or_unknown_model_rejected_before_checkout(self):
        for model in ("openrouter/anthropic/claude-4","openrouter/minimax/minimax-m3.1-flash",
                      "groq/openai/gpt-oss-120b","deepseek/deepseek-chat"):
            with self.subTest(model=model):
                result=self.invoke("true","dummy-not-real-key",model)
                self.assertEqual(result.returncode,2,result.stdout+result.stderr)
                self.assertIn("Unapproved OpenRouter model",result.stdout)

    def test_workflow_never_exposes_key_to_untrusted_install_or_cron(self):
        name="      - name: Optional manual-only OpenRouter zero-priced coding fallback"
        self.assertEqual(WF.count(name),1)
        before,after=WF.split(name)
        self.assertNotIn("OPENROUTER_API_KEY:",before)
        self.assertIn("github.event_name == 'workflow_dispatch'",after.split("      - name:",1)[0])
        self.assertIn("vars.AUTODEV_OPENROUTER_FREE_ENABLED == 'true'",after)
        self.assertEqual(WF.count("secrets.AUTODEV_OPENROUTER_FREE_API_KEY"),1)
        self.assertLess(WF.index("run: bash scripts/develop_target.sh"),
                        WF.index("run: bash scripts/openrouter_free_fallback.sh"))
        self.assertLess(WF.index("run: bash scripts/openrouter_free_fallback.sh"),
                        WF.index("run: bash scripts/gemini_free_fallback.sh"))

    def test_agent_is_free_only_and_not_allowed_to_run_shell(self):
        for model in ("openrouter/minimax/minimax-m3.1-flash:free",
                      "openrouter/cohere/north-mini-code:free",
                      "openrouter/qwen/qwen3-coder:free"):
            self.assertIn(model,SCRIPT)
        self.assertIn('"bash":"deny"',SCRIPT)
        self.assertIn('"external_directory":"deny"',SCRIPT)
        self.assertIn('"webfetch":"deny"',SCRIPT)
        self.assertIn('"task":"deny"',SCRIPT)
        self.assertIn('unset OPENROUTER_API_KEY OPENCODE_CONFIG_CONTENT',SCRIPT)
        self.assertIn('scripts/prepare_gemini_handoff.sh',SCRIPT)
        self.assertIn('git diff --check',SCRIPT)
        self.assertIn('VALIDATION_B64',SCRIPT)
        self.assertIn('BATCH_READY=true',SCRIPT)
        self.assertIn('restore_clean',SCRIPT)
        self.assertNotIn('--yolo',SCRIPT)
        self.assertNotIn('GROQ_API_KEY',SCRIPT)

if __name__=="__main__":
    unittest.main()
