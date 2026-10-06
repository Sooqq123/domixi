`timescale 1ns/1ps

module tb_dma_bus_firewall;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    // APB4 signals
    reg  [31:0] s_apb_paddr = 32'd0;
    reg         s_apb_psel = 1'b0;
    reg         s_apb_penable = 1'b0;
    reg         s_apb_pwrite = 1'b0;
    reg  [31:0] s_apb_pwdata = 32'd0;
    reg  [2:0]  s_apb_pprot = 3'b001;
    wire [31:0] s_apb_prdata;
    wire        s_apb_pready;
    wire        s_apb_pslverr;

    // DMA Context Sideband
    reg         dma_ctx_valid = 1'b0;
    reg  [31:0] dma_ctx_src_addr = 32'd0;
    reg  [31:0] dma_ctx_dst_addr = 32'd0;
    reg  [31:0] dma_ctx_byte_len = 32'd0;
    reg         dma_ctx_done = 1'b0;
    wire        sec_irq;

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

    // Downstream AXI (Master to Matrix)
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

    // DUT instantiation
    dma_bus_firewall u_dut (
        .clk(clk),
        .rst_n(rst_n),
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
    reg [31:0] rd_data;

    task check;
        input condition;
        input [8*128-1:0] msg;
        begin
            if (!condition) begin
                $display("[FAIL] %0s at time %0t", msg, $time);
                failures = failures + 1;
            end else begin
                $display("[PASS] %0s", msg);
            end
        end
    endtask

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
            #1;
            check(s_apb_pready && !s_apb_pslverr, "APB Write Accepted");
            @(negedge clk);
            s_apb_psel    = 1'b0;
            s_apb_penable = 1'b0;
            s_apb_pwrite  = 1'b0;
        end
    endtask

    task apb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(negedge clk);
            s_apb_paddr   = addr;
            s_apb_pwrite  = 1'b0;
            s_apb_psel    = 1'b1;
            s_apb_penable = 1'b0;
            @(negedge clk);
            s_apb_penable = 1'b1;
            @(posedge clk);
            #1;
            check(s_apb_pready && !s_apb_pslverr, "APB Read Accepted");
            data = s_apb_prdata;
            @(negedge clk);
            s_apb_psel    = 1'b0;
            s_apb_penable = 1'b0;
        end
    endtask

    // Background Matrix responder for allowed writes
    always @(posedge clk) begin
        if (rst_n) begin
            if (m_axi_wvalid && m_axi_wready && m_axi_wlast) begin
                // Return B response on next cycle
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

    // Background Matrix responder for allowed reads
    always @(posedge clk) begin
        if (rst_n) begin
            if (m_axi_arvalid && m_axi_arready) begin
                @(posedge clk);
                #1;
                m_axi_rvalid = 1'b1;
                m_axi_rid    = m_axi_arid;
                m_axi_rdata  = 32'hBEEF_CAFE;
                m_axi_rresp  = 2'b00; // OKAY
                m_axi_rlast  = 1'b1;
                @(posedge clk);
                while (!m_axi_rready) @(posedge clk);
                #1;
                m_axi_rvalid = 1'b0;
                m_axi_rlast  = 1'b0;
            end
        end
    end

    initial begin
        $display("========================================================");
        $display("STARTING FULL UNIT TESTBENCH: tb_dma_bus_firewall");
        $display("========================================================");

        // 1. Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // TEST 1: Check Reset Default
        $display("\n--- TEST 1: Check Reset Defaults & Enable IRQ ---");
        apb_read(32'h00, rd_data);
        check(rd_data == 32'h0000_000D, "FW_CONTROL reset value is 0x0000_000D");
        check(sec_irq == 1'b0, "sec_irq is deasserted at reset");
        check(s_axi_awready == 1'b1, "s_axi_awready is high and ready for new AW");
        check(s_axi_arready == 1'b1, "s_axi_arready is high and ready for new AR");

        // Enable IRQ by setting FW_CONTROL = 0x0000_000F (FW_EN=1, IRQ_EN=1, AUTO_CTX_EN=1, ERR_MODE=1)
        apb_write(32'h00, 32'h0000_000F);
        apb_read(32'h00, rd_data);
        check(rd_data == 32'h0000_000F, "FW_CONTROL updated to 0x0000_000F (IRQ enabled)");

        // TEST 2: Configure Static Region 0 (0x1000_0000 - 0x1000_0FFF, RW, MID=0, MASK=0xF - any ID)
        $display("\n--- TEST 2: Configure Static Region 0 ---");
        apb_write(32'h20, 32'h1000_0000); // RGN0_BASE
        apb_write(32'h24, 32'h1000_0FFF); // RGN0_LIMIT
        apb_write(32'h2C, 32'h0000_00F0); // RGN0_MID=0, MASK=4'hF (ignore ID bits)
        apb_write(32'h28, 32'h8000_0003); // RGN0_PERM: Active=1, RD=1, WR=1, SEC=0, PRIV=0
        apb_read(32'h20, rd_data);
        check(rd_data == 32'h1000_0000, "RGN0_BASE readback matches");
        apb_read(32'h28, rd_data);
        check(rd_data[31] == 1'b1, "RGN0 is active");

        // TEST 3: Allowed Write to Region 0
        $display("\n--- TEST 3: Allowed Write to Region 0 ---");
        @(negedge clk);
        s_axi_awaddr  = 32'h1000_0100;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'h1234_5678;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b00, "Allowed Write returns OKAY");
        check(s_axi_bid == 4'h0, "Allowed Write returns matching BID 4'h0");
        @(negedge clk);
        s_axi_bready = 1'b0;
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "No IRQ on allowed write");

        // TEST 4: Allowed Read from Region 0
        $display("\n--- TEST 4: Allowed Read from Region 0 ---");
        @(negedge clk);
        s_axi_araddr  = 32'h1000_0200;
        s_axi_arid    = 4'h0;
        s_axi_arlen   = 8'd0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arprot  = 3'b001;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        @(negedge clk);
        s_axi_arvalid = 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        check(s_axi_rresp == 2'b00, "Allowed Read returns OKAY");
        check(s_axi_rid == 4'h0, "Allowed Read returns matching RID 4'h0");
        check(s_axi_rdata == 32'hBEEF_CAFE, "Allowed Read data received from Matrix");
        check(s_axi_rlast == 1'b1, "Allowed Read RLAST received");
        @(negedge clk);
        s_axi_rready = 1'b0;
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "No IRQ on allowed read");

        // TEST 5: Denied Write (Default Deny - unmapped address 0x8000_0000)
        $display("\n--- TEST 5: Denied Write (Default Deny) ---");
        @(negedge clk);
        s_axi_awaddr  = 32'h8000_0000;
        s_axi_awid    = 4'h5;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hDEAD_0001;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b11, "Denied Write returns DECERR");
        check(s_axi_bid == 4'h5, "Denied Write echoes BID 4'h5");
        @(negedge clk);
        s_axi_bready = 1'b0;

        repeat (2) @(posedge clk);
        check(sec_irq == 1'b1, "Security IRQ asserted on Denied Write");
        apb_read(32'h08, rd_data); // FAULT_STATUS
        check(rd_data[1] == 1'b1, "FAULT_STATUS bit 1 (WR_FAULT) is set");
        check(rd_data[31] == 1'b1, "FAULT_STATUS bit 31 (IRQ_PENDING) is set");
        apb_read(32'h0C, rd_data); // FAULT_ADDR
        check(rd_data == 32'h8000_0000, "FAULT_ADDR captures 0x8000_0000");

        // Clear FAULT_STATUS via W1C (bit 1 WR_FAULT and bit 31 IRQ_PENDING)
        apb_write(32'h08, 32'h8000_0002);
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "Security IRQ deasserts after FAULT_STATUS W1C");

        // TEST 6: Denied Read (Default Deny - unmapped address 0x9000_0000)
        $display("\n--- TEST 6: Denied Read (Default Deny) ---");
        @(negedge clk);
        s_axi_araddr  = 32'h9000_0000;
        s_axi_arid    = 4'h6;
        s_axi_arlen   = 8'd0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arprot  = 3'b001;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        @(negedge clk);
        s_axi_arvalid = 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        check(s_axi_rresp == 2'b11, "Denied Read returns DECERR");
        check(s_axi_rid == 4'h6, "Denied Read echoes RID 4'h6");
        check(s_axi_rlast == 1'b1, "Denied Read synthetic RLAST");
        @(negedge clk);
        s_axi_rready = 1'b0;

        repeat (2) @(posedge clk);
        check(sec_irq == 1'b1, "Security IRQ asserted on Denied Read");
        apb_read(32'h08, rd_data); // FAULT_STATUS
        check(rd_data[0] == 1'b1, "FAULT_STATUS bit 0 (RD_FAULT) is set");
        check(rd_data[31] == 1'b1, "FAULT_STATUS bit 31 (IRQ_PENDING) is set");
        apb_read(32'h0C, rd_data); // FAULT_ADDR
        check(rd_data == 32'h9000_0000, "FAULT_ADDR captures 0x9000_0000");

        // Clear FAULT_STATUS via W1C (bit 0 RD_FAULT and bit 31 IRQ_PENDING)
        apb_write(32'h08, 32'h8000_0001);
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "Security IRQ deasserts after FAULT_STATUS W1C");

        // TEST 7: Dynamic DMA Context Sideband Activation & Revocation
        $display("\n--- TEST 7: Dynamic DMA Context Sideband ---");
        @(negedge clk);
        dma_ctx_src_addr = 32'h2000_0000;
        dma_ctx_dst_addr = 32'h2000_1000;
        dma_ctx_byte_len = 32'd64;
        dma_ctx_valid    = 1'b1;

        repeat (2) @(posedge clk);
        apb_read(32'h60, rd_data); // RGN4_BASE
        check(rd_data == 32'h2000_0000, "Dynamic Region 4 Base = 0x2000_0000");
        apb_read(32'h64, rd_data); // RGN4_LIMIT
        check(rd_data == 32'h2000_003F, "Dynamic Region 4 Limit = 0x2000_003F");
        apb_read(32'h68, rd_data); // RGN4_PERM
        check(rd_data[31] == 1'b1, "Dynamic Region 4 is active");

        apb_read(32'h70, rd_data); // RGN5_BASE
        check(rd_data == 32'h2000_1000, "Dynamic Region 5 Base = 0x2000_1000");
        apb_read(32'h74, rd_data); // RGN5_LIMIT
        check(rd_data == 32'h2000_103F, "Dynamic Region 5 Limit = 0x2000_103F");
        apb_read(32'h78, rd_data); // RGN5_PERM
        check(rd_data[31] == 1'b1, "Dynamic Region 5 is active");

        // Read from Region 4 (SRC) -> Should be ALLOWED
        @(negedge clk);
        s_axi_araddr  = 32'h2000_0010;
        s_axi_arid    = 4'h0;
        s_axi_arlen   = 8'd0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arprot  = 3'b001;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        @(negedge clk);
        s_axi_arvalid = 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        check(s_axi_rresp == 2'b00, "Dynamic Region 4 Read is ALLOWED (OKAY)");
        @(negedge clk);
        s_axi_rready = 1'b0;

        // Write to Region 5 (DST) -> Should be ALLOWED
        @(negedge clk);
        s_axi_awaddr  = 32'h2000_1010;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'h5555_AAAA;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b00, "Dynamic Region 5 Write is ALLOWED (OKAY)");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // Write to Region 4 (SRC is read-only) -> Should be DENIED
        @(negedge clk);
        s_axi_awaddr  = 32'h2000_0020;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hDEAD_BEEF;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b11, "Write to Region 4 (RO) is DENIED with DECERR");
        @(negedge clk);
        s_axi_bready = 1'b0;
        // Clear fault (bit 1 WR_FAULT and bit 31 IRQ_PENDING)
        apb_write(32'h08, 32'h8000_0002);

        // Revoke Context via dma_ctx_done pulse
        $display("\n--- Revoking Dynamic Context ---");
        @(negedge clk);
        dma_ctx_done  = 1'b1;
        dma_ctx_valid = 1'b0;
        @(negedge clk);
        dma_ctx_done  = 1'b0;
        repeat (2) @(posedge clk);

        apb_read(32'h68, rd_data);
        check(rd_data[31] == 1'b0, "Dynamic Region 4 revoked (Active=0)");
        apb_read(32'h78, rd_data);
        check(rd_data[31] == 1'b0, "Dynamic Region 5 revoked (Active=0)");

        // Read from Region 4 after revocation -> Must be DENIED
        @(negedge clk);
        s_axi_araddr  = 32'h2000_0010;
        s_axi_arid    = 4'h0;
        s_axi_arlen   = 8'd0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arprot  = 3'b001;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        @(negedge clk);
        s_axi_arvalid = 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        check(s_axi_rresp == 2'b11, "Access to revoked dynamic region is DENIED with DECERR");
        @(negedge clk);
        s_axi_rready = 1'b0;
        // Clear fault (bit 0 RD_FAULT and bit 31 IRQ_PENDING)
        apb_write(32'h08, 32'h8000_0001);

        // TEST 8: Gate G3 Early WVALID
        $display("\n--- TEST 8: Gate G3 Early WVALID Isolation ---");
        @(negedge clk);
        s_axi_wdata   = 32'hCAFE_0001;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1; // Early WVALID before AW

        repeat (3) @(posedge clk);
        check(s_axi_wready == 1'b0, "Gate G3 blocks s_axi_wready when no AW is active");
        check(m_axi_wvalid == 1'b0, "Gate G3 isolates m_axi_wvalid from early WVALID");

        // Now issue AW to Region 0 with ID=0
        @(negedge clk);
        s_axi_awaddr  = 32'h1000_0080;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;
        s_axi_bready  = 1'b1;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 1'b0;

        // Now W handshake should complete once AW is resolved
        while (!s_axi_wready) @(posedge clk);
        check(m_axi_wvalid == 1'b1, "Gate G3 unblocks m_axi_wvalid after AW resolution");
        @(negedge clk);
        s_axi_wvalid = 1'b0;
        s_axi_wlast  = 1'b0;

        while (!s_axi_bvalid) @(posedge clk);
        check(s_axi_bresp == 2'b00, "Early WVALID transaction completes cleanly with OKAY");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // =====================================================================
        // TEST 9: Laser Glitch / Fault Injection Attack (CWE-1338)
        // =====================================================================
        $display("\n--- TEST 9: Laser Glitch / Fault Injection Attack (CWE-1338) ---");

        // Part 9A: Laser Glitch on Write Channel (Simulate bit corruption forcing decision_allow = 4'b0000)
        @(negedge clk);
        s_axi_awaddr  = 32'h8888_0000;
        s_axi_awid    = 4'h7;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hBAAD_F00D;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
        s_axi_bready  = 1'b1;

        // Force illegal glitch encoding (neither SAFE_ALLOW=4'b1010 nor SAFE_DENY=4'b0101)
        force u_dut.decision_allow = 4'b0000;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 1'b0;

        while (!s_axi_wready) @(posedge clk);
        @(negedge clk);
        s_axi_wvalid = 1'b0;
        s_axi_wlast  = 1'b0;

        while (u_dut.wr_owner == 2'b00) @(posedge clk);
        check(u_dut.wr_owner == 2'b10, "Firewall traps write glitch and forces OWNER_DRAIN");
        release u_dut.decision_allow;

        while (!s_axi_bvalid) @(posedge clk);
        check(s_axi_bresp == 2'b11, "Glitch attack on Write is safely terminated with DECERR");
        check(s_axi_bid == 4'h7, "Glitch write echoes BID 4'h7");
        check(m_axi_awvalid == 1'b0, "Glitch attack never penetrates to downstream AXI matrix");
        @(negedge clk);
        s_axi_bready = 1'b0;

        repeat (2) @(posedge clk);
        check(sec_irq == 1'b1, "Security IRQ asserted on Write Glitch attack");
        apb_read(32'h08, rd_data); // FAULT_STATUS
        check(rd_data[1] == 1'b1, "FAULT_STATUS bit 1 (WR_FAULT) is set on glitch");
        check(rd_data[31] == 1'b1, "FAULT_STATUS bit 31 (IRQ_PENDING) is set");
        apb_read(32'h18, rd_data); // FAULT_SOURCE
        check(rd_data[5:2] == 4'b1110, "FAULT_SOURCE captures GLITCH_FAULT_WR (0xE)");
        apb_read(32'h0C, rd_data); // FAULT_ADDR
        check(rd_data == 32'h8888_0000, "FAULT_ADDR captures glitch attack address 0x8888_0000");

        // Clear FAULT_STATUS via W1C
        apb_write(32'h08, 32'h8000_000F);
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "Security IRQ deasserts after Glitch FAULT_STATUS W1C");

        // Part 9B: Laser Glitch on Read Channel (Simulate bit corruption forcing decision_allow = 4'b1111)
        @(negedge clk);
        s_axi_araddr  = 32'h9999_0000;
        s_axi_arid    = 4'h8;
        s_axi_arlen   = 8'd0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arprot  = 3'b001;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b1;

        // Force illegal glitch encoding on read decision
        force u_dut.decision_allow = 4'b1111;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        @(negedge clk);
        s_axi_arvalid = 1'b0;

        while (u_dut.rd_owner == 2'b00) @(posedge clk);
        check(u_dut.rd_owner == 2'b10, "Firewall traps read glitch and forces OWNER_DRAIN");
        release u_dut.decision_allow;

        while (!s_axi_rvalid) @(posedge clk);
        check(s_axi_rresp == 2'b11, "Glitch attack on Read is safely terminated with DECERR");
        check(s_axi_rid == 4'h8, "Glitch read echoes RID 4'h8");
        check(s_axi_rdata == 32'h0000_0000, "Glitch read data zeroized to prevent information leakage");
        check(m_axi_arvalid == 1'b0, "Glitch read never penetrates to downstream AXI matrix");
        @(negedge clk);
        s_axi_rready = 1'b0;

        repeat (2) @(posedge clk);
        check(sec_irq == 1'b1, "Security IRQ asserted on Read Glitch attack");
        apb_read(32'h08, rd_data); // FAULT_STATUS
        check(rd_data[0] == 1'b1, "FAULT_STATUS bit 0 (RD_FAULT) is set on read glitch");
        check(rd_data[31] == 1'b1, "FAULT_STATUS bit 31 (IRQ_PENDING) is set");
        apb_read(32'h18, rd_data); // FAULT_SOURCE
        check(rd_data[5:2] == 4'b1111, "FAULT_SOURCE captures GLITCH_FAULT_RD (0xF)");

        // Clear FAULT_STATUS via W1C
        apb_write(32'h08, 32'h8000_000F);
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "Security IRQ deasserts after Read Glitch FAULT_STATUS W1C");

        // =====================================================================
        // TEST 10: Starvation / DoS Drain Timeout Verification
        // =====================================================================
        $display("\n--- TEST 10: Starvation / DoS Drain Timeout Verification ---");
        // An unmapped write request is issued, but Master stalls and withholds W data (s_axi_wvalid = 0)
        @(negedge clk);
        s_axi_awaddr  = 32'hA000_0000;
        s_axi_awid    = 4'h9;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wvalid  = 1'b0; // STALL: Master intentionally does not send W data
        s_axi_bready  = 1'b0; // Master holds bready low until response is ready

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 1'b0;

        // Verify that in the first 200 cycles, BVALID is not yet asserted (waiting for W channel)
        repeat (200) @(posedge clk);
        check(s_axi_bvalid == 1'b0, "Firewall Drain correctly waits for W channel before timeout");
        check(u_dut.wr_owner == 2'b10, "Firewall holds OWNER_DRAIN while waiting");

        // Wait for Drain Watchdog Timer (TIMEOUT_CYCLES = 256) to trip
        $display("[INFO] Waiting for Drain Watchdog Timer (256 cycles) to trip...");
        while (!s_axi_bvalid) @(posedge clk);

        check(s_axi_bvalid == 1'b1, "Watchdog expired after 256 cycles and asserted BVALID");
        check(s_axi_bresp == 2'b11, "Watchdog force-terminates write burst with DECERR");
        check(s_axi_bid == 4'h9, "Watchdog echoes AWID 4'h9 in B response");

        // Master acknowledges B channel response
        @(negedge clk);
        s_axi_bready = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        s_axi_bready = 1'b0;
        repeat (2) @(posedge clk);

        check(u_dut.wr_owner == 2'b00, "Write channel completely freed (wr_owner = OWNER_NONE)");

        // Clear fault status from timeout
        apb_write(32'h08, 32'h8000_000F);
        repeat (2) @(posedge clk);

        // Verify subsequent legitimate traffic proceeds immediately without chip reset
        @(negedge clk);
        s_axi_awaddr  = 32'h1000_0050; // Legitimate Region 0
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'h1122_3344;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b00, "Subsequent legitimate write completes OKAY - Bus unblocked without reset");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // =====================================================================
        // TEST 11: TOCTOU Dynamic Window Revocation & Context Watchdog
        // =====================================================================
        $display("\n--- TEST 11: TOCTOU Dynamic Window Revocation & Context Watchdog ---");

        // Step 11A: Activate dynamic region and test immediate software revocation
        @(negedge clk);
        dma_ctx_src_addr = 32'h4000_0000;
        dma_ctx_dst_addr = 32'h4000_1000;
        dma_ctx_byte_len = 32'd128;
        dma_ctx_valid    = 1'b1;

        repeat (2) @(posedge clk);
        apb_read(32'h68, rd_data); // RGN4_PERM
        check(rd_data[31] == 1'b1, "Dynamic Region 4 is active for DMA transfer");
        apb_read(32'h78, rd_data); // RGN5_PERM
        check(rd_data[31] == 1'b1, "Dynamic Region 5 is active for DMA transfer");

        // Software Revocation via dma_ctx_done
        @(negedge clk);
        dma_ctx_done  = 1'b1;
        dma_ctx_valid = 1'b0;
        @(negedge clk);
        dma_ctx_done  = 1'b0;
        repeat (2) @(posedge clk);

        apb_read(32'h68, rd_data);
        check(rd_data[31] == 1'b0, "Dynamic Region 4 instantly revoked (Active=0)");
        apb_read(32'h78, rd_data);
        check(rd_data[31] == 1'b0, "Dynamic Region 5 instantly revoked (Active=0)");

        // Late DMA write attempt to revoked window -> Must be REJECTED with DECERR
        @(negedge clk);
        s_axi_awaddr  = 32'h4000_1020;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hBAAD_FACE;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b11, "Late TOCTOU write to revoked dynamic region is DENIED (DECERR)");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // Clear fault status
        apb_write(32'h08, 32'h8000_000F);
        repeat (2) @(posedge clk);

        // Step 11B: Hardware Context Watchdog Auto-Revocation (CTX_TIMEOUT_CYCLES = 4096)
        $display("\n[INFO] Activating dynamic context and testing Hardware Watchdog Auto-Revocation...");
        @(negedge clk);
        dma_ctx_src_addr = 32'h5000_0000;
        dma_ctx_dst_addr = 32'h5000_1000;
        dma_ctx_byte_len = 32'd128;
        dma_ctx_valid    = 1'b1;

        repeat (2) @(posedge clk);
        apb_read(32'h68, rd_data);
        check(rd_data[31] == 1'b1, "Dynamic Region 4 active prior to watchdog timeout");

        // Advance simulation past 4096 clock cycles
        $display("[INFO] Advancing 4110 clock cycles for Context Watchdog Expiry (CTX_TIMEOUT_CYCLES = 4096)...");
        repeat (4110) @(posedge clk);

        check(sec_irq == 1'b1, "Security IRQ asserted upon Context Watchdog timeout");
        apb_read(32'h68, rd_data);
        check(rd_data[31] == 1'b0, "Dynamic Region 4 auto-revoked by Hardware Watchdog (Active=0)");
        apb_read(32'h78, rd_data);
        check(rd_data[31] == 1'b0, "Dynamic Region 5 auto-revoked by Hardware Watchdog (Active=0)");

        apb_read(32'h08, rd_data); // FAULT_STATUS
        check(rd_data[3] == 1'b1, "FAULT_STATUS bit 3 (BOUND_ERR) set by Context Watchdog");
        check(rd_data[31] == 1'b1, "FAULT_STATUS bit 31 (IRQ_PENDING) set");
        apb_read(32'h0C, rd_data); // FAULT_ADDR
        check(rd_data == 32'h5000_0000, "FAULT_ADDR captures expired dynamic window source address");
        apb_read(32'h18, rd_data); // FAULT_SOURCE
        check(rd_data[1:0] == 2'b10, "FAULT_SOURCE captures Context Tracker as fault source (2'b10)");

        // Adversary attempts to transfer data after timeout -> Must be DENIED with DECERR
        @(negedge clk);
        s_axi_awaddr  = 32'h5000_1010;
        s_axi_awid    = 4'h0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = 32'hDEAD_5000;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b1;
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
        check(s_axi_bresp == 2'b11, "Access after Context Watchdog timeout is DENIED (DECERR)");
        @(negedge clk);
        s_axi_bready = 1'b0;

        // Cleanup: deassert dma_ctx_valid and clear fault status
        @(negedge clk);
        dma_ctx_valid = 1'b0;
        repeat (2) @(posedge clk);
        apb_write(32'h08, 32'h8000_000F);
        repeat (2) @(posedge clk);
        check(sec_irq == 1'b0, "Security IRQ deasserts after cleanup");

        repeat (5) @(posedge clk);
        $display("\n========================================================");
        if (failures == 0) begin
            $display("ALL TESTS PASSED SUCCESSFULLY! (0 failures)");
            $display("========================================================");
            $finish;
        end else begin
            $fatal(1, "TESTBENCH FAILED with %0d errors", failures);
        end
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $fatal(1, "WATCHDOG TIMEOUT in tb_dma_bus_firewall");
    end

endmodule
