
read_liberty /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib
read_db /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.odb
read_spef /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.spef
read_sdc /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.sdc

# Constrain to 19.23 MHz (52.0 ns period) for Industrial SS corner
create_clock -name clk -period 52.000 [get_ports clk]
set_propagated_clock [all_clocks]

# Functional mode: test_mode is static low (DFT bypass inactive)
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]

puts "\n========================================================"
puts ">>> INDUSTRIAL EXTENDED SS CORNER (1.6V, 100C, 52.0ns) FOR aegis_soc_top"
puts "========================================================"
report_checks -path_delay max -fields {slew cap input fanout} -digits 3

puts "\n>>> HOLD CHECKS FOR SS CORNER (aegis_soc_top):"
report_checks -path_delay min -fields {slew cap input fanout} -digits 3

puts "\n>>> SLACK SUMMARY AT 52.0ns (19.23 MHz):"
puts -nonewline "Setup WNS: "
report_worst_slack -max
puts -nonewline "Setup TNS: "
report_tns -max
puts -nonewline "Hold WNS: "
report_worst_slack -min
puts -nonewline "Hold TNS: "
report_tns -min

exit
