#!/usr/bin/env python3
"""Verify the 60-minute Verilog RTL foundation lesson and generated PDF."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import pdfplumber
from pypdf import PdfReader


SOURCE = Path(
    "DMA-controller/docs/tutorials/firewall-rtl/foundation/"
    "00_verilog_rtl_foundation_60min.md"
)
OUTPUT = Path("output/pdf/00_verilog_rtl_foundation_60min.pdf")

EXPECTED_SLOTS = (
    (0, 5),
    (5, 13),
    (13, 22),
    (22, 33),
    (33, 41),
    (41, 50),
    (50, 56),
    (56, 60),
)

REQUIRED_CODE_TOKENS = (
    "module",
    "wire",
    "reg",
    "assign",
    "always @(*)",
    "always @(posedge clk)",
    "localparam",
    "case",
)

FORBIDDEN_CODE_PATTERNS = (
    r"\blogic\b",
    r"\balways_comb\b",
    r"\balways_ff\b",
    r"\btypedef\b",
    r"\benum\b",
    r"\binterface\b",
)

FORBIDDEN_SOURCE_PATTERNS = (
    r"\bfw_",
    r"\bacl_",
    r"\bAPB\b",
    r"\bAXI\b",
    r"\bDMA\b",
)

REQUIRED_HEADINGS = (
    "# Giáo án cho giảng viên",
    "# Phút 0-5: Từ sơ đồ mạch sang RTL",
    "# Phút 5-13: Cấu trúc module và tín hiệu",
    "# Phút 13-22: Logic tổ hợp",
    "# Phút 22-33: Logic tuần tự",
    "# Phút 33-41: Blocking và nonblocking",
    "# Phút 41-50: Bộ đếm",
    "# Phút 41-50: FSM bằng Verilog-2001",
    "# Phút 50-56: Tư duy RTL có thể tổng hợp",
    "# Phút 56-60: Tổng kết đứng lớp",
    "## Bảng tra cứu Verilog-2001 một trang",
    "## Câu hỏi kiểm tra cuối tiết",
    "## Kiến thức cần tự ôn trước bài thực hành",
)


def verify_schedule(source_text: str) -> int:
    """Return the lesson duration after checking contiguous schedule slots."""
    slots = tuple(
        (int(start), int(end))
        for start, end in re.findall(
            r"^\|\s*(\d+)-(\d+)\s*phút\s*\|", source_text, re.MULTILINE
        )
    )
    if slots != EXPECTED_SLOTS:
        raise AssertionError(f"Lịch học không đúng tám khoảng đã duyệt: {slots}")
    if not all(left[1] == right[0] for left, right in zip(slots, slots[1:])):
        raise AssertionError("Lịch học có khoảng hở hoặc chồng thời gian")
    duration = sum(end - start for start, end in slots)
    if duration != 60:
        raise AssertionError(f"Tổng thời lượng phải là 60, nhận được {duration}")
    return duration


def extract_verilog_blocks(source_text: str) -> list[str]:
    """Extract fenced Verilog examples from Markdown."""
    return re.findall(r"```verilog\s*\n(.*?)```", source_text, re.DOTALL)


def verify_source(source_path: Path) -> dict[str, int]:
    """Check scope, structure, examples, questions, and lesson duration."""
    if not source_path.exists():
        raise AssertionError(f"Thiếu source: {source_path}")
    source_text = source_path.read_text(encoding="utf-8")
    if len(source_text) < 8_000:
        raise AssertionError(f"Source quá ngắn: {len(source_text)} ký tự")

    for heading in REQUIRED_HEADINGS:
        if heading not in source_text:
            raise AssertionError(f"Thiếu heading: {heading}")

    for marker in ("TBD", "TODO", "PLACEHOLDER", "LOREM IPSUM"):
        if marker in source_text.upper():
            raise AssertionError(f"Còn marker chưa hoàn thiện: {marker}")

    for forbidden in ("\u2013", "\u2014", " -- "):
        if forbidden in source_text:
            raise AssertionError(f"Có dấu gạch không hợp lệ: {forbidden!r}")

    for pattern in FORBIDDEN_SOURCE_PATTERNS:
        match = re.search(pattern, source_text, re.IGNORECASE)
        if match:
            raise AssertionError(f"Có nội dung riêng của dự án: {match.group(0)}")

    code_blocks = extract_verilog_blocks(source_text)
    if len(code_blocks) < 5:
        raise AssertionError(f"Cần ít nhất năm code block Verilog, có {len(code_blocks)}")
    joined_code = "\n".join(code_blocks)
    for token in REQUIRED_CODE_TOKENS:
        if token not in joined_code:
            raise AssertionError(f"Thiếu mẫu Verilog bắt buộc: {token}")
    for pattern in FORBIDDEN_CODE_PATTERNS:
        match = re.search(pattern, joined_code)
        if match:
            raise AssertionError(f"Có cú pháp ngoài Verilog-2001: {match.group(0)}")

    quiz_numbers = re.findall(r"^### Câu ([1-6])$", source_text, re.MULTILINE)
    if quiz_numbers != ["1", "2", "3", "4", "5", "6"]:
        raise AssertionError(f"Cần đúng sáu câu hỏi theo thứ tự, nhận được {quiz_numbers}")

    duration = verify_schedule(source_text)
    return {
        "characters": len(source_text),
        "code_blocks": len(code_blocks),
        "duration": duration,
        "questions": len(quiz_numbers),
    }


def _find_page(page_texts: list[str], needle: str) -> int:
    matches = [index for index, text in enumerate(page_texts) if needle in text]
    if len(matches) != 1:
        raise AssertionError(f"Heading {needle!r} xuất hiện trên các trang {matches}")
    return matches[0]


def verify_pdf(pdf_path: Path) -> dict[str, int]:
    """Check A4 geometry, extractability, page content, and handout pagination."""
    if not pdf_path.exists():
        raise AssertionError(f"Thiếu PDF: {pdf_path}")
    file_size = pdf_path.stat().st_size
    if file_size < 50 * 1024:
        raise AssertionError(f"PDF quá nhỏ: {file_size} bytes")

    reader = PdfReader(str(pdf_path))
    if len(reader.pages) < 10:
        raise AssertionError(f"PDF quá ngắn: {len(reader.pages)} trang")

    page_texts: list[str] = []
    blank_pages: list[int] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page_number, page in enumerate(pdf.pages, start=1):
            width, height = float(page.width), float(page.height)
            if abs(width - 595.276) > 2 or abs(height - 841.89) > 2:
                raise AssertionError(
                    f"Trang {page_number} không phải A4: {width:.2f}x{height:.2f}"
                )
            text = page.extract_text() or ""
            page_texts.append(text)
            if len(re.sub(r"\s+", "", text)) < 12:
                blank_pages.append(page_number)

    if blank_pages:
        raise AssertionError(f"Có trang rỗng: {blank_pages}")
    all_text = "\n".join(page_texts)
    if len(all_text) < 8_000:
        raise AssertionError(f"Text extract quá ngắn: {len(all_text)} ký tự")
    for pattern in FORBIDDEN_SOURCE_PATTERNS:
        match = re.search(pattern, all_text, re.IGNORECASE)
        if match:
            raise AssertionError(f"PDF chứa nội dung riêng của dự án: {match.group(0)}")

    quick_reference_page = _find_page(
        page_texts, "Bảng tra cứu Verilog-2001 một trang"
    )
    quiz_page = _find_page(page_texts, "Câu hỏi kiểm tra cuối tiết")
    if quiz_page != quick_reference_page + 1:
        raise AssertionError(
            "Bảng tra cứu không nằm gọn trên một trang riêng: "
            f"trang {quick_reference_page + 1} đến {quiz_page + 1}"
        )

    return {
        "bytes": file_size,
        "characters": len(all_text),
        "pages": len(reader.pages),
        "quick_reference_page": quick_reference_page + 1,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[5]
    )
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    source_result = verify_source(repo_root / SOURCE)
    pdf_result = verify_pdf(repo_root / OUTPUT)
    print(
        "PASS "
        f"duration={source_result['duration']} "
        f"questions={source_result['questions']} "
        f"code_blocks={source_result['code_blocks']} "
        f"pages={pdf_result['pages']} "
        f"characters={pdf_result['characters']} "
        f"bytes={pdf_result['bytes']} "
        f"quick_reference_page={pdf_result['quick_reference_page']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
