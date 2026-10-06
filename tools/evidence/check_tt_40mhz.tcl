read_liberty /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.odb
read_spef /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_sdc /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.sdc
create_clock -name clk -period 25.000 [get_ports clk]
set_propagated_clock [all_clocks]
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]
puts "=== CHECKING FIREWALL TT 40MHz ==="
report_checks -path_delay max -digits 3
report_checks -path_delay min -digits 3
puts -nonewline "Setup WNS: "; report_worst_slack -max
puts -nonewline "Setup TNS: "; report_tns -max
puts -nonewline "Hold WNS: "; report_worst_slack -min
puts -nonewline "Hold TNS: "; report_tns -min

read_db /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.odb
read_spef /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.spef
read_sdc /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.sdc
create_clock -name clk -period 25.000 [get_ports clk]
set_propagated_clock [all_clocks]
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]
puts "=== CHECKING SOC TT 40MHz ==="
report_checks -path_delay max -digits 3
report_checks -path_delay min -digits 3
puts -nonewline "Setup WNS: "; report_worst_slack -max
puts -nonewline "Setup TNS: "; report_tns -max
puts -nonewline "Hold WNS: "; report_worst_slack -min
puts -nonewline "Hold TNS: "; report_tns -min

exit
