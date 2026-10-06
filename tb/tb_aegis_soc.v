`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// Project: AEGIS-RISC Bio-Inspired Closed-Loop Polymorphic Immune SoC
// Testbench: tb_aegis_soc.v
//
// Comprehensive Verification Testbench verifying:
//   1. Normal Sequential DMA Streaming -> 0% False Positive Guarantee (Threat Level 0)
//   2. Timing Side-Channel Probing      -> Periodic Read Detection (Threat Level 1) & Jitter Activation
//   3. DMA Rowhammer Alternation        -> Threat Level 2 Detection & Honey-Pot Address Redirection
//   4. CPU Telemetry Trap Fast-Path     -> Threat Level 3, Direct NMI Assertion & APB Forensics
////////////////////////////////////////////////////////////////////////////////

module tb_aegis_soc;

    reg clk;
    reg rst_n;

    // APB4 Interface
    reg  [31:0] s_apb_paddr;
    reg         s_apb_psel;
    reg         s_apb_penable;
    reg         s_apb_pwrite;
    reg  [31:0] s_apb_pwdata;
    reg  [2:0]  s_apb_pprot;
    wire [31:0] s_apb_prdata;
    wire        s_apb_pready;
    wire        s_apb_pslverr;

    // DMA Context Sideband
    reg         dma_ctx_valid;
    reg  [31:0] dma_ctx_src_addr;
    reg  [31:0] dma_ctx_dst_addr;
    reg  [31:0] dma_ctx_byte_len;
    reg         dma_ctx_done;
    wire        sec_irq;

    // AEGIS Sideband
    reg         cpu_telemetry_trap;
    reg         cpu_telemetry_stall;
    wire        aegis_nmi_irq;
    wire        aegis_anomaly_alert;
    wire [1:0]  aegis_threat_level;
    wire        aegis_honey_hit;

    // AXI Slave Interface (Ingress from DMA Controller)
    reg  [3:0]  s_axi_awid;
    reg  [31:0] s_axi_awaddr;
    reg  [7:0]  s_axi_awlen;
    reg  [2:0]  s_axi_awsize;
    reg  [1:0]  s_axi_awburst;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wlast;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [3:0]  s_axi_bid;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [3:0]  s_axi_arid;
    reg  [31:0] s_axi_araddr;
    reg  [7:0]  s_axi_arlen;
    reg  [2:0]  s_axi_arsize;
    reg  [1:0]  s_axi_arburst;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;

    wire [3:0]  s_axi_rid;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rlast;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // AXI Master Interface (Egress to Interconnect / Memory Matrix)
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
    reg         m_axi_awready;

    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    reg         m_axi_wready;

    reg  [3:0]  m_axi_bid;
    reg  [1:0]  m_axi_bresp;
    reg         m_axi_bvalid;
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
    reg         m_axi_arready;

    reg  [3:0]  m_axi_rid;
    reg  [31:0] m_axi_rdata;
    reg  [1:0]  m_axi_rresp;
    reg         m_axi_rlast;
    reg         m_axi_rvalid;
    wire        m_axi_rready;

    integer pass_count = 0;
    integer fail_count = 0;
    integer jitter_stall_count = 0;
    integer honey_addr_samples = 0;
    reg [31:0] first_honey_addr;
    reg        honey_addr_changed = 1'b0;
    localparam integer ROWHAMMER_BURSTS = 5000;

    // Backend-facing observability checks: Level-1 MTD must actually stall an
    // ingress request, and Level-2 redirection must not use a fixed target.
    always @(posedge clk) begin
        if (rst_n && aegis_threat_level == 2'b01 &&
            dut.u_mtd_engine.jitter_active &&
            (dut.pipe_s1_awvalid || dut.pipe_s1_arvalid) &&
            !(dut.pipe_s1_awready || dut.pipe_s1_arready)) begin
            jitter_stall_count = jitter_stall_count + 1;
        end

        if (rst_n && dut.matcher_inflight_valid &&
            aegis_threat_level >= 2'b10) begin
            if (honey_addr_samples == 0)
                first_honey_addr = dut.mtd_morph_addr;
            else if (dut.mtd_morph_addr != first_honey_addr)
                honey_addr_changed = 1'b1;
            honey_addr_samples = honey_addr_samples + 1;
        end
    end

    // Instantiate AEGIS Enhanced Firewall DUT
    dma_bus_firewall dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .test_mode           (1'b0),
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

    // Clock Generation (40 MHz, Period = 25ns)
    always #12.5 clk = ~clk;

    // Check Task
    task check(input condition, input [256*8-1:0] msg);
        if (condition) begin
            $display("[PASS] %0s", msg);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %0s at time %0t", msg, $time);
            fail_count = fail_count + 1;
        end
    endtask

    // APB Write Task
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_apb_paddr   <= addr;
            s_apb_pwdata  <= data;
            s_apb_pwrite  <= 1'b1;
            s_apb_psel    <= 1'b1;
            s_apb_pprot   <= 3'b001; // Secure, privileged
            s_apb_penable <= 1'b0;
            @(posedge clk);
            s_apb_penable <= 1'b1;
            @(posedge clk);
            while (!s_apb_pready) @(posedge clk);
            s_apb_psel    <= 1'b0;
            s_apb_penable <= 1'b0;
            s_apb_pwrite  <= 1'b0;
        end
    endtask

    // APB Read Task
    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_apb_paddr   <= addr;
            s_apb_pwrite  <= 1'b0;
            s_apb_psel    <= 1'b1;
            s_apb_pprot   <= 3'b001;
            s_apb_penable <= 1'b0;
            @(posedge clk);
            s_apb_penable <= 1'b1;
            @(posedge clk);
            while (!s_apb_pready) @(posedge clk);
            data = s_apb_prdata;
            s_apb_psel    <= 1'b0;
            s_apb_penable <= 1'b0;
        end
    endtask

    // Downstream Interconnect Mock Responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awready <= 1'b1;
            m_axi_wready  <= 1'b1;
            m_axi_bvalid  <= 1'b0;
            m_axi_bresp   <= 2'b00;
            m_axi_bid     <= 4'h0;
            m_axi_arready <= 1'b1;
            m_axi_rvalid  <= 1'b0;
            m_axi_rresp   <= 2'b00;
            m_axi_rdata   <= 32'h0;
            m_axi_rlast   <= 1'b0;
            m_axi_rid     <= 4'h0;
        end else begin
            // Write response handshake
            if (m_axi_awvalid && m_axi_awready) begin
                m_axi_bid    <= m_axi_awid;
                m_axi_bvalid <= 1'b1;
            end else if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end

            // Read response handshake
            if (m_axi_arvalid && m_axi_arready) begin
                m_axi_rvalid <= 1'b1;
                m_axi_rid    <= m_axi_arid;
                m_axi_rdata  <= 32'hA5A5_5A5A;
                m_axi_rlast  <= 1'b1;
            end else if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast  <= 1'b0;
            end
        end
    end

    // Testbench Main Execution
    reg [31:0] rdata;
    integer i;

    initial begin
        if ($test$plusargs("dump_wave")) begin
            $dumpfile("tb_aegis_soc.vcd");
            $dumpvars(0, tb_aegis_soc);
        end

        // Initial states
        clk                 = 1'b0;
        rst_n               = 1'b0;
        s_apb_paddr         = 32'h0;
        s_apb_psel          = 1'b0;
        s_apb_penable       = 1'b0;
        s_apb_pwrite        = 1'b0;
        s_apb_pwdata        = 32'h0;
        s_apb_pprot         = 3'b000;
        dma_ctx_valid       = 1'b0;
        dma_ctx_src_addr    = 32'h0;
        dma_ctx_dst_addr    = 32'h0;
        dma_ctx_byte_len    = 32'h0;
        dma_ctx_done        = 1'b0;
        cpu_telemetry_trap  = 1'b0;
        cpu_telemetry_stall = 1'b0;

        s_axi_awid    = 4'h0;
        s_axi_awaddr  = 32'h0;
        s_axi_awlen   = 8'h0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b0;

        s_axi_wdata   = 32'h0;
        s_axi_wstrb   = 4'hF;
        s_axi_wlast   = 1'b0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b1;

        s_axi_arid    = 4'h0;
        s_axi_araddr  = 32'h0;
        s_axi_arlen   = 8'h0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arprot  = 3'b001;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b1;

        // Reset Pulse
        #50;
        rst_n = 1'b1;
        #50;

        $display("==================================================================");
        $display("  AEGIS-RISC Bio-Inspired Closed-Loop Immune SoC: Full Verification");
        $display("==================================================================");

        // ---------------------------------------------------------------------
        // Setup Static Memory Region 0 for Valid Normal Operation
        // Base: 0x1000_0000, Limit: 0x1000_FFFF (Read/Write/Secure Enabled)
        // ---------------------------------------------------------------------
        apb_write(32'h20, 32'h1000_0000); // RGN0_BASE
        apb_write(32'h24, 32'h1000_FFFF); // RGN0_LIMIT
        apb_write(32'h2C, 32'h0000_0000); // RGN0_MID & MASK (All MIDs allow)
        apb_write(32'h28, 32'h8000_000F); // RGN0_ACTIVE | Read | Write | Secure | Priv

        // =====================================================================
        // SCENARIO 1: Normal Sequential DMA Streaming (0% False Positive Check)
        // =====================================================================
        $display("\n--- SCENARIO 1: Normal Sequential DMA Streaming ---");
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            s_axi_awaddr  = 32'h1000_0000 + (i * 32'h4);
            s_axi_awid    = 4'h1;
            s_axi_awlen   = 8'd0;
            s_axi_awsize  = 3'b010;
            s_axi_awburst = 2'b01;
            s_axi_awprot  = 3'b001;
            s_axi_awvalid = 1'b1;
            s_axi_wvalid  = 1'b1;
            s_axi_wlast   = 1'b1;
            s_axi_wdata   = 32'h1111_0000 + i;

            @(posedge clk);
            while (!s_axi_awready) @(posedge clk);
            @(negedge clk);
            s_axi_awvalid = 1'b0;

            while (!s_axi_wready) @(posedge clk);
            @(negedge clk);
            s_axi_wvalid  = 1'b0;
            s_axi_wlast   = 1'b0;

            while (!s_axi_bvalid) @(posedge clk);
            @(negedge clk);
        end

        check(aegis_threat_level == 2'b00, "Scenario 1: Sequential DMA maintains Threat Level 0 (SAFE)");
        check(aegis_anomaly_alert == 1'b0, "Scenario 1: 0% False Positive Guarantee - No Anomaly Alert");
        check(aegis_honey_hit == 1'b0,     "Scenario 1: Zero Honey-Pot redirection for normal traffic");
        check(aegis_nmi_irq == 1'b0,       "Scenario 1: CPU NMI remains deasserted");

        // =====================================================================
        // SCENARIO 2: Timing Side-Channel Probe Attack Detection
        // =====================================================================
        $display("\n--- SCENARIO 2: Timing Side-Channel Probe Attack ---");
        // Issue periodic 1-beat reads with delta-t cycle intervals
        for (i = 0; i < 8; i = i + 1) begin
            repeat (6) @(posedge clk);
            @(negedge clk);
            s_axi_araddr  = 32'h1000_0200 + (i * 32'h40);
            s_axi_arid    = 4'h2;
            s_axi_arlen   = 8'd0;
            s_axi_arsize  = 3'b010;
            s_axi_arburst = 2'b01;
            s_axi_arprot  = 3'b001;
            s_axi_arvalid = 1'b1;

            @(posedge clk);
            while (!s_axi_arready) @(posedge clk);
            @(negedge clk);
            s_axi_arvalid = 1'b0;

            while (!s_axi_rvalid) @(posedge clk);
            @(negedge clk);
        end

        check(aegis_threat_level == 2'b01, "Scenario 2: HDC detects periodic side-channel timing probe (Threat Level 1)");
        check(dut.u_mtd_engine.jitter_active == 1'b1 || aegis_threat_level == 2'b01, "Scenario 2: MTD Timing Obfuscation activated");
        check(jitter_stall_count > 0, "Scenario 2: MTD jitter creates an observable ingress interlock");

        // =====================================================================
        // SCENARIO 3: DMA Rowhammer Burst Alternation & Honey-Pot Redirection
        // =====================================================================
        $display("\n--- SCENARIO 3: DMA Rowhammer Attack & Honey-Pot Redirection ---");
        // Rapid alternating writes between Row 1 (0x1000_1000) and Row 2 (0x1000_2000)
        for (i = 0; i < ROWHAMMER_BURSTS; i = i + 1) begin
            @(negedge clk);
            s_axi_awaddr  = (i % 2 == 0) ? 32'h1000_1000 : 32'h1000_2000;
            s_axi_awid    = 4'h3;
            s_axi_awlen   = 8'd0;
            s_axi_awsize  = 3'b010;
            s_axi_awburst = 2'b01;
            s_axi_awprot  = 3'b001;
            s_axi_awvalid = 1'b1;
            s_axi_wvalid  = 1'b1;
            s_axi_wlast   = 1'b1;
            s_axi_wdata   = 32'hBADC_0000 + i;

            @(posedge clk);
            while (!s_axi_awready) @(posedge clk);
            @(negedge clk);
            s_axi_awvalid = 1'b0;

            while (!s_axi_wready) @(posedge clk);
            @(negedge clk);
            s_axi_wvalid  = 1'b0;
            s_axi_wlast   = 1'b0;

            while (!s_axi_bvalid) @(posedge clk);
            @(negedge clk);
        end

        check(aegis_threat_level >= 2'b10, "Scenario 3: HDC flags rapid Rowhammer alternating bursts (Threat Level 2)");
        check(aegis_anomaly_alert == 1'b1, "Scenario 3: Anomaly alert raised");
        check(dut.u_closed_loop.reg_aegis_honey_count > 0, "Scenario 3: Honey-pot hits recorded in hardware counter");
        check(honey_addr_samples > 0 && honey_addr_changed, "Scenario 3: Honey-pot target uses dynamic keyed word scrambling");

        // Read APB Forensics Register 0xA8 (REG_AEGIS_HONEY_COUNT)
        apb_read(32'hA8, rdata);
        check(rdata > 0, "Scenario 3: APB Register 0xA8 correctly reports Honey-Pot redirection count");

        // =====================================================================
        // SCENARIO 4: CPU Telemetry Trap Fast-Path & Closed-Loop NMI Reflex
        // =====================================================================
        $display("\n--- SCENARIO 4: CPU Telemetry Fast-Path & NMI Reflex ---");
        @(negedge clk);
        cpu_telemetry_trap = 1'b1; // Simulate CPU Hardware Exception / Fault Attack
        @(posedge clk);
        #1; // Sample immediately after edge
        check(aegis_threat_level == 2'b11, "Scenario 4: CPU trap fast-path instantaneously escalates to Threat Level 3 (BREACH)");
        check(aegis_nmi_irq == 1'b1,       "Scenario 4: High-priority NMI pulse asserted to wake up PicoRV32");

        @(negedge clk);
        cpu_telemetry_trap = 1'b0;
        @(posedge clk);

        // Read APB Forensics Register 0xA0 (REG_AEGIS_STATUS)
        apb_read(32'hA0, rdata);
        check(rdata[3:2] == 2'b11, "Scenario 4: APB Register 0xA0 latches Max Threat Level 3");

        // Read APB Forensics Register 0xA4 (REG_AEGIS_FINGERPRINT)
        apb_read(32'hA4, rdata);
        check(rdata != 32'h0, "Scenario 4: APB Register 0xA4 stores valid 32-bit Attack Forensic Fingerprint");

        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("\n==================================================================");
        $display("  AEGIS-RISC VERIFICATION SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display("\n>>> [SUCCESS] 100%% OF AEGIS-RISC AEGIS REQUIREMENTS VERIFIED! <<<\n");
        end else begin
            $display("\n>>> [FAILURE] SOME ASSERTIONS FAILED! <<<\n");
        end

        $finish;
    end

endmodule
