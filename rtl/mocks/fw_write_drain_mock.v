`timescale 1ns/1ps

// SIMULATION-ONLY MOCK. This module is excluded from production source lists.
// It models the canonical package-03 port contract for wrapper verification.
module fw_write_drain (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       acl_w_fault,
    input  wire [3:0] acl_w_id,
    input  wire [7:0] acl_w_len,
    input  wire       acl_w_err_mode,
    input  wire       w_drain_wvalid,
    input  wire       w_drain_wlast,
    output wire       w_drain_wready,
    output wire       w_drain_bvalid,
    output wire [3:0] w_drain_bid,
    output wire [1:0] w_drain_bresp,
    input  wire       w_drain_bready,
    output reg        w_framing_fault_valid,
    output wire [3:0] w_framing_fault_code
);
    localparam [1:0] W_IDLE = 2'b00;
    localparam [1:0] W_SINK = 2'b01;
    localparam [1:0] W_RESP = 2'b10;

    reg [1:0] state;
    reg [3:0] id_q;
    reg [7:0] len_q;
    reg       mode_q;
    reg [7:0] count_q;

    wire expected_final = (count_q == len_q);
    wire w_handshake = w_drain_wvalid && w_drain_wready;

    assign w_drain_wready = (state == W_SINK);
    assign w_drain_bvalid = (state == W_RESP);
    assign w_drain_bid = id_q;
    assign w_drain_bresp = mode_q ? 2'b11 : 2'b00;
    assign w_framing_fault_code = 4'b0110;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= W_IDLE;
            id_q <= 4'd0;
            len_q <= 8'd0;
            mode_q <= 1'b1;
            count_q <= 8'd0;
            w_framing_fault_valid <= 1'b0;
        end else begin
            w_framing_fault_valid <= 1'b0;
            case (state)
                W_IDLE: begin
                    count_q <= 8'd0;
                    if (acl_w_fault) begin
                        id_q <= acl_w_id;
                        len_q <= acl_w_len;
                        mode_q <= acl_w_err_mode;
                        state <= W_SINK;
                    end
                end
                W_SINK: begin
                    if (w_handshake) begin
                        if (w_drain_wlast != expected_final)
                            w_framing_fault_valid <= 1'b1;
                        if (expected_final)
                            state <= W_RESP;
                        else
                            count_q <= count_q + 1'b1;
                    end
                end
                W_RESP: begin
                    if (w_drain_bready)
                        state <= W_IDLE;
                end
                default: state <= W_IDLE;
            endcase
        end
    end
endmodule
