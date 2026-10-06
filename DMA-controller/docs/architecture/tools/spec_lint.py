# -*- coding: utf-8 -*-
"""Semantic integrity checks for Canonical Architecture Baseline V2.4.1.

This linter checks specification consistency and traceability evidence. A PASS
does not imply RTL conformance, verification closure, or PPA/timing sign-off.
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import sys
from pathlib import Path


if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

ARCH_DIR = Path(__file__).resolve().parent.parent
PROJECT_DIR = ARCH_DIR.parent.parent
RTL_DIR = PROJECT_DIR / "rtl"
TB_DIR = PROJECT_DIR / "tb"
MODEL_DIR = PROJECT_DIR / "model"
BENCHMARK_DIR = PROJECT_DIR / "benchmark_data"

REQUIRED_FILES = {
    "architecture_overview.md",
    "detailed_block_diagram.md",
    "signal_list.csv",
    "pinout.csv",
    "memory_map.csv",
    "register_map.csv",
    "fsm_specification.md",
    "verification_test_plan.md",
    "requirements_traceability.csv",
    "assumptions_and_tbd.md",
    "implementation_conformance_status.md",
    "firewall_rtl_integration_contract.md",
    "document_manifest.csv",
    "verification_evidence_manifest.csv",
    "changelog.md",
}

NORMATIVE_FILES = {
    "architecture_overview.md",
    "detailed_block_diagram.md",
    "fsm_specification.md",
    "assumptions_and_tbd.md",
    "verification_test_plan.md",
    "pinout.csv",
    "signal_list.csv",
    "memory_map.csv",
    "register_map.csv",
    "requirements_traceability.csv",
    "implementation_conformance_status.md",
    "firewall_rtl_integration_contract.md",
}

ALLOWED_STATUS = {
    "Specified",
    "Model Verified",
    "Model Implemented",
    "Model Missing",
    "Model Deviation",
    "Model Under Remediation",
    "RTL Implemented",
    "RTL Missing",
    "RTL Deviation",
    "RTL Partial",
    "RTL Under Remediation",
    "Test Planned",
    "Integration Test Planned",
    "Test Present",
    "Test Passed",
    "Test Stale",
    "Evidence Refresh Pending",
    "BLOCKED_FIREWALL_RTL",
    "BLOCKED_SOC_INTEGRATION",
}


def read_csv(name: str) -> list[dict[str, str]]:
    with (ARCH_DIR / name).open(encoding="utf-8", newline="") as handle:
        raw_rows = list(csv.reader(handle))
    if not raw_rows:
        return []
    header = raw_rows[0]
    return [dict(zip(header, row)) for row in raw_rows[1:] if len(row) == len(header)]


def check_csv_integrity() -> list[str]:
    errors: list[str] = []
    for path in sorted(ARCH_DIR.glob("*.csv")):
        with path.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.reader(handle))
        if not rows:
            errors.append(f"{path.name} is empty")
            continue
        header = rows[0]
        if any(not field.strip() for field in header):
            errors.append(f"{path.name} contains an empty header")
        if len(set(header)) != len(header):
            errors.append(f"{path.name} contains duplicate headers")
        for line_no, row in enumerate(rows[1:], 2):
            if len(row) != len(header):
                errors.append(
                    f"{path.name}:{line_no} has {len(row)} columns; expected {len(header)}"
                )
    return errors


def parse_bits(value: str) -> tuple[int, int] | None:
    match = re.fullmatch(r"\[(\d+)(?::(\d+))?\]", value.strip())
    if not match:
        return None
    high = int(match.group(1))
    low = int(match.group(2) or match.group(1))
    return high, low


def parse_size(value: str) -> int | None:
    hex_match = re.fullmatch(r"(0x[0-9A-Fa-f]+)\s+Bytes", value.strip())
    if hex_match:
        return int(hex_match.group(1), 16)
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)\s+(Bytes|KiB|MiB|GiB)", value.strip())
    if not match:
        return None
    scale = {"Bytes": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3}[match.group(2)]
    return int(float(match.group(1)) * scale)


def check_required_files() -> list[str]:
    return [f"missing required file: {name}" for name in sorted(REQUIRED_FILES) if not (ARCH_DIR / name).is_file()]


def check_pinout_and_signals() -> list[str]:
    errors: list[str] = []
    pins = read_csv("pinout.csv")
    signals = read_csv("signal_list.csv")

    pin_by_name: dict[str, dict[str, str]] = {}
    for row in pins:
        name = row.get("Signal Name", "").strip()
        if not name:
            errors.append("pinout.csv contains an empty signal name")
            continue
        if name in pin_by_name:
            errors.append(f"pinout.csv duplicate signal: {name}")
        pin_by_name[name] = row
        for field in ("Direction", "Width", "Clock Domain", "Source Module", "Dest Module", "Default Reset Value"):
            if not row.get(field, "").strip():
                errors.append(f"pinout.csv {name} missing {field}")

    required_widths = {
        "clk": "1",
        "rst_n": "1",
        "s_apb_paddr": "32",
        "s_apb_pwdata": "32",
        "s_apb_prdata": "32",
        "s_apb_pprot": "3",
        "dma_apb_paddr": "32",
        "dma_apb_pwdata": "32",
        "dma_apb_prdata": "32",
        "dma_irq": "1",
        "dma_ctx_valid": "1",
        "dma_ctx_src_addr": "32",
        "dma_ctx_dst_addr": "32",
        "dma_ctx_byte_len": "32",
        "dma_ctx_done": "1",
        "m_axi_awcache": "4",
        "m_axi_awlock": "1",
        "m_axi_awqos": "4",
        "m_axi_awregion": "4",
        "m_axi_arcache": "4",
        "m_axi_arlock": "1",
        "m_axi_arqos": "4",
        "m_axi_arregion": "4",
    }
    for name, width in required_widths.items():
        if name not in pin_by_name:
            errors.append(f"pinout.csv missing required pin: {name}")
        elif pin_by_name[name]["Width"].strip() != width:
            errors.append(f"pinout.csv {name} width must be {width}")

    for name, row in pin_by_name.items():
        if re.search(r"(?:awid|arid|bid|rid)$", name) and row["Width"].strip() != "4":
            errors.append(f"pinout.csv AXI ID {name} must be 4 bits")
        if "dma_ctx_state" in name:
            errors.append("deprecated dma_ctx_state appears in pinout.csv")

    for name in ("s_axi_awprot", "s_axi_arprot", "m_axi_awprot", "m_axi_arprot"):
        if pin_by_name.get(name, {}).get("Default Reset Value", "").strip() != "3'b001":
            errors.append(f"pinout.csv {name} must use Secure-Privileged Data value 3'b001")

    forbidden_dma_pins = {"dma_apb_pprot", "dma_apb_pstrb"}
    for name in forbidden_dma_pins & pin_by_name.keys():
        errors.append(f"DMA APB3 profile must not expose {name}")

    for name, row in pin_by_name.items():
        protocol = row["Protocol/Timing"].upper()
        if name.startswith("dma_apb_") and "APB3" not in protocol:
            errors.append(f"{name} must be labeled APB3")
        if name.startswith("s_apb_") and name != "s_apb_pstrb" and "APB4" not in protocol:
            errors.append(f"{name} must be labeled APB4 protection profile")

    ready_reset_zero = {
        "s_axi_awready",
        "s_axi_wready",
        "s_axi_arready",
        "s_axi_bready",
        "s_axi_rready",
        "m_axi_bready",
        "m_axi_rready",
    }
    for name in ready_reset_zero:
        if pin_by_name.get(name, {}).get("Default Reset Value", "").strip() != "0":
            errors.append(f"pinout.csv {name} reset value must be 0")
    for name in ("s_apb_pready", "dma_apb_pready"):
        if pin_by_name.get(name, {}).get("Default Reset Value", "").strip() != "1":
            errors.append(f"pinout.csv {name} reset value must be 1")

    for name in ("s_axi_awlen", "s_axi_arlen", "m_axi_awlen", "m_axi_arlen"):
        description = pin_by_name.get(name, {}).get("Functional Description", "")
        if "<=15" not in description and "1-16 beats" not in description:
            errors.append(f"pinout.csv {name} must state the <=15 / 1-16 beat baseline")

    signal_names: set[str] = set()
    for row in signals:
        name = row.get("Signal Name", "").strip()
        if not name:
            errors.append("signal_list.csv contains an empty signal name")
            continue
        if name in signal_names:
            errors.append(f"signal_list.csv duplicate signal: {name}")
        signal_names.add(name)
        for field in ("Width", "Source Module", "Dest Module", "Default Reset Value"):
            if not row.get(field, "").strip():
                errors.append(f"signal_list.csv {name} missing {field}")
        if "dma_ctx_state" in name or "drain_timer" in name:
            errors.append(f"deprecated signal in signal_list.csv: {name}")

    required_internal = {
        "fifo_push",
        "fifo_pop",
        "fifo_count",
        "aw_accepted",
        "abort_pending",
        "read_quiescent",
        "write_quiescent",
        "done_set_event",
        "error_set_event",
        "pipe_s1_awready",
        "pipe_s1_arready",
        "acl_w_id",
        "acl_w_len",
        "acl_r_id",
        "acl_r_len",
        "w_drain_wvalid",
        "w_drain_wlast",
        "w_drain_bready",
        "w_drain_bid",
        "r_drain_rready",
        "r_drain_rid",
        "w_fault_event_valid",
        "r_fault_event_valid",
        "ctx_fault_event_valid",
    }
    for name in sorted(required_internal - signal_names):
        errors.append(f"signal_list.csv missing required internal signal: {name}")

    fifo_push = next((row for row in signals if row.get("Signal Name") == "fifo_push"), None)
    if fifo_push and ("r_error_latched" not in fifo_push["Valid Condition"] or "abort_pending" not in fifo_push["Valid Condition"]):
        errors.append("fifo_push must be gated by r_error_latched and abort_pending")
    return errors


def check_memory_map() -> list[str]:
    errors: list[str] = []
    regions: list[tuple[int, int, str]] = []
    for row in read_csv("memory_map.csv"):
        name = row["Region Name"].strip()
        try:
            base = int(row["Base Address"], 0)
            limit = int(row["Limit Address"], 0)
        except ValueError:
            errors.append(f"memory_map.csv {name} has malformed address")
            continue
        if base > limit:
            errors.append(f"memory_map.csv {name} base exceeds limit")
            continue
        declared = parse_size(row["Size"])
        actual = limit - base + 1
        if declared is None:
            errors.append(f"memory_map.csv {name} has unsupported size syntax: {row['Size']}")
        elif declared != actual:
            errors.append(f"memory_map.csv {name} size is {declared}, expected {actual}")
        regions.append((base, limit, name))

    regions.sort()
    for previous, current in zip(regions, regions[1:]):
        if current[0] <= previous[1]:
            errors.append(f"memory regions overlap: {previous[2]} and {current[2]}")
        if current[0] != previous[1] + 1:
            errors.append(f"memory map gap is not explicitly classified between {previous[2]} and {current[2]}")
    if regions and (regions[0][0] != 0 or regions[-1][1] != 0xFFFF_FFFF):
        errors.append("memory_map.csv must classify the complete 32-bit address space")
    return errors


def check_register_map() -> list[str]:
    errors: list[str] = []
    valid_access = {"RO", "RW", "RW1S", "W1C", "WO"}
    seen_fields: set[tuple[str, str, str]] = set()
    used_bits: dict[tuple[str, str], set[int]] = {}
    required_regs = {"FAULT_SOURCE", "DMA_CTRL", "DMA_SRC", "DMA_DST", "DMA_LEN", "DMA_STATUS"}
    found_regs: set[str] = set()

    for row in read_csv("register_map.csv"):
        reg = row["Register Name"].strip()
        addr = row["Offset Address"].strip()
        field = row["Field Name"].strip()
        access = row["Access Type"].strip()
        found_regs.add(reg)
        if access not in valid_access:
            errors.append(f"register_map.csv {reg}.{field} invalid access {access}")
        try:
            numeric_addr = int(addr, 0)
            if numeric_addr & 0x3:
                errors.append(f"register_map.csv {reg} address is not 4-byte aligned")
        except ValueError:
            errors.append(f"register_map.csv {reg} malformed address {addr}")

        bits = parse_bits(row["Bit Range"])
        if bits is None:
            errors.append(f"register_map.csv {reg}.{field} malformed bit range")
            continue
        high, low = bits
        if high < low or high > 31:
            errors.append(f"register_map.csv {reg}.{field} invalid bit range")
            continue
        field_key = (reg, addr, field)
        if field_key in seen_fields:
            errors.append(f"register_map.csv duplicate field {reg}.{field}")
        seen_fields.add(field_key)
        bit_key = (reg, addr)
        occupied = used_bits.setdefault(bit_key, set())
        overlap = occupied & set(range(low, high + 1))
        if overlap:
            errors.append(f"register_map.csv overlapping bits in {reg}: {sorted(overlap)}")
        occupied.update(range(low, high + 1))

        reset = row["Reset Value"].strip()
        description = row["Description"].strip().lower()
        if reg == "FW_CONTROL" and field == "FW_EN" and reset != "1'b1":
            errors.append("FW_CONTROL.FW_EN reset must be 1'b1")
        if reg in {"RGN_PERM_4", "RGN_PERM_5"} and field == "ACTIVE" and reset != "1'b0":
            errors.append(f"{reg}.ACTIVE reset must be 1'b0")
        if reg in {"RGN_PERM_4", "RGN_PERM_5"} and field in {"SECURE_ONLY", "PRIV_ONLY"} and reset != "1'b1":
            errors.append(f"{reg}.{field} reset must be 1'b1")
        if ("_4" in reg or "_5" in reg) and reg.startswith("RGN_") and access != "RO":
            errors.append(f"dynamic register {reg}.{field} must be APB RO")
        if reg == "FAULT_STATUS" and field == "IRQ_PENDING" and access != "W1C":
            errors.append("FAULT_STATUS.IRQ_PENDING must be W1C")
        if reg == "FAULT_STATUS" and field == "BOUND_ERR":
            for phrase in ("non-incr", "unaligned", "4kb", "len zero"):
                if phrase not in description:
                    errors.append(f"FAULT_STATUS.BOUND_ERR description missing cause: {phrase}")
        if reg == "FAULT_SOURCE" and field == "FIRST_FAULT_SOURCE" and "context" not in description:
            errors.append("FAULT_SOURCE.FIRST_FAULT_SOURCE must encode context faults")
        if reg == "DMA_CTRL" and field == "START":
            if access != "WO":
                errors.append("DMA_CTRL.START must be WO")
            for phrase in ("busy=1", "đọc bit trả về 0", "không tự động xóa"):
                if phrase not in description:
                    errors.append(f"DMA_CTRL.START description missing contract phrase: {phrase}")
        if reg == "DMA_STATUS" and field in {"DONE", "ERROR"} and access != "W1C":
            errors.append(f"DMA_STATUS.{field} must be W1C")

    for reg in sorted(required_regs - found_regs):
        errors.append(f"register_map.csv missing required register {reg}")
    return errors


def check_traceability() -> list[str]:
    errors: list[str] = []
    plan = (ARCH_DIR / "verification_test_plan.md").read_text(encoding="utf-8")
    requirement_ids: set[str] = set()
    for row in read_csv("requirements_traceability.csv"):
        req_id = row["Requirement ID"].strip()
        status = row["Status"].strip()
        if req_id in requirement_ids:
            errors.append(f"traceability duplicate requirement {req_id}")
        requirement_ids.add(req_id)
        if not all(row.get(field, "").strip() for field in ("Category", "Canonical Spec Reference", "Architecture Component", "Model Evidence", "RTL Evidence", "Testcase ID", "Status")):
            errors.append(f"traceability incomplete row {req_id}")

        status_tokens = [token.strip() for token in status.split("/")]
        for token in status_tokens:
            if token not in ALLOWED_STATUS:
                errors.append(f"traceability {req_id} invalid status token: {token}")

        model_evidence = row["Model Evidence"].strip()
        model_files = re.findall(r"[A-Za-z_][A-Za-z0-9_]*\.py", model_evidence)
        if "MODEL MISSING" in model_evidence.upper():
            if "Model Missing" not in status_tokens:
                errors.append(f"traceability {req_id} model evidence says missing but status does not")
        else:
            for filename in model_files:
                if not (MODEL_DIR / filename).is_file():
                    errors.append(f"traceability {req_id} references missing model file {filename}")
            if any(token in status_tokens for token in ("Model Verified", "Model Implemented", "Model Deviation", "Model Under Remediation")) and not model_files:
                errors.append(f"traceability {req_id} has model status without model file evidence")

        rtl_evidence = row["RTL Evidence"].strip()
        rtl_files = re.findall(r"[A-Za-z_][A-Za-z0-9_]*\.v", rtl_evidence)
        if rtl_evidence.upper().startswith("MISSING"):
            if "RTL Missing" not in status_tokens:
                errors.append(f"traceability {req_id} RTL evidence says missing but status does not")
            for filename in rtl_files:
                if (RTL_DIR / filename).exists():
                    errors.append(f"traceability {req_id} stale RTL Missing claim: {filename} now exists")
        elif "PARTIAL DRAFT" in rtl_evidence.upper():
            if "RTL Partial" not in status_tokens:
                errors.append(f"traceability {req_id} partial RTL evidence lacks RTL Partial status")
            for filename in rtl_files:
                if not ((RTL_DIR / filename).is_file() or (PROJECT_DIR.parent / "rtl" / filename).is_file()):
                    errors.append(f"traceability {req_id} references missing partial RTL file {filename}")
        else:
            for filename in rtl_files:
                if not (RTL_DIR / filename).is_file():
                    errors.append(f"traceability {req_id} references missing RTL file {filename}")
            if not any(token in status_tokens for token in ("RTL Implemented", "RTL Deviation", "RTL Under Remediation")):
                errors.append(f"traceability {req_id} has RTL evidence without implemented/deviation status")

        if req_id.startswith("REQ_FW_") and "BLOCKED_FIREWALL_RTL" not in status_tokens:
            if not ("RTL Implemented" in status_tokens and "Test Passed" in status_tokens):
                errors.append(f"traceability {req_id} must remain BLOCKED_FIREWALL_RTL until integration sign-off")

        for test_id in re.findall(r"TC_[A-Z0-9_]+", row["Testcase ID"]):
            if test_id not in plan:
                errors.append(f"traceability {req_id} references undefined test {test_id}")
        sva_text = row.get("SVA Assertion ID", "")
        if sva_text.strip().lower() != "none":
            for property_id in re.findall(r"p_[a-z0-9_]+", sva_text):
                if property_id not in plan:
                    errors.append(f"traceability {req_id} references undefined SVA {property_id}")

    for required in ("REQ_DMA_00", "REQ_DMA_01", "REQ_DMA_02", "REQ_DMA_03", "REQ_DMA_07", "REQ_FW_17", "REQ_FW_20"):
        if required not in requirement_ids:
            errors.append(f"traceability missing mandatory requirement {required}")
    return errors


def check_manifests() -> list[str]:
    errors: list[str] = []
    docs = read_csv("document_manifest.csv")
    doc_ids: set[str] = set()
    for row in docs:
        doc_id = row.get("Document ID", "").strip()
        if not doc_id or doc_id in doc_ids:
            errors.append(f"document_manifest.csv missing or duplicate Document ID: {doc_id}")
        doc_ids.add(doc_id)
        rel = row.get("Path", "").strip()
        if not rel or not (PROJECT_DIR / rel).resolve().is_file():
            errors.append(f"document_manifest.csv {doc_id} missing path: {rel}")

    evidence = read_csv("verification_evidence_manifest.csv")
    evidence_ids: set[str] = set()
    for row in evidence:
        evidence_id = row.get("Evidence ID", "").strip()
        result = row.get("Result", "").strip()
        if not evidence_id or evidence_id in evidence_ids:
            errors.append(f"verification_evidence_manifest.csv missing or duplicate Evidence ID: {evidence_id}")
        evidence_ids.add(evidence_id)
        for field in ("Requirement IDs", "Scope", "Command", "Tool and Version", "Source Revision", "Result", "Artifact", "Executed UTC", "Limitation"):
            if not row.get(field, "").strip():
                errors.append(f"verification_evidence_manifest.csv {evidence_id} missing {field}")
        if result == "PASS":
            artifact = row.get("Artifact", "").strip()
            if not artifact or not (PROJECT_DIR / artifact).resolve().is_file():
                errors.append(f"verification evidence {evidence_id} PASS without artifact: {artifact}")
    return errors


def check_benchmark_evidence() -> list[str]:
    errors: list[str] = []
    csv_path = BENCHMARK_DIR / "benchmark_results.csv"
    json_path = BENCHMARK_DIR / "benchmark_results.json"
    metadata_path = BENCHMARK_DIR / "benchmark_metadata.json"
    for path in (csv_path, json_path, metadata_path):
        if not path.is_file():
            errors.append(f"missing benchmark artifact: {path.name}")
    if errors:
        return errors

    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    with csv_path.open(encoding="utf-8", newline="") as handle:
        records = list(csv.DictReader(handle))
    if metadata.get("record_count") != len(records):
        errors.append("benchmark metadata record_count does not match CSV")
    if metadata.get("all_data_integrity_pass") is not True:
        errors.append("benchmark metadata does not report all_data_integrity_pass=true")

    for path in (csv_path, json_path):
        actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        expected_hash = metadata.get("output_sha256", {}).get(path.name)
        if actual_hash != expected_hash:
            errors.append(f"benchmark output hash mismatch: {path.name}")
    for filename, expected_hash in metadata.get("source_sha256", {}).items():
        source = MODEL_DIR / filename
        if not source.is_file():
            errors.append(f"benchmark metadata references missing source: {filename}")
        elif hashlib.sha256(source.read_bytes()).hexdigest() != expected_hash:
            errors.append(f"benchmark source hash stale: {filename}")

    reference = next(
        (
            row for row in records
            if row.get("test_category") == "FIFO_Depth_Sweep"
            and row.get("fifo_depth") == "32"
            and row.get("mem_latency_cycles") == "1"
            and row.get("transfer_bytes") == "1024"
        ),
        None,
    )
    if reference is None:
        errors.append("benchmark missing FIFO32/latency1/1KiB reference record")
        return errors

    throughput = f"{float(reference['throughput_gb_per_sec']):.3f}"
    utilization = f"{float(reference['bus_utilization_pct']):.1f}"
    stalls = str(int(reference["fifo_full_stalls"]))
    expected_in = {
        "architecture_overview.md": (throughput, utilization, f"từ 255 xuống {stalls}"),
        "assumptions_and_tbd.md": (throughput, utilization, f"{stalls} full-stall"),
        "verification_test_plan.md": (throughput, utilization, f"fifo_full_stall_cycles={stalls}"),
        "../system_model_spec.md": ("1,410.0", utilization, f"**{stalls}**"),
    }
    for relative, phrases in expected_in.items():
        path = (ARCH_DIR / relative).resolve()
        text = path.read_text(encoding="utf-8")
        for phrase in phrases:
            if phrase not in text:
                errors.append(f"{path.name} benchmark reference missing current value: {phrase}")
    return errors


def check_normative_text() -> list[str]:
    errors: list[str] = []
    legacy = re.compile(r"\bV2\.(?:[123]\b|4\b(?!\.1))")
    allowed_history = re.compile(r"histor|obsolete|supersed|xuất trước|tài liệu v2\.1|prd/microarchitecture", re.IGNORECASE)
    overclaim = re.compile(r"flawless|perfect|hoàn hảo|rtl pass|triệt tiêu hoàn toàn|0-cycle data latency|100%\s+(?:passed|complete|hoàn thiện)", re.IGNORECASE)

    for name in sorted(NORMATIVE_FILES):
        text = (ARCH_DIR / name).read_text(encoding="utf-8")
        for line_no, line in enumerate(text.splitlines(), 1):
            if legacy.search(line) and not allowed_history.search(line):
                errors.append(f"{name}:{line_no} unqualified legacy version reference")
            if overclaim.search(line):
                errors.append(f"{name}:{line_no} contains unsupported absolute/achievement claim")

    overview = (ARCH_DIR / "architecture_overview.md").read_text(encoding="utf-8")
    fsm = (ARCH_DIR / "fsm_specification.md").read_text(encoding="utf-8")
    plan = (ARCH_DIR / "verification_test_plan.md").read_text(encoding="utf-8")
    assumptions = (ARCH_DIR / "assumptions_and_tbd.md").read_text(encoding="utf-8")

    required_overview = (
        "Canonical Architecture Baseline V2.4.1 — RTL Integrated / Frontend Verified",
        "AW đã handshake",
        "AR outstanding",
        "Hardware-set event thắng W1C",
        "descriptor/context đang chạy",
        "metadata hiện tại vẫn giữ nguyên",
        "expected_r_beats = ARLEN+1",
    )
    for phrase in required_overview:
        if phrase.lower() not in overview.lower():
            errors.append(f"architecture_overview.md missing contract phrase: {phrase}")

    required_fsm = (
        "post_read_bytes",
        "post_write_bytes",
        "abort_pending",
        "done_set_event",
        "error_set_event",
        "expected_r_beats=ARLEN+1",
        "RLAST != expected_last",
    )
    for phrase in required_fsm:
        if phrase not in fsm:
            errors.append(f"fsm_specification.md missing terminal/abort term: {phrase}")

    drain_match = re.search(r"property p_write_drain_exact_completion;(.*?)endproperty", plan, re.DOTALL)
    if not drain_match or "w_drain_wready" not in drain_match.group(1) or "w_beat_count == w_drain_len" not in drain_match.group(1):
        errors.append("p_write_drain_exact_completion must use ready handshake and latched length")
    no_w_match = re.search(r"property p_dma_no_w_before_aw;(.*?)endproperty", plan, re.DOTALL)
    if not no_w_match or "aw_accepted" not in no_w_match.group(1):
        errors.append("p_dma_no_w_before_aw must use an AW-accepted history flag")
    if "p_dma_error_status_mutex" in plan:
        errors.append("obsolete global ERROR->!DONE assertion conflicts with independent sticky W1C flags")
    for phrase in ("TC_DMA_RLAST_FRAMING", "p_dma_r_last_position"):
        if phrase not in plan:
            errors.append(f"verification_test_plan.md missing read framing check: {phrase}")
    for phrase in ("ABORT_BOUND", "MAX_RVALID_GAP", "MAX_WREADY_LATENCY", "MAX_BVALID_LATENCY", "MAX_BREADY_LATENCY"):
        if phrase not in assumptions:
            errors.append(f"assumptions_and_tbd.md missing fairness term: {phrase}")

    test_ids = re.findall(r"^\| \*\*`(TC_[A-Z0-9_]+)`\*\* \|", plan, re.MULTILINE)
    duplicates = sorted({test_id for test_id in test_ids if test_ids.count(test_id) > 1})
    for test_id in duplicates:
        errors.append(f"verification_test_plan.md duplicate testcase definition: {test_id}")
    return errors


def run() -> int:
    checks = (
        ("required files", check_required_files),
        ("strict CSV integrity", check_csv_integrity),
        ("pinout and signal list", check_pinout_and_signals),
        ("memory map", check_memory_map),
        ("register map", check_register_map),
        ("traceability evidence", check_traceability),
        ("document and evidence manifests", check_manifests),
        ("benchmark artifact consistency", check_benchmark_evidence),
        ("normative cross-document semantics", check_normative_text),
    )
    failures: list[str] = []
    print("Canonical Architecture Baseline V2.4.1 semantic specification lint")
    print("Scope: document consistency/evidence only; RTL conformance and sign-off are separate")
    for title, check in checks:
        try:
            current = check()
        except Exception as exc:  # keep reporting other independent gates
            current = [f"checker raised {type(exc).__name__}: {exc}"]
        if current:
            print(f"[FAIL] {title}: {len(current)} issue(s)")
            for issue in current:
                print(f"  - {issue}")
            failures.extend(current)
        else:
            print(f"[PASS] {title}")
    if failures:
        print(f"LINT FAILED: {len(failures)} error(s)")
        return 1
    print("LINT PASSED: specification consistency checks completed with no detected errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
