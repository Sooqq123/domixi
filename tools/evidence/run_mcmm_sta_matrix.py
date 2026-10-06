import os
import subprocess
from pathlib import Path

REPO_ROOT = Path("/mnt/d/domixi")
PDK_LIB_DIR = Path("/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib")
OPENROAD_BIN = "/home/nhat/AIHDL/OpenROAD/build/bin/openroad"

LIB_TT = PDK_LIB_DIR / "sky130_fd_sc_hd__tt_025C_1v80.lib"
LIB_SS = PDK_LIB_DIR / "sky130_fd_sc_hd__ss_100C_1v60.lib"
LIB_FF = PDK_LIB_DIR / "sky130_fd_sc_hd__ff_n40C_1v95.lib"

TCL_SCRIPT = REPO_ROOT / "tools" / "evidence" / "run_sta_corner_detailed.tcl"

def run_sta(top_name, lib_path, sdc_path, out_prefix, corner_name):
    out_dir = REPO_ROOT / "output" / "physical" / f"sky130_{top_name}"
    odb_file = out_dir / f"{top_name}.odb"
    spef_file = out_dir / f"{top_name}.spef"
    
    tcl_content = f"""
read_liberty {lib_path}
read_db {odb_file}
read_spef {spef_file}
read_sdc {sdc_path}
set_propagated_clock [all_clocks]

puts "\\n========================================================"
puts ">>> SETUP REPORT FOR {corner_name} ({top_name})"
puts "========================================================"
report_checks -path_delay max -fields {{slew cap input fanout}} -digits 3

puts "\\n========================================================"
puts ">>> HOLD REPORT FOR {corner_name} ({top_name})"
puts "========================================================"
report_checks -path_delay min -fields {{slew cap input fanout}} -digits 3

puts "\\n>>> WORST SLACK SUMMARY:"
puts -nonewline "Setup WNS: "
report_worst_slack -max
puts -nonewline "Setup TNS: "
report_tns -max
puts -nonewline "Hold WNS: "
report_worst_slack -min
puts -nonewline "Hold TNS: "
report_tns -min

exit
"""
    tcl_file = out_dir / f"run_{out_prefix}.tcl"
    tcl_file.write_text(tcl_content, encoding="utf-8")
    log_file = out_dir / f"{out_prefix}.rpt"
    
    cmd = f"{OPENROAD_BIN} -exit {tcl_file}"
    print(f"Running STA for {top_name} {corner_name}...")
    with open(log_file, "w", encoding="utf-8") as lf:
        res = subprocess.run(["bash", "-c", cmd], stdout=lf, stderr=subprocess.STDOUT)
    print(f"  Finished with exit code {res.returncode}. Log: {log_file}")
    return res.returncode

def main():
    # 1. Create 38.5MHz SDC for dma_bus_firewall
    fw_sdc_40 = REPO_ROOT / "output" / "physical" / "sky130_dma_bus_firewall" / "dma_bus_firewall.sdc"
    fw_sdc_38p5 = REPO_ROOT / "output" / "physical" / "sky130_dma_bus_firewall" / "dma_bus_firewall_38p5mhz.sdc"
    txt = fw_sdc_40.read_text(encoding="utf-8")
    txt_38p5 = txt.replace("-period 25.000", "-period 25.974")
    fw_sdc_38p5.write_text(txt_38p5, encoding="utf-8")

    # 2. Create 38.5MHz SDC for aegis_soc_top
    soc_sdc_40 = REPO_ROOT / "output" / "physical" / "sky130_aegis_soc_top" / "aegis_soc_top.sdc"
    soc_sdc_38p5 = REPO_ROOT / "output" / "physical" / "sky130_aegis_soc_top" / "aegis_soc_top_38p5mhz.sdc"
    txt = soc_sdc_40.read_text(encoding="utf-8")
    txt_38p5 = txt.replace("-period 25.000", "-period 25.974")
    soc_sdc_38p5.write_text(txt_38p5, encoding="utf-8")

    # Run STA matrix
    for top in ["dma_bus_firewall", "aegis_soc_top"]:
        sdc_40 = REPO_ROOT / "output" / "physical" / f"sky130_{top}" / f"{top}.sdc"
        sdc_38p5 = REPO_ROOT / "output" / "physical" / f"sky130_{top}" / f"{top}_38p5mhz.sdc"
        
        # SS @ 38.5 MHz
        run_sta(top, LIB_SS, sdc_38p5, "sta_ss_100C_1v60_38p5mhz", "SS_100C_1v60_at_38.5MHz")
        # SS @ 40.0 MHz
        run_sta(top, LIB_SS, sdc_40, "sta_ss_100C_1v60_40mhz", "SS_100C_1v60_at_40MHz")
        # FF @ 40.0 MHz
        run_sta(top, LIB_FF, sdc_40, "sta_ff_n40C_1v95_40mhz", "FF_n40C_1v95_at_40MHz")

if __name__ == "__main__":
    main()
