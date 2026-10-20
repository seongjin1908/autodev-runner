#!/usr/bin/env python3
"""Offline proof that direct free coding cannot select paid models or unsafe paths."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("direct",HERE/"openrouter_direct_patch.py")
direct=importlib.util.module_from_spec(spec)
spec.loader.exec_module(direct)

class DirectFreeCodingTests(unittest.TestCase):
    def test_free_price_must_be_zero_for_both_directions(self):
        good={"data":[{"id":"minimax/minimax-m3.1-flash:free",
                       "pricing":{"prompt":"0","completion":"0"}}]}
        direct.zero_priced(good,"minimax/minimax-m3.1-flash:free")
        for val in ("0.0000001", "1"):
            with self.subTest(price=val):
                bad={"data":[{"id":"minimax/minimax-m3.1-flash:free",
                               "pricing":{"prompt":"0","completion":val}}]}
                with self.assertRaises(direct.SafeBlock): direct.zero_priced(bad,"minimax/minimax-m3.1-flash:free")
        with self.assertRaises(direct.SafeBlock): direct.zero_priced({"data":[]},"minimax/minimax-m3.1-flash:free")

    def test_reject_unknown_path_comments_only_and_invalid_schema(self):
        original="export const safe = (s: string) => s.trim();\n"
        def msg(path,content,reason="Fix demonstrable unchecked URL input"):
            import json
            return {"choices":[{"message":{"content":json.dumps({"path":path,"content":content,"reason":reason})}}]}
        with self.assertRaises(direct.SafeBlock):
            direct.interpret(msg("../.env",original+"x"),"backend/affiliate.ts",original)
        with self.assertRaises(direct.SafeBlock):
            direct.interpret(msg("backend/affiliate.ts","// note\n"+original),"backend/affiliate.ts",original)
        self.assertIn("if (!s)",direct.interpret(
            msg("backend/affiliate.ts","export const safe = (s: string) => { if (!s) return ''; return s.trim(); };\n"),
            "backend/affiliate.ts",original))

    def test_github_private_rules_skipped_but_source_selectable(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            subprocess.run(["git","init","-q",d],check=True,capture_output=True)
            for name in ("backend/affiliate.ts",".agents/skills/REA.md",".env"):
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True)
                p.write_text("export const safe = true;\n"+"a"*650+"\n",encoding="utf8")
            subprocess.run(["git","-C",d,"add","."],check=True,capture_output=True)
            cwd=Path.cwd()
            try:
                os.chdir(root)
                name,content=direct.candidate_file(root,"pricecam")
                self.assertEqual(name,"backend/affiliate.ts")
                self.assertIn("export const safe",content)
            finally:
                os.chdir(cwd)

    def test_direct_api_called_once_and_only_existing_file_writable(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            source="export function checkUrl(value: string) {\n return value.trim();\n}\n"+"// security review\n"*35
            target=root/"backend"/"affiliate.ts"
            target.parent.mkdir(parents=True)
            target.write_text(source,encoding="utf8")
            subprocess.run(["git","init","-q",d],check=True,capture_output=True)
            subprocess.run(["git","-C",d,"add","."],check=True,capture_output=True)
            fixed=source.replace("return value.trim();","return value.startsWith('https://') ? value.trim() : '';")
            response={"choices":[{"message":{"content":__import__("json").dumps({"path":"backend/affiliate.ts","content":fixed,"reason":"Reject non-HTTPS links in supplied code"})}}]}
            invocations=[]
            def fake_request(url,payload=None,key=None,timeout=30):
                invocations.append(url)
                if url.endswith("/models"):
                    return {"data":[{"id":"minimax/minimax-m3.1-flash:free","pricing":{"prompt":"0","completion":"0"}}]}
                self.assertEqual(payload["model"],"minimax/minimax-m3.1-flash:free")
                self.assertEqual(key,"synthetic-only-never-real")
                return response
            cwd=Path.cwd()
            try:
                os.chdir(root)
                with patch.dict(os.environ,{"OPENROUTER_API_KEY":"synthetic-only-never-real","ALIAS":"pricecam",
                                             "AUTODEV_OPENROUTER_FREE_MODEL":"openrouter/minimax/minimax-m3.1-flash:free"}):
                    with patch.object(direct,"request_json",side_effect=fake_request):
                        self.assertEqual(direct.run(),"backend/affiliate.ts")
                self.assertEqual(target.read_text(),fixed)
                self.assertEqual(len(invocations),2)
            finally:
                os.chdir(cwd)

    def test_code_path_does_not_call_shell_or_write_credentials(self):
        content=(HERE/"openrouter_direct_patch.py").read_text()
        self.assertNotIn("shell=True",content)
        self.assertNotIn("eval(",content)
        self.assertNotIn("exec(",content.replace("spec.loader.exec_module", ""))
        sh=(HERE/"openrouter_free_fallback.sh").read_text()
        self.assertIn('AUTODEV_OPENROUTER_DIRECT_FIRST:-false',sh)
        self.assertIn('openrouter_direct_patch.py',sh)
        self.assertIn('unset OPENROUTER_API_KEY',sh)

if __name__=="__main__":
    unittest.main()
