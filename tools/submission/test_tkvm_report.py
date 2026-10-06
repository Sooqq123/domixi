from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.submission.build_tkvm_report import build_report
from tools.submission.verify_tkvm_report import verify_pdf


class TkvmReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_root = Path(__file__).resolve().parents[2]
        cls.temporary = tempfile.TemporaryDirectory()
        cls.pdf_path = Path(cls.temporary.name) / "tkvm-report.pdf"
        build_report(
            cls.repo_root,
            cls.repo_root / "docs/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.md",
            cls.pdf_path,
        )
        cls.result = verify_pdf(cls.pdf_path)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def test_required_sections_and_values_exist(self) -> None:
        self.assertEqual(self.result.missing_text, ())

    def test_every_page_has_content_and_is_a4(self) -> None:
        self.assertEqual(self.result.blank_pages, ())
        self.assertEqual(self.result.non_a4_pages, ())

    def test_no_unfinished_markers_or_long_dashes(self) -> None:
        self.assertEqual(self.result.forbidden_matches, ())

    def test_report_page_count_is_competition_sized(self) -> None:
        self.assertGreaterEqual(self.result.page_count, 10)
        self.assertLessEqual(self.result.page_count, 18)
