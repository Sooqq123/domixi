`timescale 1ns / 1ps

module tb_dma_fifo_latch;

    // Parameters
    localparam DEPTH = 32;
    parameter WIDTH = 32;

    // Signals
    reg              clk;
    reg              rst_n;
    reg              wr_en;
    reg  [WIDTH-1:0] wdata;
    reg              rd_en;
    reg              flush;
    wire [WIDTH-1:0] rdata;
    wire             full;
    wire             empty;
    wire [5:0]       count;

    // Instantiate DUT (Device Under Test)
    dma_fifo_latch #(.DEPTH(DEPTH), .PTR_WIDTH(5)) u_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wdata(wdata),
        .rd_en(rd_en),
        .flush(flush),
        .rdata(rdata),
        .full(full),
        .empty(empty),
        .count(count)
    );

    // Clock Gen
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    initial begin
        #20000;
        $fatal(1, "[TIMEOUT] tb_dma_fifo_latch exceeded 20 us");
    end

    integer i;
    integer fail_count;
    reg [WIDTH-1:0] expected_data [0:DEPTH-1];

    initial begin
        $dumpfile("fifo_wave.vcd");
        $dumpvars(0, tb_dma_fifo_latch);
        
        $display("=== [TEST] Starting FIFO Test ===");

        // 1. Reset
        rst_n = 0; wr_en = 0; rd_en = 0; flush = 0; wdata = 0;
        fail_count = 0;
        #20;
        rst_n = 1;
        #10;
        
        // Check initial state
        if ((empty !== 1'b1) || (full !== 1'b0) || (count !== 6'd0)) begin
            fail_count = fail_count + 1;
            $error("[FAIL] Reset state incorrect");
        end else begin
            $display("[PASS] Reset state OK");
        end

        // 2. Fill all 32 entries and retain a scoreboard for ordered drain.
        $display("=== [TEST] Writing Data until FULL ===");
        for (i = 0; i < DEPTH; i = i + 1) begin
            expected_data[i] = 32'hA000_0000 + i;
            @(negedge clk);
            if (full) begin
                fail_count = fail_count + 1;
                $error("[FAIL] FIFO became full before item %0d", i);
            end
            wr_en = 1'b1;
            wdata = expected_data[i];
            @(posedge clk);
            #1;
        end
        @(negedge clk);
        wr_en = 1'b0;
        #1;
        if (full && (count == DEPTH)) begin
            $display("[PASS] FIFO is FULL at depth 32");
        end else begin
            fail_count = fail_count + 1;
            $error("[FAIL] FIFO full/count mismatch: full=%b count=%0d", full, count);
        end

        // 3. Drain and compare every entry in FIFO order.
        $display("=== [TEST] Reading Data until EMPTY ===");
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            if (empty) begin
                fail_count = fail_count + 1;
                $error("[FAIL] FIFO became empty before item %0d", i);
            end
            if (rdata !== expected_data[i]) begin
                fail_count = fail_count + 1;
                $error("[FAIL] FIFO[%0d] expected=%h got=%h",
                       i, expected_data[i], rdata);
            end
            rd_en = 1'b1;
            @(posedge clk);
            #1;
        end
        @(negedge clk);
        rd_en = 1'b0;
        #1;
        if (empty && (count == 0)) begin
            $display("[PASS] FIFO ordered scoreboard and EMPTY state");
        end else begin
            fail_count = fail_count + 1;
            $error("[FAIL] FIFO should be EMPTY after ordered drain");
        end

        // 4. Concurrent read/write must preserve the old head and make the
        // new item the next head while occupancy remains one.
        $display("=== [TEST] Concurrent Read/Write ===");
        @(negedge clk);
        wr_en = 1'b1;
        wdata = 32'hDEAD_BEEF;
        @(posedge clk);
        #1;

        @(negedge clk);
        if (rdata !== 32'hDEAD_BEEF) begin
            fail_count = fail_count + 1;
            $error("[FAIL] Simultaneous pre-read expected=DEADBEEF got=%h", rdata);
        end
        wr_en = 1'b1;
        wdata = 32'hCAFE_BABE;
        rd_en = 1'b1;
        @(posedge clk);
        #1;
        if ((count !== 6'd1) || (rdata !== 32'hCAFE_BABE)) begin
            fail_count = fail_count + 1;
            $error("[FAIL] Simultaneous RW count/data mismatch: count=%0d data=%h",
                   count, rdata);
        end

        @(negedge clk);
        wr_en = 1'b0;
        rd_en = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        rd_en = 1'b0;
        if (!empty || (count != 0)) begin
            fail_count = fail_count + 1;
            $error("[FAIL] FIFO not empty after simultaneous-case drain");
        end else begin
            $display("[PASS] Simultaneous read/write ordering and occupancy");
        end

        // 5. Abort flush must atomically return occupancy to zero without a
        // read pop. This is the V2.4.1 terminal-error cleanup path.
        for (i = 0; i < 4; i = i + 1) begin
            @(negedge clk);
            wr_en = 1'b1;
            wdata = 32'h1111_0001 + i;
            @(posedge clk);
            #1;
        end
        @(negedge clk);
        wr_en = 1'b0;
        if (count == 0) begin
            fail_count = fail_count + 1;
            $error("[FAIL] FIFO flush precondition was not established");
        end
        flush = 1'b1;
        @(posedge clk);
        #1;
        flush = 1'b0;
        if (!empty || full || (count != 0)) begin
            fail_count = fail_count + 1;
            $error("[FAIL] FIFO flush did not clear occupancy");
        end else begin
            $display("[PASS] FIFO abort flush clears occupancy");
        end

        if (fail_count != 0)
            $fatal(1, "[FAIL] tb_dma_fifo_latch recorded %0d check failures", fail_count);
        $display("[PASS] tb_dma_fifo_latch completed with no check failures");
        $finish;
    end

endmodule
