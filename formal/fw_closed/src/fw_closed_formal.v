module fw_closed_formal (
    input wire        clk,
    input wire        resetn,
    input wire [1:0]  threat_level,
    input wire        hdc_anomaly_alert,
    input wire        honey_pot_hit,
    input wire        force_drain_req,
    input wire [31:0] attack_fingerprint,
    input wire [3:0]  current_mid,
    input wire        irq_ack_pulse,
    input wire        clear_forensics_pulse,
    input wire        unquarantine_pulse,
    input wire [3:0]  unquarantine_mid
);

    wire        aegis_nmi_irq;
    wire [15:0] quarantine_mask;
    wire [31:0] reg_aegis_status;
    wire [31:0] reg_aegis_fingerprint;
    wire [31:0] reg_aegis_honey_count;

    fw_closed_loop_ctrl dut (
        .clk(clk),
        .resetn(resetn),
        .threat_level(threat_level),
        .hdc_anomaly_alert(hdc_anomaly_alert),
        .honey_pot_hit(honey_pot_hit),
        .force_drain_req(force_drain_req),
        .attack_fingerprint(attack_fingerprint),
        .current_mid(current_mid),
        .telemetry_overrun(1'b0),
        .overrun_mid(4'h0),
        .event_addr(32'h0),
        .event_len(8'h0),
        .event_size(3'h0),
        .event_is_write(1'b0),
        .event_reason(6'h0),
        .fifo_pop_pulse(1'b0),
        .clear_overflow_pulse(1'b0),
        .irq_ack_pulse(irq_ack_pulse),
        .clear_forensics_pulse(clear_forensics_pulse),
        .unquarantine_pulse(unquarantine_pulse),
        .unquarantine_mid(unquarantine_mid),
        .aegis_nmi_irq(aegis_nmi_irq),
        .quarantine_mask(quarantine_mask),
        .fifo_overflow_containment(),
        .reg_aegis_status(reg_aegis_status),
        .reg_aegis_fingerprint(reg_aegis_fingerprint),
        .reg_aegis_honey_count(reg_aegis_honey_count),
        .reg_aegis_caps(),
        .reg_aegis_event_meta(),
        .reg_aegis_event_addr(),
        .reg_aegis_event_time(),
        .reg_aegis_event_ctrl()
    );

    reg [1:0] reset_counter = 2'd0;
    always @(posedge clk) begin
        if (reset_counter < 2'd2)
            reset_counter <= reset_counter + 1'b1;
    end

    always @(*) begin
        if (reset_counter < 2'd2)
            assume(!resetn);
        else
            assume(resetn);
    end

    // Reference model for 1-cycle NMI pulse & Anti-Storm
    reg exp_pending;
    reg exp_nmi;
    wire cur_trigger = (threat_level == 2'b11) || force_drain_req;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            exp_pending <= 1'b0;
            exp_nmi     <= 1'b0;
        end else begin
            if (irq_ack_pulse) begin
                exp_pending <= 1'b0;
                exp_nmi     <= 1'b0;
            end else if (cur_trigger) begin
                if (!exp_pending) begin
                    exp_pending <= 1'b1;
                    exp_nmi     <= 1'b1;
                end else begin
                    exp_nmi     <= 1'b0;
                end
            end else begin
                exp_nmi <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            assert(aegis_nmi_irq == 1'b0);
            assert(quarantine_mask == 16'h0000);
            assert(reg_aegis_fingerprint == 32'h0000_0000);
            assert(reg_aegis_honey_count == 32'h0000_0000);
        end else begin
            // NMI 1-cycle pulse & Anti-storm exact match
            assert(aegis_nmi_irq == exp_nmi);
            // If pending, NMI must never pulse (anti-storm)
            if (exp_pending && !exp_nmi) begin
                assert(aegis_nmi_irq == 1'b0);
            end
        end

        // Status register alignment
        assert(reg_aegis_status[31:16] == quarantine_mask);
        assert(reg_aegis_status[1:0] == threat_level);
    end

endmodule
