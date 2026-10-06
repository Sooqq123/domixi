from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from tools.submission.package_tkvm import build_zip, stage_submission, write_manifest
from tools.submission.tkvm_manifest import ArtifactSpec, sha256_file


class PackageTkvmTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temporary.name)
        self.output_root = self.repo_root / "output/submission/tkvm-2026"
        self.archive_path = self.repo_root / "output/submission/tkvm-2026-submission.zip"
        self.source = self.repo_root / "rtl/top.v"
        self.source.parent.mkdir(parents=True)
        self.source.write_text("module top; endmodule\n", encoding="utf-8")
        self.source = self.source.resolve()
        self.inventory = [
            ArtifactSpec(Path("source/rtl/rtl/top.v"), self.source, "rtl", "TEST")
        ]

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_copy_preserves_sha256_and_manifest_is_sorted(self) -> None:
        with patch("tools.submission.package_tkvm.build_inventory", return_value=self.inventory):
            result = stage_submission(self.repo_root, self.output_root)
        write_manifest(result)
        for record in result.records:
            self.assertEqual(record.sha256, sha256_file(record.staged_path))
        paths = [record.relative_path.as_posix() for record in result.records]
        self.assertEqual(paths, sorted(paths))

    def test_unlisted_file_is_not_copied(self) -> None:
        (self.repo_root / "debug.tmp").write_text("debug", encoding="utf-8")
        with patch("tools.submission.package_tkvm.build_inventory", return_value=self.inventory):
            stage_submission(self.repo_root, self.output_root)
        self.assertFalse((self.output_root / "debug.tmp").exists())

    def test_zip_does_not_contain_itself(self) -> None:
        with patch("tools.submission.package_tkvm.build_inventory", return_value=self.inventory):
            result = stage_submission(self.repo_root, self.output_root)
        write_manifest(result)
        archive = build_zip(self.output_root, self.archive_path)
        with zipfile.ZipFile(archive) as zip_file:
            self.assertNotIn(archive.name, zip_file.namelist())
            self.assertTrue(all(name.startswith("tkvm-2026/") for name in zip_file.namelist()))

    def test_refuses_unexpected_output_directory(self) -> None:
        with patch("tools.submission.package_tkvm.build_inventory", return_value=self.inventory):
            with self.assertRaises(ValueError):
                stage_submission(self.repo_root, self.repo_root / "other")
