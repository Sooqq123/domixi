`timescale 1ns/1ps

module tb_adversarial_m1;

    reg clk;
    reg resetn;
    reg s1_awvalid;
    reg [31:0] s1_awaddr;
    reg [7:0] s1_awlen;
    reg [2:0] s1_awsize;
    reg [3:0] s1_awmid;
    reg s1_arvalid;
    reg [31:0] s1_araddr;
    reg [7:0] s1_arlen;
    reg [2:0] s1_arsize;
    reg [3:0] s1_armid;
    reg cpu_telemetry_trap;
    reg cpu_telemetry_stall;

    wire [1:0] threat_level;
    wire hdc_anomaly_alert;
    wire [31:0] attack_fingerprint;

    fw_hdc_sense dut (
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
        .attack_fingerprint(attack_fingerprint)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task apply_reset;
    begin
        @(negedge clk);
        resetn = 1'b0;
        s1_awvalid = 1'b0;
        s1_awaddr = 32'h0;
        s1_awlen = 8'h0;
        s1_awsize = 3'b010;
        s1_awmid = 4'h0;
        s1_arvalid = 1'b0;
        s1_araddr = 32'h0;
        s1_arlen = 8'h0;
        s1_arsize = 3'b010;
        s1_armid = 4'h0;
        cpu_telemetry_trap = 1'b0;
        cpu_telemetry_stall = 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(posedge clk);
    end
    endtask

    integer i;
    integer fp_count = 0;
    integer hdc_match_count = 0;
    reg [31:0] curr_addr;
    reg [7:0] curr_len;

    initial begin
        $display("=== STARTING ADVERSARIAL STRESS TESTS FOR fw_hdc_sense ===");
        apply_reset();

        // -------------------------------------------------------------
        // Stress Test 1: 5,000 Random Benign Non-Sequential DMA Bursts
        // (Testing HDC false positive rate on unconstrained random access)
        // -------------------------------------------------------------
        $display("\n--- Stress Test 1: 5,000 Random Benign DMA Bursts ---");
        fp_count = 0;
        for (i = 0; i < 5000; i = i + 1) begin
            @(negedge clk);
            if (i % 2 == 0) begin
                s1_awvalid = 1'b1;
                s1_awaddr = 32'h2000_0000 + ($urandom & 32'h000F_FFFC);
                s1_awlen = $urandom_range(0, 15);
                s1_awsize = 3'b010;
                s1_awmid = $urandom_range(0, 7);
                s1_arvalid = 1'b0;
            end else begin
                s1_arvalid = 1'b1;
                s1_araddr = 32'h2000_0000 + ($urandom & 32'h000F_FFFC);
                s1_arlen = $urandom_range(2, 15); // len > 1 so probe streak isn't hit
                s1_arsize = 3'b010;
                s1_armid = $urandom_range(0, 7);
                s1_awvalid = 1'b0;
            end
            @(posedge clk); #1;
            if (threat_level != 2'b00) begin
                fp_count = fp_count + 1;
                if (fp_count <= 5) begin
                    $display("[STRESS_1_FP] Iter %0d: False alarm! level=%b alert=%b addr=0x%08x is_write=%b",
                             i, threat_level, hdc_anomaly_alert, (s1_awvalid ? s1_awaddr : s1_araddr), s1_awvalid);
                end
            end
            @(negedge clk);
            s1_awvalid = 1'b0;
            s1_arvalid = 1'b0;
            // delta >= 6 cycles so rapid / periodicity not hit
            repeat ($urandom_range(6, 15)) @(posedge clk);
        end
        $display("Stress Test 1 Result: Total FP on 5,000 random bursts = %0d", fp_count);

        // -------------------------------------------------------------
        // Stress Test 2: Sequential DMA with Varying Burst Lengths
        // (e.g. 64B -> 32B -> 16B -> 64B contiguous addresses)
        // -------------------------------------------------------------
        $display("\n--- Stress Test 2: Contiguous DMA with Varying Burst Lengths ---");
        apply_reset();
        fp_count = 0;
        curr_addr = 32'h2000_0000;
        for (i = 0; i < 200; i = i + 1) begin
            // Vary length: 15 (64B), 7 (32B), 3 (16B), 1 (8B)
            case (i % 4)
                0: curr_len = 8'd15;
                1: curr_len = 8'd7;
                2: curr_len = 8'd3;
                3: curr_len = 8'd1;
            endcase

            @(negedge clk);
            s1_awvalid = 1'b1;
            s1_awaddr = curr_addr;
            s1_awlen = curr_len;
            s1_awsize = 3'b010;
            s1_awmid = 4'd1;
            @(posedge clk); #1;
            if (threat_level != 2'b00) begin
                fp_count = fp_count + 1;
                $display("[STRESS_2_FP] Iter %0d: level=%b alert=%b addr=0x%08x len=%0d",
                         i, threat_level, hdc_anomaly_alert, curr_addr, curr_len);
            end
            @(negedge clk);
            s1_awvalid = 1'b0;
            curr_addr = curr_addr + ((curr_len + 1) * 4);
            repeat (2) @(posedge clk); // Rapid back-to-back streaming
        end
        $display("Stress Test 2 Result: False Positives on Contiguous Varying-Length DMA = %0d", fp_count);

        // -------------------------------------------------------------
        // Stress Test 3: Rapid Sequential DMA Across 4KB Row Boundaries
        // -------------------------------------------------------------
        $display("\n--- Stress Test 3: Rapid Contiguous DMA Across 4KB Row Boundaries ---");
        apply_reset();
        fp_count = 0;
        curr_addr = 32'h2000_0F00; // Near boundary
        for (i = 0; i < 100; i = i + 1) begin
            @(negedge clk);
            s1_awvalid = 1'b1;
            s1_awaddr = curr_addr;
            s1_awlen = 8'd15; // 64 bytes
            s1_awsize = 3'b010;
            s1_awmid = 4'd1;
            @(posedge clk); #1;
            if (threat_level != 2'b00) begin
                fp_count = fp_count + 1;
                $display("[STRESS_3_FP] Iter %0d: level=%b alert=%b addr=0x%08x",
                         i, threat_level, hdc_anomaly_alert, curr_addr);
            end
            @(negedge clk);
            s1_awvalid = 1'b0;
            curr_addr = curr_addr + 64;
            repeat (1) @(posedge clk); // Rapid: 1 cycle wait
        end
        $display("Stress Test 3 Result: False Positives on Rapid Boundary Crossing = %0d", fp_count);

        // -------------------------------------------------------------
        // Stress Test 4: Rowhammer Evasion with 1 Read Interleaved
        // -------------------------------------------------------------
        $display("\n--- Stress Test 4: Rowhammer Evasion with Interleaved Read ---");
        apply_reset();
        for (i = 0; i < 10; i = i + 1) begin
            // Write Row A
            @(negedge clk);
            s1_awvalid = 1'b1; s1_awaddr = 32'h2000_1000; s1_awlen = 8'd0; s1_awsize = 3'b010; s1_awmid = 4'd5;
            @(posedge clk); #1; @(negedge clk); s1_awvalid = 1'b0;
            @(posedge clk);

            // Interleaved dummy read to benign address
            @(negedge clk);
            s1_arvalid = 1'b1; s1_araddr = 32'h2000_5000; s1_arlen = 8'd3; s1_arsize = 3'b010; s1_armid = 4'd0;
            @(posedge clk); #1; @(negedge clk); s1_arvalid = 1'b0;
            @(posedge clk);

            // Write Row B
            @(negedge clk);
            s1_awvalid = 1'b1; s1_awaddr = 32'h2000_2000; s1_awlen = 8'd0; s1_awsize = 3'b010; s1_awmid = 4'd5;
            @(posedge clk); #1; @(negedge clk); s1_awvalid = 1'b0;
            @(posedge clk);
        end
        $display("Stress Test 4 Result: After 10 interleaved read-write pairs, threat_level=%b alert=%b",
                 threat_level, hdc_anomaly_alert);

        $display("\n=== ADVERSARIAL STRESS TESTS COMPLETE ===");
        $finish(0);
    end

endmodule
