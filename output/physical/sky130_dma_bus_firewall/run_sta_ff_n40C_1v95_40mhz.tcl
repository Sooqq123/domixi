
read_liberty /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v95.lib
read_db /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.odb
read_spef /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_sdc /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.sdc
set_propagated_clock [all_clocks]

puts "\n========================================================"
puts ">>> SETUP REPORT FOR FF_n40C_1v95_at_40MHz (dma_bus_firewall)"
puts "========================================================"
report_checks -path_delay max -fields {slew cap input fanout} -digits 3

puts "\n========================================================"
puts ">>> HOLD REPORT FOR FF_n40C_1v95_at_40MHz (dma_bus_firewall)"
puts "========================================================"
report_checks -path_delay min -fields {slew cap input fanout} -digits 3

puts "\n>>> WORST SLACK SUMMARY:"
puts -nonewline "Setup WNS: "
report_worst_slack -max
puts -nonewline "Setup TNS: "
report_tns -max
puts -nonewline "Hold WNS: "
report_worst_slack -min
puts -nonewline "Hold TNS: "
report_tns -min

exit
