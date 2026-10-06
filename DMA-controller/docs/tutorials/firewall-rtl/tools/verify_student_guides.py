#!/usr/bin/env python3
"""Structural verification for the generated Firewall RTL student guides."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import pdfplumber
from pypdf import PdfReader


OUTPUTS = (
    "01_fw_apb_regs_lab_guide.pdf",
    "02_fw_acl_matcher_lab_guide.pdf",
    "03_fw_write_drain_lab_guide.pdf",
    "04_fw_read_drain_lab_guide.pdf",
)

FORBIDDEN = ("PLACEHOLDER", "[[CHƯA", "<FILL>", "LOREM IPSUM")


def verify_pdf(path: Path) -> dict[str, int]:
    if not path.exists():
        raise AssertionError(f"Thiếu PDF: {path}")
    if path.stat().st_size < 50 * 1024:
        raise AssertionError(f"PDF quá nhỏ: {path.stat().st_size} bytes")

    reader = PdfReader(str(path))
    if len(reader.pages) <= 10:
        raise AssertionError(f"PDF quá ngắn: {len(reader.pages)} trang")

    blank_pages = []
    all_text = []
    with pdfplumber.open(path) as pdf:
        for page_number, page in enumerate(pdf.pages, start=1):
            width, height = float(page.width), float(page.height)
            if abs(width - 595.276) > 2 or abs(height - 841.89) > 2:
                raise AssertionError(f"Trang {page_number} không phải A4: {width}x{height}")
            text = page.extract_text() or ""
            all_text.append(text)
            if len(re.sub(r"\s+", "", text)) < 12:
                blank_pages.append(page_number)

    if blank_pages:
        raise AssertionError(f"Trang rỗng: {blank_pages}")
    joined = "\n".join(all_text)
    if len(joined) < 5000:
        raise AssertionError(f"Text extract quá ngắn: {len(joined)} ký tự")
    upper = joined.upper()
    found = [token for token in FORBIDDEN if token in upper]
    if found:
        raise AssertionError(f"Còn marker chưa hoàn thiện: {found}")

    return {"pages": len(reader.pages), "characters": len(joined), "bytes": path.stat().st_size}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[5])
    args = parser.parse_args()
    output_dir = args.repo_root.resolve() / "output/pdf"
    for name in OUTPUTS:
        result = verify_pdf(output_dir / name)
        print(f"PASS {name}: {result['pages']} pages, {result['characters']} chars, {result['bytes']} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
