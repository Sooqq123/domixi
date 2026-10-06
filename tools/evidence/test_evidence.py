"""Collector tests use synthetic fixtures in temporary directories, never project signoff data."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

import evidence
from physical import collect_physical, sha256
from waveform import read_vcd, render_svg


OK = {"timeout": False, "exit_code": 0}


class SimulationTests(unittest.TestCase):
    def test_exit_zero_is_not_sufficient(self):
        self.assertEqual(evidence.classify_run(OK, OK, "finished", "PASS"), "FAIL")

    def test_fail_marker_overrides_pass(self):
        for failure in ("[FAIL] mismatch", "FATAL: timeout", "ERROR: mismatch", "[TIMEOUT] stalled"):
            with self.subTest(failure=failure):
                self.assertEqual(evidence.classify_run(OK, OK, f"PASS\n{failure}", "PASS"), "FAIL")

    def test_expected_error_scenario_is_not_a_failure_marker(self):
        self.assertEqual(evidence.classify_run(OK, OK, "[PASS] terminal ERROR\nPASS", "PASS"), "PASS")

    def test_exit_and_timeout_override_pass(self):
        for result in ({"exit_code": 1, "timeout": False}, {"exit_code": None, "timeout": True}):
            self.assertEqual(evidence.classify_run(OK, result, "PASS", "PASS"), "FAIL")

    def test_warning_requires_review_and_manual_bench_is_observed(self):
        self.assertEqual(evidence.classify_run(OK, OK, "PASS", "PASS", 1), "REVIEW")
        self.assertEqual(evidence.classify_run(OK, OK, "DONE", None), "OBSERVED")

    def test_output_cannot_escape_bundle(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                evidence.local_path(Path(tmp), "../escaped")

    def test_unknown_sources_are_blocked_not_passed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            row = evidence.run_test({"id": "pending", "scope": "UNIT", "top": "tb", "sources": ["missing.v"]}, root, root / "bundle", 1)
            self.assertEqual(row["status"], "BLOCKED")


class WaveformTests(unittest.TestCase):
    HEADER = "$timescale\n 1 ps\n$end\n$scope module tb $end\n$var wire 1 ! clk $end\n$var wire 1 ! alias $end\n$var wire 8 # data [7:0] $end\n$upscope $end\n$enddefinitions $end\n"

    def test_aliases_vector_xz_and_window(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.vcd"
            path.write_text(self.HEADER + "#0\n0!\nbx #\n#5\n1!\nb10100101 #\n#10\n0!\nbz #\n#20\n", encoding="ascii")
            trace = read_vcd(path, ["*"], start=6, end=16)
            self.assertEqual(trace["timescale"], "1 ps")
            signals = {s["name"]: s for s in trace["signals"]}
            self.assertEqual(signals["tb.clk"]["events"][0], (6, "1"))
            self.assertEqual(signals["tb.clk"]["events"], signals["tb.alias"]["events"])
            self.assertEqual(signals["tb.data"]["events"], [(6, "10100101"), (10, "z")])
            svg = Path(tmp) / "wave.svg"
            render_svg(trace, svg)
            self.assertIn("0xA5", svg.read_text(encoding="utf-8"))

    def test_clipped_wave_is_explicit_and_not_flat_to_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "trace.vcd"
            path.write_text(self.HEADER + "#0\n0!\n#1\n1!\n#2\n0!\n#3\n1!\n#4\n", encoding="ascii")
            trace = read_vcd(path, ["*clk"], max_events=2)
            self.assertTrue(trace["truncated"])
            self.assertEqual(trace["end"], 2)

    def test_malformed_and_empty_time_window_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.vcd"
            for text in ("garbage", self.HEADER + "#0\n0!\n"):
                path.write_text(text, encoding="ascii")
                with self.assertRaises(ValueError):
                    read_vcd(path)


class PhysicalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        # Synthetic signature fixtures exercise packaging only, not GDS/image validity.
        files = {"gds": ("chip.gds", b"\x00\x06\x00\x02\x02\x58FIXTURE"),
                 "layout_image": ("layout.png", b"\x89PNG\r\n\x1a\nFIXTURE")}
        for name in ("netlist", "sdc", "spef", "sdf", "liberty", "drc_deck", "lvs_deck"):
            files[name] = (name + ".txt", b"SYNTHETIC UNIT TEST ONLY")
        for filename, contents in files.values():
            (self.root / filename).write_bytes(contents)
        (self.root / "report.txt").write_text("SYNTHETIC REPORT FIXTURE", encoding="ascii")
        run = {"tool": "fixture-tool", "version": "test", "command": "fixture command", "exit_code": 0, "report": "report.txt"}
        self.data = {"schema_version": 1, "top": "fixture", "source_revision": "fixture-revision", "pdk": "fixture-pdk", "pdk_version": "fixture-version",
                     "gds_sha256": sha256(self.root / "chip.gds"), "artifacts": {key: value[0] for key, value in files.items()},
                     "drc": dict(run, format="normalized", violations=0), "lvs": dict(run, matched=True),
                     "required_timing_views": ["slow/functional/setup", "fast/functional/hold"],
                     "timing": [dict(run, corner=corner, mode="functional", stage="post_route", check=check, unit="ns", wns=0, tns=0, unconstrained_endpoints=0) for corner, check in (("slow", "setup"), ("fast", "hold"))]}
        self.counter = 0

    def collect(self, data):
        self.counter += 1
        manifest = self.root / f"input_{self.counter}.json"
        manifest.write_text(json.dumps(data), encoding="utf-8")
        return collect_physical(manifest, self.root / f"output_{self.counter}")

    def test_complete_is_only_reported_pass(self):
        self.assertEqual(self.collect(self.data)["status"], "REPORTED_PASS")

    def test_empty_template_is_incomplete(self):
        template = json.loads((evidence.HERE / "physical_template.json").read_text())
        self.assertEqual(self.collect(template)["status"], "INCOMPLETE")

    def test_missing_file_and_revision_mismatch_never_pass(self):
        for field in ("sdc", "layout_image", "gds"):
            data = copy.deepcopy(self.data)
            data["artifacts"][field] = "missing.file"
            self.assertEqual(self.collect(data)["status"], "INCOMPLETE")
        self.data["gds_sha256"] = "incorrect"
        self.assertEqual(self.collect(self.data)["status"], "INCOMPLETE")

    def test_raw_report_is_mandatory(self):
        self.data["lvs"]["report"] = None
        self.assertEqual(self.collect(self.data)["status"], "INCOMPLETE")

    def test_physical_failures_are_not_hidden(self):
        for stage, field, value in (("drc", "violations", 2), ("lvs", "matched", False), ("drc", "exit_code", 1)):
            data = copy.deepcopy(self.data)
            data[stage][field] = value
            self.assertEqual(self.collect(data)["status"], "FAIL")

    def test_unknown_metrics_nan_and_missing_views_never_pass(self):
        for value in (None, float("nan"), float("inf"), "0", True):
            data = copy.deepcopy(self.data)
            data["timing"][0]["wns"] = value
            self.assertEqual(self.collect(data)["status"], "INCOMPLETE")
        self.data["timing"].pop()
        self.assertEqual(self.collect(self.data)["status"], "INCOMPLETE")

    def test_negative_slack_and_unconstrained_paths_fail(self):
        for field, value in (("wns", -0.01), ("tns", -3), ("unconstrained_endpoints", 1)):
            data = copy.deepcopy(self.data)
            data["timing"][0][field] = value
            self.assertEqual(self.collect(data)["status"], "FAIL")

    def test_multicorner_input_libraries_are_all_archived(self):
        self.data["artifacts"]["liberty"] = ["liberty.txt", "report.txt"]
        result = self.collect(self.data)
        self.assertEqual(result["status"], "REPORTED_PASS")
        self.assertEqual(len([a for a in result["artifacts"] if a["kind"].startswith("liberty_")]), 2)

    def test_klayout_xml_counts_multiplicity_and_rejects_wrong_top(self):
        path = self.root / "drc.lyrdb"
        path.write_text('<report-database><top-cell>fixture</top-cell><items><item><multiplicity>3</multiplicity></item></items></report-database>')
        self.data["drc"].update(report="drc.lyrdb", format="klayout-rdb")
        result = self.collect(self.data)
        self.assertEqual(result["checks"][0]["value"], 3)
        self.assertEqual(result["status"], "FAIL")
        path.write_text('<report-database><top-cell>wrong</top-cell><items/></report-database>')
        self.assertEqual(self.collect(self.data)["status"], "INCOMPLETE")


class IntegrityTests(unittest.TestCase):
    def test_tampering_and_extra_files_are_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp)
            (bundle / "result.log").write_text("PASS")
            evidence.inventory(bundle)
            self.assertEqual(evidence.verify_bundle(bundle), [])
            (bundle / "result.log").write_text("FAIL")
            self.assertTrue(evidence.verify_bundle(bundle))
            (bundle / "result.log").write_text("PASS")
            (bundle / "nested").mkdir()
            (bundle / "nested" / "artifacts.csv").write_text("extra")
            self.assertTrue(evidence.verify_bundle(bundle))


if __name__ == "__main__":
    unittest.main()
