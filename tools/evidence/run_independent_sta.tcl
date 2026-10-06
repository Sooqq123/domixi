# Independent OpenSTA signoff script
set design [lindex $argv 0]
set phys_dir "/mnt/d/domixi/output/physical/$design"

puts "Running independent STA on $design..."
read_liberty "$phys_dir/sky130_fd_sc_hd__tt_025C_1v80.lib"
read_verilog "$phys_dir/$design.pnl.v"
link_design $design
read_sdc "$phys_dir/$design.sdc"
read_spef "$phys_dir/$design.spef"

puts "\n=== SETUP CHECK (MAX) ==="
report_checks -path_delay max -fields {slew cap input_pin} -digits 3

puts "\n=== HOLD CHECK (MIN) ==="
report_checks -path_delay min -fields {slew cap input_pin} -digits 3

puts "\n=== TIMING METRICS SUMMARY ==="
report_worst_slack -max
report_worst_slack -min
report_tns -max
report_tns -min
exit
