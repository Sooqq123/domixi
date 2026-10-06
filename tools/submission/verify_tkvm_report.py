from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

from pypdf import PdfReader


REQUIRED_TEXT = (
    "Ý tưởng và đóng góp",
    "Mục tiêu bảo vệ",
    "Kiến trúc thiết kế",
    "Thiết kế logic và RTL",
    "Kết quả mô phỏng",
    "Dạng sóng kiểm chứng",
    "Layout và GDS/GDSII",
    "DRC và LVS",
    "Báo cáo timing",
    "+0.89 ns",
    "+0.041 ns",
    "+0.81 ns",
    "-0.02 ns",
    "-0.07 ns",
    "-25.10 ns",
    "+0.92 ns",
    "REVIEW_REQUIRED",
    "TT post-route",
    "EVIDENCE_COMPLETE_REVIEW_REQUIRED",
)
FORBIDDEN_PATTERNS = (
    r"\bTBD\b",
    r"\bTODO\b",
    r"\bPLACEHOLDER\b",
    r"lorem ipsum",
    r"sẽ bổ sung",
    r"đang cập nhật",
    "—",
    "–",
)


@dataclass(frozen=True)
class PdfVerification:
    page_count: int
    missing_text: tuple[str, ...]
    blank_pages: tuple[int, ...]
    non_a4_pages: tuple[int, ...]
    forbidden_matches: tuple[str, ...]

    @property
    def ok(self) -> bool:
        return not (self.missing_text or self.blank_pages or self.non_a4_pages or self.forbidden_matches)


def verify_pdf(pdf_path: Path) -> PdfVerification:
    reader = PdfReader(str(pdf_path))
    page_texts = [(page.extract_text() or "") for page in reader.pages]
    full_text = "\n".join(page_texts)
    missing = tuple(text for text in REQUIRED_TEXT if text not in full_text)
    blank = tuple(index for index, text in enumerate(page_texts, start=1) if not text.strip())
    non_a4: list[int] = []
    for index, page in enumerate(reader.pages, start=1):
        width = float(page.mediabox.width)
        height = float(page.mediabox.height)
        if abs(width - 595.28) > 2 or abs(height - 841.89) > 2:
            non_a4.append(index)
    forbidden: list[str] = []
    for pattern in FORBIDDEN_PATTERNS:
        if re.search(pattern, full_text, flags=re.IGNORECASE):
            forbidden.append(pattern)
    if not 10 <= len(reader.pages) <= 18:
        forbidden.append(f"unexpected_page_count:{len(reader.pages)}")
    return PdfVerification(len(reader.pages), missing, blank, tuple(non_a4), tuple(forbidden))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    args = parser.parse_args()
    result = verify_pdf(args.pdf)
    print(f"pages={result.page_count}")
    print(f"missing_text={list(result.missing_text)}")
    print(f"blank_pages={list(result.blank_pages)}")
    print(f"non_a4_pages={list(result.non_a4_pages)}")
    print(f"forbidden_matches={list(result.forbidden_matches)}")
    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
