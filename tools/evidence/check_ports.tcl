readnet spice /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/lvs_work/dma_bus_firewall_layout.spice 1
readnet verilog /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.pnl.v 2
puts "Spice ports: [llength [ports dma_bus_firewall 1]]"
puts "Verilog ports: [llength [ports dma_bus_firewall 2]]"
quit
