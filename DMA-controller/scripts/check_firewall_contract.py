#!/usr/bin/env python3
"""Validate Codex integration-preparation artifacts against canonical CSVs."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


DMA_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = DMA_ROOT.parent

GROUPS = {
    "A": {
        "dma_apb_slave",
        "dma_axi_master",
        "dma_fifo_latch",
        "dma_controller",
        "fw_axi_address_slice",
        "fw_context_tracker",
        "fw_data_path_mux",
    },
    "B": {"fw_apb_regs", "fw_acl_matcher", "fw_write_drain", "fw_read_drain"},
    "C": {"fw_drain_fsm", "dma_bus_firewall"},
    "UNASSIGNED": {"fw_apb_slave", "dma_top", "dma32", "fifo32"},
}

REAL_FIREWALL_SOURCES = {
    name: REPO_ROOT / "rtl" / f"{name}.v"
    for name in (
        "fw_axi_address_slice",
        "fw_context_tracker",
        "fw_apb_regs",
        "fw_acl_matcher",
        "fw_write_drain",
        "fw_read_drain",
        "fw_drain_fsm",
        "fw_data_path_mux",
        "fw_hdc_sense",
        "fw_mtd_engine",
        "fw_honeypot_sink",
        "fw_closed_loop_ctrl",
    )
}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)
    print(f"[FAIL] {message}")


def passed(message: str) -> None:
    print(f"[PASS] {message}")


PortContract = tuple[str, int | None]


def declared_ports(path: Path) -> dict[str, PortContract]:
    text = path.read_text(encoding="utf-8")
    ports: dict[str, PortContract] = {}
    pattern = re.compile(
        r"^\s*(input|output|inout)\s+(?:(?:wire|reg|logic)\s+)?"
        r"(?:signed\s+)?(?:\[([^\]]+)\]\s+)?([A-Za-z_]\w*)",
        re.MULTILINE,
    )
    for direction, packed_range, name in pattern.findall(text):
        width = 1
        if packed_range:
            bounds = re.fullmatch(r"\s*(\d+)\s*:\s*(\d+)\s*", packed_range)
            width = abs(int(bounds.group(1)) - int(bounds.group(2))) + 1 if bounds else None
        ports[name] = (direction, width)
    return ports


def expected_public_ports() -> dict[str, PortContract]:
    path = DMA_ROOT / "docs" / "architecture" / "pinout.csv"
    expected: dict[str, PortContract] = {}
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            name = row["Signal Name"]
            interface = row["Module/Interface"]
            include = (
                interface in {
                    "TOP_GLOBAL",
                    "AXI_SLAVE",
                    "AXI_MASTER",
                    "DMA_CONTROLLER_SIDEBAND",
                    "CPU_TELEMETRY",
                    "AEGIS_STATUS",
                    "INTERRUPT",
                }
                or (interface == "APB_SLAVE" and name.startswith("s_apb_"))
            )
            if include:
                # Sideband Direction is documented at its DMA producer. At the
                # Firewall public boundary the same five signals are inputs.
                direction = (
                    "input" if interface == "DMA_CONTROLLER_SIDEBAND" else row["Direction"].lower()
                )
                expected[name] = (direction, int(row["Width"]))
    return expected


def expected_wrapper_ports() -> dict[str, PortContract]:
    path = DMA_ROOT / "docs" / "architecture" / "signal_list.csv"
    expected: dict[str, PortContract] = {"clk": ("input", 1), "rst_n": ("input", 1)}
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            source = row["Source Module"]
            destination = row["Dest Module"]
            if source == "fw_drain_fsm":
                expected[row["Signal Name"]] = ("output", int(row["Width"]))
            elif destination == "fw_drain_fsm":
                expected[row["Signal Name"]] = ("input", int(row["Width"]))
    return expected


def check_ports(
    path: Path,
    errors: list[str],
    label: str,
    expected: dict[str, PortContract],
) -> None:
    actual = declared_ports(path)
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    wrong_direction = sorted(
        name for name in expected.keys() & actual.keys() if expected[name][0] != actual[name][0]
    )
    wrong_width = sorted(
        name for name in expected.keys() & actual.keys() if expected[name][1] != actual[name][1]
    )
    if missing:
        fail(errors, f"{label} missing ports: {', '.join(missing)}")
    if extra:
        fail(errors, f"{label} has non-canonical ports: {', '.join(extra)}")
    if wrong_direction:
        fail(errors, f"{label} has wrong directions: {', '.join(wrong_direction)}")
    if wrong_width:
        fail(errors, f"{label} has wrong widths: {', '.join(wrong_width)}")
    if not (missing or extra or wrong_direction or wrong_width):
        passed(f"{label} matches {len(expected)} canonical port directions and widths")


def check_sdc_port_coverage(
    rtl_path: Path,
    sdc_path: Path,
    errors: list[str],
    label: str,
) -> None:
    actual = set(declared_ports(rtl_path))
    text = sdc_path.read_text(encoding="utf-8")
    referenced: set[str] = set()
    for braced, scalar in re.findall(
        r"get_ports\s+(?:\{([^}]*)\}|([A-Za-z_]\w*))",
        text,
        re.DOTALL,
    ):
        referenced.update((braced or scalar).split())
    missing = sorted(actual - referenced)
    phantom = sorted(referenced - actual)
    if missing:
        fail(errors, f"{label} SDC misses RTL ports: {', '.join(missing)}")
    if phantom:
        fail(errors, f"{label} SDC references unknown ports: {', '.join(phantom)}")
    if not (missing or phantom):
        passed(f"{label} SDC references all {len(actual)} RTL ports with no phantom ports")


def check_ownership(errors: list[str]) -> None:
    initial_error_count = len(errors)
    path = DMA_ROOT / "docs" / "integration" / "integration_traceability.csv"
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    module_rows = [row for row in rows if row["Kind"] == "MODULE"]
    names = [row["Module or work item"] for row in module_rows]
    expected_names = set().union(*GROUPS.values())
    if len(names) != 17 or set(names) != expected_names or len(names) != len(set(names)):
        fail(errors, "ownership ledger must contain each of the 17 module targets exactly once")
        return
    for group, expected in GROUPS.items():
        actual = {row["Module or work item"] for row in module_rows if row["Group"] == group}
        if actual != expected:
            fail(errors, f"ownership group {group} mismatch: expected={sorted(expected)} actual={sorted(actual)}")
    if len(errors) == initial_error_count:
        passed("ownership ledger contains 17 unique modules with canonical A/B/C/UNASSIGNED groups")


def check_wrapper(errors: list[str]) -> None:
    path = REPO_ROOT / "rtl" / "fw_drain_fsm.v"
    initial_error_count = len(errors)
    check_ports(path, errors, "fw_drain_fsm", expected_wrapper_ports())
    text = path.read_text(encoding="utf-8")
    write_instances = len(re.findall(r"\bfw_write_drain\s+[A-Za-z_]\w*\s*\(", text))
    read_instances = len(re.findall(r"\bfw_read_drain\s+[A-Za-z_]\w*\s*\(", text))
    if write_instances != 1 or read_instances != 1:
        fail(errors, "fw_drain_fsm must instantiate exactly one write drain and one read drain")
    if re.search(r"\balways\b", text):
        fail(errors, "fw_drain_fsm contains sequential/combinational state logic; wrapper must remain structural")
    if len(errors) == initial_error_count:
        passed("fw_drain_fsm is a structural two-leaf wrapper")


def check_mocks(errors: list[str]) -> None:
    initial_error_count = len(errors)
    mock_root = DMA_ROOT / "tb" / "integration" / "mocks"
    mocks = sorted(mock_root.glob("*.v"))
    if not mocks:
        fail(errors, "no integration mocks found")
        return
    for path in mocks:
        text = path.read_text(encoding="utf-8")
        if "SIMULATION-ONLY MOCK" not in text:
            fail(errors, f"mock lacks mandatory label: {path.relative_to(DMA_ROOT)}")
    production_mock_hits = []
    for path in (REPO_ROOT / "rtl").glob("*.v"):
        if "SIMULATION-ONLY MOCK" in path.read_text(encoding="utf-8"):
            production_mock_hits.append(str(path.relative_to(REPO_ROOT)))
    if production_mock_hits:
        fail(errors, f"simulation mock found in production RTL: {', '.join(production_mock_hits)}")
    elif len(errors) == initial_error_count:
        passed(f"{len(mocks)} labelled mocks are isolated under tb/integration/mocks")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-real",
        action="store_true",
        help="Return failure while any real Firewall leaf dependency is absent.",
    )
    args = parser.parse_args()
    errors: list[str] = []

    check_ownership(errors)
    check_wrapper(errors)
    check_mocks(errors)
    check_ports(
        DMA_ROOT / "tb" / "integration" / "mocks" / "dma_bus_firewall_stub.v",
        errors,
        "simulation Firewall stub",
        expected_public_ports(),
    )

    production_top = REPO_ROOT / "rtl" / "dma_bus_firewall.v"
    if production_top.exists():
        check_ports(
            production_top,
            errors,
            "production dma_bus_firewall",
            expected_public_ports(),
        )
    else:
        print("[BLOCKED_DEPENDENCY] production dma_bus_firewall.v awaits accepted leaf interfaces")

    check_sdc_port_coverage(
        production_top,
        REPO_ROOT / "constraints" / "dma_bus_firewall.sdc",
        errors,
        "dma_bus_firewall",
    )
    check_sdc_port_coverage(
        REPO_ROOT / "rtl" / "aegis_soc_top.v",
        REPO_ROOT / "constraints" / "aegis_soc_top.sdc",
        errors,
        "aegis_soc_top",
    )

    missing = [name for name, path in REAL_FIREWALL_SOURCES.items() if not path.exists()]
    for name in missing:
        print(f"[BLOCKED_DEPENDENCY] real source absent: {name} ({REAL_FIREWALL_SOURCES[name]})")
    if args.require_real and missing:
        fail(errors, f"--require-real requested but {len(missing)} Firewall leaf sources are absent")
    elif not missing:
        passed(f"all {len(REAL_FIREWALL_SOURCES)} production Firewall dependencies are present")

    if errors:
        print(f"CONTRACT CHECK FAILED: {len(errors)} issue(s)")
        return 1
    print("CONTRACT CHECK PASSED: production Firewall sources and public interfaces are consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
