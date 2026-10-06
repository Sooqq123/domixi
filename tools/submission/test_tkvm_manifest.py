from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.submission.tkvm_manifest import SELECTED_WAVEFORM_SCOPES, build_inventory, sha256_file


class TkvmManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repo_root = Path(self.temporary.name)
        source = self.repo_root / "rtl/dma_bus_firewall.v"
        source.parent.mkdir(parents=True)
        source.write_text("module dma_bus_firewall; endmodule\n", encoding="utf-8")
        testbench = self.repo_root / "tb/tb_dma_bus_firewall.v"
        testbench.parent.mkdir(parents=True)
        testbench.write_text("module tb_dma_bus_firewall; endmodule\n", encoding="utf-8")
        bundle = self.repo_root / "output/evidence/release_signoff_bundle_20260920_soc"
        sim = bundle / "simulation/dma_bus_firewall"
        sim.mkdir(parents=True)
        for name in ("compile.log", "simulation.log", "waveform.svg", "waveform.json"):
            (sim / name).write_text(name, encoding="utf-8")
        (bundle / "simulation_results.csv").write_text("id,status\ndma_bus_firewall,PASS\n", encoding="utf-8")
        summary = {
            "status": "EVIDENCE_COMPLETE_REVIEW_REQUIRED",
            "tests": [
                {
                    "id": "dma_bus_firewall",
                    "scope": "FIREWALL_TOP",
                    "status": "PASS",
                    "sources": [
                        {"path": "rtl/dma_bus_firewall.v", "sha256": sha256_file(source)},
                        {"path": "tb/tb_dma_bus_firewall.v", "sha256": sha256_file(testbench)},
                    ],
                    "waveform": "simulation/dma_bus_firewall/waves.vcd",
                }
            ],
        }
        (bundle / "summary.json").write_text(json.dumps(summary), encoding="utf-8")
        for selected in (item for item in SELECTED_WAVEFORM_SCOPES if item != "dma_bus_firewall"):
            selected_dir = bundle / "simulation" / selected
            selected_dir.mkdir(parents=True)
            for name in ("compile.log", "simulation.log", "waveform.svg", "waveform.json"):
                (selected_dir / name).write_text(name, encoding="utf-8")
            selected_source = self.repo_root / f"rtl/{selected}.v"
            selected_source.write_text(f"module {selected}; endmodule\n", encoding="utf-8")
            summary["tests"].append(
                {
                    "id": selected,
                    "scope": "SOC_REAL",
                    "status": "PASS",
                    "sources": [{"path": f"rtl/{selected}.v", "sha256": sha256_file(selected_source)}],
                    "waveform": f"simulation/{selected}/waves.vcd",
                }
            )
        (bundle / "summary.json").write_text(json.dumps(summary), encoding="utf-8")
        constraints = self.repo_root / "constraints"
        constraints.mkdir()
        for name in ("aegis_soc_top.sdc", "dma_bus_firewall.sdc"):
            (constraints / name).write_text("create_clock -period 26.315\n", encoding="utf-8")
        ppa = self.repo_root / "output/ppa"
        (ppa / "dma_bus_firewall").mkdir(parents=True)
        (ppa / "aegis_soc_top").mkdir(parents=True)
        (ppa / "PPA_SUMMARY.md").write_text("PPA\n", encoding="utf-8")
        (ppa / "ppa_master_summary.json").write_text("{}", encoding="utf-8")
        (ppa / "power_vcd_summary.json").write_text("{}", encoding="utf-8")
        (ppa / "release_provenance.json").write_text("{}", encoding="utf-8")
        for top in ("dma_bus_firewall", "aegis_soc_top"):
            (ppa / top / "run_manifest.json").write_text("{}", encoding="utf-8")
        for top in ("aegis_soc_top", "dma_bus_firewall"):
            physical = self.repo_root / f"output/physical/sky130_{top}"
            physical.mkdir(parents=True)
            for name in ("layout.png", "klayout_drc.rpt", "lvs.rpt", "sta_tt_025C_1v80_38mhz.rpt", f"{top}.gds"):
                (physical / name).write_bytes(name.encode("utf-8"))
            for name in ("netgen_lvs.log", "sta_ss_100C_1v60_38p5mhz.rpt", "sta_ss_100C_1v60_52ns.rpt"):
                (physical / name).write_bytes(name.encode("utf-8"))
            expected = {
                "aegis_soc_top": {"setup": (0.89, 0.0), "hold": (0.041, 0.0)},
                "dma_bus_firewall": {"setup": (0.81, 0.0), "hold": (-0.02, -0.07)},
            }[top]
            manifest = {
                "top": top,
                "gds_sha256": sha256_file(physical / f"{top}.gds"),
                "artifacts": {"gds": f"{top}.gds"},
                "drc": {"violations": 0},
                "lvs": {"matched": True},
                "timing": [
                    {"check": check, "wns": values[0], "tns": values[1]}
                    for check, values in expected.items()
                ],
            }
            (physical / "physical_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_required_physical_artifacts_are_selected(self) -> None:
        inventory = build_inventory(self.repo_root)
        destinations = {item.destination.as_posix() for item in inventory}
        self.assertIn("physical/aegis_soc_top/aegis_soc_top.gds", destinations)
        self.assertIn("physical/aegis_soc_top/layout.png", destinations)
        self.assertIn("physical/aegis_soc_top/netgen_lvs.log", destinations)
        self.assertIn("physical/aegis_soc_top/sta_ss_100C_1v60_38p5mhz.rpt", destinations)
        self.assertIn("physical/aegis_soc_top/sta_ss_100C_1v60_52ns.rpt", destinations)
        self.assertIn("ppa/PPA_SUMMARY.md", destinations)
        self.assertIn("ppa/release_provenance.json", destinations)

    def test_mock_integration_is_not_selected(self) -> None:
        inventory = build_inventory(self.repo_root)
        for item in inventory:
            self.assertNotIn("/mocks/", item.source.as_posix())
            self.assertNotEqual(item.scope, "MOCK_INTEGRATION")

    def test_large_vcd_is_skipped_but_companions_remain(self) -> None:
        vcd = self.repo_root / "output/evidence/release_signoff_bundle_20260920_soc/simulation/dma_bus_firewall/waves.vcd"
        vcd.write_bytes(b"large")
        inventory = build_inventory(self.repo_root, vcd_limit_bytes=1)
        destinations = {item.destination.as_posix() for item in inventory}
        self.assertFalse(any(path.endswith(".vcd") for path in destinations))
        self.assertTrue(any(path.endswith("waveform.svg") for path in destinations))
        self.assertTrue(any(path.endswith("waveform.json") for path in destinations))

    def test_missing_required_artifact_raises(self) -> None:
        (self.repo_root / "constraints/aegis_soc_top.sdc").unlink()
        with self.assertRaises(FileNotFoundError):
            build_inventory(self.repo_root)

    def test_gds_hash_mismatch_raises(self) -> None:
        gds = self.repo_root / "output/physical/sky130_aegis_soc_top/aegis_soc_top.gds"
        gds.write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "GDS hash differs"):
            build_inventory(self.repo_root)
