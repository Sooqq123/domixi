`timescale 1ns/1ps

// SIMULATION-ONLY MOCK. This module is excluded from production source lists.
// It models the canonical package-04 port contract for wrapper verification.
module fw_read_drain (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        acl_r_fault,
    input  wire [3:0]  acl_r_id,
    input  wire [7:0]  acl_r_len,
    input  wire        acl_r_err_mode,
    output wire        r_drain_rvalid,
    input  wire        r_drain_rready,
    output wire [3:0]  r_drain_rid,
    output wire [31:0] r_drain_rdata,
    output wire [1:0]  r_drain_rresp,
    output wire        r_drain_rlast
);
    reg       active_q;
    reg [3:0] id_q;
    reg [7:0] len_q;
    reg       mode_q;
    reg [7:0] count_q;

    wire r_handshake = r_drain_rvalid && r_drain_rready;

    assign r_drain_rvalid = active_q;
    assign r_drain_rid = id_q;
    assign r_drain_rdata = 32'd0;
    assign r_drain_rresp = mode_q ? 2'b11 : 2'b00;
    assign r_drain_rlast = active_q && (count_q == len_q);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_q <= 1'b0;
            id_q <= 4'd0;
            len_q <= 8'd0;
            mode_q <= 1'b1;
            count_q <= 8'd0;
        end else if (!active_q) begin
            count_q <= 8'd0;
            if (acl_r_fault) begin
                active_q <= 1'b1;
                id_q <= acl_r_id;
                len_q <= acl_r_len;
                mode_q <= acl_r_err_mode;
            end
        end else if (r_handshake) begin
            if (count_q == len_q)
                active_q <= 1'b0;
            else
                count_q <= count_q + 1'b1;
        end
    end
endmodule
