`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: tb_fw_honeypot_sink.v
// Verifies Honey-Pot AXI Sink behavior against Section 8 of specification
////////////////////////////////////////////////////////////////////////////////

module tb_fw_honeypot_sink;

    reg clk;
    reg rst_n;

    // Write Channel
    reg        hp_awvalid;
    wire       hp_awready;
    reg  [3:0] hp_awid;
    reg [31:0] hp_awaddr;
    reg  [7:0] hp_awlen;
    reg  [2:0] hp_awsize;
    reg  [1:0] hp_awburst;

    reg        hp_wvalid;
    wire       hp_wready;
    reg [31:0] hp_wdata;
    reg  [3:0] hp_wstrb;
    reg        hp_wlast;

    wire       hp_bvalid;
    reg        hp_bready;
    wire [3:0] hp_bid;
    wire [1:0] hp_bresp;

    // Read Channel
    reg        hp_arvalid;
    wire       hp_arready;
    reg  [3:0] hp_arid;
    reg [31:0] hp_araddr;
    reg  [7:0] hp_arlen;
    reg  [2:0] hp_arsize;
    reg  [1:0] hp_arburst;

    wire       hp_rvalid;
    reg        hp_rready;
    wire [3:0] hp_rid;
    wire [31:0] hp_rdata;
    wire [1:0] hp_rresp;
    wire       hp_rlast;

    wire [15:0] scrambler_state;
    wire [31:0] honey_trans_count;
    wire       sink_busy;
    wire       wlast_err;

    fw_honeypot_sink u_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .hp_awvalid         (hp_awvalid),
        .hp_awready         (hp_awready),
        .hp_awid            (hp_awid),
        .hp_awaddr          (hp_awaddr),
        .hp_awlen           (hp_awlen),
        .hp_awsize          (hp_awsize),
        .hp_awburst         (hp_awburst),
        .hp_wvalid          (hp_wvalid),
        .hp_wready          (hp_wready),
        .hp_wdata           (hp_wdata),
        .hp_wstrb           (hp_wstrb),
        .hp_wlast           (hp_wlast),
        .hp_bvalid          (hp_bvalid),
        .hp_bready          (hp_bready),
        .hp_bid             (hp_bid),
        .hp_bresp           (hp_bresp),
        .hp_arvalid         (hp_arvalid),
        .hp_arready         (hp_arready),
        .hp_arid            (hp_arid),
        .hp_araddr          (hp_araddr),
        .hp_arlen           (hp_arlen),
        .hp_arsize          (hp_arsize),
        .hp_arburst         (hp_arburst),
        .hp_rvalid          (hp_rvalid),
        .hp_rready          (hp_rready),
        .hp_rid             (hp_rid),
        .hp_rdata           (hp_rdata),
        .hp_rresp           (hp_rresp),
        .hp_rlast           (hp_rlast),
        .scrambler_state_out(scrambler_state),
        .honey_trans_count  (honey_trans_count),
        .sink_busy          (sink_busy),
        .wlast_err          (wlast_err)
    );

    // 40 MHz clock (25 ns period)
    always #12.5 clk = ~clk;

    integer i;
    reg [31:0] captured_rdata;

    initial begin
        clk = 0;
        rst_n = 0;
        hp_awvalid = 0;
        hp_awid = 0;
        hp_awaddr = 0;
        hp_awlen = 0;
        hp_awsize = 3'b010;
        hp_awburst = 2'b01;
        hp_wvalid = 0;
        hp_wdata = 0;
        hp_wstrb = 4'hF;
        hp_wlast = 0;
        hp_bready = 0;

        hp_arvalid = 0;
        hp_arid = 0;
        hp_araddr = 0;
        hp_arlen = 0;
        hp_arsize = 3'b010;
        hp_arburst = 2'b01;
        hp_rready = 0;

        #50;
        rst_n = 1;
        #50;

        $display("[TEST 1] Testing Normal Write Burst (LEN=3 -> 4 beats)");
        @(posedge clk);
        #1;
        hp_awvalid = 1;
        hp_awid = 4'h3;
        hp_awaddr = 32'h7F00_1000;
        hp_awlen = 8'd3;
        
        while (!hp_awready) @(posedge clk);
        @(posedge clk);
        #1;
        hp_awvalid = 0;

        for (i = 0; i < 4; i = i + 1) begin
            hp_wvalid = 1;
            hp_wdata = 32'hDEAD_0000 + i;
            hp_wlast = (i == 3);
            @(posedge clk);
            while (!hp_wready) @(posedge clk);
            #1;
        end
        hp_wvalid = 0;
        hp_wlast = 0;

        while (!hp_bvalid) @(posedge clk);
        if (hp_bresp !== 2'b00 || hp_bid !== 4'h3) begin
            $display("[FAIL] B channel response mismatch: resp=%b bid=%h", hp_bresp, hp_bid);
            $finish(1);
        end
        hp_bready = 1;
        @(posedge clk);
        #1;
        hp_bready = 0;

        #25;
        if (honey_trans_count !== 32'd1 || wlast_err !== 1'b0) begin
            $display("[FAIL] Honey count or wlast_err unexpected: count=%d err=%b", honey_trans_count, wlast_err);
            $finish(1);
        end
        $display("[PASS] Write burst completed successfully. Count=%d", honey_trans_count);

        $display("[TEST 2] Testing Read Burst with Backpressure (LEN=2 -> 3 beats)");
        @(posedge clk);
        #1;
        hp_arvalid = 1;
        hp_arid = 4'h5;
        hp_araddr = 32'h7F00_2000;
        hp_arlen = 8'd2;
        
        while (!hp_arready) @(posedge clk);
        @(posedge clk);
        #1;
        hp_arvalid = 0;

        // Beat 0: accept immediately
        while (!hp_rvalid) @(posedge clk);
        if (hp_rid !== 4'h5 || hp_rlast !== 1'b0) begin
            $display("[FAIL] Read Beat 0 incorrect");
            $finish(1);
        end
        hp_rready = 1;
        @(posedge clk);
        #1;
        hp_rready = 0; // inject backpressure for beat 1

        // Beat 1: hold backpressure for 3 cycles and check stability
        while (!hp_rvalid) @(posedge clk);
        captured_rdata = hp_rdata;
        repeat(3) begin
            @(posedge clk);
            #1;
            if (!hp_rvalid || hp_rdata !== captured_rdata || hp_rid !== 4'h5) begin
                $display("[FAIL] R channel unstable under backpressure");
                $finish(1);
            end
        end
        hp_rready = 1;
        @(posedge clk);
        #1;
        hp_rready = 0;

        // Beat 2: last beat
        while (!hp_rvalid) @(posedge clk);
        if (!hp_rlast) begin
            $display("[FAIL] RLAST not asserted on final beat");
            $finish(1);
        end
        hp_rready = 1;
        @(posedge clk);
        #1;
        hp_rready = 0;

        #25;
        if (honey_trans_count !== 32'd2) begin
            $display("[FAIL] Honey count mismatch after read: count=%d", honey_trans_count);
            $finish(1);
        end
        $display("[PASS] Read burst with backpressure passed. Count=%d", honey_trans_count);

        $display("[ALL TESTS PASSED] fw_honeypot_sink verified successfully!");
        $finish(0);
    end

endmodule
