#!/usr/bin/env python3
"""No-network regression for current Gemini CLI headless configuration schema.

See official Gemini CLI docs, which specify hooksConfig.enabled (NOT hooks.enabled):
https://geminicli.com/docs/cli/settings/
"""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "scripts/gemini_free_fallback.sh").read_text(encoding="utf-8")


class GeminiSettingsSchemaTests(unittest.TestCase):
    def settings(self):
        marker = 'cat > "$SAFE_HOME/.gemini/settings.json" <<\'SETTINGS\'\n'
        self.assertIn(marker, SCRIPT, "Cannot locate generated clean HOME settings")
        start = SCRIPT.index(marker) + len(marker)
        end = SCRIPT.index("\nSETTINGS", start)
        return json.loads(SCRIPT[start:end])

    def test_current_schema_and_security(self):
        settings = self.settings()
        self.assertEqual(settings["hooksConfig"], {"enabled": False})
        self.assertNotIn("enabled", settings.get("hooks", {}))
        self.assertNotIn("hooks", settings)
        self.assertEqual(settings["security"]["disableYoloMode"], True)
        self.assertEqual(settings["security"]["folderTrust"]["enabled"], True)
        self.assertEqual(settings["general"]["enableAutoUpdate"], False)
        self.assertEqual(settings["tools"]["core"],
                         ["read_file", "write_file", "replace", "list_directory", "glob", "grep_search"])
        self.assertNotIn("run_shell_command", settings["tools"]["core"])
        self.assertNotIn("mcpServers", settings)

    def test_local_no_key_preflight_before_any_model_call(self):
        self.assertIn("gemini \\\n  --skip-trust --extensions none --list-extensions", SCRIPT)
        self.assertIn("env -u GEMINI_API_KEY -u GOOGLE_API_KEY HOME=", SCRIPT)
        self.assertLess(SCRIPT.index("gemini \\\n  --skip-trust --extensions none --list-extensions"),
                        SCRIPT.index('echo "Starting opt-in Gemini free-tier fallback'))
        self.assertIn("Gemini local CLI configuration check failed", SCRIPT)
        self.assertIn("no API request made.", SCRIPT)
        self.assertIn("GEMINI_TIMEOUT_SECONDS=180", SCRIPT)
        self.assertIn("git diff --check", SCRIPT)
        self.assertIn("BATCH_READY=true", SCRIPT)

    def test_source_checkout_and_budget_guards(self):
        self.assertIn('AUTODEV_GEMINI_FREE_ENABLED:-false', SCRIPT)
        self.assertIn('GEMINI_API_KEY:-', SCRIPT)
        self.assertIn('bash "$ROOT_DIR/scripts/prepare_gemini_handoff.sh"', SCRIPT)
        self.assertIn('gemini-2.5-flash|gemini-2.5-flash-lite', SCRIPT)
        self.assertIn("--approval-mode auto_edit", SCRIPT)
        self.assertNotIn("--approval-mode yolo", SCRIPT)
        self.assertIn("--extensions none", SCRIPT)


if __name__ == "__main__":
    unittest.main()
