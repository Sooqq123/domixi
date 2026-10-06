import os
from pathlib import Path

designs = [
    ('sky130_dma_bus_firewall', 'dma_bus_firewall'),
    ('sky130_aegis_soc_top', 'aegis_soc_top')
]

for design_dir, top in designs:
    phys_dir = f"/mnt/d/domixi/output/physical/{design_dir}"
    tcl = f"""# Independent OpenSTA signoff script for {top}
set phys_dir "{phys_dir}"

puts "=== Reading Liberty ==="
read_liberty "$phys_dir/sky130_fd_sc_hd__tt_025C_1v80.lib"

puts "=== Reading Verilog ==="
read_verilog "$phys_dir/{top}.pnl.v"

puts "=== Linking Design ==="
link_design {top}

puts "=== Reading SDC ==="
read_sdc "$phys_dir/{top}.sdc"

puts "=== Reading SPEF ==="
read_spef "$phys_dir/{top}.spef"

puts "\\n=========================================="
puts "=== SETUP TIMING CHECK (PATH_DELAY MAX) ==="
puts "=========================================="
report_checks -path_delay max -fields {{slew cap input_pin}} -digits 3

puts "\\n========================================="
puts "=== HOLD TIMING CHECK (PATH_DELAY MIN) ==="
puts "========================================="
report_checks -path_delay min -fields {{slew cap input_pin}} -digits 3

puts "\\n==============================="
puts "=== TIMING METRIC SUMMARY ==="
puts "==============================="
puts "--- Worst Slack (Setup) ---"
report_worst_slack -max
puts "--- Worst Slack (Hold) ---"
report_worst_slack -min
puts "--- Total Negative Slack ---"
report_tns
puts "--- Unconstrained Endpoints ---"
report_checks -unconstrained
exit
"""
    tcl_path = Path(f"tools/evidence/run_sta_{top}.tcl")
    tcl_path.write_text(tcl, encoding="utf-8")
    print(f"Written: {tcl_path}")
