`timescale 1ns/1ps

module tb_fw_read_drain;

    reg clk;
    reg rst_n;

    reg        acl_r_fault;
    reg [3:0]  acl_r_id;
    reg [7:0]  acl_r_len;
    reg        acl_r_err_mode;

    reg        r_drain_rready;

    wire        r_drain_rvalid;
    wire [3:0]  r_drain_rid;
    wire [31:0] r_drain_rdata;
    wire [1:0]  r_drain_rresp;
    wire        r_drain_rlast;

    fw_read_drain DUT (
        .clk(clk),
        .rst_n(rst_n),
        .acl_r_fault(acl_r_fault),
        .acl_r_id(acl_r_id),
        .acl_r_len(acl_r_len),
        .acl_r_err_mode(acl_r_err_mode),
        .r_drain_rready(r_drain_rready),
        .r_drain_rvalid(r_drain_rvalid),
        .r_drain_rid(r_drain_rid),
        .r_drain_rdata(r_drain_rdata),
        .r_drain_rresp(r_drain_rresp),
        .r_drain_rlast(r_drain_rlast)
    );

    // ============================================================
    // 1. CLOCK + TIMEOUT + WAVEFORM
    // ============================================================

    initial clk = 1'b0;
    always #5 clk = ~clk;



    // Timeout: 1000 random bursts + backpressure có thể vượt 10000 clock.
    initial begin
        repeat (100000) @(posedge clk);
        $fatal(1, "TIMEOUT: read drain test did not complete.");
    end

    // ============================================================
    // 2. SCOREBOARD
    // ============================================================

    integer total_tests_passed;
    integer expected_beats;
    integer accepted_beats;

    reg [3:0] expected_id;
    reg [1:0] expected_resp;
    reg       in_burst;

    initial begin
        total_tests_passed = 0;
        expected_beats     = 0;
        accepted_beats     = 0;
        expected_id        = 4'd0;
        expected_resp      = 2'd0;
        in_burst           = 1'b0;
    end

    always @(posedge clk) begin

        if (rst_n && r_drain_rvalid && r_drain_rready) begin

            // Check RID
            if (r_drain_rid !== expected_id)
                $fatal(1, "SAI ID: %0h != %0h", r_drain_rid, expected_id);

            // Check RDATA
            if (r_drain_rdata !== 32'h0000_0000)
                $fatal(1, "SAI DATA: %0h != 0", r_drain_rdata);

            // Check RRESP
            if (r_drain_rresp !== expected_resp)
                $fatal(1, "SAI RESP: %0b != %0b", r_drain_rresp, expected_resp);

            // Check RLAST
            if (r_drain_rlast !== (accepted_beats == expected_beats - 1)) begin
                $fatal(1, "SAI RLAST at beat %0d", accepted_beats);
            end

            // Count handshake
            accepted_beats = accepted_beats + 1;

            // Final beat
            if (accepted_beats == expected_beats) begin
                in_burst = 1'b0;
            end
        end

        // RD-XTR-01: Chỉ kiểm tra extra beat khi KHÔNG phải cycle vừa handshake final.
        else begin
            if (rst_n && !in_burst && r_drain_rvalid)
                $fatal(1, "EXTRA BEAT DETECTED AFTER FINAL HANDSHAKE.");
        end
    end

    // ============================================================
    // 3. STABILITY MONITOR
    // ============================================================

    reg [3:0]  held_id;
    reg [31:0] held_data;
    reg [1:0]  held_resp;
    reg        held_last;
    reg        was_stalled;

    always @(posedge clk) begin

        if (!rst_n) begin
            was_stalled <= 1'b0;
        end
        else begin

            // Nếu cycle trước bị stall, toàn bộ payload phải giữ nguyên.
            if (was_stalled) begin
                if (!r_drain_rvalid ||
                    r_drain_rid   !== held_id ||
                    r_drain_rdata !== held_data ||
                    r_drain_rresp !== held_resp ||
                    r_drain_rlast !== held_last) begin
                    $fatal(1, "R PAYLOAD CHANGED UNDER BACKPRESSURE.");
                end
            end

            was_stalled <= r_drain_rvalid && !r_drain_rready;

            if (r_drain_rvalid) begin
                held_id   <= r_drain_rid;
                held_data <= r_drain_rdata;
                held_resp <= r_drain_rresp;
                held_last <= r_drain_rlast;
            end
        end
    end

    // ============================================================
    // 4. DENIED AR ACCEPTANCE
    // ============================================================

    task accept_denied_ar;
        input [3:0] id;
        input [7:0] len;
        input       mode;

        begin
            @(negedge clk);

            acl_r_id       = id;
            acl_r_len      = len;
            acl_r_err_mode = mode;
            acl_r_fault    = 1'b1;

            // Expected values
            expected_beats = len + 1;
            expected_id    = id;
            expected_resp  = mode ? 2'b11 : 2'b00;

            accepted_beats = 0;
            in_burst       = 1'b1;

            // DUT accepts fault here
            @(posedge clk);

            @(negedge clk);
            acl_r_fault = 1'b0;
        end
    endtask

    // ============================================================
    // 5. RANDOM RREADY + FAIRNESS
    // ============================================================

    reg random_ready_enable;
    integer stall_counter;
    reg random_ready_value;

    initial begin
        random_ready_enable = 1'b0;
        stall_counter       = 0;
        random_ready_value  = 1'b0;
    end

    always @(negedge clk) begin

        if (!rst_n) begin
            r_drain_rready <= 1'b0;
            stall_counter  = 0;
        end
        else if (random_ready_enable) begin
            // Generate random value
            random_ready_value = $urandom_range(0, 1);

            // Fairness: Không cho RREADY thấp quá 5 cycle liên tiếp.
            if (stall_counter >= 5) begin
                r_drain_rready <= 1'b1;
                stall_counter  = 0;
            end
            else begin
                r_drain_rready <= random_ready_value;

                if (random_ready_value == 1'b0)
                    stall_counter = stall_counter + 1;
                else
                    stall_counter = 0;
            end
        end
    end

    // ============================================================
    // 6. WAIT FOR BURST
    // ============================================================

    task wait_burst_done;
        begin
            wait (!in_burst);

            // Chờ thêm một clock để DUT trở về IDLE
            @(posedge clk);

            total_tests_passed = total_tests_passed + 1;
        end
    endtask

    // ============================================================
    // 7. TEST MATRIX
    // ============================================================

    integer i;

    initial begin

        $display("========================================");
        $display("FW READ DRAIN TESTBENCH");
        $display("========================================");

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        rst_n            = 1'b0;
        acl_r_fault      = 1'b0;
        acl_r_id         = 4'd0;
        acl_r_len        = 8'd0;
        acl_r_err_mode   = 1'b0;
        r_drain_rready   = 1'b0;

        #15;

        rst_n = 1'b1;

        // ========================================================
        // RD-LEN-00
        // ========================================================
        $display("RUN RD-LEN-00");
        @(negedge clk);
        r_drain_rready = 1'b1;
        accept_denied_ar(4'h0, 8'd0, 1'b1);
        wait_burst_done();

        // ========================================================
        // RD-LEN-03
        // ========================================================
        $display("RUN RD-LEN-03");
        @(negedge clk);
        r_drain_rready = 1'b1;
        accept_denied_ar(4'h1, 8'd3, 1'b1);
        wait_burst_done();

        // ========================================================
        // RD-LEN-15
        // ========================================================
        $display("RUN RD-LEN-15");
        @(negedge clk);
        r_drain_rready = 1'b1;
        accept_denied_ar(4'h2, 8'd15, 1'b1);
        wait_burst_done();

        // ========================================================
        // RD-STL-01: Stall trước beat đầu
        // ========================================================
        $display("RUN RD-STL-01");
        @(negedge clk);
        r_drain_rready = 1'b0;
        accept_denied_ar(4'h3, 8'd1, 1'b1);
        repeat (3) @(posedge clk);
        @(negedge clk);
        r_drain_rready = 1'b1;
        wait_burst_done();

        // ========================================================
        // RD-STL-02: Stall giữa burst
        // ========================================================
        $display("RUN RD-STL-02");
        accept_denied_ar(4'h4, 8'd3, 1'b1);

        // Beat 0
        @(negedge clk);
        r_drain_rready = 1'b1;
        @(posedge clk);

        // Stall beat 1
        @(negedge clk);
        r_drain_rready = 1'b0;
        repeat (3) @(posedge clk);

        // Beat 1
        @(negedge clk);
        r_drain_rready = 1'b1;
        @(posedge clk);

        // Beat 2
        @(negedge clk);
        r_drain_rready = 1'b1;
        @(posedge clk);

        // ========================================================
        // RD-STL-03: Stall final beat
        // ========================================================
        @(negedge clk);
        r_drain_rready = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        r_drain_rready = 1'b1;
        wait_burst_done();

        // ========================================================
        // RD-TMO-01: Response backpressure beyond watchdog period
        // ========================================================
        $display("RUN RD-TMO-01");
        @(negedge clk);
        r_drain_rready = 1'b0;
        accept_denied_ar(4'h9, 8'd0, 1'b1);

        // Once RVALID is asserted, it must remain stable until handshake.
        // A response-channel stall is not a legal reason to drop RVALID.
        repeat (260) begin
            @(posedge clk); #1;
            if (!r_drain_rvalid)
                $fatal(1, "RVALID dropped during prolonged response backpressure.");
            if (r_drain_rid !== 4'h9 ||
                r_drain_rdata !== 32'h0000_0000 ||
                r_drain_rresp !== 2'b11 ||
                r_drain_rlast !== 1'b1)
                $fatal(1, "R payload changed during prolonged response backpressure.");
        end

        @(negedge clk);
        r_drain_rready = 1'b1;
        wait_burst_done();

        // ========================================================
        // RD-MOD-01: DECERR mode
        // ========================================================
        $display("RUN RD-MOD-01");
        @(negedge clk);
        r_drain_rready = 1'b1;
        accept_denied_ar(4'h5, 8'd2, 1'b1);
        wait_burst_done();

        // ========================================================
        // RD-MOD-02 + RD-SNP-01: OKAY honeypot + snapshot mutation
        // ========================================================
        $display("RUN RD-MOD-02 & RD-SNP-01");
        @(negedge clk);
        r_drain_rready = 1'b1;
        accept_denied_ar(4'h6, 8'd2, 1'b0);

        // Thay đổi live inputs sau khi đã accept.
        // Burst hiện tại KHÔNG được thay đổi.
        @(negedge clk);
        acl_r_err_mode = 1'b1;
        acl_r_id       = 4'hF;
        wait_burst_done();

        // ========================================================
        // RD-OWN-01: Attempt second owner trong khi đang GEN
        // ========================================================
        $display("RUN RD-OWN-01");
        @(negedge clk);
        r_drain_rready = 1'b0;
        accept_denied_ar(4'h7, 8'd1, 1'b1);

        // Chờ DUT đang ở GEN và bị stall
        @(posedge clk);
        @(negedge clk);

        // Bắn owner thứ hai
        acl_r_fault = 1'b1;
        acl_r_id    = 4'hA;
        acl_r_len   = 8'd5;
        acl_r_err_mode = 1'b0;
        @(posedge clk);
        @(negedge clk);
        acl_r_fault = 1'b0;

        // Owner cũ phải vẫn còn nguyên
        r_drain_rready = 1'b1;
        wait_burst_done();

        // ========================================================
        // RD-RST-01: Reset giữa burst
        // ========================================================
        $display("RUN RD-RST-01");
        @(negedge clk);
        r_drain_rready = 1'b1;
        accept_denied_ar(4'h8, 8'd5, 1'b1);
        @(posedge clk);
        @(posedge clk);

        // Reset giữa burst
        rst_n = 1'b0;
        #1;
        if (r_drain_rvalid)
            $fatal(1, "RESET DID NOT LOWER RVALID.");
        @(posedge clk);
        rst_n = 1'b1;
        in_burst = 1'b0;

        // ========================================================
        // RD-RND-01: 1000 Random Bursts
        // ========================================================
        $display("RUN RD-RND-01 (1000 Random Bursts)");
        random_ready_enable = 1'b1;

        for (i = 0; i < 1000; i = i + 1) begin
            accept_denied_ar(
                $urandom_range(0, 15),
                $urandom_range(0, 15),
                $urandom_range(0, 1)
            );
            wait_burst_done();
        end

        random_ready_enable = 1'b0;
        @(negedge clk);
        r_drain_rready = 1'b1;

        // ========================================================
        // PASS
        // ========================================================
        $display("========================================");
        $display("PASS: tb_fw_read_drain");
        $display("Total completed bursts: %0d", total_tests_passed);
        $display("========================================");

        $finish;
    end

endmodule
