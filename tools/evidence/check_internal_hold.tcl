read_liberty /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.odb
read_spef /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_sdc /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.sdc
create_clock -name clk -period 26.315 [get_ports clk]
set_propagated_clock [all_clocks]
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]
puts "=== INTERNAL FLOP-TO-FLOP HOLD CHECKS ==="
report_checks -path_delay min -from [all_registers] -to [all_registers] -digits 3
exit
