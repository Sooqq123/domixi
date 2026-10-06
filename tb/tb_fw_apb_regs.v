`timescale 1ns/1ps

module tb_fw_apb_regs;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg clk;
    reg rst_n;
    reg [ADDR_WIDTH-1:0] s_apb_paddr;
    reg s_apb_psel;
    reg s_apb_penable;
    reg s_apb_pwrite;
    reg [DATA_WIDTH-1:0] s_apb_pwdata;
    reg [2:0] s_apb_pprot;
    wire [DATA_WIDTH-1:0] s_apb_prdata;
    wire s_apb_pready;
    wire s_apb_pslverr;
    wire fw_en;
    wire irq_en;
    wire auto_ctx_en;
    wire err_mode;
    wire sec_irq;

    // Fault logging
    reg        w_fault_event_valid;
    reg [3:0]  w_fault_event_code;
    reg [31:0] w_fault_event_addr;
    reg [3:0]  w_fault_event_id;
    reg [7:0]  w_fault_event_len;
    reg [2:0]  w_fault_event_size;

    reg        r_fault_event_valid;
    reg [3:0]  r_fault_event_code;
    reg [31:0] r_fault_event_addr;
    reg [3:0]  r_fault_event_id;
    reg [7:0]  r_fault_event_len;
    reg [2:0]  r_fault_event_size;

    reg        ctx_fault_event_valid;
    reg [3:0]  ctx_fault_event_code;
    reg [31:0] ctx_fault_event_addr;
    reg [3:0]  ctx_fault_event_id;

    // Dynamic Context
    reg [31:0] dyn_rgn4_base;
    reg [31:0] dyn_rgn4_limit;
    reg        dyn_rgn4_active;
    reg [31:0] dyn_rgn5_base;
    reg [31:0] dyn_rgn5_limit;
    reg        dyn_rgn5_active;

    // Policy Outputs
    wire [255:0]     rgn_base;
    wire [255:0]     rgn_limit;
    wire [7:0]       rgn_active;
    wire [7:0]       rgn_read;
    wire [7:0]       rgn_write;
    wire [7:0]       rgn_secure;
    wire [7:0]       rgn_priv;
    wire [31:0]      rgn_mid;
    wire [31:0]      rgn_mask;

    // Canonical AEGIS inputs
    reg  [31:0] reg_aegis_status_in;
    reg  [31:0] reg_aegis_fingerprint_in;
    reg  [31:0] reg_aegis_honey_count_in;
    reg  [31:0] reg_aegis_caps_in;
    reg  [31:0] reg_aegis_event_meta_in;
    reg  [31:0] reg_aegis_event_addr_in;
    reg  [31:0] reg_aegis_event_time_in;
    reg  [31:0] reg_aegis_event_ctrl_in;

    // Control pulses
    wire        aegis_fifo_pop_pulse;
    wire        aegis_clear_overflow_pulse;
    wire        aegis_irq_ack_pulse;
    wire        aegis_unquarantine_pulse;
    wire [3:0]  aegis_unquarantine_mid;

    integer errors = 0;

    fw_apb_regs #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .s_apb_paddr                (s_apb_paddr),
        .s_apb_psel                 (s_apb_psel),
        .s_apb_penable              (s_apb_penable),
        .s_apb_pwrite               (s_apb_pwrite),
        .s_apb_pwdata               (s_apb_pwdata),
        .s_apb_pprot                (s_apb_pprot),
        .s_apb_prdata               (s_apb_prdata),
        .s_apb_pready               (s_apb_pready),
        .s_apb_pslverr              (s_apb_pslverr),
        .fw_en                      (fw_en),
        .irq_en                     (irq_en),
        .auto_ctx_en                (auto_ctx_en),
        .err_mode                   (err_mode),
        .sec_irq                    (sec_irq),
        .w_fault_event_valid        (w_fault_event_valid),
        .w_fault_event_code         (w_fault_event_code),
        .w_fault_event_addr         (w_fault_event_addr),
        .w_fault_event_id           (w_fault_event_id),
        .w_fault_event_len          (w_fault_event_len),
        .w_fault_event_size         (w_fault_event_size),
        .r_fault_event_valid        (r_fault_event_valid),
        .r_fault_event_code         (r_fault_event_code),
        .r_fault_event_addr         (r_fault_event_addr),
        .r_fault_event_id           (r_fault_event_id),
        .r_fault_event_len          (r_fault_event_len),
        .r_fault_event_size         (r_fault_event_size),
        .ctx_fault_event_valid      (ctx_fault_event_valid),
        .ctx_fault_event_code       (ctx_fault_event_code),
        .ctx_fault_event_addr       (ctx_fault_event_addr),
        .ctx_fault_event_id         (ctx_fault_event_id),
        .dyn_rgn4_base              (dyn_rgn4_base),
        .dyn_rgn4_limit             (dyn_rgn4_limit),
        .dyn_rgn4_active            (dyn_rgn4_active),
        .dyn_rgn5_base              (dyn_rgn5_base),
        .dyn_rgn5_limit             (dyn_rgn5_limit),
        .dyn_rgn5_active            (dyn_rgn5_active),
        .rgn_base                   (rgn_base),
        .rgn_limit                  (rgn_limit),
        .rgn_active                 (rgn_active),
        .rgn_read                   (rgn_read),
        .rgn_write                  (rgn_write),
        .rgn_secure                 (rgn_secure),
        .rgn_priv                   (rgn_priv),
        .rgn_mid                    (rgn_mid),
        .rgn_mask                   (rgn_mask),
        .reg_aegis_status_in        (reg_aegis_status_in),
        .reg_aegis_fingerprint_in   (reg_aegis_fingerprint_in),
        .reg_aegis_honey_count_in   (reg_aegis_honey_count_in),
        .reg_aegis_caps_in          (reg_aegis_caps_in),
        .reg_aegis_event_meta_in    (reg_aegis_event_meta_in),
        .reg_aegis_event_addr_in    (reg_aegis_event_addr_in),
        .reg_aegis_event_time_in    (reg_aegis_event_time_in),
        .reg_aegis_event_ctrl_in    (reg_aegis_event_ctrl_in),
        .aegis_fifo_pop_pulse       (aegis_fifo_pop_pulse),
        .aegis_clear_overflow_pulse (aegis_clear_overflow_pulse),
        .aegis_irq_ack_pulse        (aegis_irq_ack_pulse),
        .aegis_unquarantine_pulse   (aegis_unquarantine_pulse),
        .aegis_unquarantine_mid     (aegis_unquarantine_mid)
    );

    always #5 clk = ~clk;

    task automatic apb_idle;
        begin
            s_apb_paddr   = 32'd0;
            s_apb_psel    = 1'b0;
            s_apb_penable = 1'b0;
            s_apb_pwrite  = 1'b0;
            s_apb_pwdata  = 32'd0;
            s_apb_pprot   = 3'b001;
        end
    endtask

    task automatic apb_write;
        input [31:0] address;
        input [31:0] data;
        input [2:0]  protection;
        begin
            @(negedge clk);
            s_apb_paddr   = address;
            s_apb_psel    = 1'b1;
            s_apb_penable = 1'b0;
            s_apb_pwrite  = 1'b1;
            s_apb_pwdata  = data;
            s_apb_pprot   = protection;
            @(negedge clk);
            s_apb_penable = 1'b1;
            @(posedge clk);
            #1;
            apb_idle();
        end
    endtask

    task automatic apb_read;
        input  [31:0] address;
        input  [2:0]  protection;
        output [31:0] data;
        output        error;
        begin
            @(negedge clk);
            s_apb_paddr   = address;
            s_apb_psel    = 1'b1;
            s_apb_penable = 1'b0;
            s_apb_pwrite  = 1'b0;
            s_apb_pwdata  = 32'd0;
            s_apb_pprot   = protection;
            @(negedge clk);
            s_apb_penable = 1'b1;
            @(posedge clk);
            #1;
            data  = s_apb_prdata;
            error = s_apb_pslverr;
            apb_idle();
        end
    endtask

    reg [31:0] read_data;
    reg        read_err;

    initial begin
        clk = 0;
        rst_n = 0;
        apb_idle();
        w_fault_event_valid = 0; w_fault_event_code = 0; w_fault_event_addr = 0;
        w_fault_event_id = 0; w_fault_event_len = 0; w_fault_event_size = 0;
        r_fault_event_valid = 0; r_fault_event_code = 0; r_fault_event_addr = 0;
        r_fault_event_id = 0; r_fault_event_len = 0; r_fault_event_size = 0;
        ctx_fault_event_valid = 0; ctx_fault_event_code = 0; ctx_fault_event_addr = 0;
        ctx_fault_event_id = 0;
        dyn_rgn4_base = 0; dyn_rgn4_limit = 0; dyn_rgn4_active = 0;
        dyn_rgn5_base = 0; dyn_rgn5_limit = 0; dyn_rgn5_active = 0;
        reg_aegis_status_in = 32'h0000_1234;
        reg_aegis_fingerprint_in = 32'hFEED_BEEF;
        reg_aegis_honey_count_in = 32'h0000_0042;
        reg_aegis_caps_in = 32'h0201_02A6;
        reg_aegis_event_meta_in = 32'hAA55_0102;
        reg_aegis_event_addr_in = 32'hCAFE_BABE;
        reg_aegis_event_time_in = 32'h0011_2233;
        reg_aegis_event_ctrl_in = 32'h0000_0004;

        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // 1. Check Reset Values
        apb_read(32'h00, 3'b001, read_data, read_err);
        if (read_data[3:0] !== 4'b1101 || read_err !== 1'b0) begin
            $display("[FAIL] FW_CONTROL reset: %h (err=%b)", read_data, read_err);
            errors = errors + 1;
        end

        apb_read(32'h04, 3'b001, read_data, read_err);
        if (read_data[0] !== 1'b0 || read_err !== 1'b0) begin
            $display("[FAIL] FW_LOCK reset: %h", read_data);
            errors = errors + 1;
        end

        // 2. Check Protection and Alignment
        apb_read(32'h00, 3'b011, read_data, read_err); // Non-secure
        if (read_err !== 1'b1) begin
            $display("[FAIL] Non-secure read should assert PSLVERR");
            errors = errors + 1;
        end

        apb_read(32'h01, 3'b001, read_data, read_err); // Unaligned
        if (read_err !== 1'b1) begin
            $display("[FAIL] Unaligned read should assert PSLVERR");
            errors = errors + 1;
        end

        // 3. Write FW_CONTROL & FW_LOCK
        apb_write(32'h00, 32'h00000007, 3'b001); // FW_EN=1, IRQ_EN=1, AUTO_CTX_EN=1, ERR_MODE=0
        apb_read(32'h00, 3'b001, read_data, read_err);
        if (read_data[3:0] !== 4'h7) begin
            $display("[FAIL] FW_CONTROL write expected 0x7, got %h", read_data);
            errors = errors + 1;
        end

        // 4. Configure Static Region 0
        apb_write(32'h20, 32'h20000000, 3'b001); // BASE
        apb_write(32'h24, 32'h2000FFFF, 3'b001); // LIMIT
        apb_write(32'h28, 32'h8000000F, 3'b001); // ACTIVE=1, PRIV=1, SEC=1, WR=1, RD=1
        apb_write(32'h2C, 32'h00000000, 3'b001); // MID=0, MASK=0

        apb_read(32'h20, 3'b001, read_data, read_err);
        if (read_data !== 32'h20000000) begin
            $display("[FAIL] Region 0 BASE mismatch: %h", read_data);
            errors = errors + 1;
        end
        apb_read(32'h28, 3'b001, read_data, read_err);
        if (read_data[31] !== 1'b1 || read_data[3:0] !== 4'hF) begin
            $display("[FAIL] Region 0 PERM mismatch: %h", read_data);
            errors = errors + 1;
        end

        // 5. Test Static Region 7 (0x090 - 0x09C)
        apb_write(32'h90, 32'h70000000, 3'b001); // Region 7 BASE
        apb_write(32'h94, 32'h70001FFF, 3'b001); // Region 7 LIMIT
        apb_write(32'h98, 32'h80000005, 3'b001); // ACTIVE=1, SEC=1, RD=1
        apb_write(32'h9C, 32'h00000007, 3'b001); // MID=7, MASK=0

        apb_read(32'h90, 3'b001, read_data, read_err);
        if (read_data !== 32'h70000000) begin
            $display("[FAIL] Region 7 BASE mismatch: %h", read_data);
            errors = errors + 1;
        end
        apb_read(32'h94, 3'b001, read_data, read_err);
        if (read_data !== 32'h70001FFF) begin
            $display("[FAIL] Region 7 LIMIT mismatch: %h", read_data);
            errors = errors + 1;
        end
        apb_read(32'h98, 3'b001, read_data, read_err);
        if (read_data[31] !== 1'b1 || read_data[2] !== 1'b1 || read_data[0] !== 1'b1) begin
            $display("[FAIL] Region 7 PERM mismatch: %h", read_data);
            errors = errors + 1;
        end
        apb_read(32'h9C, 3'b001, read_data, read_err);
        if (read_data[3:0] !== 4'd7) begin
            $display("[FAIL] Region 7 MID mismatch: %h", read_data);
            errors = errors + 1;
        end

        // 6. Test Canonical AEGIS Register Readouts (0x0A0 - 0x0BC)
        apb_read(32'hA0, 3'b001, read_data, read_err);
        if (read_data !== 32'h0000_1234) begin
            $display("[FAIL] 0x0A0 AEGIS_STATUS readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hA4, 3'b001, read_data, read_err);
        if (read_data !== 32'hFEED_BEEF) begin
            $display("[FAIL] 0x0A4 AEGIS_FINGERPRINT readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hA8, 3'b001, read_data, read_err);
        if (read_data !== 32'h0000_0042) begin
            $display("[FAIL] 0x0A8 AEGIS_HONEY_COUNT readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hAC, 3'b001, read_data, read_err);
        if (read_data !== 32'h0201_02A6) begin
            $display("[FAIL] 0x0AC AEGIS_CAPS readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hB0, 3'b001, read_data, read_err);
        if (read_data !== 32'hAA55_0102) begin
            $display("[FAIL] 0x0B0 AEGIS_EVENT_META readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hB4, 3'b001, read_data, read_err);
        if (read_data !== 32'hCAFE_BABE) begin
            $display("[FAIL] 0x0B4 AEGIS_EVENT_ADDR readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hB8, 3'b001, read_data, read_err);
        if (read_data !== 32'h0011_2233) begin
            $display("[FAIL] 0x0B8 AEGIS_EVENT_TIME readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'hBC, 3'b001, read_data, read_err);
        if (read_data !== 32'h0000_0004) begin
            $display("[FAIL] 0x0BC AEGIS_EVENT_CTRL readback mismatch: %h", read_data);
            errors = errors + 1;
        end

        // 7. Test Canonical AEGIS Control Writes (W1P)
        // 0x0A0 is strictly RO: Attempt write must return PSLVERR
        apb_write(32'hA0, 32'hFFFF_FFFF, 3'b001);
        if (s_apb_pslverr !== 1'b1) begin
            $display("[FAIL] 0x0A0 REG_AEGIS_STATUS is RO: write should assert PSLVERR");
            errors = errors + 1;
        end

        // 0x0BC: bit 8 POP, bit 9 CLEAR_OVERFLOW, bit 10 IRQ_ACK, bit 11 UNQUARANTINE, bits [15:12] MID
        apb_write(32'hBC, 32'h0000_3F00, 3'b001); // All W1P pulses with MID 3
        #1;
        if (!aegis_fifo_pop_pulse || !aegis_clear_overflow_pulse || !aegis_irq_ack_pulse ||
            !aegis_unquarantine_pulse || aegis_unquarantine_mid !== 4'h3) begin
            $display("[FAIL] 0x0BC W1P pulses failed to generate expected control strobes!");
            errors = errors + 1;
        end
        @(posedge clk);
        #1;
        if (aegis_fifo_pop_pulse || aegis_clear_overflow_pulse || aegis_irq_ack_pulse || aegis_unquarantine_pulse) begin
            $display("[FAIL] 0x0BC W1P pulses did not auto-clear after 1 cycle!");
            errors = errors + 1;
        end

        // 8. Test Invalid Activation BASE > LIMIT
        apb_write(32'h30, 32'h30005000, 3'b001); // Region 1 BASE
        apb_write(32'h34, 32'h30001000, 3'b001); // Region 1 LIMIT < BASE
        apb_write(32'h38, 32'h8000000F, 3'b001); // Attempt activate
        if (s_apb_pslverr !== 1'b1) begin
            $display("[FAIL] Invalid activation BASE > LIMIT should assert PSLVERR");
            errors = errors + 1;
        end
        apb_read(32'h38, 3'b001, read_data, read_err);
        if (read_data[31] !== 1'b0) begin
            $display("[FAIL] Region 1 should remain inactive");
            errors = errors + 1;
        end

        // 9. Dynamic Region 4 Readback
        dyn_rgn4_base = 32'h40000000;
        dyn_rgn4_limit = 32'h40003FFF;
        dyn_rgn4_active = 1'b1;
        @(posedge clk);
        apb_read(32'h60, 3'b001, read_data, read_err);
        if (read_data !== 32'h40000000) begin
            $display("[FAIL] Dynamic Region 4 BASE readback: %h", read_data);
            errors = errors + 1;
        end
        apb_read(32'h68, 3'b001, read_data, read_err);
        if (read_data[31] !== 1'b1 || read_data[0] !== 1'b1 || read_data[1] !== 1'b0) begin
            $display("[FAIL] Dynamic Region 4 PERM readback: %h", read_data);
            errors = errors + 1;
        end

        // 10. Test Hardware Fault Event
        @(negedge clk);
        w_fault_event_valid = 1'b1;
        w_fault_event_code  = 4'b0010; // WRITE_ERR
        w_fault_event_addr  = 32'hA0001234;
        w_fault_event_id    = 4'h2;
        w_fault_event_len   = 8'h03;
        w_fault_event_size  = 3'b010;
        @(negedge clk);
        w_fault_event_valid = 1'b0;

        @(posedge clk);
        #1;
        if (sec_irq !== 1'b1) begin
            $display("[FAIL] sec_irq should be asserted (irq_en=1, IRQ_PENDING=1)");
            errors = errors + 1;
        end

        apb_read(32'h08, 3'b001, read_data, read_err); // FAULT_STATUS
        if (read_data[1] !== 1'b1 || read_data[31] !== 1'b1) begin
            $display("[FAIL] FAULT_STATUS expected WRITE_ERR & IRQ_PENDING: %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'h0C, 3'b001, read_data, read_err); // FAULT_ADDR
        if (read_data !== 32'hA0001234) begin
            $display("[FAIL] FAULT_ADDR expected 0xA0001234, got %h", read_data);
            errors = errors + 1;
        end

        apb_read(32'h10, 3'b001, read_data, read_err); // FAULT_INFO
        if (read_data[31:16] !== 16'd1 || read_data[3:0] !== 4'h2) begin
            $display("[FAIL] FAULT_INFO mismatch: %h", read_data);
            errors = errors + 1;
        end

        // 11. Clear IRQ via W1C
        apb_write(32'h08, 32'h80000000, 3'b001); // Clear IRQ_PENDING
        #1;
        if (sec_irq !== 1'b0) begin
            $display("[FAIL] sec_irq should deassert after clearing IRQ_PENDING");
            errors = errors + 1;
        end

        // 12. FW_LOCK Protection
        apb_write(32'h04, 32'h00000001, 3'b001); // Lock
        apb_write(32'h00, 32'h00000000, 3'b001); // Try modify FW_CONTROL
        if (s_apb_pslverr !== 1'b1) begin
            $display("[FAIL] Write to FW_CONTROL after lock should return PSLVERR");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: tb_fw_apb_regs");
        end else begin
            $display("FAIL: tb_fw_apb_regs with %0d errors", errors);
        end
        $finish;
    end

endmodule
