#!/usr/bin/env python3
"""Build the four Vietnamese Firewall RTL student guides as A4 PDFs."""

from __future__ import annotations

import argparse
import html
import re
from dataclasses import dataclass
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    ListFlowable,
    ListItem,
    LongTable,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)


@dataclass(frozen=True)
class GuideSpec:
    source_name: str
    output_name: str
    module_name: str
    accent: str


GUIDES = (
    GuideSpec("01_fw_apb_regs_lab_guide.md", "01_fw_apb_regs_lab_guide.pdf", "fw_apb_regs", "#1F5A94"),
    GuideSpec("02_fw_acl_matcher_lab_guide.md", "02_fw_acl_matcher_lab_guide.pdf", "fw_acl_matcher", "#087F8C"),
    GuideSpec("03_fw_write_drain_lab_guide.md", "03_fw_write_drain_lab_guide.pdf", "fw_write_drain", "#B85C1E"),
    GuideSpec("04_fw_read_drain_lab_guide.md", "04_fw_read_drain_lab_guide.pdf", "fw_read_drain", "#6B4C9A"),
)


def _first_existing(candidates: list[Path]) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"Không tìm thấy font trong: {candidates}")


def register_fonts() -> None:
    font_dir = Path("C:/Windows/Fonts")
    regular = _first_existing([font_dir / "arial.ttf", font_dir / "segoeui.ttf"])
    bold = _first_existing([font_dir / "arialbd.ttf", font_dir / "segoeuib.ttf"])
    italic = _first_existing([font_dir / "ariali.ttf", font_dir / "segoeuii.ttf", regular])
    mono = _first_existing([font_dir / "consola.ttf", font_dir / "cour.ttf"])
    mono_bold = _first_existing([font_dir / "consolab.ttf", font_dir / "courbd.ttf", mono])

    pdfmetrics.registerFont(TTFont("GuideSans", str(regular)))
    pdfmetrics.registerFont(TTFont("GuideSans-Bold", str(bold)))
    pdfmetrics.registerFont(TTFont("GuideSans-Italic", str(italic)))
    pdfmetrics.registerFont(TTFont("GuideMono", str(mono)))
    pdfmetrics.registerFont(TTFont("GuideMono-Bold", str(mono_bold)))
    pdfmetrics.registerFontFamily(
        "GuideSans",
        normal="GuideSans",
        bold="GuideSans-Bold",
        italic="GuideSans-Italic",
        boldItalic="GuideSans-Bold",
    )


def inline_markup(text: str) -> str:
    escaped = html.escape(text.strip())
    escaped = re.sub(r"`([^`]+)`", r'<font name="GuideMono" color="#17324D">\1</font>', escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"\*([^*]+)\*", r"<i>\1</i>", escaped)
    escaped = re.sub(r"\[([^]]+)\]\(([^)]+)\)", r'<u><font color="#1F5A94">\1</font></u>', escaped)
    return escaped


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError("Frontmatter chưa đóng")
    metadata: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        metadata[key.strip()] = value.strip()
    return metadata, text[end + 5 :]


def make_styles(accent_hex: str) -> dict[str, ParagraphStyle]:
    accent = colors.HexColor(accent_hex)
    base = getSampleStyleSheet()
    return {
        "body": ParagraphStyle(
            "GuideBody",
            parent=base["BodyText"],
            fontName="GuideSans",
            fontSize=10.2,
            leading=14.2,
            textColor=colors.HexColor("#243447"),
            spaceAfter=6,
            alignment=TA_LEFT,
            allowWidows=0,
            allowOrphans=0,
        ),
        "h1": ParagraphStyle(
            "GuideH1",
            parent=base["Heading1"],
            fontName="GuideSans-Bold",
            fontSize=19,
            leading=23,
            textColor=accent,
            spaceBefore=12,
            spaceAfter=9,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "GuideH2",
            parent=base["Heading2"],
            fontName="GuideSans-Bold",
            fontSize=14.2,
            leading=18,
            textColor=colors.HexColor("#17324D"),
            spaceBefore=11,
            spaceAfter=6,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "GuideH3",
            parent=base["Heading3"],
            fontName="GuideSans-Bold",
            fontSize=11.4,
            leading=15,
            textColor=accent,
            spaceBefore=8,
            spaceAfter=4,
            keepWithNext=True,
        ),
        "small": ParagraphStyle(
            "GuideSmall",
            parent=base["BodyText"],
            fontName="GuideSans",
            fontSize=8.3,
            leading=11,
            textColor=colors.HexColor("#485B6E"),
        ),
        "table": ParagraphStyle(
            "GuideTable",
            parent=base["BodyText"],
            fontName="GuideSans",
            fontSize=7.7,
            leading=10.2,
            textColor=colors.HexColor("#243447"),
        ),
        "table_header": ParagraphStyle(
            "GuideTableHeader",
            parent=base["BodyText"],
            fontName="GuideSans-Bold",
            fontSize=7.6,
            leading=9.5,
            textColor=colors.white,
            alignment=TA_CENTER,
        ),
        "callout": ParagraphStyle(
            "GuideCallout",
            parent=base["BodyText"],
            fontName="GuideSans",
            fontSize=9.3,
            leading=13,
            textColor=colors.HexColor("#243447"),
        ),
    }


