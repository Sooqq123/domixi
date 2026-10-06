`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// Project: AEGIS-RISC Bio-Inspired Closed-Loop Polymorphic Immune SoC
// Module:  fw_closed_loop_ctrl.v (Milestone 3)
//
// Description:
//   Closed-Loop Immune Reflex & Forensic Tracking Controller.
//   Binds HDC threat classification, MTD Honey-pot hits, and CPU NMI
//   interrupt lines to form an autonomous, bio-inspired self-healing loop.
//
// Features:
//   - Fast-path Non-Maskable Interrupt (NMI) pulse generator to wake up PicoRV32.
//   - Automatic hardware sandboxing (Quarantine Mask) for repeat offending Master IDs.
//   - Forensics telemetry registers readable by software via APB4 slave interface.
//   - Zero-DSP, fully synthesizable logic.
////////////////////////////////////////////////////////////////////////////////

module fw_closed_loop_ctrl (
    input  wire        clk,
    input  wire        resetn,

    // Threat inputs from fw_hdc_sense & fw_mtd_engine
    input  wire [1:0]  threat_level,
    input  wire        hdc_anomaly_alert,
    input  wire        honey_pot_hit,
    input  wire        force_drain_req,
    input  wire [31:0] attack_fingerprint,
    input  wire [3:0]  current_mid,

    // Software handshake from APB register write
    input  wire        clear_forensics_pulse,
    input  wire        unquarantine_pulse,
    input  wire [3:0]  unquarantine_mid,

    // Fast-path hardware NMI line to CPU
    output reg         aegis_nmi_irq,

    // Hardware quarantine enforcement
    output reg  [15:0] quarantine_mask,

    // Forensic telemetry interface to fw_apb_regs
    output wire [31:0] reg_aegis_status,
    output reg  [31:0] reg_aegis_fingerprint,
    output reg  [31:0] reg_aegis_honey_count
);

    // Threat & attack counters
    reg [7:0]  attack_event_count;
    reg [1:0]  max_threat_latched;
    reg [3:0]  last_attacking_mid;

    // NMI pulse generation (Level 3 or immediate breach triggers high-priority IRQ)
    reg [1:0] prev_threat;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            aegis_nmi_irq <= 1'b0;
            prev_threat   <= 2'b00;
        end else begin
            prev_threat <= threat_level;
            // Trigger 1-cycle NMI pulse on transition to Level 3 or critical anomaly
            if ((threat_level == 2'b11 && prev_threat != 2'b11) || force_drain_req) begin
                aegis_nmi_irq <= 1'b1;
            end else begin
                aegis_nmi_irq <= 1'b0;
            end
        end
    end

    // Forensic tracking & Master quarantine
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            attack_event_count    <= 8'h00;
            max_threat_latched    <= 2'b00;
            last_attacking_mid    <= 4'h0;
            reg_aegis_fingerprint <= 32'h0000_0000;
            reg_aegis_honey_count <= 32'h0000_0000;
            quarantine_mask       <= 16'h0000;
        end else begin
            // Track Honey-Pot hits
            if (honey_pot_hit) begin
                reg_aegis_honey_count <= reg_aegis_honey_count + 32'd1;
            end

            // Track Anomaly / Attacks
            if (hdc_anomaly_alert) begin
                if (attack_event_count != 8'hFF) begin
                    attack_event_count <= attack_event_count + 8'd1;
                end
                last_attacking_mid    <= current_mid;
                reg_aegis_fingerprint <= attack_fingerprint;

                if (threat_level > max_threat_latched) begin
                    max_threat_latched <= threat_level;
                end

                // If critical breach and persistent attack, quarantine the attacking Master ID automatically
                if (threat_level == 2'b11 && attack_event_count >= 8'd10) begin
                    quarantine_mask[current_mid] <= 1'b1;
                end
            end

            // Software clears & unquarantine
            if (clear_forensics_pulse) begin
                attack_event_count    <= 8'h00;
                max_threat_latched    <= 2'b00;
                reg_aegis_fingerprint <= 32'h0000_0000;
                reg_aegis_honey_count <= 32'h0000_0000;
            end

            if (unquarantine_pulse) begin
                quarantine_mask[unquarantine_mid] <= 1'b0;
            end
        end
    end

    // Status word composition:
    // [31:16]: Quarantine mask
    // [15:8] : Attack count
    // [7:4]  : Last attacking MID
    // [3:2]  : Max threat latched
    // [1:0]  : Current live threat level
    assign reg_aegis_status = {
        quarantine_mask,
        attack_event_count,
        last_attacking_mid,
        max_threat_latched,
        threat_level
    };

endmodule
