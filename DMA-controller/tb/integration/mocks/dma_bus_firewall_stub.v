`timescale 1ns/1ps

// SIMULATION-ONLY MOCK. This module is excluded from production source lists.
// It exposes the canonical Firewall public boundary and implements only the
// fail-secure default-deny behavior needed to validate DMA integration wiring.
module dma_bus_firewall_stub (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        test_mode,

    input  wire [31:0] s_apb_paddr,
    input  wire        s_apb_psel,
    input  wire        s_apb_penable,
    input  wire        s_apb_pwrite,
    input  wire [31:0] s_apb_pwdata,
    input  wire [2:0]  s_apb_pprot,
    output wire [31:0] s_apb_prdata,
    output wire        s_apb_pready,
    output wire        s_apb_pslverr,

    input  wire        dma_ctx_valid,
    input  wire [31:0] dma_ctx_src_addr,
    input  wire [31:0] dma_ctx_dst_addr,
    input  wire [31:0] dma_ctx_byte_len,
    input  wire        dma_ctx_done,
    output wire        sec_irq,

    input  wire        cpu_telemetry_trap,
    input  wire        cpu_telemetry_stall,
    output wire        aegis_nmi_irq,
    output wire        aegis_anomaly_alert,
    output wire [1:0]  aegis_threat_level,
    output wire        aegis_honey_hit,

    input  wire [3:0]  s_axi_awid,
    input  wire [31:0] s_axi_awaddr,
    input  wire [7:0]  s_axi_awlen,
    input  wire [2:0]  s_axi_awsize,
    input  wire [1:0]  s_axi_awburst,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wlast,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [3:0]  s_axi_bid,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [3:0]  s_axi_arid,
    input  wire [31:0] s_axi_araddr,
    input  wire [7:0]  s_axi_arlen,
    input  wire [2:0]  s_axi_arsize,
    input  wire [1:0]  s_axi_arburst,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [3:0]  s_axi_rid,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rlast,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

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
    localparam [1:0] W_IDLE = 2'b00;
    localparam [1:0] W_SINK = 2'b01;
    localparam [1:0] W_RESP = 2'b10;

    reg [1:0] w_state;
    reg [3:0] w_id_q;
    reg [7:0] w_len_q;
    reg [7:0] w_count_q;
    reg       r_active_q;
    reg [3:0] r_id_q;
    reg [7:0] r_len_q;
    reg [7:0] r_count_q;

    wire unused_inputs = ^{test_mode, cpu_telemetry_trap, cpu_telemetry_stall,
                           s_apb_paddr, s_apb_pwrite, s_apb_pwdata,
                           s_apb_pprot, dma_ctx_valid, dma_ctx_src_addr,
                           dma_ctx_dst_addr, dma_ctx_byte_len, dma_ctx_done,
                           s_axi_awaddr, s_axi_awsize, s_axi_awburst,
                           s_axi_awprot, s_axi_wdata, s_axi_wstrb, s_axi_wlast,
                           s_axi_araddr, s_axi_arsize, s_axi_arburst,
                           s_axi_arprot, m_axi_awready, m_axi_wready,
                           m_axi_bid, m_axi_bresp, m_axi_bvalid, m_axi_arready,
                           m_axi_rid, m_axi_rdata, m_axi_rresp, m_axi_rlast,
                           m_axi_rvalid};

    assign s_apb_prdata = 32'd0;
    assign s_apb_pready = 1'b1;
    assign s_apb_pslverr = s_apb_psel && s_apb_penable;
    assign sec_irq = 1'b0;
    assign aegis_nmi_irq = 1'b0;
    assign aegis_anomaly_alert = 1'b0;
    assign aegis_threat_level = 2'b00;
    assign aegis_honey_hit = 1'b0;

    assign s_axi_awready = rst_n && (w_state == W_IDLE);
    assign s_axi_wready = rst_n && (w_state == W_SINK);
    assign s_axi_bid = w_id_q;
    assign s_axi_bresp = 2'b11;
    assign s_axi_bvalid = rst_n && (w_state == W_RESP);

    assign s_axi_arready = rst_n && !r_active_q;
    assign s_axi_rid = r_id_q;
    assign s_axi_rdata = 32'd0;
    assign s_axi_rresp = 2'b11;
    assign s_axi_rlast = r_active_q && (r_count_q == r_len_q);
    assign s_axi_rvalid = rst_n && r_active_q;

    assign m_axi_awid = 4'd0;
    assign m_axi_awaddr = 32'd0;
    assign m_axi_awlen = 8'd0;
    assign m_axi_awsize = 3'b010;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awprot = 3'b001;
    assign m_axi_awcache = 4'd0;
    assign m_axi_awlock = 1'b0;
    assign m_axi_awqos = 4'd0;
    assign m_axi_awregion = 4'd0;
    assign m_axi_awvalid = 1'b0;
    assign m_axi_wdata = 32'd0;
    assign m_axi_wstrb = 4'd0;
    assign m_axi_wlast = 1'b0;
    assign m_axi_wvalid = 1'b0;
    assign m_axi_bready = 1'b0;
    assign m_axi_arid = 4'd0;
    assign m_axi_araddr = 32'd0;
    assign m_axi_arlen = 8'd0;
    assign m_axi_arsize = 3'b010;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arprot = 3'b001;
    assign m_axi_arcache = 4'd0;
    assign m_axi_arlock = 1'b0;
    assign m_axi_arqos = 4'd0;
    assign m_axi_arregion = 4'd0;
    assign m_axi_arvalid = 1'b0;
    assign m_axi_rready = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state <= W_IDLE;
            w_id_q <= 4'd0;
            w_len_q <= 8'd0;
            w_count_q <= 8'd0;
            r_active_q <= 1'b0;
            r_id_q <= 4'd0;
            r_len_q <= 8'd0;
            r_count_q <= 8'd0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    w_count_q <= 8'd0;
                    if (s_axi_awvalid && s_axi_awready) begin
                        w_id_q <= s_axi_awid;
                        w_len_q <= s_axi_awlen;
                        w_state <= W_SINK;
                    end
                end
                W_SINK: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        if (w_count_q == w_len_q)
                            w_state <= W_RESP;
                        else
                            w_count_q <= w_count_q + 1'b1;
                    end
                end
                W_RESP: begin
                    if (s_axi_bready)
                        w_state <= W_IDLE;
                end
                default: w_state <= W_IDLE;
            endcase

            if (!r_active_q) begin
                r_count_q <= 8'd0;
                if (s_axi_arvalid && s_axi_arready) begin
                    r_active_q <= 1'b1;
                    r_id_q <= s_axi_arid;
                    r_len_q <= s_axi_arlen;
                end
            end else if (s_axi_rvalid && s_axi_rready) begin
                if (r_count_q == r_len_q)
                    r_active_q <= 1'b0;
                else
                    r_count_q <= r_count_q + 1'b1;
            end
        end
    end

    // Keep lint aware that deliberately ignored test-only inputs are observed.
    wire _unused_ok = unused_inputs;
endmodule
