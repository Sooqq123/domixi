from __future__ import annotations

import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from tools.submission.drawio_reportlab import _arrowhead_points, render_drawio


class DrawioReportlabTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_root = Path(__file__).resolve().parents[2]
        cls.source = cls.repo_root / "docs/submission/tkvm-2026/tkvm_architecture.drawio"
        root = ET.parse(cls.source).find(".//mxGraphModel/root")
        if root is None:
            raise AssertionError("draw.io source has no graph root")
        cls.cells = {cell.get("id", ""): cell for cell in root.findall("mxCell")}

    def test_required_architecture_blocks_exist(self) -> None:
        values = {cell.get("value", "") for cell in self.cells.values()}
        required = {
            "PicoRV32\nfirmware / CPU telemetry",
            "APB bridge\ncontrol decode",
            "DMA Controller\nAPB + AXI master",
            "Context tracker\ndynamic regions",
            "APB registers\npolicy + forensics",
            "Address slice\nAW/AR snapshot",
            "Fast policy\nACL + profile + quarantine",
            "Action latch\nallow / redirect / drain",
            "Protected AXI egress\nexternal memory / interconnect",
            "Read / Write Drain FSM\ndeny response",
            "Honey-Pot AXI sink\ndecoy endpoint",
            "Telemetry queue\n2-entry sideband",
            "HDC analysis\n1024-D / 64-bit lane",
            "Threat policy / MTD\nrate-limit + redirect",
            "Closed-loop controller\nscore + forensic FIFO",
            "NMI / IRQ\nurgent alert",
        }
        self.assertTrue(required.issubset(values))

    def test_required_rtl_flows_are_directed_to_the_correct_targets(self) -> None:
        edges = {
            (cell.get("source"), cell.get("target"))
            for cell in self.cells.values()
            if cell.get("edge") == "1"
        }
        self.assertTrue(
            {
                ("6", "10"),
                ("10", "11"),
                ("11", "12"),
                ("12", "13"),
                ("12", "14"),
                ("12", "15"),
                ("10", "17"),
                ("17", "18"),
                ("18", "19"),
                ("19", "12"),
                ("19", "20"),
                ("20", "11"),
                ("20", "8"),
                ("20", "21"),
            }.issubset(edges)
        )

    def test_arrowhead_tip_follows_each_final_segment(self) -> None:
        for start, end in (
            ((0.0, 0.0), (10.0, 0.0)),
            ((0.0, 0.0), (0.0, 10.0)),
            ((10.0, 10.0), (0.0, 0.0)),
            ((0.0, 10.0), (10.0, 0.0)),
        ):
            points = _arrowhead_points(start, end)
            tip = (points[0], points[1])
            base = ((points[2] + points[4]) / 2.0, (points[3] + points[5]) / 2.0)
            segment = (end[0] - start[0], end[1] - start[1])
            head = (tip[0] - base[0], tip[1] - base[1])
            self.assertGreater(segment[0] * head[0] + segment[1] * head[1], 0.0)

    def test_editable_source_renders_without_external_drawio(self) -> None:
        drawing = render_drawio(self.source, width=480, height=285)
        self.assertEqual(drawing.width, 480)
        self.assertEqual(drawing.height, 285)
        self.assertGreater(len(drawing.contents), 80)


if __name__ == "__main__":
    unittest.main()
