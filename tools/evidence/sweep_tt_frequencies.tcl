read_liberty /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.odb
read_spef /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_sdc /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.sdc
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]

puts "\n========================================================"
puts ">>> SWEEPING FIREWALL TT FREQUENCIES"
puts "========================================================"
foreach period {25.0 25.5 25.7 26.0 26.315 27.0 28.0 30.0} {
    create_clock -name clk -period $period [get_ports clk]
    set_propagated_clock [all_clocks]
    set freq [expr {1000.0 / $period}]
    puts [format "--- Period: %.3f ns (Freq: %.2f MHz) ---" $period $freq]
    puts -nonewline "Setup WNS: "; report_worst_slack -max
    puts -nonewline "Setup TNS: "; report_tns -max
    puts -nonewline "Hold WNS: "; report_worst_slack -min
    puts -nonewline "Hold TNS: "; report_tns -min
}
exit
