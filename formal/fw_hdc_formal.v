module fw_hdc_formal (
    input wire        clk,
    input wire        resetn,
    input wire        s1_awvalid,
    input wire [31:0] s1_awaddr,
    input wire [7:0]  s1_awlen,
    input wire [2:0]  s1_awsize,
    input wire [3:0]  s1_awmid,
    input wire        s1_arvalid,
    input wire [31:0] s1_araddr,
    input wire [7:0]  s1_arlen,
    input wire [2:0]  s1_arsize,
    input wire [3:0]  s1_armid,
    input wire        cpu_telemetry_trap,
    input wire        cpu_telemetry_stall
);

    parameter [6:0] RAPID_THRESH = 7'd4;

    wire [1:0]  threat_level;
    wire        hdc_anomaly_alert;
    wire [31:0] attack_fingerprint;

    fw_hdc_sense #(
        .RAPID_THRESH(RAPID_THRESH)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .clear_overflow_pulse(1'b0),
        .s1_awvalid(s1_awvalid),
        .s1_awaddr(s1_awaddr),
        .s1_awlen(s1_awlen),
        .s1_awsize(s1_awsize),
        .s1_awmid(s1_awmid),
        .s1_arvalid(s1_arvalid),
        .s1_araddr(s1_araddr),
        .s1_arlen(s1_arlen),
        .s1_arsize(s1_arsize),
        .s1_armid(s1_armid),
        .cpu_telemetry_trap(cpu_telemetry_trap),
        .cpu_telemetry_stall(cpu_telemetry_stall),
        .threat_level(threat_level),
        .hdc_anomaly_alert(hdc_anomaly_alert),
        .attack_fingerprint(attack_fingerprint),
        .telemetry_overrun(),
        .overrun_mid(),
        .hdc_busy()
    );

    // Initial reset assumption: reset for first 2 cycles, then active
    reg [2:0] reset_counter = 0;
    always @(posedge clk) begin
        if (reset_counter < 3)
            reset_counter <= reset_counter + 1;
    end

    always @(*) begin
        if (reset_counter < 2)
            assume(!resetn);
        else
            assume(resetn);
    end

    // Formal Assertions
    always @(posedge clk) begin
        // Invariant 1: Alert is asserted if and only if threat level >= 2
        assert(hdc_anomaly_alert == (threat_level >= 2'b10));

        // Invariant 2: Threat level is strictly bounded in 0..3
        assert(threat_level <= 2'b11);

        // Invariant 3: Zero-delay fast-path: CPU trap forces critical breach (Level 3) and Alert
        if (resetn && cpu_telemetry_trap) begin
            assert(threat_level == 2'b11);
            assert(hdc_anomaly_alert == 1'b1);
        end

        // Invariant 4: Under active reset, threat level and alert must remain 0
        if (!resetn) begin
            assert(threat_level == 2'b00);
            assert(hdc_anomaly_alert == 1'b0);
        end

        // Invariant 5: Threat level 0 or 1 never triggers hdc_anomaly_alert
        if (threat_level < 2'b10) begin
            assert(hdc_anomaly_alert == 1'b0);
        end
    end

endmodule
