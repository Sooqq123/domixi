read_liberty /mnt/d/domixi/output/physical/sky130_aegis_soc_top/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.odb
read_spef /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.spef
read_sdc /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.sdc
create_clock -name clk -period 26.315 [get_ports clk]
set_propagated_clock [all_clocks]

puts "=========================================================="
puts ">>> REPORT POWER BASELINE (Vectorless alpha=0.1, 38 MHz)"
puts "=========================================================="
set_power_activity -input -activity 0.1
report_power

puts "=========================================================="
puts ">>> READING POWER ACTIVITIES FROM VCD"
puts "=========================================================="
catch { read_vcd -scope tb_gate_sdf_soc /mnt/d/domixi/output/physical/sky130_aegis_soc_top/gate_sdf_soc.vcd } res
puts "Result: $res"

puts "=========================================================="
puts ">>> REPORT POWER AFTER VCD (Workload Activity, 38 MHz)"
puts "=========================================================="
report_power

exit 0