def make_cover(metadata: dict[str, str], spec: GuideSpec, styles: dict[str, ParagraphStyle]):
    accent = colors.HexColor(spec.accent)
    title = metadata.get("title", spec.module_name)
    subtitle = metadata.get("subtitle", "Hướng dẫn thực hành RTL tự học")
    version = metadata.get("version", "Kiến trúc V2.4.1")
    cover_title = ParagraphStyle(
        "CoverTitle",
        fontName="GuideSans-Bold",
        fontSize=27,
        leading=33,
        textColor=accent,
        alignment=TA_CENTER,
    )
    cover_module = ParagraphStyle(
        "CoverModule",
        fontName="GuideMono-Bold",
        fontSize=17,
        leading=22,
        textColor=colors.HexColor("#17324D"),
        alignment=TA_CENTER,
    )
    cover_sub = ParagraphStyle(
        "CoverSub",
        fontName="GuideSans",
        fontSize=12,
        leading=17,
        textColor=colors.HexColor("#485B6E"),
        alignment=TA_CENTER,
    )
    card = Table(
        [[Paragraph(inline_markup(subtitle), cover_sub)], [Paragraph(inline_markup(version), styles["small"]) ]],
        colWidths=[142 * mm],
        rowHeights=[24 * mm, 12 * mm],
    )
    card.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F3F7FA")),
                ("BOX", (0, 0), (-1, -1), 0.8, accent),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    return [
        Spacer(1, 31 * mm),
        Paragraph("DMA-AWARE BUS FIREWALL", cover_sub),
        Spacer(1, 12 * mm),
        Paragraph(inline_markup(title), cover_title),
        Spacer(1, 9 * mm),
        Paragraph(inline_markup(spec.module_name), cover_module),
        Spacer(1, 23 * mm),
        card,
        Spacer(1, 36 * mm),
        Paragraph("Tài liệu dành cho sinh viên thiết kế và kiểm chứng độc lập", cover_sub),
        PageBreak(),
    ]


def _paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(inline_markup(" ".join(part.strip() for part in text.splitlines())), style)


def _code_blocks(lines: list[str], styles: dict[str, ParagraphStyle]):
    output = []
    for start in range(0, len(lines), 34):
        chunk = "\n".join(lines[start : start + 34])
        box = Table(
            [[Preformatted(chunk, ParagraphStyle("Code", fontName="GuideMono", fontSize=7.7, leading=10.2, textColor=colors.HexColor("#EAF2F8"))) ]],
            colWidths=[169 * mm],
        )
        box.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#172330")),
                    ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#41576D")),
                    ("LEFTPADDING", (0, 0), (-1, -1), 7),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                    ("TOPPADDING", (0, 0), (-1, -1), 6),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ]
            )
        )
        output.extend([box, Spacer(1, 5)])
    return output


def _markdown_table(lines: list[str], styles: dict[str, ParagraphStyle], accent_hex: str):
    rows = []
    for line in lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell.replace(" ", "")) for cell in cells):
            continue
        rows.append(cells)
    if not rows:
        return []
    width = max(len(row) for row in rows)
    for row in rows:
        row.extend([""] * (width - len(row)))
    data = []
    for row_index, row in enumerate(rows):
        style = styles["table_header"] if row_index == 0 else styles["table"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])
    available = 169 * mm
    col_widths = [available / width] * width
    table = LongTable(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(accent_hex)),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B8C5D1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F4F7F9")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return [table, Spacer(1, 6)]


