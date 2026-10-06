`timescale 1ns/1ps

module fw_stream_contract_formal (
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
    input wire        hp_rready,

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

    fw_honeypot_sink u_honeypot (
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

    wire        drain_wready;
    wire        drain_bvalid;
    wire [3:0]  drain_bid;
    wire [1:0]  drain_bresp;
    wire        drain_framing_fault;
    wire [3:0]  drain_framing_code;
    wire        drain_rvalid;
    wire [3:0]  drain_rid;
    wire [31:0] drain_rdata;
    wire [1:0]  drain_rresp;
    wire        drain_rlast;

    fw_drain_fsm u_drain (
        .clk                  (clk),
        .rst_n                (rst_n),
        .acl_w_fault          (acl_w_fault),
        .acl_w_id             (acl_w_id),
        .acl_w_len            (acl_w_len),
        .acl_w_err_mode       (acl_w_err_mode),
        .w_drain_wvalid       (w_drain_wvalid),
        .w_drain_wlast        (w_drain_wlast),
        .w_drain_wready       (drain_wready),
        .w_drain_bvalid       (drain_bvalid),
        .w_drain_bid          (drain_bid),
        .w_drain_bresp        (drain_bresp),
        .w_drain_bready       (w_drain_bready),
        .w_framing_fault_valid(drain_framing_fault),
        .w_framing_fault_code (drain_framing_code),
        .acl_r_fault          (acl_r_fault),
        .acl_r_id             (acl_r_id),
        .acl_r_len            (acl_r_len),
        .acl_r_err_mode       (acl_r_err_mode),
        .r_drain_rvalid       (drain_rvalid),
        .r_drain_rready       (r_drain_rready),
        .r_drain_rid          (drain_rid),
        .r_drain_rdata        (drain_rdata),
        .r_drain_rresp        (drain_rresp),
        .r_drain_rlast        (drain_rlast)
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

    // Honey-Pot write: exactly AWLEN+1 accepted beats before BVALID.
    reg        hp_w_active_q;
    reg [7:0]  hp_w_len_q;
    reg [7:0]  hp_w_count_q;
    reg        hp_w_expect_b_q;
    reg        hp_wlast_expect_q;
    always @(posedge clk) begin
        if (!rst_n) begin
            hp_w_active_q  <= 1'b0;
            hp_w_len_q     <= 8'd0;
            hp_w_count_q   <= 8'd0;
            hp_w_expect_b_q <= 1'b0;
            hp_wlast_expect_q <= 1'b0;
        end else begin
            if (hp_w_expect_b_q)
                assert(hp_bvalid);
            if (hp_wlast_expect_q) begin
                assert(hp_wlast_err);
                hp_wlast_expect_q <= 1'b0;
            end
            if (!hp_w_active_q && hp_awvalid && hp_awready) begin
                hp_w_active_q <= 1'b1;
                hp_w_len_q    <= hp_awlen;
                hp_w_count_q  <= 8'd0;
            end
            if (hp_w_active_q && hp_wvalid && hp_wready) begin
                if (hp_w_count_q == hp_w_len_q) begin
                    hp_w_active_q   <= 1'b0;
                    hp_w_expect_b_q <= 1'b1;
                    hp_wlast_expect_q <= !hp_wlast;
                end else begin
                    hp_w_count_q <= hp_w_count_q + 1'b1;
                end
            end
            if (hp_bvalid && hp_bready)
                hp_w_expect_b_q <= 1'b0;
        end
    end

    // Honey-Pot read: exactly ARLEN+1 accepted beats, stable under backpressure.
    reg        hp_r_active_q;
    reg [7:0]  hp_r_len_q;
    reg [7:0]  hp_r_count_q;
    reg        hp_r_hold_q;
    reg [39:0] hp_r_bundle_q;
    wire [39:0] hp_r_bundle = {hp_rvalid, hp_rid, hp_rdata, hp_rresp, hp_rlast};
    always @(posedge clk) begin
        if (!rst_n) begin
            hp_r_active_q <= 1'b0;
            hp_r_len_q    <= 8'd0;
            hp_r_count_q  <= 8'd0;
            hp_r_hold_q   <= 1'b0;
            hp_r_bundle_q <= 40'd0;
        end else begin
            if (hp_r_hold_q)
                assert(hp_r_bundle == hp_r_bundle_q);
            if (!hp_r_active_q && hp_arvalid && hp_arready) begin
                hp_r_active_q <= 1'b1;
                hp_r_len_q    <= hp_arlen;
                hp_r_count_q  <= 8'd0;
            end
            if (hp_r_active_q && hp_rvalid && hp_rready) begin
                assert(hp_rlast == (hp_r_count_q == hp_r_len_q));
                if (hp_r_count_q == hp_r_len_q)
                    hp_r_active_q <= 1'b0;
                else
                    hp_r_count_q <= hp_r_count_q + 1'b1;
            end
            hp_r_hold_q <= hp_rvalid && !hp_rready;
            if (hp_rvalid && !hp_rready)
                hp_r_bundle_q <= hp_r_bundle;
        end
    end

    // Honey-Pot write response must hold ID and response until handshake.
    reg        hp_b_hold_q;
    reg [5:0]  hp_b_bundle_q;
    wire [5:0] hp_b_bundle = {hp_bvalid, hp_bid, hp_bresp};
    always @(posedge clk) begin
        if (!rst_n) begin
            hp_b_hold_q   <= 1'b0;
            hp_b_bundle_q <= 6'd0;
        end else begin
            if (hp_b_hold_q)
                assert(hp_b_bundle == hp_b_bundle_q);
            hp_b_hold_q <= hp_bvalid && !hp_bready;
            if (hp_bvalid && !hp_bready)
                hp_b_bundle_q <= hp_b_bundle;
        end
    end

    // Drain write/read channels share no memory-master path and hold responses.
    reg        d_w_active_q;
    reg [7:0]  d_w_len_q;
    reg [7:0]  d_w_count_q;
    reg        d_w_expect_b_q;
    reg        d_wlast_expect_q;
    always @(*) begin
        if (d_w_active_q || d_w_expect_b_q)
            assume(!acl_w_fault);
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            d_w_active_q   <= 1'b0;
            d_w_len_q      <= 8'd0;
            d_w_count_q    <= 8'd0;
            d_w_expect_b_q <= 1'b0;
            d_wlast_expect_q <= 1'b0;
        end else begin
            if (d_w_expect_b_q)
                assert(drain_bvalid);
            if (d_wlast_expect_q) begin
                assert(drain_framing_fault);
                d_wlast_expect_q <= 1'b0;
            end
            if (!d_w_active_q && !d_w_expect_b_q && acl_w_fault) begin
                d_w_active_q <= 1'b1;
                d_w_len_q    <= acl_w_len;
                d_w_count_q  <= 8'd0;
            end
            if (d_w_active_q && w_drain_wvalid && drain_wready) begin
                if (d_w_count_q == d_w_len_q) begin
                    d_w_active_q   <= 1'b0;
                    d_w_expect_b_q <= 1'b1;
                    d_wlast_expect_q <= !w_drain_wlast;
                end else begin
                    d_w_count_q <= d_w_count_q + 1'b1;
                end
            end
            if (drain_bvalid && w_drain_bready)
                d_w_expect_b_q <= 1'b0;
        end
    end

    reg        d_b_hold_q;
    reg [5:0]  d_b_bundle_q;
    wire [5:0] d_b_bundle = {drain_bvalid, drain_bid, drain_bresp};
    always @(posedge clk) begin
        if (!rst_n) begin
            d_b_hold_q   <= 1'b0;
            d_b_bundle_q <= 6'd0;
        end else begin
            if (d_b_hold_q)
                assert(d_b_bundle == d_b_bundle_q);
            d_b_hold_q <= drain_bvalid && !w_drain_bready;
            if (drain_bvalid && !w_drain_bready)
                d_b_bundle_q <= d_b_bundle;
        end
    end

    reg        d_r_active_q;
    reg [7:0]  d_r_len_q;
    reg [7:0]  d_r_count_q;
    reg        d_r_hold_q;
    reg [39:0] d_r_bundle_q;
    wire [39:0] d_r_bundle = {drain_rvalid, drain_rid, drain_rdata, drain_rresp, drain_rlast};
    always @(*) begin
        if (d_r_active_q)
            assume(!acl_r_fault);
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            d_r_active_q <= 1'b0;
            d_r_len_q    <= 8'd0;
            d_r_count_q  <= 8'd0;
            d_r_hold_q   <= 1'b0;
            d_r_bundle_q <= 40'd0;
        end else begin
            if (d_r_hold_q)
                assert(d_r_bundle == d_r_bundle_q);
            if (!d_r_active_q && acl_r_fault) begin
                d_r_active_q <= 1'b1;
                d_r_len_q    <= acl_r_len;
                d_r_count_q  <= 8'd0;
            end
            if (d_r_active_q && drain_rvalid && r_drain_rready) begin
                assert(drain_rlast == (d_r_count_q == d_r_len_q));
                if (d_r_count_q == d_r_len_q)
                    d_r_active_q <= 1'b0;
                else
                    d_r_count_q <= d_r_count_q + 1'b1;
            end
            d_r_hold_q <= drain_rvalid && !r_drain_rready;
            if (drain_rvalid && !r_drain_rready)
                d_r_bundle_q <= d_r_bundle;
        end
    end

    // Structural safety invariants: the sink/drain interfaces have no memory
    // master ports, and their responses are always non-forwarding payloads.
    always @(*) begin
        assert(hp_bresp == 2'b00);
        assert(hp_rresp == 2'b00);
        assert(drain_rdata == 32'h0);
    end

endmodule
