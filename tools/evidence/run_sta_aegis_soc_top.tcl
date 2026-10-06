# Independent OpenSTA signoff script for aegis_soc_top
set phys_dir "/mnt/d/domixi/output/physical/sky130_aegis_soc_top"

puts "=== Reading Liberty ==="
read_liberty "$phys_dir/sky130_fd_sc_hd__tt_025C_1v80.lib"

puts "=== Reading Verilog ==="
read_verilog "$phys_dir/aegis_soc_top.pnl.v"

puts "=== Linking Design ==="
link_design aegis_soc_top

puts "=== Reading SDC ==="
read_sdc "$phys_dir/aegis_soc_top.sdc"

puts "=== Reading SPEF ==="
read_spef "$phys_dir/aegis_soc_top.spef"

puts "\n=========================================="
puts "=== SETUP TIMING CHECK (PATH_DELAY MAX) ==="
puts "=========================================="
report_checks -path_delay max -fields {slew cap input_pin} -digits 3

puts "\n========================================="
puts "=== HOLD TIMING CHECK (PATH_DELAY MIN) ==="
puts "========================================="
report_checks -path_delay min -fields {slew cap input_pin} -digits 3

puts "\n==============================="
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
