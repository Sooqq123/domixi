from __future__ import annotations

import html
import math
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors


class DrawioRenderError(ValueError):
    """Raised when the report diagram uses an unsupported draw.io construct."""


@dataclass(frozen=True)
class Geometry:
    x: float
    y: float
    width: float
    height: float

    @property
    def center(self) -> tuple[float, float]:
        return (self.x + self.width / 2.0, self.y + self.height / 2.0)


def _style_map(raw: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for token in raw.split(";"):
        token = token.strip()
        if not token:
            continue
        if "=" in token:
            key, value = token.split("=", 1)
            parsed[key] = value
        else:
            parsed[token] = "1"
    return parsed


def _number(mapping: dict[str, str], key: str, default: float) -> float:
    try:
        return float(mapping.get(key, default))
    except (TypeError, ValueError) as exc:
        raise DrawioRenderError(f"Invalid numeric style value for {key}") from exc


def _plain_lines(value: str) -> list[str]:
    value = html.unescape(value or "")
    value = re.sub(r"(?i)<br\s*/?>", "\n", value)
    value = re.sub(r"<[^>]+>", "", value)
    return [line.strip() for line in value.splitlines() if line.strip()]


def _arrowhead_points(
    start: tuple[float, float],
    end: tuple[float, float],
    length: float = 7.0,
    half_width: float = 3.5,
) -> list[float]:
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    magnitude = math.hypot(dx, dy)
    if magnitude <= 1e-9:
        raise DrawioRenderError("Arrow final segment has zero length")
    ux = dx / magnitude
    uy = dy / magnitude
    base_x = end[0] - length * ux
    base_y = end[1] - length * uy
    px = -uy * half_width
    py = ux * half_width
    return [
        end[0],
        end[1],
        base_x + px,
        base_y + py,
        base_x - px,
        base_y - py,
    ]


def render_drawio(
    source: Path,
    *,
    width: float = 480.0,
    height: float = 285.0,
    font_name: str = "TkvmSans",
    bold_font_name: str = "TkvmSans-Bold",
) -> Drawing:
    """Render the report's supported draw.io architecture subset to ReportLab."""

    source = source.resolve()
    if not source.is_file():
        raise FileNotFoundError(f"Editable architecture diagram not found: {source}")
    try:
        tree = ET.parse(source)
    except ET.ParseError as exc:
        raise DrawioRenderError(f"Malformed draw.io XML: {source}: {exc}") from exc

    model = tree.find(".//mxGraphModel")
    if model is None:
        raise DrawioRenderError(f"No mxGraphModel found in {source}")
    root = model.find("root")
    if root is None:
        raise DrawioRenderError(f"No draw.io graph root found in {source}")

    page_width = float(model.get("pageWidth", "1180"))
    page_height = float(model.get("pageHeight", "720"))
    if page_width <= 0 or page_height <= 0:
        raise DrawioRenderError("draw.io page dimensions must be positive")

    cells = {cell.get("id", ""): cell for cell in root.findall("mxCell")}
    vertices = [cell for cell in root.findall("mxCell") if cell.get("vertex") == "1"]
    edges = [cell for cell in root.findall("mxCell") if cell.get("edge") == "1"]
    geometry_cache: dict[str, Geometry] = {}

    def absolute_geometry(cell_id: str) -> Geometry:
        if cell_id in geometry_cache:
            return geometry_cache[cell_id]
        cell = cells.get(cell_id)
        if cell is None:
            raise DrawioRenderError(f"Unknown draw.io cell id: {cell_id}")
        geometry = cell.find("mxGeometry")
        if geometry is None:
            raise DrawioRenderError(f"Cell {cell_id} has no mxGeometry")
        x = float(geometry.get("x", "0"))
        y = float(geometry.get("y", "0"))
        result = Geometry(
            x=x,
            y=y,
            width=float(geometry.get("width", "0")),
            height=float(geometry.get("height", "0")),
        )
        parent_id = cell.get("parent", "1")
        if parent_id not in {"0", "1", ""} and parent_id in cells:
            parent = absolute_geometry(parent_id)
            result = Geometry(
                x=result.x + parent.x,
                y=result.y + parent.y,
                width=result.width,
                height=result.height,
            )
        geometry_cache[cell_id] = result
        return result

    scale = min(width / page_width, height / page_height)
    offset_x = (width - page_width * scale) / 2.0
    offset_y = (height - page_height * scale) / 2.0

    def point(x: float, y: float) -> tuple[float, float]:
        return (offset_x + x * scale, offset_y + (page_height - y) * scale)

    def report_geometry(geometry: Geometry) -> Geometry:
        x, top = point(geometry.x, geometry.y)
        return Geometry(x, top - geometry.height * scale, geometry.width * scale, geometry.height * scale)

    def colour(raw: str | None, fallback: str) -> colors.Color:
        value = fallback if raw in {None, "", "none"} else str(raw)
        return colors.HexColor(value)

    def anchor(geometry: Geometry, style: dict[str, str], prefix: str) -> tuple[float, float]:
        default_x = 1.0 if prefix == "exit" else 0.0
        x_fraction = _number(style, f"{prefix}X", default_x)
        y_fraction = _number(style, f"{prefix}Y", 0.5)
        return point(
            geometry.x + geometry.width * x_fraction,
            geometry.y + geometry.height * y_fraction,
        )

    drawing = Drawing(width, height)

    for cell in vertices:
        if cell.get("id") != "2":
            continue
        style = _style_map(cell.get("style", ""))
        geometry = report_geometry(absolute_geometry("2"))
        drawing.add(
            Rect(
                geometry.x,
                geometry.y,
                geometry.width,
                geometry.height,
                fillColor=colour(style.get("fillColor"), "#F8FAFB"),
                strokeColor=colour(style.get("strokeColor"), "#D6E0E6"),
                strokeWidth=max(0.35, _number(style, "strokeWidth", 1.0) * scale),
            )
        )

    for edge in edges:
        edge_id = edge.get("id", "<unknown>")
        source_id = edge.get("source")
        target_id = edge.get("target")
        if not source_id or not target_id:
            raise DrawioRenderError(f"Edge {edge_id} is missing source or target")
        source_geometry = absolute_geometry(source_id)
        target_geometry = absolute_geometry(target_id)
        style = _style_map(edge.get("style", ""))
        points = [anchor(source_geometry, style, "exit")]
        edge_geometry = edge.find("mxGeometry")
        if edge_geometry is None or edge_geometry.get("relative") != "1":
            raise DrawioRenderError(f"Edge {edge_id} needs relative mxGeometry")
        waypoints = edge_geometry.find("Array[@as='points']")
        if waypoints is not None:
            for waypoint in waypoints.findall("mxPoint"):
                points.append(point(float(waypoint.get("x", "0")), float(waypoint.get("y", "0"))))
        points.append(anchor(target_geometry, style, "entry"))

        stroke = colour(style.get("strokeColor"), "#0B6E69")
        stroke_width = max(0.7, _number(style, "strokeWidth", 2.0) * scale)
        dash = [4 * scale, 3 * scale] if style.get("dashed") == "1" else None
        for start, end in zip(points, points[1:]):
            line = Line(
                start[0],
                start[1],
                end[0],
                end[1],
                strokeColor=stroke,
                strokeWidth=stroke_width,
            )
            if dash:
                line.strokeDashArray = dash
            drawing.add(line)
        if style.get("endArrow", "block") != "none":
            drawing.add(
                Polygon(
                    _arrowhead_points(points[-2], points[-1], 7.0, 3.5),
                    fillColor=stroke,
                    strokeColor=stroke,
                )
            )

    for cell in vertices:
        cell_id = cell.get("id", "")
        if cell_id == "2":
            continue
        style = _style_map(cell.get("style", ""))
        geometry = report_geometry(absolute_geometry(cell_id))
        lines = _plain_lines(cell.get("value", ""))
        is_text = "text" in style
        fill_raw = style.get("fillColor", "none" if is_text else "#F5F5F5")
        stroke_raw = style.get("strokeColor", "none" if is_text else "#666666")

        if not is_text:
            supported_shape = style.get("shape")
            if supported_shape not in {None, ""}:
                raise DrawioRenderError(
                    f"Unsupported shape '{supported_shape}' in cell {cell_id}; use a rounded rectangle"
                )
            fill = None if fill_raw == "none" else colour(fill_raw, "#F5F5F5")
            stroke = None if stroke_raw == "none" else colour(stroke_raw, "#666666")
            radius = 7.0 * scale if style.get("rounded") == "1" else 0
            drawing.add(
                Rect(
                    geometry.x,
                    geometry.y,
                    geometry.width,
                    geometry.height,
                    rx=radius,
                    ry=radius,
                    fillColor=fill,
                    strokeColor=stroke,
                    strokeWidth=max(0.35, _number(style, "strokeWidth", 1.5) * scale),
                )
            )

        if not lines:
            continue
        font_size = _number(style, "fontSize", 17.0) * scale
        font_colour = colour(style.get("fontColor"), "#17324D")
        center_x = geometry.x + geometry.width / 2.0
        center_y = geometry.y + geometry.height / 2.0
        line_gap = font_size * 1.35
        first_y = center_y + (len(lines) - 1) * line_gap / 2.0 - font_size * 0.35
        all_bold = style.get("fontStyle") == "1"
        for index, label in enumerate(lines):
            drawing.add(
                String(
                    center_x,
                    first_y - index * line_gap,
                    label,
                    fontName=bold_font_name if all_bold or (not is_text and index == 0) else font_name,
                    fontSize=font_size if index == 0 or is_text else font_size * 0.78,
                    textAnchor="middle",
                    fillColor=font_colour,
                )
            )

    return drawing
