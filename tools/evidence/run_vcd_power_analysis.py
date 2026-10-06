import subprocess
from pathlib import Path
import re
import json
import os

REPO_ROOT = Path("/mnt/d/domixi")
OPENROAD_BIN = os.environ.get("OPENROAD_BIN", "/build/bin/openroad")
CANDIDATE_ROOT = Path(
    os.environ.get(
        "AEGIS_RERUN_ROOT",
        "/mnt/d/domixi/output/verification/ppa_rerun_20260920",
    )
)
CANDIDATE_ROOT.mkdir(parents=True, exist_ok=True)

tasks = [
    {
        "top": "dma_bus_firewall",
        "scope": "tb_gate_sdf_firewall",
        "vcd": "/mnt/d/domixi/output/physical/sky130_dma_bus_firewall/gate_sdf_firewall.vcd",
        "out_dir": "/mnt/d/domixi/output/physical/sky130_dma_bus_firewall"
    },
    {
        "top": "aegis_soc_top",
        "scope": "tb_gate_sdf_soc",
        "vcd": "/mnt/d/domixi/output/physical/sky130_aegis_soc_top/gate_sdf_soc.vcd",
        "out_dir": "/mnt/d/domixi/output/physical/sky130_aegis_soc_top"
    }
]

results = {}

for t in tasks:
    top = t["top"]
    out_dir = Path(t["out_dir"])
    tcl_file = CANDIDATE_ROOT / f"{top}_run_vcd_power.tcl"
    rpt_file = CANDIDATE_ROOT / f"{top}_power_vcd.rpt"
    
    tcl_code = f"""
read_liberty {out_dir}/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db {out_dir}/{top}.odb
read_spef {out_dir}/{top}.spef
read_sdc {out_dir}/{top}.sdc
create_clock -name clk -period 26.315 [get_ports clk]
set_propagated_clock [all_clocks]

puts "=========================================================="
puts ">>> READING POWER ACTIVITIES FROM VCD ({t['vcd']})"
puts "=========================================================="
read_vcd -scope {t['scope']} {t['vcd']}

puts "=========================================================="
puts ">>> REPORT POWER WITH VCD WORKLOAD ACTIVITY @ 38.00 MHz"
puts "=========================================================="
report_power

exit 0
"""
    tcl_file.write_text(tcl_code, encoding="utf-8")
    print(f"Running OpenROAD VCD power analysis for {top}...")
    
    res = subprocess.run(
        [OPENROAD_BIN, "-exit", str(tcl_file)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    rpt_file.write_text(res.stdout, encoding="utf-8")
    if res.returncode != 0:
        results[top] = {
            "status": "RERUN_BLOCKED",
            "report_status": "CANDIDATE_RAW_REPORT_PRESERVED",
            "return_code": res.returncode,
            "error": "OpenROAD VCD power analysis failed",
            "candidate_report": str(rpt_file.relative_to(REPO_ROOT)),
        }
        print(f"  {top}: rerun blocked with exit code {res.returncode}; candidate report preserved")
        continue
    
    # Parse table from stdout
    # Look for Total line: Total <Internal> <Switching> <Leakage> <Total>
    lines = res.stdout.splitlines()
    total_match = re.search(r"Total\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)", res.stdout)
    seq_match = re.search(r"Sequential\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)", res.stdout)
    comb_match = re.search(r"Combinational\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)", res.stdout)
    clk_match = re.search(r"Clock\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)", res.stdout)
    
    if total_match:
        int_p = float(total_match.group(1)) * 1e3
        sw_p = float(total_match.group(2)) * 1e3
        leak_p = float(total_match.group(3)) * 1e9
        tot_p = float(total_match.group(4)) * 1e3
        results[top] = {
            "status": "PASS",
            "report_status": "RAW_REPORT_GENERATED",
            "frequency_mhz": 38.0,
            "period_ns": 26.315,
            "total_power_mw": round(tot_p, 2),
            "internal_power_mw": round(int_p, 2),
            "switching_power_mw": round(sw_p, 2),
            "leakage_power_nw": round(leak_p, 1),
            "sequential_power_mw": round(float(seq_match.group(4)) * 1e3, 2) if seq_match else None,
            "combinational_power_mw": round(float(comb_match.group(4)) * 1e3, 2) if comb_match else None,
            "clock_tree_power_mw": round(float(clk_match.group(4)) * 1e3, 2) if clk_match else None,
            "analysis_method": "OpenROAD read_vcd activity annotation",
            "activity_scope": t["scope"],
            "activity_source": str(Path(t["vcd"]).relative_to(REPO_ROOT)),
            "report": str(rpt_file.relative_to(REPO_ROOT)),
            "promotion": "NOT_PROMOTED_PENDING_REVIEW",
        }
        print(f"  {top}: Total Power = {tot_p:.2f} mW (Int: {int_p:.2f} mW, Sw: {sw_p:.2f} mW, Leak: {leak_p:.1f} nW)")
    else:
        results[top] = {
            "status": "RERUN_BLOCKED",
            "report_status": "CANDIDATE_RAW_REPORT_PRESERVED",
            "return_code": res.returncode,
            "error": "Power table could not be parsed",
            "candidate_report": str(rpt_file.relative_to(REPO_ROOT)),
        }
        print(f"  {top}: Failed to parse power report!")

print("\n=== SUMMARY OF VCD WORKLOAD-BASED POWER SIGN-OFF ===")
print(json.dumps(results, indent=2))
with open(CANDIDATE_ROOT / "power_vcd_summary.json", "w", encoding="utf-8") as jf:
    json.dump(results, jf, indent=2)
