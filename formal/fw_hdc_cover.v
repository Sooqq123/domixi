module fw_hdc_cover (
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

    wire [1:0] threat_level;
    wire       hdc_anomaly_alert;
    wire [31:0] attack_fingerprint;

    fw_hdc_sense #(.RAPID_THRESH(7'd4)) dut (
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

    // Reachability coverage: every advertised classification and its key
    // fast-path/alert behavior must be reachable within the bounded trace.
    always @(posedge clk) begin
        cover(resetn && threat_level == 2'b00);
        cover(resetn && threat_level == 2'b01);
        cover(resetn && threat_level == 2'b10);
        cover(resetn && threat_level == 2'b11);
        cover(resetn && hdc_anomaly_alert);
        cover(resetn && cpu_telemetry_trap && threat_level == 2'b11);
        cover(resetn && cpu_telemetry_stall && threat_level == 2'b11);
    end

endmodule
