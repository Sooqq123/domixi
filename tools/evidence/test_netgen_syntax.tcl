# Test netgen syntax
set std_cell_spice "/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice"
set verilog_netlist "/mnt/d/domixi/output/physical/sky130_dma_bus_firewall/mapped_netlist.v"

puts "Reading stdcell spice into circuit 2..."
readnet spice $std_cell_spice 2
puts "Reading verilog into circuit 2..."
readnet verilog $verilog_netlist 2
puts "Circuit 2 loaded successfully."
exit 0
