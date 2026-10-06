`timescale 1ns/1ps

// Canonical package-03 leaf. The top owns upstream backpressure and issues
// acl_w_fault only for an idle write owner; there is no request queue here.
module fw_write_drain #(
    parameter TIMEOUT_CYCLES = 256
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       acl_w_fault,
    input  wire [3:0] acl_w_id,
    input  wire [7:0] acl_w_len,
    input  wire       acl_w_err_mode,
    input  wire       w_drain_wvalid,
    input  wire       w_drain_wlast,
    output reg        w_drain_wready,
    output reg        w_drain_bvalid,
    output reg  [3:0] w_drain_bid,
    output reg  [1:0] w_drain_bresp,
    input  wire       w_drain_bready,
    output reg        w_framing_fault_valid,
    output reg  [3:0] w_framing_fault_code
);
    localparam [1:0] W_DRAIN_IDLE = 2'b00;
    localparam [1:0] W_DRAIN_SINK = 2'b01;
    localparam [1:0] W_DRAIN_RESP = 2'b10;

    // register_map.csv FAULT_STATUS bits [1]/[2]; signal_list.csv requires
    // w_framing_fault_code = 4'b0110. No shared RTL package exists in baseline.
    localparam [3:0] WRITE_ERR = 4'b0010;
    localparam [3:0] PROT_ERR  = 4'b0100;
    localparam [1:0] AXI_OKAY   = 2'b00;
    localparam [1:0] AXI_DECERR = 2'b11;

    reg [1:0] state, state_next;
    reg [3:0] id_q, id_next;
    reg [7:0] len_q, len_next;
    reg       mode_q, mode_next;
    reg [7:0] count_q, count_next;
    reg       framing_fault_q, framing_fault_next;
    reg [9:0] timer_q, timer_next;
    reg       timeout_latched_q, timeout_latched_next;

    wire w_handshake = w_drain_wvalid && w_drain_wready;
    wire b_handshake = w_drain_bvalid && w_drain_bready;
    // Zero-based index of the next W beat, not a wall-clock counter.
    wire expected_final = (count_q == len_q);
    wire timeout_tripped = (timer_q >= (TIMEOUT_CYCLES - 1));

    always @(*) begin
        // Reset defaults are canonical payload values, not all-zero payloads.
        w_drain_wready = 1'b0;
        w_drain_bvalid = 1'b0;
        w_drain_bid = 4'd0;
        w_drain_bresp = AXI_DECERR;
        w_framing_fault_valid = 1'b0;
        w_framing_fault_code = WRITE_ERR | PROT_ERR;
        if (rst_n) begin
            case (state)
                W_DRAIN_IDLE, W_DRAIN_SINK, W_DRAIN_RESP: begin
                    w_drain_wready = (state == W_DRAIN_SINK);
                    w_drain_bvalid = (state == W_DRAIN_RESP);
                    w_drain_bid = id_q;
                    w_drain_bresp = (mode_q || timeout_latched_q) ? AXI_DECERR : AXI_OKAY;
                    w_framing_fault_valid = framing_fault_q;
                end
                default: begin
                    // Illegal-state controls and payload are inactive now;
                    // sequential recovery clears the active context next edge.
                    w_drain_bresp = 2'd0;
                    w_framing_fault_code = 4'd0;
                end
            endcase
        end
    end

    always @(*) begin
        state_next = state;
        id_next = id_q;
        len_next = len_q;
        mode_next = mode_q;
        count_next = count_q;
        framing_fault_next = 1'b0;
        timer_next = timer_q;
        timeout_latched_next = timeout_latched_q;

        case (state)
            W_DRAIN_IDLE: begin
                timer_next = 10'd0;
                timeout_latched_next = 1'b0;
                if (acl_w_fault) begin
                    id_next = acl_w_id;
                    len_next = acl_w_len;
                    mode_next = acl_w_err_mode;
                    count_next = 8'd0;
                    state_next = W_DRAIN_SINK;
                end
            end
            W_DRAIN_SINK: begin
                if (w_handshake) begin
                    timer_next = 10'd0;
                    framing_fault_next = (w_drain_wlast != expected_final);
                    if (expected_final)
                        state_next = W_DRAIN_RESP;
                    else
                        count_next = count_q + 1'b1;
                end else if (timeout_tripped) begin
                    framing_fault_next   = 1'b1;
                    timeout_latched_next = 1'b1;
                    state_next           = W_DRAIN_RESP;
                    timer_next           = 10'd0;
                end else begin
                    timer_next = timer_q + 1'b1;
                end
            end
            W_DRAIN_RESP: begin
                if (b_handshake) begin
                    state_next = W_DRAIN_IDLE;
                    timer_next = 10'd0;
                end else begin
                    // Once BVALID is asserted, AXI requires the response
                    // payload to remain valid until BREADY arrives.  Do not
                    // silently drop it on response-channel backpressure:
                    // the top-level owner is released only by the
                    // BVALID && BREADY handshake.
                    timer_next = timer_q + 1'b1;
                end
            end
            default: begin
                state_next = W_DRAIN_IDLE;
                id_next = 4'd0;
                len_next = 8'd0;
                mode_next = 1'b1;
                count_next = 8'd0;
                framing_fault_next = 1'b0;
                timer_next = 10'd0;
                timeout_latched_next = 1'b0;
            end
        endcase
    end

    // rst_n is supplied by the system reset controller with synchronous
    // deassertion (integration contract 4.1 / pinout.csv). No local synchronizer.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= W_DRAIN_IDLE;
            id_q <= 4'd0;
            len_q <= 8'd0;
            mode_q <= 1'b1;
            count_q <= 8'd0;
            framing_fault_q <= 1'b0;
            timer_q <= 10'd0;
            timeout_latched_q <= 1'b0;
        end else begin
            state <= state_next;
            id_q <= id_next;
            len_q <= len_next;
            mode_q <= mode_next;
            count_q <= count_next;
            framing_fault_q <= framing_fault_next;
            timer_q <= timer_next;
            timeout_latched_q <= timeout_latched_next;
        end
    end
endmodule
