`timescale 1ns/1ps

module tb_fw_drain_fsm;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    reg acl_w_fault;
    reg [3:0] acl_w_id;
    reg [7:0] acl_w_len;
    reg acl_w_err_mode;
    reg w_drain_wvalid;
    reg w_drain_wlast;
    wire w_drain_wready;
    wire w_drain_bvalid;
    wire [3:0] w_drain_bid;
    wire [1:0] w_drain_bresp;
    reg w_drain_bready;
    wire w_framing_fault_valid;
    wire [3:0] w_framing_fault_code;

    reg acl_r_fault;
    reg [3:0] acl_r_id;
    reg [7:0] acl_r_len;
    reg acl_r_err_mode;
    wire r_drain_rvalid;
    reg r_drain_rready;
    wire [3:0] r_drain_rid;
    wire [31:0] r_drain_rdata;
    wire [1:0] r_drain_rresp;
    wire r_drain_rlast;

    integer failures = 0;
    integer read_beats = 0;
    integer write_beats = 0;
    integer framing_events = 0;

    fw_drain_fsm dut (
        .clk(clk), .rst_n(rst_n),
        .acl_w_fault(acl_w_fault), .acl_w_id(acl_w_id),
        .acl_w_len(acl_w_len), .acl_w_err_mode(acl_w_err_mode),
        .w_drain_wvalid(w_drain_wvalid), .w_drain_wlast(w_drain_wlast),
        .w_drain_wready(w_drain_wready), .w_drain_bvalid(w_drain_bvalid),
        .w_drain_bid(w_drain_bid), .w_drain_bresp(w_drain_bresp),
        .w_drain_bready(w_drain_bready),
        .w_framing_fault_valid(w_framing_fault_valid),
        .w_framing_fault_code(w_framing_fault_code),
        .acl_r_fault(acl_r_fault), .acl_r_id(acl_r_id),
        .acl_r_len(acl_r_len), .acl_r_err_mode(acl_r_err_mode),
        .r_drain_rvalid(r_drain_rvalid), .r_drain_rready(r_drain_rready),
        .r_drain_rid(r_drain_rid), .r_drain_rdata(r_drain_rdata),
        .r_drain_rresp(r_drain_rresp), .r_drain_rlast(r_drain_rlast)
    );

    task check;
        input condition;
        input [8*96-1:0] message;
        begin
            if (!condition) begin
                failures = failures + 1;
                $display("[FAIL] %0s", message);
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            if (w_drain_wvalid && w_drain_wready)
                write_beats = write_beats + 1;
            if (r_drain_rvalid && r_drain_rready)
                read_beats = read_beats + 1;
            if (w_framing_fault_valid)
                framing_events = framing_events + 1;
        end
    end

    initial begin
        acl_w_fault = 1'b0;
        acl_w_id = 4'd0;
        acl_w_len = 8'd0;
        acl_w_err_mode = 1'b1;
        w_drain_wvalid = 1'b0;
        w_drain_wlast = 1'b0;
        w_drain_bready = 1'b0;
        acl_r_fault = 1'b0;
        acl_r_id = 4'd0;
        acl_r_len = 8'd0;
        acl_r_err_mode = 1'b1;
        r_drain_rready = 1'b0;

        repeat (3) @(posedge clk);
        #1;
        check(!w_drain_wready && !w_drain_bvalid && !r_drain_rvalid,
              "reset keeps both directions idle");
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        @(negedge clk);
        acl_w_fault = 1'b1;
        acl_w_id = 4'h5;
        acl_w_len = 8'd1;
        acl_w_err_mode = 1'b1;
        acl_r_fault = 1'b1;
        acl_r_id = 4'hA;
        acl_r_len = 8'd2;
        acl_r_err_mode = 1'b0;
        @(posedge clk);
        #1;
        check(w_drain_wready && r_drain_rvalid,
              "simultaneous requests activate independent directions");
        check(r_drain_rid == 4'hA && r_drain_rresp == 2'b00 && r_drain_rdata == 32'd0,
              "read snapshot and honeypot response propagate through wrapper");
        @(negedge clk);
        acl_w_fault = 1'b0;
        acl_r_fault = 1'b0;
        w_drain_wvalid = 1'b1;
        w_drain_wlast = 1'b1;
        r_drain_rready = 1'b1;
        @(posedge clk);
        #1;
        check(w_framing_fault_valid && w_framing_fault_code == 4'b0110,
              "early WLAST framing event propagates");

        w_drain_wlast = 1'b1;
        @(posedge clk);
        #1;
        check(w_drain_bvalid && w_drain_bid == 4'h5 && w_drain_bresp == 2'b11,
              "write response snapshot propagates after exact beats");
        check(r_drain_rvalid && r_drain_rlast,
              "read direction reaches its final beat while write response is stalled");
        check(w_drain_bvalid && w_drain_bid == 4'h5 && w_drain_bresp == 2'b11,
              "write response remains stable under BREADY stall");

        @(negedge clk);
        w_drain_wvalid = 1'b0;
        @(posedge clk);
        #1;
        check(!r_drain_rvalid, "read owner clears only after final handshake");
        @(negedge clk);
        r_drain_rready = 1'b0;
        w_drain_bready = 1'b1;
        @(posedge clk);
        #1;
        check(!w_drain_bvalid, "write owner clears on B handshake");
        @(negedge clk);
        w_drain_bready = 1'b0;
        check(write_beats == 2, "write mock consumed AWLEN plus one handshakes");
        check(read_beats == 3, "read mock generated ARLEN plus one handshakes");
        check(framing_events == 1, "one early-WLAST event observed");

        if (failures == 0) begin
            $display("PASS: tb_fw_drain_fsm");
            $finish;
        end
        $fatal(1, "FAIL: tb_fw_drain_fsm failures=%0d", failures);
    end

    initial begin
        repeat (200) @(posedge clk);
        $fatal(1, "TIMEOUT: tb_fw_drain_fsm");
    end
endmodule
