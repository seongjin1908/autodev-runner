"""Regression: free-model source picker must only touch Partner Hub code."""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "direct_partner_picker", ROOT / "scripts" / "openrouter_direct_patch.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PartnerHubSourcePickerTests(TestCase):
    def test_partner_hub_picks_nested_application_code(self):
        with TemporaryDirectory() as dirname:
            root = Path(dirname)
            target = root / "partner-hub/integrations/merchant-outbox.mjs"
            target.parent.mkdir(parents=True)
            target.write_text("export const safe = true;\n" * 45, encoding="utf-8")
            with patch.object(
                MODULE.subprocess,
                "check_output",
                return_value=b"src/unrelated.js\x00partner-hub/integrations/merchant-outbox.mjs\x00",
            ):
                name, content = MODULE.candidate_file(root, "coston-partner-hub")
            self.assertEqual(name, "partner-hub/integrations/merchant-outbox.mjs")
            self.assertIn("safe", content)

    def test_partner_hub_never_falls_back_to_unrelated_ddd_source(self):
        with TemporaryDirectory() as dirname:
            root = Path(dirname)
            path = root / "src/unrelated.js"
            path.parent.mkdir(parents=True)
            path.write_text("export const unrelated = true;\n" * 40, encoding="utf-8")
            with patch.object(
                MODULE.subprocess,
                "check_output",
                return_value=b"src/unrelated.js\x00",
            ):
                with self.assertRaisesRegex(MODULE.SafeBlock, "no_small_approved_source"):
                    MODULE.candidate_file(root, "coston-partner-hub")

    def test_rejects_tiny_or_untracked_files(self):
        with TemporaryDirectory() as dirname:
            root = Path(dirname)
            target = root / "partner-hub/integrations/merchant-outbox.mjs"
            target.parent.mkdir(parents=True)
            target.write_text("x", encoding="utf-8")
            with patch.object(
                MODULE.subprocess,
                "check_output",
                return_value=b"partner-hub/integrations/merchant-outbox.mjs\x00",
            ):
                with self.assertRaisesRegex(MODULE.SafeBlock, "no_small_approved_source"):
                    MODULE.candidate_file(root, "coston-partner-hub")


if __name__ == "__main__":
    import unittest

    unittest.main()
