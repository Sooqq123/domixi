#!/usr/bin/env python3
"""
AEGIS-RISC HDC Model and Verilog Parameter Generator
Conforms to docs/AEGIS_RISC_ARCHITECTURE_SPECIFICATION.md Section 6.3 & 10.1
"""

import os
import sys
import json
import hashlib

# Ensure UTF-8 output on Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODEL_DIR = os.path.join(REPO_ROOT, "model")
MODEL_JSON = os.path.join(MODEL_DIR, "aegis_hdc_model.json")
RTL_GEN_DIR = os.path.join(REPO_ROOT, "rtl", "generated")
PARAMS_VH = os.path.join(RTL_GEN_DIR, "aegis_hdc_params.vh")


def generate_deterministic_vector(seed_name: str, num_chunks: int = 16) -> list[str]:
    """Generates 16x 64-bit deterministic chunks using SHA-256."""
    chunks = []
    for i in range(num_chunks):
        h = hashlib.sha256(f"AEGIS_RISC_V2_{seed_name}_CHUNK_{i}".encode()).hexdigest()
        # Take 16 hex characters = 64 bits
        chunks.append(f"64'h{h[:16].upper()}")
    return chunks


def popcount64(val: int) -> int:
    return bin(val).count("1")


def project_query_chunk(snap: int, chunk_idx: int) -> int:
    mask64 = (1 << 64) - 1
    chunk_idx &= 0xF
    if chunk_idx == 0:
        rot = snap & mask64
    else:
        rot = ((snap << chunk_idx) | (snap >> (64 - chunk_idx))) & mask64
    replicated = 0
    for _ in range(16):
        replicated = (replicated << 4) | chunk_idx
    constant = 0xA5A55A5AC3C33C3C
    shift_right = snap >> chunk_idx
    return (rot ^ replicated ^ constant ^ shift_right) & mask64


def build_model_json() -> dict:
    protos_hex = {
        "PROBE": generate_deterministic_vector("PROBE", 16),
        "ATTACK": generate_deterministic_vector("ATTACK", 16),
        "BREACH": generate_deterministic_vector("BREACH", 16)
    }

    protos_int = {
        k: [int(x.replace("64'h", ""), 16) for x in v] for k, v in protos_hex.items()
    }

    feature_encoding = {
        "snapshot_width_bits": 64,
        "fields": {
            "address": "[63:32] Target access address",
            "delta_t": "[31:24] Saturated inter-arrival cycle timer",
            "axlen": "[23:16] AXI burst length AxLEN",
            "axsize": "[15:13] AXI burst transfer size AxSIZE",
            "master_id": "[12:9] AXI Master identifier MID",
            "is_write": "[8] 1 for write transfer, 0 for read transfer",
            "row_toggle": "[7] 1 if address alternates row index",
            "stall_detected": "[6] 1 if CPU pipeline starvation exceeds threshold",
            "cpu_telemetry_trap": "[5] 1 if CPU hardware exception/trap occurs",
            "reason_precode": "[4:0] Fast-path classification reason precode"
        },
        "query_projection_formula": "rot(snap, chunk_idx) ^ {16{chunk_idx}} ^ 64'hA5A5_5A5A_C3C3_3C3C ^ (snap >> chunk_idx)"
    }

    test_scenarios = [
        {
            "name": "SAFE",
            "addr": 0x10000000, "delta_t": 0x01, "len": 0x07, "size": 0x2, "mid": 0x1,
            "is_write": 1, "row_toggle": 0, "stall": 0, "trap": 0, "reason": 0x01,
            "threat_level": "2'b00"
        },
        {
            "name": "PROBE",
            "addr": 0x10000200, "delta_t": 0x06, "len": 0x00, "size": 0x2, "mid": 0x2,
            "is_write": 0, "row_toggle": 0, "stall": 0, "trap": 0, "reason": 0x02,
            "threat_level": "2'b01"
        },
        {
            "name": "ROW_THRASH",
            "addr": 0x10001000, "delta_t": 0x02, "len": 0x00, "size": 0x2, "mid": 0x3,
            "is_write": 1, "row_toggle": 1, "stall": 0, "trap": 0, "reason": 0x04,
            "threat_level": "2'b10"
        },
        {
            "name": "BREACH",
            "addr": 0x80000000, "delta_t": 0x00, "len": 0x00, "size": 0x2, "mid": 0x0,
            "is_write": 0, "row_toggle": 0, "stall": 0, "trap": 1, "reason": 0x10,
            "threat_level": "2'b11"
        }
    ]

    golden_vectors = []
    for sc in test_scenarios:
        snap = ((sc["addr"] & 0xFFFFFFFF) << 32) | \
               ((sc["delta_t"] & 0xFF) << 24) | \
               ((sc["len"] & 0xFF) << 16) | \
               ((sc["size"] & 0x7) << 13) | \
               ((sc["mid"] & 0xF) << 9) | \
               ((sc["is_write"] & 0x1) << 8) | \
               ((sc["row_toggle"] & 0x1) << 7) | \
               ((sc["stall"] & 0x1) << 6) | \
               ((sc["trap"] & 0x1) << 5) | \
               (sc["reason"] & 0x1F)

        chunks_int = [project_query_chunk(snap, i) for i in range(16)]
        d_probe = sum(popcount64(c ^ p) for c, p in zip(chunks_int, protos_int["PROBE"]))
        d_attack = sum(popcount64(c ^ p) for c, p in zip(chunks_int, protos_int["ATTACK"]))
        d_breach = sum(popcount64(c ^ p) for c, p in zip(chunks_int, protos_int["BREACH"]))

        golden_vectors.append({
            "name": sc["name"],
            "snapshot": f"64'h{snap:016X}",
            "query_chunks": [f"64'h{c:016X}" for c in chunks_int],
            "distances": {
                "probe": d_probe,
                "attack": d_attack,
                "breach": d_breach
            },
            "threat_level": sc["threat_level"]
        })

    return {
        "architecture_major": 2,
        "hdc_model_version": 1,
        "fingerprint_version": 2,
        "dimension": 1024,
        "dimension_log2": 10,
        "lane_width": 64,
        "lane_width_log2": 6,
        "num_chunks": 16,
        "caps_word": "0x020102A6",
        "thresholds": {
            "probe": 380,
            "attack": 350,
            "breach": 320
        },
        "prototypes": protos_hex,
        "feature_encoding": feature_encoding,
        "golden_vectors": golden_vectors
    }


