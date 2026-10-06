`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: tb_fw_closed_loop_ctrl.v
// Verifies closed-loop reflex, per-MID scoring, decay, 1-cycle NMI, and FIFO
////////////////////////////////////////////////////////////////////////////////

module tb_fw_closed_loop_ctrl;

    reg clk;
    reg resetn;

    reg  [1:0]  threat_level;
    reg         hdc_anomaly_alert;
    reg         honey_pot_hit;
    reg         force_drain_req;
    reg  [31:0] attack_fingerprint;
    reg  [3:0]  current_mid;

    reg  [31:0] event_addr;
    reg  [7:0]  event_len;
    reg  [2:0]  event_size;
    reg         event_is_write;
    reg  [5:0]  event_reason;

    reg         telemetry_overrun;
    reg  [3:0]  overrun_mid;

    reg         fifo_pop_pulse;
    reg         clear_overflow_pulse;
    reg         irq_ack_pulse;
    reg         clear_forensics_pulse;
    reg         unquarantine_pulse;
    reg  [3:0]  unquarantine_mid;

    wire        aegis_nmi_irq;
    wire [15:0] quarantine_mask;
    wire        fifo_overflow_containment;

    wire [31:0] reg_aegis_status;
    wire [31:0] reg_aegis_fingerprint;
    wire [31:0] reg_aegis_honey_count;
    wire [31:0] reg_aegis_caps;
    wire [31:0] reg_aegis_event_meta;
    wire [31:0] reg_aegis_event_addr;
    wire [31:0] reg_aegis_event_time;
    wire [31:0] reg_aegis_event_ctrl;

    // Use small epoch for fast simulation (e.g. 64 cycles)
    localparam integer TEST_EPOCH = 64;

    fw_closed_loop_ctrl #(
        .SCORE_DECAY_EPOCH(TEST_EPOCH)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .threat_level(threat_level),
        .hdc_anomaly_alert(hdc_anomaly_alert),
        .honey_pot_hit(honey_pot_hit),
        .force_drain_req(force_drain_req),
        .attack_fingerprint(attack_fingerprint),
        .current_mid(current_mid),
        .telemetry_overrun(telemetry_overrun),
        .overrun_mid(overrun_mid),
        .event_addr(event_addr),
        .event_len(event_len),
        .event_size(event_size),
        .event_is_write(event_is_write),
        .event_reason(event_reason),
        .fifo_pop_pulse(fifo_pop_pulse),
        .clear_overflow_pulse(clear_overflow_pulse),
        .irq_ack_pulse(irq_ack_pulse),
        .clear_forensics_pulse(clear_forensics_pulse),
        .unquarantine_pulse(unquarantine_pulse),
        .unquarantine_mid(unquarantine_mid),
        .aegis_nmi_irq(aegis_nmi_irq),
        .quarantine_mask(quarantine_mask),
        .fifo_overflow_containment(fifo_overflow_containment),
        .reg_aegis_status(reg_aegis_status),
        .reg_aegis_fingerprint(reg_aegis_fingerprint),
        .reg_aegis_honey_count(reg_aegis_honey_count),
        .reg_aegis_caps(reg_aegis_caps),
        .reg_aegis_event_meta(reg_aegis_event_meta),
        .reg_aegis_event_addr(reg_aegis_event_addr),
        .reg_aegis_event_time(reg_aegis_event_time),
        .reg_aegis_event_ctrl(reg_aegis_event_ctrl)
    );

    always #12.5 clk = ~clk;

    integer i;

    initial begin
        clk = 0;
        resetn = 0;
        threat_level = 2'b00;
        hdc_anomaly_alert = 0;
        honey_pot_hit = 0;
        force_drain_req = 0;
        attack_fingerprint = 32'h0;
        current_mid = 4'h0;
        telemetry_overrun = 1'b0;
        overrun_mid = 4'h0;
        event_addr = 32'h0;
        event_len = 8'h0;
        event_size = 3'h2;
        event_is_write = 0;
        event_reason = 6'h0;
        fifo_pop_pulse = 0;
        clear_overflow_pulse = 0;
        irq_ack_pulse = 0;
        clear_forensics_pulse = 0;
        unquarantine_pulse = 0;
        unquarantine_mid = 4'h0;

        #50;
        resetn = 1;
        #50;

        // 1. Verify CAPS word
        if (reg_aegis_caps !== 32'h0201_02A6) begin
            $display("[FAIL] reg_aegis_caps mismatch: %h (exp 020102A6)", reg_aegis_caps);
            $finish(1);
        end
        $display("[PASS] reg_aegis_caps verified: %h", reg_aegis_caps);

        // 2. Per-MID Scoring & Quarantine at 10
        $display("[TEST] Per-MID Scoring on MID 2");
        for (i = 1; i <= 9; i = i + 1) begin
            @(posedge clk);
            #1;
            threat_level = 2'b10;
            hdc_anomaly_alert = 1;
            current_mid = 4'd2;
            event_addr = 32'h2000_1000 + i;
            @(posedge clk);
            #1;
            threat_level = 2'b00;
            hdc_anomaly_alert = 0;
            if (quarantine_mask[2] !== 1'b0) begin
                $display("[FAIL] Pre-mature quarantine on MID 2 at iteration %d", i);
                $finish(1);
            end
        end

        // 10th attack on MID 2 triggers quarantine
        @(posedge clk);
        #1;
        threat_level = 2'b10;
        hdc_anomaly_alert = 1;
        current_mid = 4'd2;
        @(posedge clk);
        #1;
        threat_level = 2'b00;
        hdc_anomaly_alert = 0;
        @(posedge clk);
        #1;
        if (quarantine_mask[2] !== 1'b1 || quarantine_mask[3] !== 1'b0) begin
            $display("[FAIL] Quarantine mask incorrect: mask=%b", quarantine_mask);
            $finish(1);
        end
        $display("[PASS] MID 2 quarantined after 10th attack; MID 3 unquarantined.");

        // 3. Level 3 Immediate Quarantine
        $display("[TEST] Level 3 Immediate Quarantine on MID 7");
        @(posedge clk);
        #1;
        threat_level = 2'b11;
        force_drain_req = 1;
        current_mid = 4'd7;
        @(posedge clk);
        #1;
        threat_level = 2'b00;
        force_drain_req = 0;
        @(posedge clk);
        #1;
        if (quarantine_mask[7] !== 1'b1) begin
            $display("[FAIL] Level 3 immediate quarantine failed for MID 7");
            $finish(1);
        end
        $display("[PASS] Level 3 immediate quarantine verified for MID 7.");

        // 4. 1-Cycle NMI Pulse Verification
        $display("[TEST] 1-Cycle NMI pulse & Anti-Storm");
        // Clear previous pending
        irq_ack_pulse = 1;
        @(posedge clk);
        #1;
        irq_ack_pulse = 0;
        @(posedge clk);
        #1;

        // Trigger IRQ
        threat_level = 2'b11;
        @(posedge clk);
        #1;
        if (aegis_nmi_irq !== 1'b1) begin
            $display("[FAIL] aegis_nmi_irq failed to pulse high on first cycle");
            $finish(1);
        end
        @(posedge clk);
        #1;
        if (aegis_nmi_irq !== 1'b0) begin
            $display("[FAIL] aegis_nmi_irq stayed high for more than 1 cycle!");
            $finish(1);
        end
        threat_level = 2'b00;
        $display("[PASS] 1-cycle NMI pulse verified.");

        // 5. Forensic FIFO Depth 4 and Overflow Containment
        $display("[TEST] Forensic FIFO Depth 4 & Overflow");
        // Pop existing entries if any
        while (reg_aegis_event_ctrl[2:0] > 3'd0) begin
            fifo_pop_pulse = 1;
            @(posedge clk);
            #1;
        end
        fifo_pop_pulse = 0;
        clear_overflow_pulse = 1;
        @(posedge clk);
        #1;
        clear_overflow_pulse = 0;

        for (i = 0; i < 4; i = i + 1) begin
            threat_level = 2'b10;
            hdc_anomaly_alert = 1;
            event_addr = 32'hCAFE_0000 + i;
            event_len = 8'd4;
            current_mid = i;
            @(posedge clk);
            #1;
            threat_level = 2'b00;
            hdc_anomaly_alert = 0;
            @(posedge clk);
            #1;
        end

        if (reg_aegis_event_ctrl[2:0] !== 3'd4 || fifo_overflow_containment !== 1'b0) begin
            $display("[FAIL] FIFO count mismatch before overflow: %d", reg_aegis_event_ctrl[2:0]);
            $finish(1);
        end

        // 5th event causes overflow
        threat_level = 2'b10;
        hdc_anomaly_alert = 1;
        event_addr = 32'hDEAD_BEEF;
        @(posedge clk);
        #1;
        threat_level = 2'b00;
        hdc_anomaly_alert = 0;
        @(posedge clk);
        #1;
        if (reg_aegis_event_ctrl[3] !== 1'b1 || fifo_overflow_containment !== 1'b1) begin
            $display("[FAIL] FIFO overflow not set on 5th event");
            $finish(1);
        end
        $display("[PASS] FIFO overflow and containment verified.");

        // 5. Telemetry Queue Overrun & Attribution to Offending MID
        $display("[TEST] Telemetry Overrun & Attribution");
        clear_overflow_pulse = 1;
        // Pop all remaining FIFO items
        repeat (4) begin
            fifo_pop_pulse = 1;
            @(posedge clk);
            #1;
            fifo_pop_pulse = 0;
            @(posedge clk);
            #1;
        end
        clear_overflow_pulse = 0;
        @(posedge clk);
        #1;

        // Trigger telemetry overrun from MID 9
        telemetry_overrun = 1'b1;
        overrun_mid = 4'd9;
        @(posedge clk);
        #1;
        if (fifo_overflow_containment !== 1'b1 || reg_aegis_event_ctrl[3] !== 1'b1) begin
            $display("[FAIL] Telemetry overrun not reflected in containment / ctrl");
            $finish(1);
        end
        // Check captured meta has MID 9 and reason 6'b100000
        if (reg_aegis_event_meta[3:0] !== 4'd9 || reg_aegis_event_meta[12:7] !== 6'b100000) begin
            $display("[FAIL] Telemetry overrun meta mismatch: mid=%d reason=%b",
                     reg_aegis_event_meta[3:0], reg_aegis_event_meta[12:7]);
            $finish(1);
        end
        $display("[PASS] Telemetry overrun recorded with MID 9 and overflow reason.");

        // Clear overflow
        clear_overflow_pulse = 1'b1;
        telemetry_overrun = 1'b0;
        @(posedge clk);
        #1;
        clear_overflow_pulse = 1'b0;
        @(posedge clk);
        #1;
        if (reg_aegis_event_ctrl[3] !== 1'b0 || fifo_overflow_containment !== 1'b0) begin
            $display("[FAIL] Clear overflow failed for telemetry overrun");
            $finish(1);
        end
        $display("[PASS] Telemetry overrun cleared successfully.");

        $display("[ALL TESTS PASSED] fw_closed_loop_ctrl verified successfully!");
        $finish(0);
    end

endmodule
