#!/usr/bin/env python3
"""Run with python3 scripts/test-visual-review.py."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("visual_review", Path(__file__).with_name("visual-review.py"))
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)


class VisualReviewTests(unittest.TestCase):
    def sample(self):
        return {"score": 4, "summary": "窮屈です", "findings": [
            {"area": "隅", "issue": "狭い", "severity": severity, "suggestion": "余白を増やす"}
            for severity in ["low", "high", "medium"]]}

    def test_report_sorting_and_empty_and_error(self):
        report = review.build_report({"home": self.sample(), "empty": {
            "score": 10, "summary": "良い", "findings": []}, "broken": {"error": "HTTP 500"}})
        self.assertLess(report.index("**high"), report.index("**medium"))
        self.assertLess(report.index("**medium"), report.index("**low"))
        self.assertIn("指摘なし", report)
        self.assertIn("HTTP 500", report)

    def test_mock_and_threshold(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "home.png").write_bytes(b"mock skips image decoding")
            mock = root / "mock.json"
            mock.write_text(json.dumps(self.sample()))
            args = [str(root), "--mock", str(mock), "--out", str(root / "report.md"), "--json", str(root / "report.json")]
            with patch.object(review.urllib.request, "urlopen", side_effect=AssertionError("Network used")):
                self.assertEqual(review.main(args), 0)
                self.assertEqual(review.main(args + ["--fail-on", "high"]), 1)
            self.assertIn("home", json.loads((root / "report.json").read_text())["screens"])

    def test_missing_key(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True):
            root = Path(directory)
            self.assertEqual(review.main([str(root), "--out", str(root / "r.md"), "--json", str(root / "r.json")]), 0)
            self.assertIn("スキップ", (root / "r.md").read_text())

    def test_invalid_mock_is_per_image_error(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "a.png").touch()
            (root / "b.png").touch()
            (root / "mock.json").write_text("{}")
            self.assertEqual(review.main([str(root), "--mock", str(root / "mock.json"), "--out", str(root / "r.md"), "--json", str(root / "r.json")]), 0)
            self.assertEqual(len(json.loads((root / "r.json").read_text())["screens"]), 2)


if __name__ == "__main__":
    unittest.main()
