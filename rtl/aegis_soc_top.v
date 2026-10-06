`timescale 1ns/1ps

// Synthesizable AEGIS frontend integration boundary.
//
// This top contains the production bridge, DMA controller, and firewall.  It
// deliberately does not contain a RAM model: ext_mem_* and m_axi_* are the
// integration-facing memory/interconnect contracts used by backend synthesis
// and by the end-to-end simulation testbench.
// The bridge and DMA use the top-level synchronized reset.  The Firewall is
// passed the raw pad reset and owns its own synchronizer so both paths have a
// single, explicit two-flop deassertion contract.
/* verilator lint_off SYNCASYNCNET */
module aegis_soc_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        test_mode,

    // PicoRV32 external instruction/data memory port.
    output wire        ext_mem_valid,
    output wire        ext_mem_instr,
    output wire [31:0] ext_mem_addr,
    output wire [31:0] ext_mem_wdata,
    output wire [3:0]  ext_mem_wstrb,
    input  wire        ext_mem_ready,
    input  wire [31:0] ext_mem_rdata,

    // AEGIS and interrupt observability.
    output wire        cpu_irq3,
    output wire        cpu_trap,
    output wire        cpu_stall,
    output wire        dma_irq,
    output wire        sec_irq,
    output wire        aegis_nmi_irq,
    output wire        aegis_anomaly_alert,
    output wire [1:0]  aegis_threat_level,
    output wire        aegis_honey_hit,

    // Firewall downstream AXI4 master interface.
    output wire [3:0]  m_axi_awid,
    output wire [31:0] m_axi_awaddr,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    output wire [2:0]  m_axi_awprot,
    output wire [3:0]  m_axi_awcache,
    output wire        m_axi_awlock,
    output wire [3:0]  m_axi_awqos,
    output wire [3:0]  m_axi_awregion,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [3:0]  m_axi_bid,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    output wire [3:0]  m_axi_arid,
    output wire [31:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    output wire [2:0]  m_axi_arprot,
    output wire [3:0]  m_axi_arcache,
    output wire        m_axi_arlock,
    output wire [3:0]  m_axi_arqos,
    output wire [3:0]  m_axi_arregion,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [3:0]  m_axi_rid,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready
);

    // =========================================================================
    // Reset Synchronizer: Asynchronous assert, synchronous deassert
    // In test_mode (scan test), bypass synchronizer to allow direct reset control
    // =========================================================================
    reg rst_n_sync1;
    reg rst_n_sync2;
    wire rst_n_synced = test_mode ? rst_n : rst_n_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_sync1 <= 1'b0;
            rst_n_sync2 <= 1'b0;
        end else begin
            rst_n_sync1 <= 1'b1;
            rst_n_sync2 <= rst_n_sync1;
        end
    end

    // CPU bridge APB boundary.
    wire [31:0] fw_paddr;
    wire        fw_psel;
    wire        fw_penable;
    wire        fw_pwrite;
    wire [31:0] fw_pwdata;
    wire [2:0]  fw_pprot;
    wire [31:0] fw_prdata;
    wire        fw_pready;
    wire        fw_pslverr;
    wire [31:0] dma_paddr;
    wire        dma_psel;
    wire        dma_penable;
    wire        dma_pwrite;
    wire [31:0] dma_pwdata;
    wire [31:0] dma_prdata;
    wire        dma_pready;
    wire        dma_pslverr;

    aegis_picorv32_apb_bridge u_cpu_bridge (
        .clk           (clk),
        .rst_n         (rst_n_synced),
        .ext_mem_valid (ext_mem_valid),
        .ext_mem_instr (ext_mem_instr),
        .ext_mem_addr  (ext_mem_addr),
        .ext_mem_wdata (ext_mem_wdata),
        .ext_mem_wstrb (ext_mem_wstrb),
        .ext_mem_ready (ext_mem_ready),
        .ext_mem_rdata (ext_mem_rdata),
        .fw_paddr      (fw_paddr),
        .fw_psel       (fw_psel),
        .fw_penable    (fw_penable),
        .fw_pwrite     (fw_pwrite),
        .fw_pwdata     (fw_pwdata),
        .fw_pprot      (fw_pprot),
        .fw_prdata     (fw_prdata),
        .fw_pready     (fw_pready),
        .fw_pslverr    (fw_pslverr),
        .dma_paddr     (dma_paddr),
        .dma_psel      (dma_psel),
        .dma_penable   (dma_penable),
        .dma_pwrite    (dma_pwrite),
        .dma_pwdata    (dma_pwdata),
        .dma_prdata    (dma_prdata),
        .dma_pready    (dma_pready),
        .dma_pslverr   (dma_pslverr),
        .aegis_nmi_irq (aegis_nmi_irq),
        .cpu_irq3      (cpu_irq3),
        .cpu_trap      (cpu_trap),
        .cpu_stall     (cpu_stall)
    );

    // DMA controller AXI master boundary.
    wire [31:0] dma_araddr;
    wire [3:0]  dma_arid;
    wire [7:0]  dma_arlen;
    wire [2:0]  dma_arsize;
    wire [1:0]  dma_arburst;
    wire [2:0]  dma_arprot;
    wire        dma_arvalid;
    wire        dma_arready;
    wire [31:0] dma_rdata;
    wire        dma_rlast;
    wire        dma_rvalid;
    wire [3:0]  dma_rid;
    wire [1:0]  dma_rresp;
    wire        dma_rready;
    wire [31:0] dma_awaddr;
    wire [3:0]  dma_awid;
    wire [7:0]  dma_awlen;
    wire [2:0]  dma_awsize;
    wire [1:0]  dma_awburst;
    wire        dma_awvalid;
    wire        dma_awready;
    wire [31:0] dma_wdata;
    wire [3:0]  dma_wstrb;
    wire        dma_wlast;
    wire        dma_wvalid;
    wire        dma_wready;
    wire [3:0]  dma_bid;
    wire [1:0]  dma_bresp;
    wire        dma_bvalid;
    wire        dma_bready;
    wire        dma_ctx_valid;
    wire [31:0] dma_ctx_src_addr;
    wire [31:0] dma_ctx_dst_addr;
    wire [31:0] dma_ctx_byte_len;
    wire        dma_ctx_done;

    dma_controller u_dma (
        .clk              (clk),
        .rst_n            (rst_n_synced),
        .psel             (dma_psel),
        .penable          (dma_penable),
        .pwrite           (dma_pwrite),
        .paddr            (dma_paddr),
        .pwdata           (dma_pwdata),
        .prdata           (dma_prdata),
        .pready           (dma_pready),
        .pslverr          (dma_pslverr),
        .dma_irq          (dma_irq),
        .dma_ctx_valid    (dma_ctx_valid),
        .dma_ctx_src_addr (dma_ctx_src_addr),
        .dma_ctx_dst_addr (dma_ctx_dst_addr),
        .dma_ctx_byte_len (dma_ctx_byte_len),
        .dma_ctx_done     (dma_ctx_done),
        .m_axi_araddr     (dma_araddr),
        .m_axi_arid       (dma_arid),
        .m_axi_arlen      (dma_arlen),
        .m_axi_arsize     (dma_arsize),
        .m_axi_arburst    (dma_arburst),
        .m_axi_prot       (dma_arprot),
        .m_axi_arvalid    (dma_arvalid),
        .m_axi_arready    (dma_arready),
        .m_axi_rdata      (dma_rdata),
        .m_axi_rlast      (dma_rlast),
        .m_axi_rvalid     (dma_rvalid),
        .m_axi_rid        (dma_rid),
        .m_axi_rresp      (dma_rresp),
        .m_axi_rready     (dma_rready),
        .m_axi_awaddr     (dma_awaddr),
        .m_axi_awid       (dma_awid),
        .m_axi_awlen      (dma_awlen),
        .m_axi_awsize     (dma_awsize),
        .m_axi_awburst    (dma_awburst),
        .m_axi_awvalid    (dma_awvalid),
        .m_axi_awready    (dma_awready),
        .m_axi_wdata      (dma_wdata),
        .m_axi_wstrb      (dma_wstrb),
        .m_axi_wlast      (dma_wlast),
        .m_axi_wvalid     (dma_wvalid),
        .m_axi_wready     (dma_wready),
        .m_axi_bid        (dma_bid),
        .m_axi_bresp      (dma_bresp),
        .m_axi_bvalid     (dma_bvalid),
        .m_axi_bready     (dma_bready)
    );

    // Security firewall and AEGIS feedback loop.
    // The Firewall owns its own two-flop reset synchronizer. Feed it the raw
    // pad reset so its functional-mode deassertion aligns with the top-level
    // synchronizer used by the bridge and DMA, instead of adding two cycles.
    dma_bus_firewall u_firewall (
        .clk                  (clk),
        .rst_n                (rst_n),
        .test_mode            (test_mode),
        .s_apb_paddr          (fw_paddr),
        .s_apb_psel           (fw_psel),
        .s_apb_penable        (fw_penable),
        .s_apb_pwrite         (fw_pwrite),
        .s_apb_pwdata         (fw_pwdata),
        .s_apb_pprot          (fw_pprot),
        .s_apb_prdata         (fw_prdata),
        .s_apb_pready         (fw_pready),
        .s_apb_pslverr        (fw_pslverr),
        .dma_ctx_valid        (dma_ctx_valid),
        .dma_ctx_src_addr     (dma_ctx_src_addr),
        .dma_ctx_dst_addr     (dma_ctx_dst_addr),
        .dma_ctx_byte_len     (dma_ctx_byte_len),
        .dma_ctx_done         (dma_ctx_done),
        .sec_irq              (sec_irq),
        .cpu_telemetry_trap   (cpu_trap),
        .cpu_telemetry_stall  (cpu_stall),
        .aegis_nmi_irq        (aegis_nmi_irq),
        .aegis_anomaly_alert  (aegis_anomaly_alert),
        .aegis_threat_level   (aegis_threat_level),
        .aegis_honey_hit      (aegis_honey_hit),
        .s_axi_awid           (dma_awid),
        .s_axi_awaddr         (dma_awaddr),
        .s_axi_awlen          (dma_awlen),
        .s_axi_awsize         (dma_awsize),
        .s_axi_awburst        (dma_awburst),
        .s_axi_awprot         (dma_arprot),
        .s_axi_awvalid        (dma_awvalid),
        .s_axi_awready        (dma_awready),
        .s_axi_wdata          (dma_wdata),
        .s_axi_wstrb          (dma_wstrb),
        .s_axi_wlast          (dma_wlast),
        .s_axi_wvalid         (dma_wvalid),
        .s_axi_wready         (dma_wready),
        .s_axi_bid            (dma_bid),
        .s_axi_bresp          (dma_bresp),
        .s_axi_bvalid         (dma_bvalid),
        .s_axi_bready         (dma_bready),
        .s_axi_arid           (dma_arid),
        .s_axi_araddr         (dma_araddr),
        .s_axi_arlen          (dma_arlen),
        .s_axi_arsize         (dma_arsize),
        .s_axi_arburst        (dma_arburst),
        .s_axi_arprot         (dma_arprot),
        .s_axi_arvalid        (dma_arvalid),
        .s_axi_arready        (dma_arready),
        .s_axi_rid            (dma_rid),
        .s_axi_rdata          (dma_rdata),
        .s_axi_rresp          (dma_rresp),
        .s_axi_rlast          (dma_rlast),
        .s_axi_rvalid         (dma_rvalid),
        .s_axi_rready         (dma_rready),
        .m_axi_awid           (m_axi_awid),
        .m_axi_awaddr         (m_axi_awaddr),
        .m_axi_awlen          (m_axi_awlen),
        .m_axi_awsize         (m_axi_awsize),
        .m_axi_awburst        (m_axi_awburst),
        .m_axi_awprot         (m_axi_awprot),
        .m_axi_awcache        (m_axi_awcache),
        .m_axi_awlock         (m_axi_awlock),
        .m_axi_awqos          (m_axi_awqos),
        .m_axi_awregion       (m_axi_awregion),
        .m_axi_awvalid        (m_axi_awvalid),
        .m_axi_awready        (m_axi_awready),
        .m_axi_wdata          (m_axi_wdata),
        .m_axi_wstrb          (m_axi_wstrb),
        .m_axi_wlast          (m_axi_wlast),
        .m_axi_wvalid         (m_axi_wvalid),
        .m_axi_wready         (m_axi_wready),
        .m_axi_bid            (m_axi_bid),
        .m_axi_bresp          (m_axi_bresp),
        .m_axi_bvalid         (m_axi_bvalid),
        .m_axi_bready         (m_axi_bready),
        .m_axi_arid           (m_axi_arid),
        .m_axi_araddr         (m_axi_araddr),
        .m_axi_arlen          (m_axi_arlen),
        .m_axi_arsize         (m_axi_arsize),
        .m_axi_arburst        (m_axi_arburst),
        .m_axi_arprot         (m_axi_arprot),
        .m_axi_arcache        (m_axi_arcache),
        .m_axi_arlock         (m_axi_arlock),
        .m_axi_arqos          (m_axi_arqos),
        .m_axi_arregion       (m_axi_arregion),
        .m_axi_arvalid        (m_axi_arvalid),
        .m_axi_arready        (m_axi_arready),
        .m_axi_rid            (m_axi_rid),
        .m_axi_rdata          (m_axi_rdata),
        .m_axi_rresp          (m_axi_rresp),
        .m_axi_rlast          (m_axi_rlast),
        .m_axi_rvalid         (m_axi_rvalid),
        .m_axi_rready         (m_axi_rready)
    );

endmodule
/* verilator lint_on SYNCASYNCNET */