def _callout(text: str, styles: dict[str, ParagraphStyle], accent_hex: str):
    label_match = re.match(r"\[([^]]+)\]\s*(.*)", text.strip())
    label = label_match.group(1) if label_match else "GHI CHÚ"
    body = label_match.group(2) if label_match else text.strip()
    palette = {
        "ĐẶC TẢ": ("#EAF3FA", "#1F5A94"),
        "BÀI TẬP": ("#EDF8F5", "#087F8C"),
        "CẢNH BÁO": ("#FFF4E8", "#B85C1E"),
        "KIỂM TRA": ("#F2ECF8", "#6B4C9A"),
    }
    background, bar = palette.get(label.upper(), ("#F3F6F8", accent_hex))
    content = Paragraph(f"<b>{html.escape(label)}</b><br/>{inline_markup(body)}", styles["callout"])
    table = Table([[content]], colWidths=[169 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(background)),
                ("LINEBEFORE", (0, 0), (0, -1), 4, colors.HexColor(bar)),
                ("BOX", (0, 0), (-1, -1), 0.3, colors.HexColor("#CDD7E0")),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return [KeepTogether([table, Spacer(1, 6)])]


def markdown_to_flowables(text: str, styles: dict[str, ParagraphStyle], accent_hex: str):
    lines = text.splitlines()
    flowables = []
    index = 0
    paragraph_lines: list[str] = []

    def flush_paragraph() -> None:
        nonlocal paragraph_lines
        if paragraph_lines:
            flowables.append(_paragraph("\n".join(paragraph_lines), styles["body"]))
            paragraph_lines = []

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if not stripped:
            flush_paragraph()
            index += 1
            continue
        if stripped == "<!-- pagebreak -->":
            flush_paragraph()
            flowables.append(Spacer(1, 4))
            index += 1
            continue
        if stripped.startswith("```"):
            flush_paragraph()
            index += 1
            code_lines = []
            while index < len(lines) and not lines[index].strip().startswith("```"):
                code_lines.append(lines[index])
                index += 1
            index += 1
            flowables.extend(_code_blocks(code_lines, styles))
            continue
        if stripped.startswith("#"):
            flush_paragraph()
            level = len(stripped) - len(stripped.lstrip("#"))
            heading = stripped[level:].strip()
            flowables.append(Paragraph(inline_markup(heading), styles["h1" if level == 1 else "h2" if level == 2 else "h3"]))
            index += 1
            continue
        if stripped.startswith("|"):
            flush_paragraph()
            table_lines = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                table_lines.append(lines[index])
                index += 1
            flowables.extend(_markdown_table(table_lines, styles, accent_hex))
            continue
        if stripped.startswith(">"):
            flush_paragraph()
            quote = stripped[1:].strip()
            index += 1
            while index < len(lines) and lines[index].strip().startswith(">"):
                quote += " " + lines[index].strip()[1:].strip()
                index += 1
            flowables.extend(_callout(quote, styles, accent_hex))
            continue
        if re.match(r"^[-*]\s+", stripped):
            flush_paragraph()
            items = []
            while index < len(lines) and re.match(r"^[-*]\s+", lines[index].strip()):
                item_text = re.sub(r"^[-*]\s+", "", lines[index].strip())
                items.append(ListItem(Paragraph(inline_markup(item_text), styles["body"]), leftIndent=5))
                index += 1
            flowables.extend([ListFlowable(items, bulletType="bullet", leftIndent=16, bulletFontName="GuideSans"), Spacer(1, 4)])
            continue
        if re.match(r"^\d+\.\s+", stripped):
            flush_paragraph()
            items = []
            start_number = int(stripped.split(".", 1)[0])
            while index < len(lines) and re.match(r"^\d+\.\s+", lines[index].strip()):
                item_text = re.sub(r"^\d+\.\s+", "", lines[index].strip())
                items.append(ListItem(Paragraph(inline_markup(item_text), styles["body"]), leftIndent=5))
                index += 1
            flowables.extend([ListFlowable(items, bulletType="1", start=str(start_number), leftIndent=20, bulletFontName="GuideSans"), Spacer(1, 4)])
            continue
        paragraph_lines.append(stripped)
        index += 1
    flush_paragraph()
    return flowables


def build_guide(source_path: Path, output_path: Path, spec: GuideSpec) -> None:
    text = source_path.read_text(encoding="utf-8")
    metadata, body = parse_frontmatter(text)
    styles = make_styles(spec.accent)

    doc = BaseDocTemplate(
        str(output_path),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=20 * mm,
        bottomMargin=17 * mm,
        title=metadata.get("title", spec.module_name),
        author="DMA AXI Firewall RTL course",
        subject=f"Hướng dẫn thực hành {spec.module_name}",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")

    accent = colors.HexColor(spec.accent)

    def draw_header_footer(canvas, document):
        canvas.saveState()
        page = canvas.getPageNumber()
        if page > 1:
            canvas.setStrokeColor(accent)
            canvas.setLineWidth(0.6)
            canvas.line(18 * mm, A4[1] - 14 * mm, A4[0] - 18 * mm, A4[1] - 14 * mm)
            canvas.setFont("GuideMono-Bold", 8.2)
            canvas.setFillColor(colors.HexColor("#17324D"))
            canvas.drawString(18 * mm, A4[1] - 11 * mm, spec.module_name)
            canvas.setFont("GuideSans", 8)
            canvas.setFillColor(colors.HexColor("#5B6B7A"))
            canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Trang {page}")
        canvas.restoreState()

    doc.addPageTemplates([PageTemplate(id="guide", frames=[frame], onPage=draw_header_footer)])
    story = make_cover(metadata, spec, styles)
    story.extend(markdown_to_flowables(body, styles, spec.accent))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc.build(story)


def build_all(repo_root: Path) -> list[Path]:
    register_fonts()
    source_dir = repo_root / "DMA-controller/docs/tutorials/firewall-rtl/student-guides"
    output_dir = repo_root / "output/pdf"
    outputs = []
    for spec in GUIDES:
        source = source_dir / spec.source_name
        output = output_dir / spec.output_name
        if not source.exists():
            raise FileNotFoundError(f"Thiếu source: {source}")
        build_guide(source, output, spec)
        outputs.append(output)
        print(output)
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[5])
    args = parser.parse_args()
    build_all(args.repo_root.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
