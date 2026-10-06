`timescale 1ns/1ps

// ==============================================================================
// Testbench: tb_fw_abnormal_stress
// Focus: Abnormal protocol scenarios & edge cases for dma_bus_firewall:
//   1. Mid-Burst Asynchronous Reset & Recovery
//   2. Sustained Matrix Backpressure (Stalled READY)
//   3. Illegal Window Traversal with DECERR containment
// ==============================================================================

module tb_fw_abnormal_stress;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    // APB4 Control & Status Interface
    reg  [31:0] s_apb_paddr = 32'd0;
    reg         s_apb_psel = 1'b0;
    reg         s_apb_penable = 1'b0;
    reg         s_apb_pwrite = 1'b0;
    reg  [31:0] s_apb_pwdata = 32'd0;
    reg  [2:0]  s_apb_pprot = 3'b001;
    wire [31:0] s_apb_prdata;
    wire        s_apb_pready;
    wire        s_apb_pslverr;

    // DMA Sideband
    reg         dma_ctx_valid = 1'b0;
    reg  [31:0] dma_ctx_src_addr = 32'd0;
    reg  [31:0] dma_ctx_dst_addr = 32'd0;
    reg  [31:0] dma_ctx_byte_len = 32'd0;
    reg         dma_ctx_done = 1'b0;
    wire        sec_irq;

    // AEGIS Sideband
    reg         cpu_telemetry_trap = 1'b0;
    reg         cpu_telemetry_stall = 1'b0;
    wire        aegis_nmi_irq;
    wire        aegis_anomaly_alert;
    wire [1:0]  aegis_threat_level;
    wire        aegis_honey_hit;

    // Upstream AXI (Slave)
    reg  [3:0]  s_axi_awid = 4'd0;
    reg  [31:0] s_axi_awaddr = 32'd0;
    reg  [7:0]  s_axi_awlen = 8'd0;
    reg  [2:0]  s_axi_awsize = 3'b010;
    reg  [1:0]  s_axi_awburst = 2'b01;
    reg  [2:0]  s_axi_awprot = 3'b001;
    reg         s_axi_awvalid = 1'b0;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata = 32'd0;
    reg  [3:0]  s_axi_wstrb = 4'b1111;
    reg         s_axi_wlast = 1'b0;
    reg         s_axi_wvalid = 1'b0;
    wire        s_axi_wready;

    wire [3:0]  s_axi_bid;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready = 1'b0;

    reg  [3:0]  s_axi_arid = 4'd0;
    reg  [31:0] s_axi_araddr = 32'd0;
    reg  [7:0]  s_axi_arlen = 8'd0;
    reg  [2:0]  s_axi_arsize = 3'b010;
    reg  [1:0]  s_axi_arburst = 2'b01;
    reg  [2:0]  s_axi_arprot = 3'b001;
    reg         s_axi_arvalid = 1'b0;
    wire        s_axi_arready;

    wire [3:0]  s_axi_rid;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rlast;
    wire        s_axi_rvalid;
    reg         s_axi_rready = 1'b0;

    // Downstream AXI (Master)
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
    reg         m_axi_awready = 1'b1;

    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    reg         m_axi_wready = 1'b1;

    reg  [3:0]  m_axi_bid = 4'd0;
    reg  [1:0]  m_axi_bresp = 2'b00;
    reg         m_axi_bvalid = 1'b0;
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
    reg         m_axi_arready = 1'b1;

    reg  [3:0]  m_axi_rid = 4'd0;
    reg  [31:0] m_axi_rdata = 32'd0;
    reg  [1:0]  m_axi_rresp = 2'b00;
    reg         m_axi_rlast = 1'b0;
    reg         m_axi_rvalid = 1'b0;
    wire        m_axi_rready;

    // Instantiate DUT
    dma_bus_firewall dut (
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(1'b0),
        .s_apb_paddr(s_apb_paddr),
        .s_apb_psel(s_apb_psel),
        .s_apb_penable(s_apb_penable),
        .s_apb_pwrite(s_apb_pwrite),
        .s_apb_pwdata(s_apb_pwdata),
        .s_apb_pprot(s_apb_pprot),
        .s_apb_prdata(s_apb_prdata),
        .s_apb_pready(s_apb_pready),
        .s_apb_pslverr(s_apb_pslverr),
        .dma_ctx_valid(dma_ctx_valid),
        .dma_ctx_src_addr(dma_ctx_src_addr),
        .dma_ctx_dst_addr(dma_ctx_dst_addr),
        .dma_ctx_byte_len(dma_ctx_byte_len),
        .dma_ctx_done(dma_ctx_done),
        .sec_irq(sec_irq),
        .cpu_telemetry_trap(cpu_telemetry_trap),
        .cpu_telemetry_stall(cpu_telemetry_stall),
        .aegis_nmi_irq(aegis_nmi_irq),
        .aegis_anomaly_alert(aegis_anomaly_alert),
        .aegis_threat_level(aegis_threat_level),
        .aegis_honey_hit(aegis_honey_hit),
        .s_axi_awid(s_axi_awid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rid(s_axi_rid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awregion(m_axi_awregion),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arregion(m_axi_arregion),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    integer failures = 0;
    task check;
        input cond;
        input [255:0] msg;
        begin
            if (!cond) begin
                $display("[FAIL] %0s at time %0t", msg, $time);
                failures = failures + 1;
            end else begin
                $display("[PASS] %0s", msg);
            end
        end
    endtask

    // Background Matrix B responder for allowed writes
    always @(posedge clk) begin
        if (rst_n) begin
            if (m_axi_wvalid && m_axi_wready && m_axi_wlast) begin
                @(posedge clk);
                #1;
                m_axi_bvalid = 1'b1;
                m_axi_bid    = m_axi_awid;
                m_axi_bresp  = 2'b00; // OKAY
                @(posedge clk);
                while (!m_axi_bready) @(posedge clk);
                #1;
                m_axi_bvalid = 1'b0;
            end
        end
    end

    // APB Write Helper
    task apb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            s_apb_paddr   = addr;
            s_apb_pwdata  = data;
            s_apb_pwrite  = 1'b1;
            s_apb_psel    = 1'b1;
            s_apb_penable = 1'b0;
            @(negedge clk);
            s_apb_penable = 1'b1;
            @(posedge clk);
            while (!s_apb_pready) @(posedge clk);
            @(negedge clk);
            s_apb_psel    = 1'b0;
            s_apb_penable = 1'b0;
        end
    endtask

    initial begin
        $display("=== STARTING ABNORMAL STRESS & NEGATIVE SCENARIOS REGRESSION ===");
        rst_n = 1'b0;
        #25;
        rst_n = 1'b1;
        #20;

        // Configure Firewall Region 0: 0x1000_0000 - 0x1000_0FFF as ALLOW (RW, MID=0, MASK=4'hF)
        apb_write(32'h00, 32'h0000_000F); // FW_CONTROL: FW_EN=1, IRQ_EN=1
        apb_write(32'h20, 32'h1000_0000); // RGN0_BASE
        apb_write(32'h24, 32'h1000_0FFF); // RGN0_LIMIT
        apb_write(32'h2C, 32'h0000_00F0); // RGN0_MID=0, MASK=4'hF (ignore ID bits)
        apb_write(32'h28, 32'h8000_0003); // RGN0_PERM: Active=1, RD=1, WR=1
        repeat (2) @(posedge clk);

        // -----------------------------------------------------------------
        // SCENARIO 1: Mid-Burst Asynchronous Reset Assertion
        // -----------------------------------------------------------------
        $display("\n--- SCENARIO 1: Mid-Burst Asynchronous Reset Assertion ---");
        @(negedge clk);
        s_axi_awaddr  = 32'h1000_0100;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd3; // 4-beat burst
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awvalid = 1'b1;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 1'b0;

        // Send beat 0
        s_axi_wdata   = 32'hA001;
        s_axi_wvalid  = 1'b1;
        s_axi_wlast   = 1'b0;
        @(posedge clk);
        while (!s_axi_wready) @(posedge clk);

        // Assert asynchronous reset midway through burst (at beat 1)
        @(negedge clk);
        s_axi_wdata   = 32'hA002;
        #2;
        rst_n = 1'b0; // HARD RESET MID-BURST
        $display("[INFO] Hard Reset asserted mid-burst at time %0t", $time);
        #1;
        check(m_axi_awvalid == 1'b0, "Downstream m_axi_awvalid deasserted immediately on reset");
        check(m_axi_wvalid  == 1'b0, "Downstream m_axi_wvalid deasserted immediately on reset");

        // Release reset and verify clean restart
        #30;
        @(negedge clk);
        s_axi_wvalid = 1'b0;
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // Re-configure region 0 after reset
        apb_write(32'h00, 32'h0000_000F);
        apb_write(32'h20, 32'h1000_0000);
        apb_write(32'h24, 32'h1000_0FFF);
        apb_write(32'h2C, 32'h0000_00F0);
        apb_write(32'h28, 32'h8000_0003);
        repeat (2) @(posedge clk);
        check(dut.s_axi_awready == 1'b1, "DUT recovers to ready state after mid-burst reset");

        // -----------------------------------------------------------------
        // SCENARIO 2: Sustained Downstream Backpressure
        // -----------------------------------------------------------------
        $display("\n--- SCENARIO 2: Sustained Matrix Backpressure (Stalled READY) ---");
        m_axi_wready = 1'b0; // STALL DOWNSTREAM MATRIX WRITE DATA

        @(negedge clk);
        s_axi_awaddr  = 32'h1000_0200;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0; // 1-beat
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hCAFE_BABE;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
        s_axi_bready  = 1'b1;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 1'b0;

        // Hold stalled for 25 cycles
        $display("[INFO] Holding matrix backpressure for 25 clock cycles...");
        repeat (25) @(posedge clk);

        // Release backpressure
        $display("[INFO] Releasing matrix backpressure (m_axi_wready=1)...");
        @(negedge clk);
        m_axi_wready = 1'b1;

        while (!s_axi_wready) @(posedge clk);
        @(negedge clk);
        s_axi_wvalid = 1'b0;
        s_axi_wlast  = 1'b0;

        while (!s_axi_bvalid) @(posedge clk);
        check(s_axi_bresp == 2'b00, "Transaction successfully retired with OKAY after backpressure release");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // -----------------------------------------------------------------
        // SCENARIO 3: Access Beyond Configured Window (Illegal Destination)
        // -----------------------------------------------------------------
        $display("\n--- SCENARIO 3: Illegal Window Traversal (Default Deny Routing) ---");
        @(negedge clk);
        s_axi_awaddr  = 32'h7000_0000; // Unmapped region -> Must be DENIED
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hDEAD_BEEF;
        s_axi_wstrb   = 4'b1111;
        s_axi_wvalid  = 1'b1;
        s_axi_wlast   = 1'b1;
        s_axi_bready  = 1'b1;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 1'b0;

        while (!s_axi_wready) @(posedge clk);
        @(negedge clk);
        s_axi_wvalid = 1'b0;
        s_axi_wlast  = 1'b0;

        while (!s_axi_bvalid) @(posedge clk);
        check(s_axi_bresp == 2'b11, "Unmapped illegal write trapped with DECERR response");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // Final Summary
        repeat (5) @(posedge clk);
        $display("\n========================================================");
        if (failures == 0) begin
            $display("[PASS] ALL ABNORMAL STRESS SCENARIOS VERIFIED SUCCESSFULLY!");
            $display("=== ABNORMAL STRESS REGRESSION COMPLETE: 0 FAILURES ===");
            $display("========================================================");
            $finish;
        end else begin
            $fatal(1, "[FAIL] ABNORMAL STRESS FAILED with %0d errors", failures);
        end
    end

    // Safety timeout
    initial begin
        #500000;
        $fatal(1, "TIMEOUT in tb_fw_abnormal_stress");
    end

endmodule
