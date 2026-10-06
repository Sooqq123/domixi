module fw_honeypot_contract_formal (
    input wire        clk,
    input wire        rst_n,
    input wire        hp_awvalid,
    input wire [3:0]  hp_awid,
    input wire [31:0] hp_awaddr,
    input wire [7:0]  hp_awlen,
    input wire [2:0]  hp_awsize,
    input wire [1:0]  hp_awburst,
    input wire        hp_wvalid,
    input wire [31:0] hp_wdata,
    input wire [3:0]  hp_wstrb,
    input wire        hp_wlast,
    input wire        hp_bready,
    input wire        hp_arvalid,
    input wire [3:0]  hp_arid,
    input wire [31:0] hp_araddr,
    input wire [7:0]  hp_arlen,
    input wire [2:0]  hp_arsize,
    input wire [1:0]  hp_arburst,
    input wire        hp_rready
);

    wire        hp_awready;
    wire        hp_wready;
    wire        hp_bvalid;
    wire [3:0]  hp_bid;
    wire [1:0]  hp_bresp;
    wire        hp_arready;
    wire        hp_rvalid;
    wire [3:0]  hp_rid;
    wire [31:0] hp_rdata;
    wire [1:0]  hp_rresp;
    wire        hp_rlast;
    wire [15:0] hp_scrambler_state;
    wire [31:0] hp_honey_count;
    wire        hp_sink_busy;
    wire        hp_wlast_err;

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
        .scrambler_state_out(hp_scrambler_state),
        .honey_trans_count  (hp_honey_count),
        .sink_busy          (hp_sink_busy),
        .wlast_err          (hp_wlast_err)
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

    // The AXI source is required to hold the payload while a response stalls.
    reg        b_hold_q;
    reg [5:0]  b_bundle_q;
    wire [5:0] b_bundle = {hp_bvalid, hp_bid, hp_bresp};
    always @(posedge clk) begin
        if (!rst_n) begin
            b_hold_q <= 1'b0;
            b_bundle_q <= 6'd0;
        end else begin
            if (b_hold_q)
                assert(b_bundle == b_bundle_q);
            b_hold_q <= hp_bvalid && !hp_bready;
            if (hp_bvalid && !hp_bready)
                b_bundle_q <= b_bundle;
        end
    end

    reg        r_hold_q;
    reg [39:0] r_bundle_q;
    wire [39:0] r_bundle = {hp_rvalid, hp_rid, hp_rdata, hp_rresp, hp_rlast};
    always @(posedge clk) begin
        if (!rst_n) begin
            r_hold_q <= 1'b0;
            r_bundle_q <= 40'd0;
        end else begin
            if (r_hold_q)
                assert(r_bundle == r_bundle_q);
            r_hold_q <= hp_rvalid && !hp_rready;
            if (hp_rvalid && !hp_rready)
                r_bundle_q <= r_bundle;
        end
    end

    always @(*) begin
        assert(hp_bresp == 2'b00);
        assert(hp_rresp == 2'b00);
        assert(hp_scrambler_state != 16'h0000);
        if (hp_bvalid)
            assert(!hp_wready);
        if (hp_rvalid)
            assert(!hp_arready);
    end

endmodule
