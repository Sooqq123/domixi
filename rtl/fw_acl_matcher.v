`timescale 1ns/1ps

module fw_acl_matcher #(
    parameter REGION_COUNT = 8,
    parameter ID_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,

    // Request payload & handshake
    input wire req_valid,
    output wire req_ready,
    input wire req_is_write,
    input wire [31:0] req_start,
    input wire [7:0] req_len,
    input wire [2:0] req_size,
    input wire [ID_WIDTH-1:0] req_id,
    input wire [2:0] req_prot,
    
    // Stage 1 error flags
    input wire req_profile_err,
    input wire req_overflow_err,
    input wire req_4kb_err,

    // Policy & Context
    input wire fw_en,
    input wire err_mode,
    input wire [(REGION_COUNT*32)-1:0]       rgn_base,
    input wire [(REGION_COUNT*32)-1:0]       rgn_limit,
    input wire [REGION_COUNT-1:0]            rgn_active,
    input wire [REGION_COUNT-1:0]            rgn_read,
    input wire [REGION_COUNT-1:0]            rgn_write,
    input wire [REGION_COUNT-1:0]            rgn_secure,
    input wire [REGION_COUNT-1:0]            rgn_priv,
    input wire [(REGION_COUNT*ID_WIDTH)-1:0] rgn_mid,
    input wire [(REGION_COUNT*ID_WIDTH)-1:0] rgn_mask,

    // Decision output (Multi-bit Safe Encoding: SAFE_ALLOW=4'b1010, SAFE_DENY=4'b0101)
    output reg decision_valid,
    input wire decision_ready,
    output reg [3:0] decision_allow,
    output reg [3:0] decision_fault_code,
    output reg [ID_WIDTH-1:0] decision_id,
    output reg [7:0] decision_len,
    output reg decision_err_mode
);

    // Multi-bit Hamming encoding against fault injection (CWE-1338)
    localparam [3:0] SAFE_ALLOW = 4'b1010;
    localparam [3:0] SAFE_DENY  = 4'b0101;

    // ---------------------------------------------------------
    // STEP 1: AXI BURST ARITHMETIC
    // ---------------------------------------------------------
    wire [4:0] beats = req_len[3:0] + 5'd1;
    wire [32:0] extended_last = {1'b0, req_start} + ({28'd0, beats} << req_size) - 33'd1;
    wire [31:0] last_byte = extended_last[31:0];

    // ---------------------------------------------------------
    // STEP 2: ADDRESS OVERFLOW AND 4KIB CROSSING CHECKS
    // ---------------------------------------------------------
    wire calc_overflow = extended_last[32];
    wire calc_4kb_err = (req_start[31:12] != last_byte[31:12]);

    // ---------------------------------------------------------
    // STEP 3 & 4: PARALLEL REGION COMPARATORS & REDUCTION
    // ---------------------------------------------------------
    wire [REGION_COUNT-1:0] cover_vec;
    wire [REGION_COUNT-1:0] overlap_vec;
    wire [REGION_COUNT-1:0] id_ok_vec;
    wire [REGION_COUNT-1:0] prot_ok_vec;
    wire [REGION_COUNT-1:0] perm_ok_vec;
    wire [REGION_COUNT-1:0] rgn_match_allow;

    genvar g;
    generate
        for (g = 0; g < REGION_COUNT; g = g + 1) begin : gen_comparators
            wire [31:0] g_base  = rgn_base[g*32 +: 32];
            wire [31:0] g_limit = rgn_limit[g*32 +: 32];
            wire [ID_WIDTH-1:0] g_mid  = rgn_mid[g*ID_WIDTH +: ID_WIDTH];
            wire [ID_WIDTH-1:0] g_mask = rgn_mask[g*ID_WIDTH +: ID_WIDTH];

            assign cover_vec[g] = rgn_active[g] && 
                                  (req_start >= g_base) && 
                                  (last_byte <= g_limit);

            assign overlap_vec[g] = rgn_active[g] && 
                                    (req_start <= g_limit) && 
                                    (last_byte >= g_base);

            assign id_ok_vec[g] = ((req_id & ~g_mask) == (g_mid & ~g_mask));

            assign prot_ok_vec[g] = ((!rgn_secure[g]) || (req_prot[1] == 1'b0)) &&
                                    ((!rgn_priv[g])   || (req_prot[0] == 1'b1));

            assign perm_ok_vec[g] = req_is_write ? rgn_write[g] : rgn_read[g];

            assign rgn_match_allow[g] = !cover_vec[g] || (id_ok_vec[g] && prot_ok_vec[g] && perm_ok_vec[g]);
        end
    endgenerate

    wire any_cover           = |cover_vec;
    wire any_overlap         = |overlap_vec;
    wire partial_containment = any_overlap && !any_cover;
    wire all_cover_allow     = &rgn_match_allow;
    wire acl_allowed         = any_cover && all_cover_allow;
    wire has_prot_err        = |(cover_vec & ~prot_ok_vec);
    wire _unused_matcher     = req_prot[2];

    // ---------------------------------------------------------
    // STEP 5 & 6: FAULT CLASSIFICATION & DECISION
    // ---------------------------------------------------------
    wire req_stage1_error = req_profile_err || req_overflow_err || req_4kb_err || calc_overflow || calc_4kb_err;

    reg [3:0] calc_allow;
    reg [3:0] calc_fault_code;

    always @(*) begin
        if (req_stage1_error) begin
            calc_allow = SAFE_DENY;
            calc_fault_code = 4'b0101; // READ/WRITE_ERR | BOUND_ERR
        end
        else if (!fw_en) begin
            calc_allow = SAFE_ALLOW;
            calc_fault_code = 4'b0000;
        end
        else if (!any_cover) begin
            calc_allow = SAFE_DENY;
            calc_fault_code = partial_containment ? 4'b0101 : 4'b0001;
        end
        else if (acl_allowed) begin
            calc_allow = SAFE_ALLOW;
            calc_fault_code = 4'b0000;
        end
        else begin
            calc_allow = SAFE_DENY;
            calc_fault_code = has_prot_err ? 4'b0011 : 4'b0001;
        end
    end

    // ---------------------------------------------------------
    // STEP 7: DECISION REGISTER & BACKPRESSURE
    // ---------------------------------------------------------
    assign req_ready = (!decision_valid) || decision_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decision_valid      <= 1'b0;
            decision_allow      <= SAFE_DENY;
            decision_fault_code <= 4'b0000;
            decision_id         <= {ID_WIDTH{1'b0}};
            decision_len        <= 8'd0;
            decision_err_mode   <= 1'b0;
        end
        else begin
            if (req_valid && req_ready) begin
                decision_valid      <= 1'b1;
                decision_allow      <= calc_allow;
                decision_fault_code <= calc_fault_code;
                decision_id         <= req_id;
                decision_len        <= req_len;
                decision_err_mode   <= err_mode;
            end
            else if (decision_valid && decision_ready) begin
                decision_valid      <= 1'b0;
            end
        end
    end

endmodule
