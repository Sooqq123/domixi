`timescale 1ns/1ps

// Canonical structural wrapper. Transaction state remains in the two leaf
// modules owned by student packages 03 and 04.
module fw_drain_fsm (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        acl_w_fault,
    input  wire [3:0]  acl_w_id,
    input  wire [7:0]  acl_w_len,
    input  wire        acl_w_err_mode,
    input  wire        w_drain_wvalid,
    input  wire        w_drain_wlast,
    output wire        w_drain_wready,
    output wire        w_drain_bvalid,
    output wire [3:0]  w_drain_bid,
    output wire [1:0]  w_drain_bresp,
    input  wire        w_drain_bready,
    output wire        w_framing_fault_valid,
    output wire [3:0]  w_framing_fault_code,

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

    fw_write_drain u_write_drain (
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

    fw_read_drain u_read_drain (
        .clk(clk),
        .rst_n(rst_n),
        .acl_r_fault(acl_r_fault),
        .acl_r_id(acl_r_id),
        .acl_r_len(acl_r_len),
        .acl_r_err_mode(acl_r_err_mode),
        .r_drain_rvalid(r_drain_rvalid),
        .r_drain_rready(r_drain_rready),
        .r_drain_rid(r_drain_rid),
        .r_drain_rdata(r_drain_rdata),
        .r_drain_rresp(r_drain_rresp),
        .r_drain_rlast(r_drain_rlast)
    );

endmodule
