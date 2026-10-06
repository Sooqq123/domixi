#!/usr/bin/env python3
"""Build the Vietnamese 60-minute Verilog RTL foundation lesson as A4 PDF."""

from __future__ import annotations

import argparse
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

from build_student_guides import (
    GuideSpec,
    make_styles,
    markdown_to_flowables,
    parse_frontmatter,
    register_fonts,
)


SOURCE = Path(
    "DMA-controller/docs/tutorials/firewall-rtl/foundation/"
    "00_verilog_rtl_foundation_60min.md"
)
OUTPUT = Path("output/pdf/00_verilog_rtl_foundation_60min.pdf")
SPEC = GuideSpec(
    SOURCE.name,
    OUTPUT.name,
    "Verilog RTL nền tảng",
    "#2F6B4F",
)


def make_lesson_cover(metadata: dict[str, str], accent: colors.Color):
    """Return a project-independent cover for the foundation lesson."""
    kicker_style = ParagraphStyle(
        "LessonCoverKicker",
        fontName="GuideSans-Bold",
        fontSize=10,
        leading=13,
        textColor=colors.HexColor("#5B6B7A"),
        alignment=TA_CENTER,
        spaceAfter=7,
    )
    title_style = ParagraphStyle(
        "LessonCoverTitle",
        fontName="GuideSans-Bold",
        fontSize=27,
        leading=33,
        textColor=accent,
        alignment=TA_CENTER,
    )
    subtitle_style = ParagraphStyle(
        "LessonCoverSubtitle",
        fontName="GuideSans",
        fontSize=12,
        leading=17,
        textColor=colors.HexColor("#334E68"),
        alignment=TA_CENTER,
    )
    small_style = ParagraphStyle(
        "LessonCoverSmall",
        fontName="GuideSans",
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#5B6B7A"),
        alignment=TA_CENTER,
    )
    card = Table(
        [
            [Paragraph(metadata.get("subtitle", "Giáo trình Verilog RTL"), subtitle_style)],
            [Paragraph(metadata.get("version", "Giáo trình 60 phút"), small_style)],
        ],
        colWidths=[150 * mm],
    )
    card.setStyle(
        TableStyle(
            [
                ("BOX", (0, 0), (-1, -1), 0.8, accent),
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F3F8F5")),
                ("TOPPADDING", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
            ]
        )
    )
    return [
        Spacer(1, 26 * mm),
        Paragraph("THIẾT KẾ VI MẠCH SỐ", kicker_style),
        Paragraph(metadata.get("title", SPEC.module_name), title_style),
        Spacer(1, 17 * mm),
        card,
        Spacer(1, 35 * mm),
        Paragraph(
            "Bài học nền tảng dành cho sinh viên năm 3 đã học mạch số",
            subtitle_style,
        ),
        PageBreak(),
    ]


def build(repo_root: Path) -> Path:
    """Build the lesson PDF and return its absolute path."""
    source_path = repo_root / SOURCE
    output_path = repo_root / OUTPUT
    if not source_path.exists():
        raise FileNotFoundError(f"Thiếu source: {source_path}")

    register_fonts()
    source_text = source_path.read_text(encoding="utf-8")
    metadata, body = parse_frontmatter(source_text)
    styles = make_styles(SPEC.accent)
    accent = colors.HexColor(SPEC.accent)

    doc = BaseDocTemplate(
        str(output_path),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=20 * mm,
        bottomMargin=17 * mm,
        title=metadata.get("title", SPEC.module_name),
        author="Khóa học Verilog RTL",
        subject="Giáo trình lý thuyết Verilog-2001 trong 60 phút",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")

    def draw_header_footer(canvas, document):
        canvas.saveState()
        page = canvas.getPageNumber()
        if page > 1:
            canvas.setStrokeColor(accent)
            canvas.setLineWidth(0.6)
            canvas.line(18 * mm, A4[1] - 14 * mm, A4[0] - 18 * mm, A4[1] - 14 * mm)
            canvas.setFont("GuideMono-Bold", 8.2)
            canvas.setFillColor(colors.HexColor("#17324D"))
            canvas.drawString(18 * mm, A4[1] - 11 * mm, SPEC.module_name)
            canvas.setFont("GuideSans", 8)
            canvas.setFillColor(colors.HexColor("#5B6B7A"))
            canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Trang {page}")
        canvas.restoreState()

    doc.addPageTemplates(
        [PageTemplate(id="lesson", frames=[frame], onPage=draw_header_footer)]
    )
    story = make_lesson_cover(metadata, accent)
    for index, section in enumerate(body.split("<!-- pagebreak -->")):
        if index:
            story.append(PageBreak())
        story.extend(markdown_to_flowables(section, styles, SPEC.accent))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc.build(story)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[5]
    )
    args = parser.parse_args()
    output_path = build(args.repo_root.resolve())
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
