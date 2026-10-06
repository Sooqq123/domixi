module fw_drain_contract_formal (
    input wire        clk,
    input wire        rst_n,
    input wire        acl_w_fault,
    input wire [3:0]  acl_w_id,
    input wire [7:0]  acl_w_len,
    input wire        acl_w_err_mode,
    input wire        w_drain_wvalid,
    input wire        w_drain_wlast,
    input wire        w_drain_bready,
    input wire        acl_r_fault,
    input wire [3:0]  acl_r_id,
    input wire [7:0]  acl_r_len,
    input wire        acl_r_err_mode,
    input wire        r_drain_rready
);

    wire        w_drain_wready;
    wire        w_drain_bvalid;
    wire [3:0]  w_drain_bid;
    wire [1:0]  w_drain_bresp;
    wire        w_framing_fault_valid;
    wire [3:0]  w_framing_fault_code;
    wire        r_drain_rvalid;
    wire [3:0]  r_drain_rid;
    wire [31:0] r_drain_rdata;
    wire [1:0]  r_drain_rresp;
    wire        r_drain_rlast;

    fw_drain_fsm u_dut (
        .clk                  (clk),
        .rst_n                (rst_n),
        .acl_w_fault          (acl_w_fault),
        .acl_w_id             (acl_w_id),
        .acl_w_len            (acl_w_len),
        .acl_w_err_mode       (acl_w_err_mode),
        .w_drain_wvalid       (w_drain_wvalid),
        .w_drain_wlast        (w_drain_wlast),
        .w_drain_wready       (w_drain_wready),
        .w_drain_bvalid       (w_drain_bvalid),
        .w_drain_bid          (w_drain_bid),
        .w_drain_bresp        (w_drain_bresp),
        .w_drain_bready       (w_drain_bready),
        .w_framing_fault_valid(w_framing_fault_valid),
        .w_framing_fault_code (w_framing_fault_code),
        .acl_r_fault          (acl_r_fault),
        .acl_r_id             (acl_r_id),
        .acl_r_len            (acl_r_len),
        .acl_r_err_mode       (acl_r_err_mode),
        .r_drain_rvalid       (r_drain_rvalid),
        .r_drain_rready       (r_drain_rready),
        .r_drain_rid          (r_drain_rid),
        .r_drain_rdata        (r_drain_rdata),
        .r_drain_rresp        (r_drain_rresp),
        .r_drain_rlast        (r_drain_rlast)
    );

    reg [2:0] reset_counter = 3'd0;
    always @(posedge clk) begin
        if (reset_counter < 3'd3)
            reset_counter <= reset_counter + 1'b1;
    end
    always @(*) begin
        if (reset_counter < 3'd2)
            assume(!rst_n);
        else
            assume(rst_n);
    end

    reg        w_active_q;
    reg [7:0]  w_len_q;
    reg [7:0]  w_count_q;
    reg        w_expect_b_q;
    reg        wlast_expect_q;
    always @(*) begin
        if (w_active_q || w_expect_b_q)
            assume(!acl_w_fault);
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            w_active_q <= 1'b0;
            w_len_q <= 8'd0;
            w_count_q <= 8'd0;
            w_expect_b_q <= 1'b0;
            wlast_expect_q <= 1'b0;
        end else begin
            if (w_expect_b_q)
                assert(w_drain_bvalid);
            if (wlast_expect_q) begin
                assert(w_framing_fault_valid);
                wlast_expect_q <= 1'b0;
            end
            if (!w_active_q && !w_expect_b_q && acl_w_fault) begin
                w_active_q <= 1'b1;
                w_len_q <= acl_w_len;
                w_count_q <= 8'd0;
            end
            if (w_active_q && w_drain_wvalid && w_drain_wready) begin
                if (w_count_q == w_len_q) begin
                    w_active_q <= 1'b0;
                    w_expect_b_q <= 1'b1;
                    wlast_expect_q <= !w_drain_wlast;
                end else begin
                    w_count_q <= w_count_q + 1'b1;
                end
            end
            if (w_drain_bvalid && w_drain_bready)
                w_expect_b_q <= 1'b0;
        end
    end

    reg        b_hold_q;
    reg [5:0]  b_bundle_q;
    wire [5:0] b_bundle = {w_drain_bvalid, w_drain_bid, w_drain_bresp};
    always @(posedge clk) begin
        if (!rst_n) begin
            b_hold_q <= 1'b0;
            b_bundle_q <= 6'd0;
        end else begin
            if (b_hold_q)
                assert(b_bundle == b_bundle_q);
            b_hold_q <= w_drain_bvalid && !w_drain_bready;
            if (w_drain_bvalid && !w_drain_bready)
                b_bundle_q <= b_bundle;
        end
    end

    reg        r_active_q;
    reg [7:0]  r_len_q;
    reg [7:0]  r_count_q;
    reg        r_hold_q;
    reg [39:0] r_bundle_q;
    wire [39:0] r_bundle = {r_drain_rvalid, r_drain_rid, r_drain_rdata, r_drain_rresp, r_drain_rlast};
    always @(*) begin
        if (r_active_q)
            assume(!acl_r_fault);
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            r_active_q <= 1'b0;
            r_len_q <= 8'd0;
            r_count_q <= 8'd0;
            r_hold_q <= 1'b0;
            r_bundle_q <= 40'd0;
        end else begin
            if (r_hold_q)
                assert(r_bundle == r_bundle_q);
            if (!r_active_q && acl_r_fault) begin
                r_active_q <= 1'b1;
                r_len_q <= acl_r_len;
                r_count_q <= 8'd0;
            end
            if (r_active_q && r_drain_rvalid && r_drain_rready) begin
                assert(r_drain_rlast == (r_count_q == r_len_q));
                if (r_count_q == r_len_q)
                    r_active_q <= 1'b0;
                else
                    r_count_q <= r_count_q + 1'b1;
            end
            r_hold_q <= r_drain_rvalid && !r_drain_rready;
            if (r_drain_rvalid && !r_drain_rready)
                r_bundle_q <= r_bundle;
        end
    end

    always @(*) begin
        assert(r_drain_rdata == 32'h0000_0000);
    end

endmodule
