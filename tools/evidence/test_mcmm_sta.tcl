read_lef /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

define_corners ss_corner tt_corner ff_corner
read_liberty -corner ss_corner /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib
read_liberty -corner tt_corner /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_liberty -corner ff_corner /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v95.lib

read_verilog /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/mapped_netlist.v
link_design dma_bus_firewall

read_spef -corner ss_corner /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_spef -corner tt_corner /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_spef -corner ff_corner /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef

read_sdc /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.sdc

puts "\n=========================================="
puts "  CORNER: SS (Slow-Slow 1.60V, 100C) SETUP"
puts "=========================================="
report_worst_slack -corner ss_corner -max
report_tns -corner ss_corner -max
report_checks -corner ss_corner -path_delay max -fields {slew cap input nets fanout} -digits 3

puts "\n=========================================="
puts "  CORNER: TT (Typical-Typical 1.80V, 25C) SETUP"
puts "=========================================="
report_worst_slack -corner tt_corner -max
report_tns -corner tt_corner -max
report_checks -corner tt_corner -path_delay max -fields {slew cap input nets fanout} -digits 3

puts "\n=========================================="
puts "  CORNER: FF (Fast-Fast 1.95V, -40C) HOLD"
puts "=========================================="
report_worst_slack -corner ff_corner -min
report_tns -corner ff_corner -min
report_checks -corner ff_corner -path_delay min -fields {slew cap input nets fanout} -digits 3
exit
