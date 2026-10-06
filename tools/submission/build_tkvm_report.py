from __future__ import annotations

import argparse
import html
import json
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image as PillowImage
from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    LongTable,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

try:
    from tools.submission.drawio_reportlab import render_drawio
except ModuleNotFoundError:  # Direct script execution from the repository root.
    from drawio_reportlab import render_drawio


ACCENT = "#0B6E69"
NAVY = "#17324D"
TEXT = "#243447"
MUTED = "#5B6B7A"
LIGHT = "#F2F7F6"


@dataclass(frozen=True)
class FigureSpec:
    key: str
    source: Path | None
    caption: str
    kind: str


def _first_existing(candidates: list[Path]) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"No usable font found: {candidates}")


def register_fonts() -> None:
    if "TkvmSans" in pdfmetrics.getRegisteredFontNames():
        return
    font_dir = Path("C:/Windows/Fonts")
    regular = _first_existing([font_dir / "arial.ttf", font_dir / "segoeui.ttf"])
    bold = _first_existing([font_dir / "arialbd.ttf", font_dir / "segoeuib.ttf"])
    italic = _first_existing([font_dir / "ariali.ttf", font_dir / "segoeuii.ttf", regular])
    mono = _first_existing([font_dir / "consola.ttf", font_dir / "cour.ttf"])
    pdfmetrics.registerFont(TTFont("TkvmSans", str(regular)))
    pdfmetrics.registerFont(TTFont("TkvmSans-Bold", str(bold)))
    pdfmetrics.registerFont(TTFont("TkvmSans-Italic", str(italic)))
    pdfmetrics.registerFont(TTFont("TkvmMono", str(mono)))
    pdfmetrics.registerFontFamily(
        "TkvmSans",
        normal="TkvmSans",
        bold="TkvmSans-Bold",
        italic="TkvmSans-Italic",
        boldItalic="TkvmSans-Bold",
    )


def inline_markup(text: str) -> str:
    escaped = html.escape(text.strip())
    escaped = re.sub(r"`([^`]+)`", r'<font name="TkvmMono" color="#17324D">\1</font>', escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"\*([^*]+)\*", r"<i>\1</i>", escaped)
    return escaped


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError("Unclosed frontmatter")
    metadata: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            metadata[key.strip()] = value.strip()
    return metadata, text[end + 5 :]


def make_styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "body": ParagraphStyle(
            "TkvmBody",
            parent=base["BodyText"],
            fontName="TkvmSans",
            fontSize=9.35,
            leading=13.1,
            textColor=colors.HexColor(TEXT),
            spaceAfter=5,
            alignment=TA_LEFT,
            allowWidows=0,
            allowOrphans=0,
        ),
        "h1": ParagraphStyle(
            "TkvmH1",
            parent=base["Heading1"],
            fontName="TkvmSans-Bold",
            fontSize=19,
            leading=23,
            textColor=colors.HexColor(ACCENT),
            spaceBefore=4,
            spaceAfter=9,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "TkvmH2",
            parent=base["Heading2"],
            fontName="TkvmSans-Bold",
            fontSize=12.6,
            leading=16,
            textColor=colors.HexColor(NAVY),
            spaceBefore=9,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "TkvmH3",
            parent=base["Heading3"],
            fontName="TkvmSans-Bold",
            fontSize=10.5,
            leading=14,
            textColor=colors.HexColor(ACCENT),
            spaceBefore=7,
            spaceAfter=4,
            keepWithNext=True,
        ),
        "small": ParagraphStyle(
            "TkvmSmall",
            parent=base["BodyText"],
            fontName="TkvmSans",
            fontSize=7.8,
            leading=10.3,
            textColor=colors.HexColor(MUTED),
        ),
        "caption": ParagraphStyle(
            "TkvmCaption",
            parent=base["BodyText"],
            fontName="TkvmSans-Italic",
            fontSize=8.1,
            leading=10.5,
            alignment=TA_CENTER,
            textColor=colors.HexColor(MUTED),
            spaceBefore=3,
            spaceAfter=7,
        ),
        "table": ParagraphStyle(
            "TkvmTable",
            parent=base["BodyText"],
            fontName="TkvmSans",
            fontSize=7.2,
            leading=9.2,
            textColor=colors.HexColor(TEXT),
        ),
        "table_header": ParagraphStyle(
            "TkvmTableHeader",
            parent=base["BodyText"],
            fontName="TkvmSans-Bold",
            fontSize=7.1,
            leading=9,
            textColor=colors.white,
            alignment=TA_CENTER,
        ),
        "callout": ParagraphStyle(
            "TkvmCallout",
            parent=base["BodyText"],
            fontName="TkvmSans",
            fontSize=8.8,
            leading=12.3,
            textColor=colors.HexColor(TEXT),
        ),
    }


