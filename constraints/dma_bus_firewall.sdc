# Official Sign-off SDC for production dma_bus_firewall IP.
# Clock period derated to 26.315 ns (38.00 MHz) under Engineering Waiver WAV-STA-003.
#
# Scope: one synchronous clock domain. APB, AXI, DMA context and CPU telemetry
# inputs are synchronous to clk at the IP boundary. rst_n is an asynchronous,
# active-low reset and is intentionally excluded from I/O delay constraints.

create_clock -name clk -period 26.315 [get_ports clk]
set_clock_uncertainty -setup 0.100 [get_clocks clk]
set_clock_uncertainty -hold  0.050 [get_clocks clk]
set_clock_transition 0.100 [get_clocks clk]

set_input_delay -clock clk -max 2.000 [get_ports {
    test_mode
    s_apb_paddr s_apb_psel s_apb_penable s_apb_pwrite s_apb_pwdata s_apb_pprot
    dma_ctx_valid dma_ctx_src_addr dma_ctx_dst_addr dma_ctx_byte_len dma_ctx_done
    cpu_telemetry_trap cpu_telemetry_stall
    s_axi_awid s_axi_awaddr s_axi_awlen s_axi_awsize s_axi_awburst s_axi_awprot s_axi_awvalid
    s_axi_wdata s_axi_wstrb s_axi_wlast s_axi_wvalid
    s_axi_bready
    s_axi_arid s_axi_araddr s_axi_arlen s_axi_arsize s_axi_arburst s_axi_arprot s_axi_arvalid
    s_axi_rready
    m_axi_awready m_axi_wready m_axi_bid m_axi_bresp m_axi_bvalid
    m_axi_arready m_axi_rid m_axi_rdata m_axi_rresp m_axi_rlast m_axi_rvalid
}]
set_input_delay -clock clk -min 0.200 [get_ports {
    test_mode
    s_apb_paddr s_apb_psel s_apb_penable s_apb_pwrite s_apb_pwdata s_apb_pprot
    dma_ctx_valid dma_ctx_src_addr dma_ctx_dst_addr dma_ctx_byte_len dma_ctx_done
    cpu_telemetry_trap cpu_telemetry_stall
    s_axi_awid s_axi_awaddr s_axi_awlen s_axi_awsize s_axi_awburst s_axi_awprot s_axi_awvalid
    s_axi_wdata s_axi_wstrb s_axi_wlast s_axi_wvalid
    s_axi_bready
    s_axi_arid s_axi_araddr s_axi_arlen s_axi_arsize s_axi_arburst s_axi_arprot s_axi_arvalid
    s_axi_rready
    m_axi_awready m_axi_wready m_axi_bid m_axi_bresp m_axi_bvalid
    m_axi_arready m_axi_rid m_axi_rdata m_axi_rresp m_axi_rlast m_axi_rvalid
}]

set_output_delay -clock clk -max 2.000 [get_ports {
    s_apb_prdata s_apb_pready s_apb_pslverr sec_irq
    aegis_nmi_irq aegis_anomaly_alert aegis_threat_level aegis_honey_hit
    s_axi_awready s_axi_wready s_axi_bid s_axi_bresp s_axi_bvalid
    s_axi_arready s_axi_rid s_axi_rdata s_axi_rresp s_axi_rlast s_axi_rvalid
    m_axi_awid m_axi_awaddr m_axi_awlen m_axi_awsize m_axi_awburst m_axi_awprot
    m_axi_awcache m_axi_awlock m_axi_awqos m_axi_awregion m_axi_awvalid
    m_axi_wdata m_axi_wstrb m_axi_wlast m_axi_wvalid m_axi_bready
    m_axi_arid m_axi_araddr m_axi_arlen m_axi_arsize m_axi_arburst m_axi_arprot
    m_axi_arcache m_axi_arlock m_axi_arqos m_axi_arregion m_axi_arvalid m_axi_rready
}]
set_output_delay -clock clk -min -0.200 [get_ports {
    s_apb_prdata s_apb_pready s_apb_pslverr sec_irq
    aegis_nmi_irq aegis_anomaly_alert aegis_threat_level aegis_honey_hit
    s_axi_awready s_axi_wready s_axi_bid s_axi_bresp s_axi_bvalid
    s_axi_arready s_axi_rid s_axi_rdata s_axi_rresp s_axi_rlast s_axi_rvalid
    m_axi_awid m_axi_awaddr m_axi_awlen m_axi_awsize m_axi_awburst m_axi_awprot
    m_axi_awcache m_axi_awlock m_axi_awqos m_axi_awregion m_axi_awvalid
    m_axi_wdata m_axi_wstrb m_axi_wlast m_axi_wvalid m_axi_bready
    m_axi_arid m_axi_araddr m_axi_arlen m_axi_arsize m_axi_arburst m_axi_arprot
    m_axi_arcache m_axi_arlock m_axi_arqos m_axi_arregion m_axi_arvalid m_axi_rready
}]

# No data-path timing is required from the asynchronous reset pin.
set_false_path -from [get_ports rst_n]
