`timescale 1ns/1ps

module fw_apb_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // APB4 Interface
    input  wire [ADDR_WIDTH-1:0] s_apb_paddr,
    input  wire                  s_apb_psel,
    input  wire                  s_apb_penable,
    input  wire                  s_apb_pwrite,
    input  wire [DATA_WIDTH-1:0] s_apb_pwdata,
    input  wire [2:0]            s_apb_pprot,

    output reg  [DATA_WIDTH-1:0] s_apb_prdata,
    output wire                  s_apb_pready,
    output reg                   s_apb_pslverr,

    // Control Outputs
    output wire                  fw_en,
    output wire                  irq_en,
    output wire                  auto_ctx_en,
    output wire                  err_mode,
    output wire                  sec_irq,

    // Fault Logging Inputs from hardware
    input  wire                  w_fault_event_valid,
    input  wire [3:0]            w_fault_event_code,
    input  wire [31:0]           w_fault_event_addr,
    input  wire [3:0]            w_fault_event_id,
    input  wire [7:0]            w_fault_event_len,
    input  wire [2:0]            w_fault_event_size,

    input  wire                  r_fault_event_valid,
    input  wire [3:0]            r_fault_event_code,
    input  wire [31:0]           r_fault_event_addr,
    input  wire [3:0]            r_fault_event_id,
    input  wire [7:0]            r_fault_event_len,
    input  wire [2:0]            r_fault_event_size,

    input  wire                  ctx_fault_event_valid,
    input  wire [3:0]            ctx_fault_event_code,
    input  wire [31:0]           ctx_fault_event_addr,
    input  wire [3:0]            ctx_fault_event_id,

    // Dynamic Context Inputs from fw_context_tracker
    input  wire [31:0]           dyn_rgn4_base,
    input  wire [31:0]           dyn_rgn4_limit,
    input  wire                  dyn_rgn4_active,
    input  wire [31:0]           dyn_rgn5_base,
    input  wire [31:0]           dyn_rgn5_limit,
    input  wire                  dyn_rgn5_active,

    // Policy Outputs to fw_acl_matcher
    output wire [255:0]          rgn_base,
    output wire [255:0]          rgn_limit,
    output wire [7:0]            rgn_active,
    output wire [7:0]            rgn_read,
    output wire [7:0]            rgn_write,
    output wire [7:0]            rgn_secure,
    output wire [7:0]            rgn_priv,
    output wire [31:0]           rgn_mid,
    output wire [31:0]           rgn_mask,

    // AEGIS Canonical Registers & Forensics Telemetry Interface (0x0A0 - 0x0BC)
    input  wire [31:0]           reg_aegis_status_in,      // 0x0A0
    input  wire [31:0]           reg_aegis_fingerprint_in, // 0x0A4
    input  wire [31:0]           reg_aegis_honey_count_in, // 0x0A8
    input  wire [31:0]           reg_aegis_caps_in,        // 0x0AC
    input  wire [31:0]           reg_aegis_event_meta_in,  // 0x0B0
    input  wire [31:0]           reg_aegis_event_addr_in,  // 0x0B4
    input  wire [31:0]           reg_aegis_event_time_in,  // 0x0B8
    input  wire [31:0]           reg_aegis_event_ctrl_in,  // 0x0BC

    // Control Pulses to fw_closed_loop_ctrl
    output reg                   aegis_fifo_pop_pulse,
    output reg                   aegis_clear_overflow_pulse,
    output reg                   aegis_irq_ack_pulse,
    output reg                   aegis_unquarantine_pulse,
    output reg  [3:0]            aegis_unquarantine_mid
);

    assign s_apb_pready = 1'b1;

    wire access_phase = s_apb_psel && s_apb_penable;
    wire secure_priv  = (!s_apb_pprot[1]) && (s_apb_pprot[0]);
    wire aligned      = (s_apb_paddr[1:0] == 2'b00);
    wire [7:0] offset = s_apb_paddr[7:0];
    wire _unused_apb = &{1'b0, s_apb_paddr[ADDR_WIDTH-1:8], s_apb_pprot[2]};

    // Registers
    reg [3:0]  fw_control_reg;
    reg        fw_lock_reg;
    reg [31:0] fault_status_reg;
    reg [31:0] fault_addr_reg;
    reg [31:0] fault_info_reg;
    reg [31:0] fault_timestamp_reg;
    reg [31:0] fault_source_reg;
    reg        fault_captured;
    reg [31:0] cycle_counter;

    // Static Regions: 0, 1, 2, 3, 6, 7
    reg [31:0] rgn0_base,  rgn0_limit;
    reg        rgn0_active, rgn0_read, rgn0_write, rgn0_secure, rgn0_priv;
    reg [3:0]  rgn0_mid,   rgn0_mask;

    reg [31:0] rgn1_base,  rgn1_limit;
    reg        rgn1_active, rgn1_read, rgn1_write, rgn1_secure, rgn1_priv;
    reg [3:0]  rgn1_mid,   rgn1_mask;

    reg [31:0] rgn2_base,  rgn2_limit;
    reg        rgn2_active, rgn2_read, rgn2_write, rgn2_secure, rgn2_priv;
    reg [3:0]  rgn2_mid,   rgn2_mask;

    reg [31:0] rgn3_base,  rgn3_limit;
    reg        rgn3_active, rgn3_read, rgn3_write, rgn3_secure, rgn3_priv;
    reg [3:0]  rgn3_mid,   rgn3_mask;

    reg [31:0] rgn6_base,  rgn6_limit;
    reg        rgn6_active, rgn6_read, rgn6_write, rgn6_secure, rgn6_priv;
    reg [3:0]  rgn6_mid,   rgn6_mask;

    reg [31:0] rgn7_base,  rgn7_limit;
    reg        rgn7_active, rgn7_read, rgn7_write, rgn7_secure, rgn7_priv;
    reg [3:0]  rgn7_mid,   rgn7_mask;

    // Assign Control Outputs
    assign fw_en       = fw_control_reg[0];
    assign irq_en      = fw_control_reg[1];
    assign auto_ctx_en = fw_control_reg[2];
    assign err_mode    = fw_control_reg[3];
    assign sec_irq     = irq_en && fault_status_reg[31];

    // Assign Policy Outputs (Flat Verilog-2001 representation)
    assign rgn_base   = {rgn7_base,   rgn6_base,   dyn_rgn5_base, dyn_rgn4_base, rgn3_base,   rgn2_base,   rgn1_base,   rgn0_base};
    assign rgn_limit  = {rgn7_limit,  rgn6_limit,  dyn_rgn5_limit, dyn_rgn4_limit, rgn3_limit,  rgn2_limit,  rgn1_limit,  rgn0_limit};
    assign rgn_active = {rgn7_active, rgn6_active, dyn_rgn5_active, dyn_rgn4_active, rgn3_active, rgn2_active, rgn1_active, rgn0_active};
    assign rgn_read   = {rgn7_read,   rgn6_read,   1'b0,          1'b1,          rgn3_read,   rgn2_read,   rgn1_read,   rgn0_read};
    assign rgn_write  = {rgn7_write,  rgn6_write,  1'b1,          1'b0,          rgn3_write,  rgn2_write,  rgn1_write,  rgn0_write};
    assign rgn_secure = {rgn7_secure, rgn6_secure, 1'b1,          1'b1,          rgn3_secure, rgn2_secure, rgn1_secure, rgn0_secure};
    assign rgn_priv   = {rgn7_priv,   rgn6_priv,   1'b1,          1'b1,          rgn3_priv,   rgn2_priv,   rgn1_priv,   rgn0_priv};
    assign rgn_mid    = {rgn7_mid,    rgn6_mid,    4'h0,          4'h0,          rgn3_mid,    rgn2_mid,    rgn1_mid,    rgn0_mid};
    assign rgn_mask   = {rgn7_mask,   rgn6_mask,   4'h0,          4'h0,          rgn3_mask,   rgn2_mask,   rgn1_mask,   rgn0_mask};

    // Shared comparator for region control write validation
    wire [31:0] sel_chk_base = (offset == 8'h28) ? rgn0_base :
                               (offset == 8'h38) ? rgn1_base :
                               (offset == 8'h48) ? rgn2_base :
                               (offset == 8'h58) ? rgn3_base :
                               (offset == 8'h88) ? rgn6_base :
                               (offset == 8'h98) ? rgn7_base : 32'h0;
    wire [31:0] sel_chk_limit = (offset == 8'h28) ? rgn0_limit :
                                (offset == 8'h38) ? rgn1_limit :
                                (offset == 8'h48) ? rgn2_limit :
                                (offset == 8'h58) ? rgn3_limit :
                                (offset == 8'h88) ? rgn6_limit :
                                (offset == 8'h98) ? rgn7_limit : 32'h0;
    wire base_gt_limit = (sel_chk_base > sel_chk_limit);

    // Check write permissions and offset validity
    reg offset_valid;
    reg write_violation;

    always @(*) begin
        offset_valid    = 1'b1;
        write_violation = 1'b0;

        case (offset)
            8'h00: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;
            8'h04: ; // FW_LOCK RW1S
            8'h08: ; // FAULT_STATUS W1C
            8'h0C, 8'h10, 8'h14, 8'h18: if (s_apb_pwrite) write_violation = 1'b1;

            // Region 0
            8'h20, 8'h24: if (s_apb_pwrite && (fw_lock_reg || rgn0_active)) write_violation = 1'b1;
            8'h28: if (s_apb_pwrite && (fw_lock_reg || (s_apb_pwdata[31] && base_gt_limit))) write_violation = 1'b1;
            8'h2C: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;

            // Region 1
            8'h30, 8'h34: if (s_apb_pwrite && (fw_lock_reg || rgn1_active)) write_violation = 1'b1;
            8'h38: if (s_apb_pwrite && (fw_lock_reg || (s_apb_pwdata[31] && base_gt_limit))) write_violation = 1'b1;
            8'h3C: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;

            // Region 2
            8'h40, 8'h44: if (s_apb_pwrite && (fw_lock_reg || rgn2_active)) write_violation = 1'b1;
            8'h48: if (s_apb_pwrite && (fw_lock_reg || (s_apb_pwdata[31] && base_gt_limit))) write_violation = 1'b1;
            8'h4C: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;

            // Region 3
            8'h50, 8'h54: if (s_apb_pwrite && (fw_lock_reg || rgn3_active)) write_violation = 1'b1;
            8'h58: if (s_apb_pwrite && (fw_lock_reg || (s_apb_pwdata[31] && base_gt_limit))) write_violation = 1'b1;
            8'h5C: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;

            // Region 4 (Dynamic - RO via APB)
            8'h60, 8'h64, 8'h68, 8'h6C: if (s_apb_pwrite) write_violation = 1'b1;

            // Region 5 (Dynamic - RO via APB)
            8'h70, 8'h74, 8'h78, 8'h7C: if (s_apb_pwrite) write_violation = 1'b1;

            // Region 6
            8'h80, 8'h84: if (s_apb_pwrite && (fw_lock_reg || rgn6_active)) write_violation = 1'b1;
            8'h88: if (s_apb_pwrite && (fw_lock_reg || (s_apb_pwdata[31] && base_gt_limit))) write_violation = 1'b1;
            8'h8C: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;

            // Region 7
            8'h90, 8'h94: if (s_apb_pwrite && (fw_lock_reg || rgn7_active)) write_violation = 1'b1;
            8'h98: if (s_apb_pwrite && (fw_lock_reg || (s_apb_pwdata[31] && base_gt_limit))) write_violation = 1'b1;
            8'h9C: if (s_apb_pwrite && fw_lock_reg) write_violation = 1'b1;

            // Canonical AEGIS Registers (0x0A0 - 0x0BC)
            8'hA0, 8'hA4, 8'hA8, 8'hAC, 8'hB0, 8'hB4, 8'hB8: if (s_apb_pwrite) write_violation = 1'b1; // RO
            8'hBC: ; // W1P pop, clear overflow, irq ack, unquarantine allowed

            default: begin
                offset_valid    = 1'b0;
                write_violation = 1'b1;
            end
        endcase
    end

    wire access_ok = access_phase && aligned && secure_priv && offset_valid && (!write_violation);
    wire apb_write_valid = access_ok && s_apb_pwrite;
    wire apb_read_valid  = access_phase && aligned && secure_priv && offset_valid && (!s_apb_pwrite);

    // PSLVERR response
    always @(*) begin
        if (access_phase && (!aligned || !secure_priv || !offset_valid || write_violation)) begin
            s_apb_pslverr = 1'b1;
        end else begin
            s_apb_pslverr = 1'b0;
        end
    end

    // Fault Event Detection
    wire any_fault = w_fault_event_valid || r_fault_event_valid || ctx_fault_event_valid;

    // Hardware fault status bits
    wire hw_read_err  = r_fault_event_valid && r_fault_event_code[0];
    wire hw_write_err = w_fault_event_valid && w_fault_event_code[1];
    wire hw_prot_err  = (w_fault_event_valid && w_fault_event_code[2]) ||
                        (r_fault_event_valid && r_fault_event_code[2]);
    wire hw_bound_err = (w_fault_event_valid && w_fault_event_code[3]) ||
                        (r_fault_event_valid && r_fault_event_code[3]) ||
                        (ctx_fault_event_valid && ctx_fault_event_code[3]);
    wire hw_irq_pend  = any_fault;
    wire [1:0] active_fault_count = (w_fault_event_valid ? 2'd1 : 2'd0) +
                                    (r_fault_event_valid ? 2'd1 : 2'd0) +
                                    (ctx_fault_event_valid ? 2'd1 : 2'd0);
    wire [16:0] next_fault_count  = {1'b0, fault_info_reg[31:16]} + {15'd0, active_fault_count};

    // Selected fault metadata for first-fault capture (Priority: Context > Write > Read)
    wire [1:0]  sel_fault_source = ctx_fault_event_valid ? 2'b10 :
                                  (w_fault_event_valid   ? 2'b01 : 2'b00);
    wire [3:0]  sel_fault_code   = ctx_fault_event_valid ? ctx_fault_event_code :
                                  (w_fault_event_valid   ? w_fault_event_code   : r_fault_event_code);
    wire [31:0] sel_fault_addr   = ctx_fault_event_valid ? ctx_fault_event_addr :
                                  (w_fault_event_valid   ? w_fault_event_addr   : r_fault_event_addr);
    wire [3:0]  sel_fault_id     = ctx_fault_event_valid ? ctx_fault_event_id :
                                  (w_fault_event_valid   ? w_fault_event_id   : r_fault_event_id);
    wire [7:0]  sel_fault_len    = ctx_fault_event_valid ? 8'h00 :
                                  (w_fault_event_valid   ? w_fault_event_len  : r_fault_event_len);
    wire [2:0]  sel_fault_size   = ctx_fault_event_valid ? 3'b000 :
                                  (w_fault_event_valid   ? w_fault_event_size : r_fault_event_size);
    wire        sel_fault_type   = w_fault_event_valid;

    // Sequential Registers update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fw_control_reg     <= 4'b1101; // 0x0D: FW_EN=1, IRQ_EN=0, AUTO_CTX_EN=1, ERR_MODE=1
            fw_lock_reg        <= 1'b0;
            fault_status_reg   <= 32'h0;
            fault_addr_reg     <= 32'h0;
            fault_info_reg     <= 32'h0;
            fault_timestamp_reg<= 32'h0;
            fault_source_reg   <= 32'h0;
            fault_captured     <= 1'b0;
            cycle_counter      <= 32'h0;

            rgn0_base <= 32'h0; rgn0_limit <= 32'h0; rgn0_active <= 1'b0;
            rgn0_read <= 1'b0; rgn0_write <= 1'b0; rgn0_secure <= 1'b0; rgn0_priv <= 1'b0;
            rgn0_mid <= 4'h0; rgn0_mask <= 4'h0;

            rgn1_base <= 32'h0; rgn1_limit <= 32'h0; rgn1_active <= 1'b0;
            rgn1_read <= 1'b0; rgn1_write <= 1'b0; rgn1_secure <= 1'b0; rgn1_priv <= 1'b0;
            rgn1_mid <= 4'h0; rgn1_mask <= 4'h0;

            rgn2_base <= 32'h0; rgn2_limit <= 32'h0; rgn2_active <= 1'b0;
            rgn2_read <= 1'b0; rgn2_write <= 1'b0; rgn2_secure <= 1'b0; rgn2_priv <= 1'b0;
            rgn2_mid <= 4'h0; rgn2_mask <= 4'h0;

            rgn3_base <= 32'h0; rgn3_limit <= 32'h0; rgn3_active <= 1'b0;
            rgn3_read <= 1'b0; rgn3_write <= 1'b0; rgn3_secure <= 1'b0; rgn3_priv <= 1'b0;
            rgn3_mid <= 4'h0; rgn3_mask <= 4'h0;

            rgn6_base <= 32'h0; rgn6_limit <= 32'h0; rgn6_active <= 1'b0;
            rgn6_read <= 1'b0; rgn6_write <= 1'b0; rgn6_secure <= 1'b0; rgn6_priv <= 1'b0;
            rgn6_mid <= 4'h0; rgn6_mask <= 4'h0;

            rgn7_base <= 32'h0; rgn7_limit <= 32'h0; rgn7_active <= 1'b0;
            rgn7_read <= 1'b0; rgn7_write <= 1'b0; rgn7_secure <= 1'b0; rgn7_priv <= 1'b0;
            rgn7_mid <= 4'h0; rgn7_mask <= 4'h0;

            aegis_fifo_pop_pulse       <= 1'b0;
            aegis_clear_overflow_pulse <= 1'b0;
            aegis_irq_ack_pulse        <= 1'b0;
            aegis_unquarantine_pulse   <= 1'b0;
            aegis_unquarantine_mid     <= 4'h0;
        end else begin
            cycle_counter <= cycle_counter + 32'd1;

            // Default pulse deassertion every cycle
            aegis_fifo_pop_pulse       <= 1'b0;
            aegis_clear_overflow_pulse <= 1'b0;
            aegis_irq_ack_pulse        <= 1'b0;
            aegis_unquarantine_pulse   <= 1'b0;

            // 1. APB Writes
            if (apb_write_valid) begin
                case (offset)
                    8'h00: begin
                        if (!fw_lock_reg) begin
                            fw_control_reg <= s_apb_pwdata[3:0];
                        end
                    end
                    8'h04: begin
                        fw_lock_reg <= fw_lock_reg | s_apb_pwdata[0];
                    end
                    8'h08: begin
                        // Software W1C handled below in conjunction with hardware-set
                    end

                    // Region 0
                    8'h20: if (!rgn0_active && !fw_lock_reg) rgn0_base <= s_apb_pwdata;
                    8'h24: if (!rgn0_active && !fw_lock_reg) rgn0_limit <= s_apb_pwdata;
                    8'h28: if (!fw_lock_reg) begin
                        rgn0_read   <= s_apb_pwdata[0];
                        rgn0_write  <= s_apb_pwdata[1];
                        rgn0_secure <= s_apb_pwdata[2];
                        rgn0_priv   <= s_apb_pwdata[3];
                        rgn0_active <= s_apb_pwdata[31];
                    end
                    8'h2C: if (!fw_lock_reg) begin
                        rgn0_mid  <= s_apb_pwdata[3:0];
                        rgn0_mask <= s_apb_pwdata[7:4];
                    end

                    // Region 1
                    8'h30: if (!rgn1_active && !fw_lock_reg) rgn1_base <= s_apb_pwdata;
                    8'h34: if (!rgn1_active && !fw_lock_reg) rgn1_limit <= s_apb_pwdata;
                    8'h38: if (!fw_lock_reg) begin
                        rgn1_read   <= s_apb_pwdata[0];
                        rgn1_write  <= s_apb_pwdata[1];
                        rgn1_secure <= s_apb_pwdata[2];
                        rgn1_priv   <= s_apb_pwdata[3];
                        rgn1_active <= s_apb_pwdata[31];
                    end
                    8'h3C: if (!fw_lock_reg) begin
                        rgn1_mid  <= s_apb_pwdata[3:0];
                        rgn1_mask <= s_apb_pwdata[7:4];
                    end

                    // Region 2
                    8'h40: if (!rgn2_active && !fw_lock_reg) rgn2_base <= s_apb_pwdata;
                    8'h44: if (!rgn2_active && !fw_lock_reg) rgn2_limit <= s_apb_pwdata;
                    8'h48: if (!fw_lock_reg) begin
                        rgn2_read   <= s_apb_pwdata[0];
                        rgn2_write  <= s_apb_pwdata[1];
                        rgn2_secure <= s_apb_pwdata[2];
                        rgn2_priv   <= s_apb_pwdata[3];
                        rgn2_active <= s_apb_pwdata[31];
                    end
                    8'h4C: if (!fw_lock_reg) begin
                        rgn2_mid  <= s_apb_pwdata[3:0];
                        rgn2_mask <= s_apb_pwdata[7:4];
                    end

                    // Region 3
                    8'h50: if (!rgn3_active && !fw_lock_reg) rgn3_base <= s_apb_pwdata;
                    8'h54: if (!rgn3_active && !fw_lock_reg) rgn3_limit <= s_apb_pwdata;
                    8'h58: if (!fw_lock_reg) begin
                        rgn3_read   <= s_apb_pwdata[0];
                        rgn3_write  <= s_apb_pwdata[1];
                        rgn3_secure <= s_apb_pwdata[2];
                        rgn3_priv   <= s_apb_pwdata[3];
                        rgn3_active <= s_apb_pwdata[31];
                    end
                    8'h5C: if (!fw_lock_reg) begin
                        rgn3_mid  <= s_apb_pwdata[3:0];
                        rgn3_mask <= s_apb_pwdata[7:4];
                    end

                    // Region 6
                    8'h80: if (!rgn6_active && !fw_lock_reg) rgn6_base <= s_apb_pwdata;
                    8'h84: if (!rgn6_active && !fw_lock_reg) rgn6_limit <= s_apb_pwdata;
                    8'h88: if (!fw_lock_reg) begin
                        rgn6_read   <= s_apb_pwdata[0];
                        rgn6_write  <= s_apb_pwdata[1];
                        rgn6_secure <= s_apb_pwdata[2];
                        rgn6_priv   <= s_apb_pwdata[3];
                        rgn6_active <= s_apb_pwdata[31];
                    end
                    8'h8C: if (!fw_lock_reg) begin
                        rgn6_mid  <= s_apb_pwdata[3:0];
                        rgn6_mask <= s_apb_pwdata[7:4];
                    end

                    // Region 7
                    8'h90: if (!rgn7_active && !fw_lock_reg) rgn7_base <= s_apb_pwdata;
                    8'h94: if (!rgn7_active && !fw_lock_reg) rgn7_limit <= s_apb_pwdata;
                    8'h98: if (!fw_lock_reg) begin
                        rgn7_read   <= s_apb_pwdata[0];
                        rgn7_write  <= s_apb_pwdata[1];
                        rgn7_secure <= s_apb_pwdata[2];
                        rgn7_priv   <= s_apb_pwdata[3];
                        rgn7_active <= s_apb_pwdata[31];
                    end
                    8'h9C: if (!fw_lock_reg) begin
                        rgn7_mid  <= s_apb_pwdata[3:0];
                        rgn7_mask <= s_apb_pwdata[7:4];
                    end

                    // Canonical AEGIS Registers Control Writes (0x0BC ONLY)
                    8'hBC: if (secure_priv) begin
                        if (s_apb_pwdata[8])  aegis_fifo_pop_pulse       <= 1'b1;
                        if (s_apb_pwdata[9])  aegis_clear_overflow_pulse <= 1'b1;
                        if (s_apb_pwdata[10]) aegis_irq_ack_pulse        <= 1'b1;
                        if (s_apb_pwdata[11]) begin
                            aegis_unquarantine_pulse <= 1'b1;
                            aegis_unquarantine_mid   <= s_apb_pwdata[15:12];
                        end
                    end
                    default: ;
                endcase
            end

            // 2. FAULT_STATUS W1C vs Hardware-Set Priority
            if (hw_read_err)
                fault_status_reg[0] <= 1'b1;
            else if (apb_write_valid && offset == 8'h08 && s_apb_pwdata[0])
                fault_status_reg[0] <= 1'b0;

            if (hw_write_err)
                fault_status_reg[1] <= 1'b1;
            else if (apb_write_valid && offset == 8'h08 && s_apb_pwdata[1])
                fault_status_reg[1] <= 1'b0;

            if (hw_prot_err)
                fault_status_reg[2] <= 1'b1;
            else if (apb_write_valid && offset == 8'h08 && s_apb_pwdata[2])
                fault_status_reg[2] <= 1'b0;

            if (hw_bound_err)
                fault_status_reg[3] <= 1'b1;
            else if (apb_write_valid && offset == 8'h08 && s_apb_pwdata[3])
                fault_status_reg[3] <= 1'b0;

            if (hw_irq_pend)
                fault_status_reg[31] <= 1'b1;
            else if (apb_write_valid && offset == 8'h08 && s_apb_pwdata[31])
                fault_status_reg[31] <= 1'b0;

            // 3. Fault Metadata Capture & Saturating Counter
            if (any_fault) begin
                if (next_fault_count[16]) begin
                    fault_info_reg[31:16] <= 16'hFFFF;
                end else begin
                    fault_info_reg[31:16] <= next_fault_count[15:0];
                end

                if (!fault_captured) begin
                    fault_captured       <= 1'b1;
                    fault_addr_reg       <= sel_fault_addr;
                    fault_info_reg[15:0] <= {sel_fault_type, sel_fault_size, sel_fault_len, sel_fault_id};
                    fault_timestamp_reg  <= cycle_counter;
                    fault_source_reg     <= {26'd0, sel_fault_code, sel_fault_source};
                end
            end else if (apb_write_valid && offset == 8'h08 && s_apb_pwdata[31]) begin
                fault_captured <= 1'b0;
            end
        end
    end

    // 4. APB Read Multiplexer
    always @(*) begin
        s_apb_prdata = 32'h0;
        if (apb_read_valid) begin
            case (offset)
                8'h00: s_apb_prdata = {28'd0, fw_control_reg};
                8'h04: s_apb_prdata = {31'd0, fw_lock_reg};
                8'h08: s_apb_prdata = fault_status_reg;
                8'h0C: s_apb_prdata = fault_addr_reg;
                8'h10: s_apb_prdata = fault_info_reg;
                8'h14: s_apb_prdata = fault_timestamp_reg;
                8'h18: s_apb_prdata = fault_source_reg;

                // Region 0
                8'h20: s_apb_prdata = rgn0_base;
                8'h24: s_apb_prdata = rgn0_limit;
                8'h28: s_apb_prdata = {rgn0_active, 27'd0, rgn0_priv, rgn0_secure, rgn0_write, rgn0_read};
                8'h2C: s_apb_prdata = {24'd0, rgn0_mask, rgn0_mid};

                // Region 1
                8'h30: s_apb_prdata = rgn1_base;
                8'h34: s_apb_prdata = rgn1_limit;
                8'h38: s_apb_prdata = {rgn1_active, 27'd0, rgn1_priv, rgn1_secure, rgn1_write, rgn1_read};
                8'h3C: s_apb_prdata = {24'd0, rgn1_mask, rgn1_mid};

                // Region 2
                8'h40: s_apb_prdata = rgn2_base;
                8'h44: s_apb_prdata = rgn2_limit;
                8'h48: s_apb_prdata = {rgn2_active, 27'd0, rgn2_priv, rgn2_secure, rgn2_write, rgn2_read};
                8'h4C: s_apb_prdata = {24'd0, rgn2_mask, rgn2_mid};

                // Region 3
                8'h50: s_apb_prdata = rgn3_base;
                8'h54: s_apb_prdata = rgn3_limit;
                8'h58: s_apb_prdata = {rgn3_active, 27'd0, rgn3_priv, rgn3_secure, rgn3_write, rgn3_read};
                8'h5C: s_apb_prdata = {24'd0, rgn3_mask, rgn3_mid};

                // Region 4 (Dynamic)
                8'h60: s_apb_prdata = dyn_rgn4_base;
                8'h64: s_apb_prdata = dyn_rgn4_limit;
                8'h68: s_apb_prdata = {dyn_rgn4_active, 27'd0, 1'b1, 1'b1, 1'b0, 1'b1};
                8'h6C: s_apb_prdata = 32'h0;

                // Region 5 (Dynamic)
                8'h70: s_apb_prdata = dyn_rgn5_base;
                8'h74: s_apb_prdata = dyn_rgn5_limit;
                8'h78: s_apb_prdata = {dyn_rgn5_active, 27'd0, 1'b1, 1'b1, 1'b1, 1'b0};
                8'h7C: s_apb_prdata = 32'h0;

                // Region 6
                8'h80: s_apb_prdata = rgn6_base;
                8'h84: s_apb_prdata = rgn6_limit;
                8'h88: s_apb_prdata = {rgn6_active, 27'd0, rgn6_priv, rgn6_secure, rgn6_write, rgn6_read};
                8'h8C: s_apb_prdata = {24'd0, rgn6_mask, rgn6_mid};

                // Region 7 (Static Region 7 restored conforming to Sky130 v2.0.0)
                8'h90: s_apb_prdata = rgn7_base;
                8'h94: s_apb_prdata = rgn7_limit;
                8'h98: s_apb_prdata = {rgn7_active, 27'd0, rgn7_priv, rgn7_secure, rgn7_write, rgn7_read};
                8'h9C: s_apb_prdata = {24'd0, rgn7_mask, rgn7_mid};

                // Canonical AEGIS Registers (0x0A0 - 0x0BC)
                8'hA0: s_apb_prdata = reg_aegis_status_in;
                8'hA4: s_apb_prdata = reg_aegis_fingerprint_in;
                8'hA8: s_apb_prdata = reg_aegis_honey_count_in;
                8'hAC: s_apb_prdata = reg_aegis_caps_in;
                8'hB0: s_apb_prdata = reg_aegis_event_meta_in;
                8'hB4: s_apb_prdata = reg_aegis_event_addr_in;
                8'hB8: s_apb_prdata = reg_aegis_event_time_in;
                8'hBC: s_apb_prdata = reg_aegis_event_ctrl_in;

                default: s_apb_prdata = 32'h0;
            endcase
        end
    end

endmodule