def _markdown_table(lines: list[str], styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    rows: list[list[str]] = []
    for line in lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell.replace(" ", "")) for cell in cells):
            continue
        rows.append(cells)
    width = max(len(row) for row in rows)
    for row in rows:
        row.extend([""] * (width - len(row)))
    data = []
    for index, row in enumerate(rows):
        style = styles["table_header" if index == 0 else "table"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])
    available = 169 * mm
    table = LongTable(data, colWidths=[available / width] * width, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(ACCENT)),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B8C5D1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F4F7F9")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    return [table, Spacer(1, 5)]


def _callout(text: str, styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    label_match = re.match(r"\[([^]]+)\]\s*(.*)", text.strip())
    label = label_match.group(1) if label_match else "GHI CHÚ"
    body = label_match.group(2) if label_match else text.strip()
    content = Paragraph(f"<b>{html.escape(label)}</b><br/>{inline_markup(body)}", styles["callout"])
    table = Table([[content]], colWidths=[169 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#EAF4F2")),
                ("LINEBEFORE", (0, 0), (0, -1), 4, colors.HexColor(ACCENT)),
                ("BOX", (0, 0), (-1, -1), 0.3, colors.HexColor("#BDD4D1")),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return [KeepTogether([table, Spacer(1, 6)])]


def architecture_drawing(source: Path) -> Drawing:
    """Render the editable draw.io source used by the architecture figure."""

    return render_drawio(source, width=480, height=285)


WAVEFORM_PRIORITIES = {
    "address_slice_observation": ("reset", "rst_n", "awvalid", "awready", "pipe_s1_awaddr", "4kb_err"),
    "fw_acl_matcher": ("rst_n", "req_valid", "req_ready", "decision_valid", "decision_ready", "pipe_valid"),
    "fw_closed_loop_ctrl": ("reset", "hdc_anomaly_alert", "threat_level", "force_drain_req", "aegis_nmi_irq"),
    "fw_honeypot_sink": ("rst_n", "hp_awvalid", "hp_awready", "hp_wvalid", "hp_wready"),
    "dma_bus_firewall": ("reset", "awvalid", "awready", "arvalid", "arready", "breach", "irq", "deny"),
    "soc_real_integration": ("reset", "trap", "irq", "dma", "breach", "awvalid", "bvalid"),
    "aegis_rowhammer_5000": ("reset", "rowhammer", "threat", "irq", "honeypot", "redirect", "breach"),
    "adversarial_m1": ("reset", "threat_level", "awvalid", "awready", "arvalid", "arready", "breach"),
}


def _choose_signals(data: dict, key: str, limit: int = 6) -> list[dict]:
    signals = data.get("signals", [])
    chosen: list[dict] = []
    used: set[str] = set()
    for pattern in WAVEFORM_PRIORITIES.get(key, ("reset", "valid", "ready", "irq", "threat")):
        for signal in signals:
            name = str(signal.get("name", ""))
            if pattern in name.lower() and name not in used:
                chosen.append(signal)
                used.add(name)
                break
        if len(chosen) >= limit:
            break
    if len(chosen) < 4:
        for signal in signals:
            name = str(signal.get("name", ""))
            if name not in used and signal.get("events"):
                chosen.append(signal)
                used.add(name)
            if len(chosen) >= limit:
                break
    return chosen


def _short_signal_name(name: str) -> str:
    parts = name.split(".")
    short = ".".join(parts[-2:]) if len(parts) > 1 else name
    return short[-29:]


def _bus_label(value: str) -> str:
    if not value or any(char in value.lower() for char in "xz"):
        return value[:10]
    try:
        return f"0x{int(value, 2):X}"
    except ValueError:
        return value[:10]


def waveform_drawing(json_path: Path, key: str) -> Drawing:
    data = json.loads(json_path.read_text(encoding="utf-8"))
    signals = _choose_signals(data, key)
    width = 480
    lane_height = 24
    height = 42 + len(signals) * lane_height
    drawing = Drawing(width, height)
    drawing.add(Rect(0, 0, width, height, fillColor=colors.HexColor("#101923"), strokeColor=colors.HexColor("#314659")))
    label_width = 145
    plot_left = label_width + 8
    plot_right = width - 12
    start = int(data.get("start", 0))
    end = int(data.get("end", start + 1))
    interesting = sorted(
        {
            int(event[0])
            for signal in signals
            if "clk" not in str(signal.get("name", "")).lower()
            for event in signal.get("events", [])
            if int(event[0]) > start
        }
    )
    if len(interesting) >= 2:
        window_start = max(start, interesting[0] - max(1, (interesting[1] - interesting[0]) * 2))
        window_end = min(end, interesting[min(len(interesting) - 1, 40)] + max(1, interesting[1] - interesting[0]) * 2)
        if window_end <= window_start:
            window_start, window_end = start, end
    else:
        window_start, window_end = start, end
    span = max(1, window_end - window_start)

    drawing.add(String(12, height - 18, f"Capture: {key}", fontName="TkvmSans-Bold", fontSize=8, fillColor=colors.HexColor("#DCE8F2")))
    drawing.add(String(width - 12, height - 18, f"{window_start} .. {window_end} {data.get('timescale', '')}", fontName="TkvmMono", fontSize=6.5, textAnchor="end", fillColor=colors.HexColor("#9FB4C6")))
    for tick in range(6):
        x = plot_left + (plot_right - plot_left) * tick / 5
        drawing.add(Line(x, 10, x, height - 30, strokeColor=colors.HexColor("#263747"), strokeWidth=0.4))

    for index, signal in enumerate(signals):
        y_mid = height - 44 - index * lane_height
        drawing.add(String(8, y_mid - 2, _short_signal_name(str(signal.get("name", ""))), fontName="TkvmMono", fontSize=6.5, fillColor=colors.HexColor("#C4D4E0")))
        drawing.add(Line(plot_left, y_mid - 10, plot_right, y_mid - 10, strokeColor=colors.HexColor("#263747"), strokeWidth=0.35))
        events = [(int(t), str(v)) for t, v in signal.get("events", [])]
        events = [(t, v) for t, v in events if t <= window_end]
        if not events:
            continue
        prior = events[0][1]
        visible: list[tuple[int, str]] = [(window_start, prior)]
        for t, value in events:
            if t <= window_start:
                visible[0] = (window_start, value)
            elif t <= window_end:
                visible.append((t, value))
        visible.append((window_end, visible[-1][1]))
        is_bit = int(signal.get("width", 1)) == 1
        if is_bit:
            previous_x = plot_left
            previous_y = y_mid + (6 if visible[0][1] == "1" else -6)
            for t, value in visible[1:]:
                x = plot_left + (plot_right - plot_left) * (t - window_start) / span
                y = y_mid + (6 if value == "1" else -6)
                drawing.add(Line(previous_x, previous_y, x, previous_y, strokeColor=colors.HexColor("#55D6BE"), strokeWidth=1.2))
                drawing.add(Line(x, previous_y, x, y, strokeColor=colors.HexColor("#55D6BE"), strokeWidth=1.2))
                previous_x, previous_y = x, y
        else:
            drawing.add(Line(plot_left, y_mid - 5, plot_right, y_mid - 5, strokeColor=colors.HexColor("#E7B75D"), strokeWidth=0.9))
            drawing.add(Line(plot_left, y_mid + 5, plot_right, y_mid + 5, strokeColor=colors.HexColor("#E7B75D"), strokeWidth=0.9))
            last_label_x = -100.0
            for t, value in visible[:-1]:
                x = plot_left + (plot_right - plot_left) * (t - window_start) / span
                drawing.add(Line(x, y_mid - 5, x + 5, y_mid + 5, strokeColor=colors.HexColor("#E7B75D"), strokeWidth=0.7))
                if x - last_label_x > 62:
                    drawing.add(String(x + 7, y_mid - 2, _bus_label(value), fontName="TkvmMono", fontSize=5.8, fillColor=colors.HexColor("#F3D699")))
                    last_label_x = x
    return drawing


def _scaled_image(path: Path, max_width: float = 169 * mm, max_height: float = 62 * mm) -> Image:
    with PillowImage.open(path) as source:
        width, height = source.size
    scale = min(max_width / width, max_height / height, 1.0)
    return Image(str(path), width=width * scale, height=height * scale)


def _figure(flowable: Flowable, caption: str, styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    return [KeepTogether([flowable, Paragraph(inline_markup(caption), styles["caption"])])]


def _test_table(repo_root: Path, styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    summary = json.loads((repo_root / "output/evidence/release_signoff_bundle_20260920_soc/summary.json").read_text(encoding="utf-8"))
    rows = [["ID", "Scope", "Kết quả", "Vai trò trong hồ sơ"]]
    for test in summary["tests"]:
        scope = str(test["scope"])
        role = "Tham khảo, không dùng làm bằng chứng production" if scope == "MOCK_INTEGRATION" else "Bằng chứng production/unit"
        rows.append([str(test["id"]), scope, str(test["status"]), role])
    data = []
    for index, row in enumerate(rows):
        style = styles["table_header" if index == 0 else "table"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])
    table = LongTable(data, colWidths=[49 * mm, 34 * mm, 20 * mm, 66 * mm], repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(ACCENT)),
                ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#B8C5D1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F4F7F9")]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 2.5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
                ("TEXTCOLOR", (0, 1), (-1, -1), colors.HexColor(TEXT)),
            ]
        )
    )
    return [table]


def _physical_table(styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    rows = [
        ["Thiết kế", "DRC", "LVS", "Setup WNS", "Hold WNS", "Trạng thái"],
        ["AEGIS SoC top", "0", "Matched", "TT +0.89 ns", "TT +0.041 ns", "SS review"],
        ["DMA bus firewall", "0", "Matched", "TT +0.81 ns", "TT -0.02 ns", "Hold waiver"],
    ]
    data = []
    for index, row in enumerate(rows):
        style = styles["table_header" if index == 0 else "table"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])
    table = Table(data, colWidths=[38 * mm, 18 * mm, 25 * mm, 27 * mm, 27 * mm, 34 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(ACCENT)),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B8C5D1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F4F7F9")]),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (1, 1), (-2, -1), "CENTER"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return [table, Spacer(1, 7)]


def _directive_flowables(
    directive: str,
    repo_root: Path,
    styles: dict[str, ParagraphStyle],
) -> list[Flowable]:
    match = re.fullmatch(r"\[\[([A-Z_]+)(?::([^]|]+))?(?:\|([^]]+))?\]\]", directive)
    if not match:
        raise ValueError(f"Invalid report directive: {directive}")
    kind, key, caption = match.groups()
    caption = caption or ""
    if kind == "FIGURE" and key == "architecture_soc":
        source = repo_root / "docs/submission/tkvm-2026/tkvm_architecture.drawio"
        return _figure(architecture_drawing(source), caption, styles)
    if kind == "WAVEFORM" and key:
        source = repo_root / "output/evidence/release_signoff_bundle_20260920_soc/simulation" / key / "waveform.json"
        return _figure(waveform_drawing(source, key), caption, styles)
    if kind == "IMAGE" and key:
        paths = {
            "layout_soc": repo_root / "output/physical/sky130_aegis_soc_top/layout.png",
            "layout_firewall": repo_root / "output/physical/sky130_dma_bus_firewall/layout.png",
        }
        return _figure(_scaled_image(paths[key]), caption, styles)
    if kind == "TEST_TABLE":
        return _test_table(repo_root, styles)
    if kind == "PHYSICAL_TABLE":
        return _physical_table(styles)
    raise ValueError(f"Unsupported report directive: {directive}")


def markdown_to_flowables(text: str, repo_root: Path, styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    lines = text.splitlines()
    flowables: list[Flowable] = []
    paragraph_lines: list[str] = []
    index = 0

    def flush_paragraph() -> None:
        nonlocal paragraph_lines
        if paragraph_lines:
            combined = " ".join(part.strip() for part in paragraph_lines)
            flowables.append(Paragraph(inline_markup(combined), styles["body"]))
            paragraph_lines = []

    while index < len(lines):
        stripped = lines[index].strip()
        if not stripped:
            flush_paragraph()
            index += 1
            continue
        if stripped == "<!-- pagebreak -->":
            flush_paragraph()
            flowables.append(PageBreak())
            index += 1
            continue
        if stripped.startswith("[["):
            flush_paragraph()
            flowables.extend(_directive_flowables(stripped, repo_root, styles))
            index += 1
            continue
        if stripped.startswith("#"):
            flush_paragraph()
            level = len(stripped) - len(stripped.lstrip("#"))
            heading = stripped[level:].strip()
            style = styles["h1" if level == 1 else "h2" if level == 2 else "h3"]
            flowables.append(Paragraph(inline_markup(heading), style))
            index += 1
            continue
        if stripped.startswith("|"):
            flush_paragraph()
            table_lines: list[str] = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                table_lines.append(lines[index])
                index += 1
            flowables.extend(_markdown_table(table_lines, styles))
            continue
        if stripped.startswith(">"):
            flush_paragraph()
            quote = stripped[1:].strip()
            index += 1
            while index < len(lines) and lines[index].strip().startswith(">"):
                quote += " " + lines[index].strip()[1:].strip()
                index += 1
            flowables.extend(_callout(quote, styles))
            continue
        if re.match(r"^[-*]\s+", stripped):
            flush_paragraph()
            items = []
            while index < len(lines) and re.match(r"^[-*]\s+", lines[index].strip()):
                item_text = re.sub(r"^[-*]\s+", "", lines[index].strip())
                items.append(ListItem(Paragraph(inline_markup(item_text), styles["body"]), leftIndent=5))
                index += 1
            flowables.extend([ListFlowable(items, bulletType="bullet", leftIndent=16, bulletFontName="TkvmSans"), Spacer(1, 3)])
            continue
        if re.match(r"^\d+\.\s+", stripped):
            flush_paragraph()
            items = []
            start_number = int(stripped.split(".", 1)[0])
            while index < len(lines) and re.match(r"^\d+\.\s+", lines[index].strip()):
                item_text = re.sub(r"^\d+\.\s+", "", lines[index].strip())
                items.append(ListItem(Paragraph(inline_markup(item_text), styles["body"]), leftIndent=5))
                index += 1
            flowables.extend([ListFlowable(items, bulletType="1", start=str(start_number), leftIndent=20, bulletFontName="TkvmSans"), Spacer(1, 3)])
            continue
        paragraph_lines.append(stripped)
        index += 1
    flush_paragraph()
    return flowables


def make_cover(metadata: dict[str, str], styles: dict[str, ParagraphStyle]) -> list[Flowable]:
    title_style = ParagraphStyle(
        "CoverTitle",
        fontName="TkvmSans-Bold",
        fontSize=26,
        leading=32,
        textColor=colors.HexColor(ACCENT),
        alignment=TA_CENTER,
    )
    subtitle_style = ParagraphStyle(
        "CoverSubtitle",
        fontName="TkvmSans",
        fontSize=12,
        leading=17,
        textColor=colors.HexColor(MUTED),
        alignment=TA_CENTER,
    )
    stat_style = ParagraphStyle(
        "CoverStat",
        fontName="TkvmSans-Bold",
        fontSize=15,
        leading=18,
        textColor=colors.HexColor(NAVY),
        alignment=TA_CENTER,
    )
    status = Table(
        [
            [Paragraph("25/25", stat_style), Paragraph("DRC 0", stat_style), Paragraph("LVS", stat_style), Paragraph("38 MHz", stat_style)],
            [Paragraph("Mô phỏng PASS", styles["small"]), Paragraph("SoC và IP", styles["small"]), Paragraph("SoC matched", styles["small"]), Paragraph("TT post-route", styles["small"])],
        ],
        colWidths=[40 * mm] * 4,
    )
    status.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(LIGHT)),
                ("BOX", (0, 0), (-1, -1), 0.7, colors.HexColor(ACCENT)),
                ("INNERGRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#BDD4D1")),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return [
        Spacer(1, 24 * mm),
        Paragraph("CUỘC THI THIẾT KẾ VI MẠCH CHO ĐÔ THỊ THÔNG MINH 2026", subtitle_style),
        Spacer(1, 15 * mm),
        Paragraph(inline_markup(metadata.get("title", "DMA-Aware Bus Firewall")), title_style),
        Spacer(1, 7 * mm),
        Paragraph(inline_markup(metadata.get("subtitle", "Hồ sơ thiết kế vi mạch bảo mật")), subtitle_style),
        Spacer(1, 18 * mm),
        status,
        Spacer(1, 21 * mm),
        _callout(
            "[PHẠM VI] RTL, mô phỏng, dạng sóng, layout, GDS/GDSII, DRC, LVS, timing và PPA theo workload VCD.",
            styles,
        )[0],
        PageBreak(),
    ]


def build_report(repo_root: Path, markdown_path: Path, output_pdf: Path) -> Path:
    """Build the A4 Vietnamese competition report with embedded evidence figures."""

    repo_root = repo_root.resolve()
    markdown_path = markdown_path.resolve()
    output_pdf = output_pdf.resolve()
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    register_fonts()
    metadata, body = parse_frontmatter(markdown_path.read_text(encoding="utf-8"))
    styles = make_styles()

    doc = BaseDocTemplate(
        str(output_pdf),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=19 * mm,
        bottomMargin=17 * mm,
        title=metadata.get("title", "DMA-Aware Bus Firewall cho AEGIS SoC"),
        author="Đội dự thi TKVM 2026",
        subject="Hồ sơ thiết kế vi mạch bảo mật",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="normal")

    def draw_header_footer(canvas, document) -> None:
        canvas.saveState()
        page = canvas.getPageNumber()
        if page > 1:
            canvas.setStrokeColor(colors.HexColor(ACCENT))
            canvas.setLineWidth(0.6)
            canvas.line(18 * mm, A4[1] - 14 * mm, A4[0] - 18 * mm, A4[1] - 14 * mm)
            canvas.setFont("TkvmSans-Bold", 7.8)
            canvas.setFillColor(colors.HexColor(NAVY))
            canvas.drawString(18 * mm, A4[1] - 11 * mm, "DMA-AWARE BUS FIREWALL | TKVM 2026")
            canvas.setFont("TkvmSans", 7.2)
            canvas.setFillColor(colors.HexColor(MUTED))
            canvas.drawString(18 * mm, 9 * mm, "EVIDENCE_COMPLETE_REVIEW_REQUIRED | PRODUCER-REPORTED")
            canvas.drawRightString(A4[0] - 18 * mm, 9 * mm, f"Trang {page}")
        canvas.restoreState()

    doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=draw_header_footer)])
    story = make_cover(metadata, styles)
    story.extend(markdown_to_flowables(body, repo_root, styles))
    doc.build(story)
    return output_pdf


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    source = (repo_root / args.source).resolve() if not args.source.is_absolute() else args.source.resolve()
    output = (repo_root / args.output).resolve() if not args.output.is_absolute() else args.output.resolve()
    result = build_report(repo_root, source, output)
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
