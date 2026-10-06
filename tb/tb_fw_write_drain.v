`timescale 1ns/1ps

module tb_fw_write_drain;
    reg        clk;
    reg        rst_n;
    reg        acl_w_fault;
    reg  [3:0] acl_w_id;
    reg  [7:0] acl_w_len;
    reg        acl_w_err_mode;
    reg        w_drain_wvalid;
    reg        w_drain_wlast;
    wire       w_drain_wready;
    wire       w_drain_bvalid;
    wire [3:0] w_drain_bid;
    wire [1:0] w_drain_bresp;
    reg        w_drain_bready;
    wire       w_framing_fault_valid;
    wire [3:0] w_framing_fault_code;

    integer errors = 0;
    integer test_step = 0;
    reg     timeout_fault_seen;

    fw_write_drain dut (
        .clk(clk),
        .rst_n(rst_n),
        .acl_w_fault(acl_w_fault),
        .acl_w_id(acl_w_id),
        .acl_w_len(acl_w_len),
        .acl_w_err_mode(acl_w_err_mode),
        .w_drain_wvalid(w_drain_wvalid),
        .w_drain_wlast(w_drain_wlast),
        .w_drain_wready(w_drain_wready),
        .w_drain_bvalid(w_drain_bvalid),
        .w_drain_bid(w_drain_bid),
        .w_drain_bresp(w_drain_bresp),
        .w_drain_bready(w_drain_bready),
        .w_framing_fault_valid(w_framing_fault_valid),
        .w_framing_fault_code(w_framing_fault_code)
    );

    always #5 clk = ~clk;

    task check_assert;
        input condition;
        input [8*120-1:0] msg;
        begin
            if (!condition) begin
                $display("[ERROR] Step %0d at %0t ps: %0s", test_step, $time, msg);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        acl_w_fault = 0;
        acl_w_id = 4'd0;
        acl_w_len = 8'd0;
        acl_w_err_mode = 1;
        w_drain_wvalid = 0;
        w_drain_wlast = 0;
        w_drain_bready = 0;

        $display("------------------------------------------------------------");
        $display("   STARTING TESTBENCH: tb_fw_write_drain");
        $display("------------------------------------------------------------");

        // ------------------------------------------------------------
        // TC01: Reset check
        // ------------------------------------------------------------
        test_step = 1;
        #20;
        check_assert(w_drain_wready == 1'b0, "TC01: wready must be 0 on reset");
        check_assert(w_drain_bvalid == 1'b0, "TC01: bvalid must be 0 on reset");
        check_assert(w_drain_bresp == 2'b11, "TC01: bresp reset default DECERR");
        check_assert(w_framing_fault_valid == 1'b0, "TC01: framing fault valid must be 0 on reset");
        check_assert(w_framing_fault_code == 4'b0110, "TC01: framing fault code must be 4'b0110");

        @(negedge clk);
        rst_n = 1;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC02: Single beat write drain (DECERR mode)
        // ------------------------------------------------------------
        test_step = 2;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'h3;
        acl_w_len = 8'd0; // 1 beat
        acl_w_err_mode = 1; // DECERR

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;
        // In W_DRAIN_SINK:
        check_assert(w_drain_wready == 1'b1, "TC02: wready must be 1 in SINK");

        // Send 1 beat with wlast = 1
        w_drain_wvalid = 1;
        w_drain_wlast = 1;
        @(posedge clk); #1;

        @(negedge clk);
        w_drain_wvalid = 0;
        w_drain_wlast = 0;

        // In W_DRAIN_RESP:
        check_assert(w_drain_bvalid == 1'b1, "TC02: bvalid must be 1 in RESP");
        check_assert(w_drain_bid == 4'h3, "TC02: bid mismatch");
        check_assert(w_drain_bresp == 2'b11, "TC02: bresp must be 2'b11 (DECERR)");
        check_assert(w_framing_fault_valid == 1'b0, "TC02: framing fault should be 0");

        // Retire B response
        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;

        @(posedge clk); #1;
        check_assert(w_drain_bvalid == 1'b0, "TC02: bvalid must clear after retirement");

        // ------------------------------------------------------------
        // TC03: 4-beat burst write drain (DECERR mode)
        // ------------------------------------------------------------
        test_step = 3;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'h7;
        acl_w_len = 8'd3; // 4 beats
        acl_w_err_mode = 1;

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;
        check_assert(w_drain_wready == 1'b1, "TC03: wready must be 1");

        // Beat 0
        w_drain_wvalid = 1;
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 1
        @(negedge clk);
        w_drain_wvalid = 1;
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 2
        @(negedge clk);
        w_drain_wvalid = 1;
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 3 (last)
        @(negedge clk);
        w_drain_wvalid = 1;
        w_drain_wlast = 1;
        @(posedge clk); #1;

        @(negedge clk);
        w_drain_wvalid = 0;
        w_drain_wlast = 0;

        check_assert(w_drain_bvalid == 1'b1, "TC03: bvalid must be 1 after 4 beats");
        check_assert(w_drain_bid == 4'h7, "TC03: bid mismatch");
        check_assert(w_drain_bresp == 2'b11, "TC03: bresp DECERR");
        check_assert(w_framing_fault_valid == 1'b0, "TC03: No framing fault");

        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;

        // ------------------------------------------------------------
        // TC04: OKAY error mode (err_mode = 0)
        // ------------------------------------------------------------
        test_step = 4;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'hA;
        acl_w_len = 8'd1; // 2 beats
        acl_w_err_mode = 0; // OKAY mode

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;

        // Beat 0
        w_drain_wvalid = 1;
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 1 (last)
        @(negedge clk);
        w_drain_wvalid = 1;
        w_drain_wlast = 1;
        @(posedge clk); #1;

        @(negedge clk);
        w_drain_wvalid = 0;
        w_drain_wlast = 0;

        check_assert(w_drain_bvalid == 1'b1, "TC04: bvalid must be 1");
        check_assert(w_drain_bresp == 2'b00, "TC04: bresp must be 2'b00 (OKAY)");
        check_assert(w_drain_bid == 4'hA, "TC04: bid mismatch");

        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;

        // ------------------------------------------------------------
        // TC05: Early wlast framing fault
        // ------------------------------------------------------------
        test_step = 5;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'h5;
        acl_w_len = 8'd3; // Expected 4 beats
        acl_w_err_mode = 1;

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;

        // Beat 0: early wlast!
        w_drain_wvalid = 1;
        w_drain_wlast = 1; // ILLEGAL: Early wlast on beat 0 of 4!
        @(posedge clk); #1;

        // Framing fault pulses on the cycle immediately after the handshake
        check_assert(w_framing_fault_valid == 1'b1, "TC05: framing fault must be asserted right after early wlast");
        check_assert(w_framing_fault_code == 4'b0110, "TC05: framing fault code must be 4'b0110");

        // Beat 1
        @(negedge clk);
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 2
        @(negedge clk);
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 3 (actual last)
        @(negedge clk);
        w_drain_wlast = 1;
        @(posedge clk); #1;

        @(negedge clk);
        w_drain_wvalid = 0;
        w_drain_wlast = 0;

        check_assert(w_drain_bvalid == 1'b1, "TC05: bvalid must be 1");

        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;

        // ------------------------------------------------------------
        // TC06: Late / Missing wlast framing fault
        // ------------------------------------------------------------
        test_step = 6;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'h2;
        acl_w_len = 8'd1; // Expected 2 beats
        acl_w_err_mode = 1;

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;

        // Beat 0: normal
        w_drain_wvalid = 1;
        w_drain_wlast = 0;
        @(posedge clk); #1;

        // Beat 1: expected final beat, but wlast is 0 (MISSING WLAST!)
        @(negedge clk);
        w_drain_wvalid = 1;
        w_drain_wlast = 0; // ILLEGAL: Missing wlast on final beat!
        @(posedge clk); #1;

        @(negedge clk);
        w_drain_wvalid = 0;
        w_drain_wlast = 0;

        check_assert(w_drain_bvalid == 1'b1, "TC06: bvalid must be 1");
        check_assert(w_framing_fault_valid == 1'b1, "TC06: framing fault must be asserted due to missing wlast");

        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;

        // ------------------------------------------------------------
        // TC07: Backpressure on B channel (bready stall)
        // ------------------------------------------------------------
        test_step = 7;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'hE;
        acl_w_len = 8'd0; // 1 beat
        acl_w_err_mode = 1;

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;

        w_drain_wvalid = 1;
        w_drain_wlast = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_wvalid = 0;
        w_drain_wlast = 0;

        // Hold bready low beyond the watchdog period. Once BVALID is
        // asserted, the response must remain stable until handshake.
        w_drain_bready = 0;
        repeat (260) begin
            @(posedge clk); #1;
            check_assert(w_drain_bvalid == 1'b1, "TC07: bvalid must remain held while bready is low");
            check_assert(w_drain_bid == 4'hE, "TC07: bid must remain stable during stall");
            check_assert(w_drain_bresp == 2'b11, "TC07: bresp must remain stable during stall");
        end

        // Release stall
        @(negedge clk);
        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;
        @(posedge clk); #1;
        // ------------------------------------------------------------
        // TC08: Hardware Watchdog Drain Timer (Starvation DoS recovery)
        // ------------------------------------------------------------
        test_step = 8;
        @(negedge clk);
        acl_w_fault = 1;
        acl_w_id = 4'hF;
        acl_w_len = 8'd3; // 4 beats expected
        acl_w_err_mode = 0; // Request is in OKAY mode, but timeout MUST force DECERR!

        @(posedge clk); #1;
        @(negedge clk);
        acl_w_fault = 0;
        check_assert(w_drain_wready == 1'b1, "TC08: wready must be 1 in SINK");

        // Send only beat 0 without wlast, then freeze/abandon transfer
        w_drain_wvalid = 1;
        w_drain_wlast = 0;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_wvalid = 0; // Malicious master stops sending beats!

        // Wait for Watchdog timeout (256 cycles) and capture 1-cycle framing fault pulse
        timeout_fault_seen = 0;
        while (!w_drain_bvalid) begin
            @(posedge clk);
            #1;
            if (w_framing_fault_valid) timeout_fault_seen = 1;
        end
        check_assert(w_drain_bvalid == 1'b1, "TC08: Watchdog must force transition to RESP after timeout");
        check_assert(w_drain_bresp == 2'b11, "TC08: Watchdog timeout must force DECERR response");
        check_assert(timeout_fault_seen == 1'b1, "TC08: Watchdog timeout must trigger framing fault event pulse");

        // Retire B response
        @(negedge clk);
        w_drain_bready = 1;
        @(posedge clk); #1;
        @(negedge clk);
        w_drain_bready = 0;
        @(posedge clk); #1;
        check_assert(w_drain_bvalid == 1'b0, "TC08: bvalid clears after timeout response retired");

        // ------------------------------------------------------------
        // Final Summary
        // ------------------------------------------------------------
        #50;
        $display("------------------------------------------------------------");
        if (errors == 0) begin
            $display("PASS: tb_fw_write_drain (All %0d test steps passed without error)", test_step);
        end else begin
            $display("FAIL: tb_fw_write_drain (%0d errors detected)", errors);
        end
        $display("------------------------------------------------------------");
        $finish;
    end
endmodule
