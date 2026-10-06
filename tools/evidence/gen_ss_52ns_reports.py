import subprocess
from pathlib import Path

REPO_ROOT = Path("/mnt/d/domixi")
LIB_SS = Path("/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib")
OPENROAD_BIN = "/home/nhat/AIHDL/OpenROAD/build/bin/openroad"

for top in ["dma_bus_firewall", "aegis_soc_top"]:
    out_dir = REPO_ROOT / "output" / "physical" / f"sky130_{top}"
    odb_file = out_dir / f"{top}.odb"
    spef_file = out_dir / f"{top}.spef"
    sdc_file = out_dir / f"{top}.sdc"
    
    tcl_code = f"""
read_liberty {LIB_SS}
read_db {odb_file}
read_spef {spef_file}
read_sdc {sdc_file}

# Constrain to 19.23 MHz (52.0 ns period) for Industrial SS corner
create_clock -name clk -period 52.000 [get_ports clk]
set_propagated_clock [all_clocks]

# Functional mode: test_mode is static low (DFT bypass inactive)
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]

puts "\\n========================================================"
puts ">>> INDUSTRIAL EXTENDED SS CORNER (1.6V, 100C, 52.0ns) FOR {top}"
puts "========================================================"
report_checks -path_delay max -fields {{slew cap input fanout}} -digits 3

puts "\\n>>> HOLD CHECKS FOR SS CORNER ({top}):"
report_checks -path_delay min -fields {{slew cap input fanout}} -digits 3

puts "\\n>>> SLACK SUMMARY AT 52.0ns (19.23 MHz):"
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
    tcl_path = out_dir / "run_sta_ss_52ns.tcl"
    tcl_path.write_text(tcl_code, encoding="utf-8")
    log_path = out_dir / f"sta_ss_100C_1v60_52ns.rpt"
    print(f"Generating detailed SS 52ns report for {top}...")
    with open(log_path, "w", encoding="utf-8") as lf:
        subprocess.run([OPENROAD_BIN, "-exit", str(tcl_path)], stdout=lf, stderr=subprocess.STDOUT)
    print(f"  Report generated: {log_path}")

print("All industrial SS reports generated successfully.")
