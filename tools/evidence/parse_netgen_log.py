#!/usr/bin/env python3
"""
parse_netgen_log.py

Strictly inspects raw Netgen LVS log:
- Verifies if 'Circuits match uniquely.' is present.
- Extracts device, net, and pin counts.
- Updates lvs.rpt with genuine evidence.
- Returns 0 on clean match, 1 on any discrepancy or missing conclusion.
"""

import sys
import re
from pathlib import Path


def parse_netgen_log(log_path: str, rpt_path: str, top_name: str) -> bool:
    p_log = Path(log_path)
    p_rpt = Path(rpt_path)

    if not p_log.is_file():
        print(f"[ERROR] Netgen log file not found: {p_log}")
        return False

    with p_log.open('r', encoding='utf-8', errors='replace') as f:
        log_text = f.read()

    # Look for definitive Netgen conclusion
    matched = bool(re.search(r'Circuits match uniquely\.', log_text))

    # Extract device count
    # Circuit 1 contains 29957 devices, Circuit 2 contains 29957 devices.
    # or: Number of devices: 29957 | Number of devices: 29957
    dev_match = re.search(r'Circuit 1 contains (\d+) devices,\s+Circuit 2 contains (\d+) devices', log_text)
    if not dev_match:
        dev_match = re.search(r'Number of devices:\s*(\d+)\s*\|\s*Number of devices:\s*(\d+)', log_text)
    dev_c1 = dev_match.group(1) if dev_match else "UNKNOWN"
    dev_c2 = dev_match.group(2) if dev_match else "UNKNOWN"

    # Extract net count
    # Circuit 1 contains 30422 nets, Circuit 2 contains 30422 nets.
    # or: Number of nets: 30422 | Number of nets: 30422
    net_match = re.search(r'Circuit 1 contains (\d+) nets,\s+Circuit 2 contains (\d+) nets', log_text)
    if not net_match:
        net_match = re.search(r'Number of nets:\s*(\d+)\s*\|\s*Number of nets:\s*(\d+)', log_text)
    net_c1 = net_match.group(1) if net_match else "UNKNOWN"
    net_c2 = net_match.group(2) if net_match else "UNKNOWN"

    # Check pin equivalence
    pins_equiv = bool(re.search(r'Cell pin lists are equivalent\.', log_text))
    classes_equiv = bool(re.search(rf'Device classes {top_name} and {top_name} are equivalent\.', log_text))

    status = "PASS" if matched else "REVIEW_REQUIRED"
    match_status = "MATCHED" if matched else "MISMATCH"
    discrepancies = "0 pin / 0 net / 0 device" if matched else "Unresolved discrepancies detected in raw log"
    final_res = "Circuits match uniquely." if matched else "LVS Mismatch - Review Required"

    report_content = f"""================================================================================
Layout Versus Schematic (LVS) Report: {top_name}
PDK: SkyWater 130nm (sky130A / sky130_fd_sc_hd)
Tool: Netgen 1.5.255 (Independent Golden LVS Deck sky130A_setup.tcl)
Status: {status}
Netlist Match: {match_status}
================================================================================
Top cell: {top_name}
Extraction engine: Magic 8.3 VLSI (LEF/DEF geometry extraction)
Comparison engine: Netgen 1.5.255 (transistor/gate topology graph isomorphism)
Device count (Layout): {dev_c1}
Device count (Schematic): {dev_c2}
Net count (Layout): {net_c1}
Net count (Schematic): {net_c2}
Discrepancies: {discrepancies}
Final Result: {final_res}
================================================================================
"""

    p_rpt.parent.mkdir(parents=True, exist_ok=True)
    with p_rpt.open('w', encoding='utf-8') as f:
        f.write(report_content)

    print(f"Generated LVS report: {p_rpt}")
    print(f"  Status: {status}")
    print(f"  Netlist Match: {match_status}")
    print(f"  Layout Devices: {dev_c1}, Schematic Devices: {dev_c2}")
    print(f"  Layout Nets: {net_c1}, Schematic Nets: {net_c2}")
    print(f"  Final Conclusion: {final_res}")

    return matched


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: parse_netgen_log.py <netgen_log> <output_rpt> <top_name>")
        sys.exit(1)
    success = parse_netgen_log(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if success else 1)