def generate_header(data: dict) -> str:
    lines = [
        "// Auto-generated by tools/gen_hdc_params.py - DO NOT EDIT MANUALLY",
        "// Conforms to AEGIS_RISC_ARCHITECTURE_SPECIFICATION.md (Sky130 v2.0.0)",
        "`ifndef AEGIS_HDC_PARAMS_VH",
        "`define AEGIS_HDC_PARAMS_VH",
        "",
        "/* verilator lint_off UNUSEDPARAM */",
        "",
        f"localparam [7:0]  AEGIS_ARCH_MAJOR       = 8'd{data['architecture_major']};",
        f"localparam [7:0]  AEGIS_HDC_MODEL_VER    = 8'd{data['hdc_model_version']};",
        f"localparam [7:0]  AEGIS_FINGERPRINT_VER  = 8'd{data['fingerprint_version']};",
        f"localparam [3:0]  AEGIS_HDC_DIM_LOG2     = 4'd{data['dimension_log2']};",
        f"localparam [3:0]  AEGIS_HDC_LANE_LOG2    = 4'd{data['lane_width_log2']};",
        f"localparam [31:0] AEGIS_REG_CAPS_VALUE   = 32'h{data['caps_word'][2:]};",
        "",
        f"localparam [10:0] HDC_THRESH_PROBE       = 11'd{data['thresholds']['probe']};",
        f"localparam [10:0] HDC_THRESH_ATTACK      = 11'd{data['thresholds']['attack']};",
        f"localparam [10:0] HDC_THRESH_BREACH      = 11'd{data['thresholds']['breach']};",
        "",
        "// HDC Prototype ROM Lookup Functions"
    ]

    for proto_name in ["PROBE", "ATTACK", "BREACH"]:
        chunks = data["prototypes"][proto_name]
        lines.append(f"function [63:0] get_proto_{proto_name.lower()};")
        lines.append("    input [3:0] chunk_idx;")
        lines.append("    begin")
        lines.append("        case (chunk_idx)")
        for idx, val in enumerate(chunks):
            lines.append(f"            4'd{idx:2d}: get_proto_{proto_name.lower()} = {val};")
        lines.append(f"            default: get_proto_{proto_name.lower()} = 64'h0;")
        lines.append("        endcase")
        lines.append("    end")
        lines.append("endfunction")
        lines.append("")

    lines.append("// HDC Golden Vector Reference Lookup Functions for Verification")
    gvecs = data.get("golden_vectors", [])
    lines.append(f"localparam [3:0] HDC_GOLDEN_VECTOR_COUNT = 4'd{len(gvecs)};")
    lines.append("")

    # get_golden_snapshot
    lines.append("function [63:0] get_golden_snapshot;")
    lines.append("    input [1:0] vec_idx;")
    lines.append("    begin")
    lines.append("        case (vec_idx)")
    for idx, gv in enumerate(gvecs):
        lines.append(f"            2'd{idx}: get_golden_snapshot = {gv['snapshot']};")
    lines.append("            default: get_golden_snapshot = 64'h0;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endfunction")
    lines.append("")

    # get_golden_query_chunk
    lines.append("function [63:0] get_golden_query_chunk;")
    lines.append("    input [1:0] vec_idx;")
    lines.append("    input [3:0] chunk_idx;")
    lines.append("    begin")
    lines.append("        case ({vec_idx, chunk_idx})")
    for v_idx, gv in enumerate(gvecs):
        for c_idx, chunk_val in enumerate(gv["query_chunks"]):
            lines.append(f"            6'h{v_idx * 16 + c_idx:02X}: get_golden_query_chunk = {chunk_val};")
    lines.append("            default: get_golden_query_chunk = 64'h0;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endfunction")
    lines.append("")

    # get_golden_dist_probe
    lines.append("function [10:0] get_golden_dist_probe;")
    lines.append("    input [1:0] vec_idx;")
    lines.append("    begin")
    lines.append("        case (vec_idx)")
    for idx, gv in enumerate(gvecs):
        lines.append(f"            2'd{idx}: get_golden_dist_probe = 11'd{gv['distances']['probe']};")
    lines.append("            default: get_golden_dist_probe = 11'd0;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endfunction")
    lines.append("")

    # get_golden_dist_attack
    lines.append("function [10:0] get_golden_dist_attack;")
    lines.append("    input [1:0] vec_idx;")
    lines.append("    begin")
    lines.append("        case (vec_idx)")
    for idx, gv in enumerate(gvecs):
        lines.append(f"            2'd{idx}: get_golden_dist_attack = 11'd{gv['distances']['attack']};")
    lines.append("            default: get_golden_dist_attack = 11'd0;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endfunction")
    lines.append("")

    # get_golden_dist_breach
    lines.append("function [10:0] get_golden_dist_breach;")
    lines.append("    input [1:0] vec_idx;")
    lines.append("    begin")
    lines.append("        case (vec_idx)")
    for idx, gv in enumerate(gvecs):
        lines.append(f"            2'd{idx}: get_golden_dist_breach = 11'd{gv['distances']['breach']};")
    lines.append("            default: get_golden_dist_breach = 11'd0;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endfunction")
    lines.append("")

    lines.append("/* verilator lint_on UNUSEDPARAM */")
    lines.append("")
    lines.append("`endif // AEGIS_HDC_PARAMS_VH")
    lines.append("")
    return "\n".join(lines)


def main():
    os.makedirs(MODEL_DIR, exist_ok=True)
    os.makedirs(RTL_GEN_DIR, exist_ok=True)

    model_data = build_model_json()
    with open(MODEL_JSON, "w", encoding="utf-8") as f:
        json.dump(model_data, f, indent=2, ensure_ascii=False)
    print(f"[GEN] Generated complete reference model with golden vectors: {MODEL_JSON}")

    header_content = generate_header(model_data)
    with open(PARAMS_VH, "w", encoding="utf-8") as f:
        f.write(header_content)
    print(f"[GEN] Generated RTL params header: {PARAMS_VH}")


if __name__ == "__main__":
    main()

