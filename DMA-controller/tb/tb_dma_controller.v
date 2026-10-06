`timescale 1ns/1ps

module tb_dma_controller;

    localparam [31:0] SRC_BASE = 32'h0000_1000;
    localparam [31:0] DST_BASE = 32'h0000_2000;
    localparam [31:0] DMA_APB_BASE = 32'h1000_1000;
    localparam integer WORD_COUNT = 16;

    reg clk;
    reg rst_n;

    // APB slave interface
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [31:0] paddr;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;
    wire        pslverr;

    wire        dma_irq;
    wire        dma_ctx_valid;
    wire [31:0] dma_ctx_src_addr;
    wire [31:0] dma_ctx_dst_addr;
    wire [31:0] dma_ctx_byte_len;
    wire        dma_ctx_done;

    // AXI4 master interface
    wire [31:0] m_axi_araddr;
    wire [3:0]  m_axi_arid;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire [2:0]  m_axi_prot;
    wire        m_axi_arvalid;
    reg         m_axi_arready;
    reg  [31:0] m_axi_rdata;
    reg         m_axi_rlast;
    reg         m_axi_rvalid;
    wire [3:0]  m_axi_rid = 4'h0;
    reg  [1:0]  m_axi_rresp;
    wire        m_axi_rready;

    wire [31:0] m_axi_awaddr;
    wire [3:0]  m_axi_awid;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire        m_axi_awvalid;
    reg         m_axi_awready;
    wire [31:0] m_axi_wdata;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    reg         m_axi_wready;
    wire [3:0]  m_axi_wstrb;
    wire [3:0]  m_axi_bid = 4'h0;
    reg  [1:0]  m_axi_bresp;
    reg         m_axi_bvalid;
    wire        m_axi_bready;

    reg [31:0] source_mem [0:WORD_COUNT-1];
    reg [31:0] destination_mem [0:WORD_COUNT-1];
    reg        read_active;
    reg [31:0] read_addr;
    reg [7:0]  read_beats_left;
    reg        write_active;
    reg [31:0] write_addr;
    reg        inject_b_error;
    integer    master_done_count;
    integer    master_error_count;
    integer    ctx_done_count;
    integer    done_before_error_test;
    integer    error_before_error_test;
    integer    ctx_done_before_error_test;
    integer    i;

    dma_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .dma_irq(dma_irq),
        .dma_ctx_valid(dma_ctx_valid),
        .dma_ctx_src_addr(dma_ctx_src_addr),
        .dma_ctx_dst_addr(dma_ctx_dst_addr),
        .dma_ctx_byte_len(dma_ctx_byte_len),
        .dma_ctx_done(dma_ctx_done),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arid(m_axi_arid),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_prot(m_axi_prot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rid(m_axi_rid),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rready(m_axi_rready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awid(m_axi_awid),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
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
        .m_axi_bready(m_axi_bready)
    );

    always #5 clk = ~clk;

    initial begin
        #200000;
        $fatal(1, "[TIMEOUT] tb_dma_controller exceeded 200 us");
    end

    task automatic apb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            psel <= 1'b1;
            pwrite <= 1'b1;
            paddr <= addr;
            pwdata <= data;
            penable <= 1'b0;
            @(posedge clk);
            penable <= 1'b1;
            @(posedge clk);
            psel <= 1'b0;
            penable <= 1'b0;
            pwrite <= 1'b0;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_active <= 1'b0;
            read_addr <= 32'd0;
            read_beats_left <= 8'd0;
            m_axi_rvalid <= 1'b0;
            m_axi_rlast <= 1'b0;
            m_axi_rdata <= 32'd0;
            m_axi_rresp <= 2'b00;
        end else begin
            if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast <= 1'b0;
            end

            if (m_axi_arvalid && m_axi_arready && !read_active) begin
                read_active <= 1'b1;
                read_addr <= m_axi_araddr;
                read_beats_left <= m_axi_arlen + 8'd1;
            end

            if (read_active && (!m_axi_rvalid || m_axi_rready)) begin
                m_axi_rvalid <= 1'b1;
                m_axi_rdata <= source_mem[(read_addr - SRC_BASE) >> 2];
                m_axi_rlast <= (read_beats_left == 8'd1);
                read_addr <= read_addr + 32'd4;
                read_beats_left <= read_beats_left - 8'd1;
                if (read_beats_left == 8'd1)
                    read_active <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_active <= 1'b0;
            write_addr <= 32'd0;
            m_axi_bvalid <= 1'b0;
            m_axi_bresp <= 2'b00;
        end else begin
            if (m_axi_bvalid && m_axi_bready)
                m_axi_bvalid <= 1'b0;

            if (m_axi_awvalid && m_axi_awready && !write_active) begin
                write_active <= 1'b1;
                write_addr <= m_axi_awaddr;
            end

            if (m_axi_wvalid && m_axi_wready && write_active) begin
                destination_mem[(write_addr - DST_BASE) >> 2] <= m_axi_wdata;
                write_addr <= write_addr + 32'd4;
                if (m_axi_wlast) begin
                    write_active <= 1'b0;
                    m_axi_bvalid <= 1'b1;
                    m_axi_bresp <= inject_b_error ? 2'b10 : 2'b00;
                end
            end

            if (m_axi_bvalid && m_axi_bready)
                m_axi_bresp <= 2'b00;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            master_done_count <= 0;
            master_error_count <= 0;
            ctx_done_count <= 0;
        end else begin
            if (dut.master_done)
                master_done_count <= master_done_count + 1;
            if (dut.master_error)
                master_error_count <= master_error_count + 1;
            if (dma_ctx_done)
                ctx_done_count <= ctx_done_count + 1;
        end
    end

    always @(posedge clk) begin
        if (rst_n && m_axi_arvalid) begin
            if ((m_axi_arid != 4'b0000) || (m_axi_prot != 3'b001))
                $fatal(1, "Unexpected AXI read ID or protection value");
        end
        if (rst_n && m_axi_awvalid) begin
            if ((m_axi_awid != 4'b0000) || (m_axi_prot != 3'b001))
                $fatal(1, "Unexpected AXI write ID or protection value");
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = 32'd0;
        pwdata = 32'd0;
        m_axi_arready = 1'b1;
        m_axi_awready = 1'b1;
        m_axi_wready = 1'b1;
        inject_b_error = 1'b0;

        for (i = 0; i < WORD_COUNT; i = i + 1) begin
            source_mem[i] = 32'hCAFE_0000 + i;
            destination_mem[i] = 32'd0;
        end

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        // 1. Normal transfer with IRQ_EN = 1
        apb_write(DMA_APB_BASE + 32'h04, SRC_BASE);
        apb_write(DMA_APB_BASE + 32'h08, DST_BASE);
        apb_write(DMA_APB_BASE + 32'h0C, WORD_COUNT * 4);
        apb_write(DMA_APB_BASE + 32'h00, 32'h0000_0003); // START=1, IRQ_EN=1

        for (i = 0; (i < 20) && !dma_ctx_valid; i = i + 1)
            @(posedge clk);
        if (!dma_ctx_valid || (dma_ctx_src_addr != SRC_BASE) ||
            (dma_ctx_dst_addr != DST_BASE) || (dma_ctx_byte_len != WORD_COUNT * 4) ||
            dma_ctx_done)
            $fatal(1, "V2.4 sideband descriptor was not latched at DMA start");

        for (i = 0; (i < 1000) && (dma_irq != 1'b1); i = i + 1)
            @(posedge clk);
        if (dma_irq != 1'b1)
            $fatal(1, "DMA transfer timed out or IRQ not asserted");

        if (!dma_ctx_done || dma_ctx_valid)
            $fatal(1, "V2.4 sideband completion lifecycle is incorrect");
        @(posedge clk);
        #1;
        if (dma_ctx_done)
            $fatal(1, "dma_ctx_done must be a one-cycle pulse");

        for (i = 0; i < WORD_COUNT; i = i + 1) begin
            if (destination_mem[i] !== source_mem[i])
                $fatal(1, "Mismatch at word %0d: expected %h, got %h", i,
                       source_mem[i], destination_mem[i]);
        end

        // Clear IRQ via W1C on DMA_STATUS[1] (DONE)
        apb_write(DMA_APB_BASE + 32'h10, 32'h0000_0002);
        @(negedge clk);
        if (dma_irq != 1'b0)
            $fatal(1, "DMA IRQ did not clear on W1C");

        // 2. Misaligned transfer attempt: Must be rejected and assert ERROR
        apb_write(DMA_APB_BASE + 32'h04, 32'h0000_1001); // Misaligned SRC
        apb_write(DMA_APB_BASE + 32'h00, 32'h0000_0003); // START=1, IRQ_EN=1
        @(posedge clk);
        #1;
        if (dma_ctx_valid)
            $fatal(1, "dma_ctx_valid was asserted for misaligned address!");
        if (dma_irq != 1'b1)
            $fatal(1, "dma_irq was not asserted on alignment error!");

        // Clear ERROR via W1C on DMA_STATUS[2]
        apb_write(DMA_APB_BASE + 32'h10, 32'h0000_0004);
        @(negedge clk);
        if (dma_irq != 1'b0)
            $fatal(1, "DMA ERROR IRQ did not clear on W1C");

        // 3. AXI BRESP error: close the active context with one ERROR
        // terminal event, never a DONE event, after FIFO cleanup.
        apb_write(DMA_APB_BASE + 32'h04, SRC_BASE);
        apb_write(DMA_APB_BASE + 32'h08, DST_BASE);
        apb_write(DMA_APB_BASE + 32'h0C, WORD_COUNT * 4);
        done_before_error_test = master_done_count;
        error_before_error_test = master_error_count;
        ctx_done_before_error_test = ctx_done_count;
        inject_b_error = 1'b1;
        apb_write(DMA_APB_BASE + 32'h00, 32'h0000_0003);

        for (i = 0; (i < 20) && !dma_ctx_valid; i = i + 1)
            @(posedge clk);
        if (!dma_ctx_valid)
            $fatal(1, "DMA context did not open for BRESP error test");

        for (i = 0; (i < 1000) && (dma_irq != 1'b1); i = i + 1)
            @(posedge clk);
        #1;
        if (dma_irq != 1'b1)
            $fatal(1, "BRESP error transfer timed out");
        if (dma_ctx_valid || (ctx_done_count != ctx_done_before_error_test + 1))
            $fatal(1, "BRESP error did not close context with one dma_ctx_done pulse");
        if ((master_done_count != done_before_error_test) ||
            (master_error_count != error_before_error_test + 1))
            $fatal(1, "BRESP error terminal event count is incorrect");
        if (!dut.fifo_empty)
            $fatal(1, "BRESP error completed before FIFO flush");

        @(posedge clk);
        #1;
        if (dma_ctx_done || (ctx_done_count != ctx_done_before_error_test + 1))
            $fatal(1, "dma_ctx_done repeated or was wider than one cycle after BRESP error");
        inject_b_error = 1'b0;
        apb_write(DMA_APB_BASE + 32'h10, 32'h0000_0004);

        $display("[PASS] dma_controller regression: copy, IRQ/W1C, alignment, and BRESP error context closure.");
        $finish;
    end

endmodule
