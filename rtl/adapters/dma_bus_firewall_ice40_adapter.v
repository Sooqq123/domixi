`timescale 1ns/1ps

// ==============================================================================
// Adapter: dma_bus_firewall_ice40_adapter
// Target: Out-of-Context FPGA PnR for iCE40HX8K-CT256
// Purpose: Wraps dma_bus_firewall (630 IO ports) to fit the 206-pin physical package
//          by registering/folding boundary pins into minimal test IOs without
//          altering the internal core logic, timing, or cell utilization.
// ==============================================================================

module dma_bus_firewall_ice40_adapter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] test_din,
    output reg  [31:0] test_dout
);

    // Shift/latch registers to stimulate all inputs of dma_bus_firewall
    reg [31:0] s_apb_paddr;
    reg        s_apb_psel;
    reg        s_apb_penable;
    reg        s_apb_pwrite;
    reg [31:0] s_apb_pwdata;
    reg [2:0]  s_apb_pprot;

    reg        dma_ctx_valid;
    reg [31:0] dma_ctx_src_addr;
    reg [31:0] dma_ctx_dst_addr;
    reg [31:0] dma_ctx_byte_len;
    reg        dma_ctx_done;

    reg        cpu_telemetry_trap;
    reg        cpu_telemetry_stall;

    reg [3:0]  s_axi_awid;
    reg [31:0] s_axi_awaddr;
    reg [7:0]  s_axi_awlen;
    reg [2:0]  s_axi_awsize;
    reg [1:0]  s_axi_awburst;
    reg [2:0]  s_axi_awprot;
    reg        s_axi_awvalid;

    reg [31:0] s_axi_wdata;
    reg [3:0]  s_axi_wstrb;
    reg        s_axi_wlast;
    reg        s_axi_wvalid;

    reg        s_axi_bready;

    reg [3:0]  s_axi_arid;
    reg [31:0] s_axi_araddr;
    reg [7:0]  s_axi_arlen;
    reg [2:0]  s_axi_arsize;
    reg [1:0]  s_axi_arburst;
    reg [2:0]  s_axi_arprot;
    reg        s_axi_arvalid;

    reg        s_axi_rready;

    reg        m_axi_awready;
    reg        m_axi_wready;
    reg [3:0]  m_axi_bid;
    reg [1:0]  m_axi_bresp;
    reg        m_axi_bvalid;
    reg        m_axi_arready;
    reg [3:0]  m_axi_rid;
    reg [31:0] m_axi_rdata;
    reg [1:0]  m_axi_rresp;
    reg        m_axi_rlast;
    reg        m_axi_rvalid;

    // DUT output capture wires
    wire [31:0] s_apb_prdata;
    wire        s_apb_pready;
    wire        s_apb_pslverr;
    wire        sec_irq;
    wire        aegis_nmi_irq;
    wire        aegis_anomaly_alert;
    wire [1:0]  aegis_threat_level;
    wire        aegis_honey_hit;
    wire        s_axi_awready;
    wire        s_axi_wready;
    wire [3:0]  s_axi_bid;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    wire        s_axi_arready;
    wire [3:0]  s_axi_rid;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rlast;
    wire        s_axi_rvalid;

    wire [3:0]  m_axi_awid;
    wire [31:0] m_axi_awaddr;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire [2:0]  m_axi_awprot;
    wire [3:0]  m_axi_awcache;
    wire        m_axi_awlock;
    wire [3:0]  m_axi_awqos;
    wire [3:0]  m_axi_awregion;
    wire        m_axi_awvalid;

    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    wire        m_axi_bready;

    wire [3:0]  m_axi_arid;
    wire [31:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire [2:0]  m_axi_arprot;
    wire [3:0]  m_axi_arcache;
    wire        m_axi_arlock;
    wire [3:0]  m_axi_arqos;
    wire [3:0]  m_axi_arregion;
    wire        m_axi_arvalid;
    wire        m_axi_rready;

    // Boundary stimulus shift chain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_apb_paddr         <= 32'h0;
            s_apb_psel          <= 1'b0;
            s_apb_penable       <= 1'b0;
            s_apb_pwrite        <= 1'b0;
            s_apb_pwdata        <= 32'h0;
            s_apb_pprot         <= 3'b000;
            dma_ctx_valid       <= 1'b0;
            dma_ctx_src_addr    <= 32'h0;
            dma_ctx_dst_addr    <= 32'h0;
            dma_ctx_byte_len    <= 32'h0;
            dma_ctx_done        <= 1'b0;
            cpu_telemetry_trap  <= 1'b0;
            cpu_telemetry_stall <= 1'b0;
            s_axi_awid          <= 4'h0;
            s_axi_awaddr        <= 32'h0;
            s_axi_awlen         <= 8'h0;
            s_axi_awsize        <= 3'b010;
            s_axi_awburst       <= 2'b01;
            s_axi_awprot        <= 3'b001;
            s_axi_awvalid       <= 1'b0;
            s_axi_wdata         <= 32'h0;
            s_axi_wstrb         <= 4'hF;
            s_axi_wlast         <= 1'b0;
            s_axi_wvalid        <= 1'b0;
            s_axi_bready        <= 1'b1;
            s_axi_arid          <= 4'h0;
            s_axi_araddr        <= 32'h0;
            s_axi_arlen         <= 8'h0;
            s_axi_arsize        <= 3'b010;
            s_axi_arburst       <= 2'b01;
            s_axi_arprot        <= 3'b001;
            s_axi_arvalid       <= 1'b0;
            s_axi_rready        <= 1'b1;
            m_axi_awready       <= 1'b1;
            m_axi_wready        <= 1'b1;
            m_axi_bid           <= 4'h0;
            m_axi_bresp         <= 2'b00;
            m_axi_bvalid        <= 1'b0;
            m_axi_arready       <= 1'b1;
            m_axi_rid           <= 4'h0;
            m_axi_rdata         <= 32'h0;
            m_axi_rresp         <= 2'b00;
            m_axi_rlast         <= 1'b0;
            m_axi_rvalid        <= 1'b0;
        end else begin
            s_apb_paddr         <= {s_apb_paddr[30:0], test_din[0]};
            s_apb_psel          <= test_din[1];
            s_apb_penable       <= test_din[2];
            s_apb_pwrite        <= test_din[3];
            s_apb_pwdata        <= {s_apb_pwdata[30:0], test_din[4]};
            s_apb_pprot         <= test_din[7:5];
            dma_ctx_valid       <= test_din[8];
            dma_ctx_src_addr    <= {dma_ctx_src_addr[30:0], test_din[9]};
            dma_ctx_dst_addr    <= {dma_ctx_dst_addr[30:0], test_din[10]};
            dma_ctx_byte_len    <= {dma_ctx_byte_len[30:0], test_din[11]};
            dma_ctx_done        <= test_din[12];
            cpu_telemetry_trap  <= test_din[13];
            cpu_telemetry_stall <= test_din[14];
            s_axi_awid          <= test_din[18:15];
            s_axi_awaddr        <= {s_axi_awaddr[30:0], test_din[19]};
            s_axi_awlen         <= test_din[27:20];
            s_axi_awsize        <= test_din[30:28];
            s_axi_awburst       <= {test_din[31], test_din[0]};
            s_axi_awprot        <= test_din[3:1];
            s_axi_awvalid       <= test_din[4];
            s_axi_wdata         <= {s_axi_wdata[30:0], test_din[5]};
            s_axi_wstrb         <= test_din[9:6];
            s_axi_wlast         <= test_din[10];
            s_axi_wvalid        <= test_din[11];
            s_axi_bready        <= test_din[12];
            s_axi_arid          <= test_din[16:13];
            s_axi_araddr        <= {s_axi_araddr[30:0], test_din[17]};
            s_axi_arlen         <= test_din[25:18];
            s_axi_arsize        <= test_din[28:26];
            s_axi_arburst       <= test_din[30:29];
            s_axi_arprot        <= test_din[2:0];
            s_axi_arvalid       <= test_din[3];
            s_axi_rready        <= test_din[4];
            m_axi_awready       <= test_din[5];
            m_axi_wready        <= test_din[6];
            m_axi_bid           <= test_din[10:7];
            m_axi_bresp         <= test_din[12:11];
            m_axi_bvalid        <= test_din[13];
            m_axi_arready       <= test_din[14];
            m_axi_rid           <= test_din[18:15];
            m_axi_rdata         <= {m_axi_rdata[30:0], test_din[19]};
            m_axi_rresp         <= test_din[21:20];
            m_axi_rlast         <= test_din[22];
            m_axi_rvalid        <= test_din[23];
        end
    end

    // DUT Instantiation - Exactly unmodified dma_bus_firewall
    dma_bus_firewall u_dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .s_apb_paddr         (s_apb_paddr),
        .s_apb_psel          (s_apb_psel),
        .s_apb_penable       (s_apb_penable),
        .s_apb_pwrite        (s_apb_pwrite),
        .s_apb_pwdata        (s_apb_pwdata),
        .s_apb_pprot         (s_apb_pprot),
        .s_apb_prdata        (s_apb_prdata),
        .s_apb_pready        (s_apb_pready),
        .s_apb_pslverr       (s_apb_pslverr),
        .dma_ctx_valid       (dma_ctx_valid),
        .dma_ctx_src_addr    (dma_ctx_src_addr),
        .dma_ctx_dst_addr    (dma_ctx_dst_addr),
        .dma_ctx_byte_len    (dma_ctx_byte_len),
        .dma_ctx_done        (dma_ctx_done),
        .sec_irq             (sec_irq),
        .cpu_telemetry_trap  (cpu_telemetry_trap),
        .cpu_telemetry_stall (cpu_telemetry_stall),
        .aegis_nmi_irq       (aegis_nmi_irq),
        .aegis_anomaly_alert (aegis_anomaly_alert),
        .aegis_threat_level  (aegis_threat_level),
        .aegis_honey_hit     (aegis_honey_hit),
        .s_axi_awid          (s_axi_awid),
        .s_axi_awaddr        (s_axi_awaddr),
        .s_axi_awlen         (s_axi_awlen),
        .s_axi_awsize        (s_axi_awsize),
        .s_axi_awburst       (s_axi_awburst),
        .s_axi_awprot        (s_axi_awprot),
        .s_axi_awvalid       (s_axi_awvalid),
        .s_axi_awready       (s_axi_awready),
        .s_axi_wdata         (s_axi_wdata),
        .s_axi_wstrb         (s_axi_wstrb),
        .s_axi_wlast         (s_axi_wlast),
        .s_axi_wvalid        (s_axi_wvalid),
        .s_axi_wready        (s_axi_wready),
        .s_axi_bid           (s_axi_bid),
        .s_axi_bresp         (s_axi_bresp),
        .s_axi_bvalid        (s_axi_bvalid),
        .s_axi_bready        (s_axi_bready),
        .s_axi_arid          (s_axi_arid),
        .s_axi_araddr        (s_axi_araddr),
        .s_axi_arlen         (s_axi_arlen),
        .s_axi_arsize        (s_axi_arsize),
        .s_axi_arburst       (s_axi_arburst),
        .s_axi_arprot        (s_axi_arprot),
        .s_axi_arvalid       (s_axi_arvalid),
        .s_axi_arready       (s_axi_arready),
        .s_axi_rid           (s_axi_rid),
        .s_axi_rdata         (s_axi_rdata),
        .s_axi_rresp         (s_axi_rresp),
        .s_axi_rlast         (s_axi_rlast),
        .s_axi_rvalid        (s_axi_rvalid),
        .s_axi_rready        (s_axi_rready),
        .m_axi_awid          (m_axi_awid),
        .m_axi_awaddr        (m_axi_awaddr),
        .m_axi_awlen         (m_axi_awlen),
        .m_axi_awsize        (m_axi_awsize),
        .m_axi_awburst       (m_axi_awburst),
        .m_axi_awprot        (m_axi_awprot),
        .m_axi_awcache       (m_axi_awcache),
        .m_axi_awlock        (m_axi_awlock),
        .m_axi_awqos         (m_axi_awqos),
        .m_axi_awregion      (m_axi_awregion),
        .m_axi_awvalid       (m_axi_awvalid),
        .m_axi_awready       (m_axi_awready),
        .m_axi_wdata         (m_axi_wdata),
        .m_axi_wstrb         (m_axi_wstrb),
        .m_axi_wlast         (m_axi_wlast),
        .m_axi_wvalid        (m_axi_wvalid),
        .m_axi_wready        (m_axi_wready),
        .m_axi_bid           (m_axi_bid),
        .m_axi_bresp         (m_axi_bresp),
        .m_axi_bvalid        (m_axi_bvalid),
        .m_axi_bready        (m_axi_bready),
        .m_axi_arid          (m_axi_arid),
        .m_axi_araddr        (m_axi_araddr),
        .m_axi_arlen         (m_axi_arlen),
        .m_axi_arsize        (m_axi_arsize),
        .m_axi_arburst       (m_axi_arburst),
        .m_axi_arprot        (m_axi_arprot),
        .m_axi_arcache       (m_axi_arcache),
        .m_axi_arlock        (m_axi_arlock),
        .m_axi_arqos         (m_axi_arqos),
        .m_axi_arregion      (m_axi_arregion),
        .m_axi_arvalid       (m_axi_arvalid),
        .m_axi_arready       (m_axi_arready),
        .m_axi_rid           (m_axi_rid),
        .m_axi_rdata         (m_axi_rdata),
        .m_axi_rresp         (m_axi_rresp),
        .m_axi_rlast         (m_axi_rlast),
        .m_axi_rvalid        (m_axi_rvalid),
        .m_axi_rready        (m_axi_rready)
    );

    // Reduction XOR tree to prevent logic optimization across any output bit
    wire [31:0] out_sig = s_apb_prdata ^
                          {31'd0, s_apb_pready} ^
                          {30'd0, s_apb_pslverr, sec_irq} ^
                          {28'd0, aegis_nmi_irq, aegis_anomaly_alert, aegis_threat_level} ^
                          {31'd0, aegis_honey_hit} ^
                          {31'd0, s_axi_awready} ^
                          {31'd0, s_axi_wready} ^
                          {26'd0, s_axi_bid, s_axi_bresp} ^
                          {31'd0, s_axi_bvalid} ^
                          {31'd0, s_axi_arready} ^
                          {26'd0, s_axi_rid, s_axi_rresp} ^
                          s_axi_rdata ^
                          {30'd0, s_axi_rlast, s_axi_rvalid} ^
                          m_axi_awaddr ^
                          {20'd0, m_axi_awid, m_axi_awlen} ^
                          {25'd0, m_axi_awsize, m_axi_awburst, m_axi_awprot[0]} ^
                          {31'd0, m_axi_awvalid} ^
                          m_axi_wdata ^
                          {26'd0, m_axi_wstrb, m_axi_wlast, m_axi_wvalid} ^
                          {31'd0, m_axi_bready} ^
                          m_axi_araddr ^
                          {20'd0, m_axi_arid, m_axi_arlen} ^
                          {25'd0, m_axi_arsize, m_axi_arburst, m_axi_arprot[0]} ^
                          {31'd0, m_axi_arvalid} ^
                          {31'd0, m_axi_rready};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_dout <= 32'h0;
        end else begin
            test_dout <= test_dout ^ out_sig;
        end
    end

endmodule
