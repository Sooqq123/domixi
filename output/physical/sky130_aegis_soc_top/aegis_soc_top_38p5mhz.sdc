# AEGIS SoC integration boundary: one synchronous clock domain.
# Reset is asynchronous and is constrained as a false path for this generic
# handoff; reset recovery/removal remains library/implementation-specific.
create_clock -name clk -period 25.974 [get_ports clk]
set_clock_uncertainty -setup 0.100 [get_clocks clk]
set_clock_uncertainty -hold 0.050 [get_clocks clk]
set_clock_transition 0.100 [get_clocks clk]
set_input_delay -clock clk -max 2.000 [get_ports {test_mode ext_mem_ready ext_mem_rdata m_axi_awready m_axi_wready m_axi_bid m_axi_bresp m_axi_bvalid m_axi_arready m_axi_rid m_axi_rdata m_axi_rresp m_axi_rlast m_axi_rvalid}]
set_input_delay -clock clk -min 0.200 [get_ports {test_mode ext_mem_ready ext_mem_rdata m_axi_awready m_axi_wready m_axi_bid m_axi_bresp m_axi_bvalid m_axi_arready m_axi_rid m_axi_rdata m_axi_rresp m_axi_rlast m_axi_rvalid}]
set_output_delay -clock clk -max 2.000 [get_ports {ext_mem_valid ext_mem_instr ext_mem_addr ext_mem_wdata ext_mem_wstrb cpu_irq3 cpu_trap cpu_stall dma_irq sec_irq aegis_nmi_irq aegis_anomaly_alert aegis_threat_level aegis_honey_hit m_axi_awid m_axi_awaddr m_axi_awlen m_axi_awsize m_axi_awburst m_axi_awprot m_axi_awcache m_axi_awlock m_axi_awqos m_axi_awregion m_axi_awvalid m_axi_wdata m_axi_wstrb m_axi_wlast m_axi_wvalid m_axi_bready m_axi_arid m_axi_araddr m_axi_arlen m_axi_arsize m_axi_arburst m_axi_arprot m_axi_arcache m_axi_arlock m_axi_arqos m_axi_arregion m_axi_arvalid m_axi_rready}]
set_output_delay -clock clk -min -0.200 [get_ports {ext_mem_valid ext_mem_instr ext_mem_addr ext_mem_wdata ext_mem_wstrb cpu_irq3 cpu_trap cpu_stall dma_irq sec_irq aegis_nmi_irq aegis_anomaly_alert aegis_threat_level aegis_honey_hit m_axi_awid m_axi_awaddr m_axi_awlen m_axi_awsize m_axi_awburst m_axi_awprot m_axi_awcache m_axi_awlock m_axi_awqos m_axi_awregion m_axi_awvalid m_axi_wdata m_axi_wstrb m_axi_wlast m_axi_wvalid m_axi_bready m_axi_arid m_axi_araddr m_axi_arlen m_axi_arsize m_axi_arburst m_axi_arprot m_axi_arcache m_axi_arlock m_axi_arqos m_axi_arregion m_axi_arvalid m_axi_rready}]
set_false_path -from [get_ports rst_n]
