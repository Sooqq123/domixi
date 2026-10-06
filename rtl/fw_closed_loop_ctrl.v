`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// Project: AEGIS-RISC Bio-Inspired Immune SoC (Sky130 v2.0.0)
// Module:  fw_closed_loop_ctrl.v
//
// Description:
//   Closed-Loop Reflex & Forensic Tracking Controller conforming to
//   docs/AEGIS_RISC_ARCHITECTURE_SPECIFICATION.md Section 5, 9, 10.
//
// Key Features:
//   - Per-MID 4-bit saturating scoring for all 16 Master IDs.
//   - Automatic quarantine at score = 10, or immediate Level 3 quarantine.
//   - Deterministic score decay epoch (SCORE_DECAY_EPOCH = 1024 cycles) with
//     priority given to increment over decay in collision cycles.
//   - Guaranteed 1-cycle NMI pulse on interrupt_pending 0 -> 1 transition
//     with complete zero-interrupt-storm guarantee while pending.
//   - 4-entry forensic FIFO capturing metadata, address, and timestamp without
//     overwriting on full, activating overflow flag and containment.
//   - Canonical APB register readouts matching 0x0A0 - 0x0BC specification.
////////////////////////////////////////////////////////////////////////////////

module fw_closed_loop_ctrl #(
    parameter integer SCORE_DECAY_EPOCH = 1024
)(
    input  wire        clk,
    input  wire        resetn,

    // Threat inputs from fw_hdc_sense / fast path
    input  wire [1:0]  threat_level,
    input  wire        hdc_anomaly_alert,
    input  wire        honey_pot_hit,
    input  wire        force_drain_req,
    input  wire [31:0] attack_fingerprint,
    input  wire [3:0]  current_mid,
    input  wire        telemetry_overrun,
    input  wire [3:0]  overrun_mid,

    // Metadata capture inputs for forensic FIFO
    input  wire [31:0] event_addr,
    input  wire [7:0]  event_len,
    input  wire [2:0]  event_size,
    input  wire        event_is_write,
    input  wire [5:0]  event_reason,

    // APB Control & Handshake inputs (from fw_apb_regs)
    input  wire        fifo_pop_pulse,
    input  wire        clear_overflow_pulse,
    input  wire        irq_ack_pulse,
    input  wire        clear_forensics_pulse,
    input  wire        unquarantine_pulse,
    input  wire [3:0]  unquarantine_mid,

    // Hardware reflex outputs
    output reg         aegis_nmi_irq,       // 1-cycle pulse when interrupt_pending transitions 0 -> 1
    output reg  [15:0] quarantine_mask,
    output wire        fifo_overflow_containment,

    // Canonical AEGIS register readouts to fw_apb_regs
    output wire [31:0] reg_aegis_status,      // 0x0A0
    output reg  [31:0] reg_aegis_fingerprint, // 0x0A4
    output reg  [31:0] reg_aegis_honey_count, // 0x0A8
    output wire [31:0] reg_aegis_caps,        // 0x0AC
    output wire [31:0] reg_aegis_event_meta,  // 0x0B0
    output wire [31:0] reg_aegis_event_addr,  // 0x0B4
    output wire [31:0] reg_aegis_event_time,  // 0x0B8
    output wire [31:0] reg_aegis_event_ctrl   // 0x0BC
);

    // =========================================================================
    // 1. Cycle Timestamp Counter & Status Registers
    // =========================================================================
    reg [31:0] cycle_timestamp;
    reg [7:0]  attack_event_count;
    reg [1:0]  max_threat_latched;
    reg [3:0]  last_attacking_mid;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cycle_timestamp <= 32'd0;
        end else begin
            cycle_timestamp <= cycle_timestamp + 32'd1;
        end
    end

    // Canonical CAPS: ARCH=2, HDC_VER=1, FP_VER=2, DIM_LOG2=10, LANE_LOG2=6
    assign reg_aegis_caps = 32'h0201_02A6;

    assign reg_aegis_status = {
        quarantine_mask,
        attack_event_count,
        last_attacking_mid,
        max_threat_latched,
        threat_level
    };

    // =========================================================================
    // 2. Per-MID 4-bit Saturating Score & Quarantine Engine
    // =========================================================================
    reg [3:0]  mid_score [0:15];
    reg [15:0] mid_active_epoch;
    reg [31:0] epoch_counter;

    wire event_is_level2 = (threat_level == 2'b10);
    wire event_is_level3 = (threat_level == 2'b11) || force_drain_req;
    wire event_is_threat = hdc_anomaly_alert || event_is_level2 || event_is_level3;

    wire is_epoch_end = (epoch_counter >= SCORE_DECAY_EPOCH - 1);

    integer m;
    integer f;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            quarantine_mask  <= 16'h0000;
            mid_active_epoch <= 16'h0000;
            epoch_counter    <= 32'd0;
            for (m = 0; m < 16; m = m + 1) begin
                mid_score[m] <= 4'd0;
            end
        end else begin
            // 1. Epoch Timer & Decay Logic
            if (is_epoch_end) begin
                epoch_counter    <= 32'd0;
                mid_active_epoch <= 16'h0000;

                // Decrement non-zero scores that had no Level 2/3 events in this epoch
                for (m = 0; m < 16; m = m + 1) begin
                    if (!mid_active_epoch[m] && mid_score[m] > 4'd0) begin
                        // Collision check: if incrementing this MID right now, increment wins!
                        if (!(event_is_threat && current_mid == m[3:0])) begin
                            mid_score[m] <= mid_score[m] - 4'd1;
                        end
                    end
                end
            end else begin
                epoch_counter <= epoch_counter + 32'd1;
            end

            // 2. Score Increment & Quarantine
            if (event_is_threat) begin
                mid_active_epoch[current_mid] <= 1'b1;

                if (event_is_level3) begin
                    // Level 3 breaches immediately quarantine the offending master
                    quarantine_mask[current_mid] <= 1'b1;
                end else if (event_is_level2) begin
                    // Level 2 attacks increment saturating score
                    if (mid_score[current_mid] < 4'd15) begin
                        mid_score[current_mid] <= mid_score[current_mid] + 4'd1;
                    end
                    // Quarantine activates when score reaches 10
                    if (mid_score[current_mid] >= 4'd9) begin
                        quarantine_mask[current_mid] <= 1'b1;
                    end
                end
            end

            // 3. Software Unquarantine
            if (unquarantine_pulse) begin
                quarantine_mask[unquarantine_mid] <= 1'b0;
                mid_score[unquarantine_mid]       <= 4'd0;
            end
        end
    end

    // =========================================================================
    // 3. Interrupt Logic (1-Cycle Pulse, Anti-Storm, Software Ack)
    // =========================================================================
    reg interrupt_pending;

    wire irq_trigger = event_is_level3;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            aegis_nmi_irq     <= 1'b0;
            interrupt_pending <= 1'b0;
        end else begin
            if (irq_ack_pulse) begin
                interrupt_pending <= 1'b0;
                aegis_nmi_irq     <= 1'b0;
            end else if (irq_trigger) begin
                if (!interrupt_pending) begin
                    interrupt_pending <= 1'b1;
                    aegis_nmi_irq     <= 1'b1; // Exactly 1-cycle pulse!
                end else begin
                    aegis_nmi_irq     <= 1'b0; // Anti-storm: zero pulse while pending
                end
            end else begin
                aegis_nmi_irq <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. Forensic FIFO (4 Entries, No-Overwrite on Full, Overflow Containment)
    // =========================================================================
    reg [31:0] fifo_meta [0:3];
    reg [31:0] fifo_addr [0:3];
    reg [31:0] fifo_time [0:3];

    reg [1:0]  fifo_wr_ptr;
    reg [1:0]  fifo_rd_ptr;
    reg [2:0]  fifo_count;
    reg        fifo_overflow;

    wire safe_telemetry_overrun = (telemetry_overrun === 1'b1);

    reg telemetry_overrun_d;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            telemetry_overrun_d <= 1'b0;
        end else begin
            telemetry_overrun_d <= safe_telemetry_overrun;
        end
    end
    wire telemetry_overrun_pulse = safe_telemetry_overrun && !telemetry_overrun_d;

    assign fifo_overflow_containment = fifo_overflow | safe_telemetry_overrun;

    wire [31:0] current_event_meta = {
        8'd1,           // HDC model version = 1
        event_size,     // [23:21] AxSIZE
        event_len,      // [20:13] AxLEN
        event_reason,   // [12:7] reason precode
        event_is_write, // [6] is_write
        threat_level,   // [5:4] threat level
        current_mid     // [3:0] Master ID
    };

    wire [31:0] overrun_event_meta = {
        8'd1,           // HDC model version = 1
        3'b010,         // [23:21] AxSIZE
        8'd0,           // [20:13] AxLEN
        6'b100000,      // [12:7] reason = 6'b100000 (Telemetry Queue Overflow)
        1'b0,           // [6] is_write = 0
        2'b01,          // [5:4] threat level = Level 1 rate-limited
        overrun_mid     // [3:0] Master ID
    };

    wire [31:0] push_event_meta = telemetry_overrun_pulse ? overrun_event_meta : current_event_meta;
    wire [31:0] push_event_addr = telemetry_overrun_pulse ? 32'h0 : event_addr;
    wire [3:0]  push_event_mid  = telemetry_overrun_pulse ? overrun_mid : current_mid;

    wire fifo_push = event_is_threat || telemetry_overrun_pulse;
    wire fifo_pop  = fifo_pop_pulse && (fifo_count > 3'd0);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            fifo_wr_ptr           <= 2'd0;
            fifo_rd_ptr           <= 2'd0;
            fifo_count            <= 3'd0;
            fifo_overflow         <= 1'b0;
            attack_event_count    <= 8'h00;
            max_threat_latched    <= 2'b00;
            last_attacking_mid    <= 4'h0;
            reg_aegis_fingerprint <= 32'h0;
            reg_aegis_honey_count <= 32'h0;
            for (f = 0; f < 4; f = f + 1) begin
                fifo_meta[f] <= 32'h0;
                fifo_addr[f] <= 32'h0;
                fifo_time[f] <= 32'h0;
            end
        end else begin
            // Track Honey-Pot hits
            if (honey_pot_hit) begin
                reg_aegis_honey_count <= reg_aegis_honey_count + 32'd1;
            end

            // Clear Forensics
            if (clear_forensics_pulse) begin
                attack_event_count    <= 8'h00;
                max_threat_latched    <= 2'b00;
                reg_aegis_fingerprint <= 32'h0;
            end

            // Clear Overflow
            if (clear_overflow_pulse) begin
                fifo_overflow <= 1'b0;
            end

            // FIFO Push & Pop simultaneous handling
            if (fifo_push && fifo_pop) begin
                if (fifo_count < 3'd4) begin
                    fifo_meta[fifo_wr_ptr] <= push_event_meta;
                    fifo_addr[fifo_wr_ptr] <= push_event_addr;
                    fifo_time[fifo_wr_ptr] <= cycle_timestamp;
                    fifo_wr_ptr            <= fifo_wr_ptr + 2'd1;
                    fifo_rd_ptr            <= fifo_rd_ptr + 2'd1;
                end else begin
                    fifo_overflow <= 1'b1;
                    fifo_rd_ptr   <= fifo_rd_ptr + 2'd1;
                    fifo_count    <= fifo_count - 3'd1;
                end
            end else if (fifo_push) begin
                if (attack_event_count != 8'hFF) begin
                    attack_event_count <= attack_event_count + 8'd1;
                end
                last_attacking_mid    <= push_event_mid;
                reg_aegis_fingerprint <= attack_fingerprint;
                if (threat_level > max_threat_latched) begin
                    max_threat_latched <= threat_level;
                end

                if (fifo_count < 3'd4) begin
                    fifo_meta[fifo_wr_ptr] <= push_event_meta;
                    fifo_addr[fifo_wr_ptr] <= push_event_addr;
                    fifo_time[fifo_wr_ptr] <= cycle_timestamp;
                    fifo_wr_ptr            <= fifo_wr_ptr + 2'd1;
                    fifo_count             <= fifo_count + 3'd1;
                end else begin
                    // Overflow: Do not overwrite old records!
                    fifo_overflow <= 1'b1;
                end
            end else if (fifo_pop) begin
                fifo_rd_ptr <= fifo_rd_ptr + 2'd1;
                fifo_count  <= fifo_count - 3'd1;
            end
        end
    end

    // Canonical FIFO APB Registers
    assign reg_aegis_event_meta = (fifo_count > 3'd0) ? fifo_meta[fifo_rd_ptr] : 32'h0;
    assign reg_aegis_event_addr = (fifo_count > 3'd0) ? fifo_addr[fifo_rd_ptr] : 32'h0;
    assign reg_aegis_event_time = (fifo_count > 3'd0) ? fifo_time[fifo_rd_ptr] : 32'h0;
    assign reg_aegis_event_ctrl = {27'h0, interrupt_pending, (fifo_overflow | telemetry_overrun), fifo_count};

`ifdef FORMAL
    integer formal_mid;
    reg [15:0] formal_quarantine_prev;
    reg        formal_event_prev;
    reg [3:0]  formal_event_mid_prev;
    reg        formal_sat_event_prev;
    reg [3:0]  formal_sat_mid_prev;
    reg        formal_fifo_full_hold;
    reg [95:0] formal_fifo_head_prev;

    // Saturation and FIFO occupancy invariants.
    always @(posedge clk) begin
        if (resetn) begin
            assert(fifo_count <= 3'd4);
            for (formal_mid = 0; formal_mid < 16; formal_mid = formal_mid + 1)
                assert(mid_score[formal_mid] <= 4'd15);
        end
    end

    // Only the Master ID associated with the preceding event may create a
    // newly set quarantine bit.  Software may clear bits independently.
    always @(posedge clk) begin
        if (!resetn) begin
            formal_quarantine_prev <= 16'h0000;
            formal_event_prev      <= 1'b0;
            formal_event_mid_prev  <= 4'h0;
            formal_sat_event_prev  <= 1'b0;
            formal_sat_mid_prev    <= 4'h0;
        end else begin
            if (|(quarantine_mask & ~formal_quarantine_prev)) begin
                assert(formal_event_prev);
                assert((quarantine_mask & ~formal_quarantine_prev) ==
                       (16'h0001 << formal_event_mid_prev));
            end
            formal_quarantine_prev <= quarantine_mask;
            formal_event_prev      <= event_is_threat;
            formal_event_mid_prev  <= current_mid;
            formal_sat_event_prev  <= event_is_level2 && (mid_score[current_mid] == 4'd15) &&
                                      !(unquarantine_pulse && (unquarantine_mid == current_mid));
            formal_sat_mid_prev    <= current_mid;
        end
    end

    // A score at its ceiling must not wrap on the following Level 2 event.
    // A same-cycle software clear is deliberately exempt because it has
    // defined priority in the product RTL.
    always @(posedge clk) begin
        if (resetn && formal_sat_event_prev && event_is_level2 &&
            (current_mid == formal_sat_mid_prev) &&
            !(unquarantine_pulse && (unquarantine_mid == formal_sat_mid_prev)))
            assert(mid_score[formal_sat_mid_prev] == 4'd15);
    end

    // A full FIFO preserves its visible head until software pops it.
    always @(posedge clk) begin
        if (!resetn) begin
            formal_fifo_full_hold <= 1'b0;
            formal_fifo_head_prev <= 96'd0;
        end else begin
            if (formal_fifo_full_hold)
                assert({reg_aegis_event_meta, reg_aegis_event_addr,
                        reg_aegis_event_time} == formal_fifo_head_prev);
            formal_fifo_full_hold <= (fifo_count == 3'd4) && !fifo_pop;
            if ((fifo_count == 3'd4) && !fifo_pop)
                formal_fifo_head_prev <= {reg_aegis_event_meta,
                                          reg_aegis_event_addr,
                                          reg_aegis_event_time};
        end
    end
`endif

endmodule
