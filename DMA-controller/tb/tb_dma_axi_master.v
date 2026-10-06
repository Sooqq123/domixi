`timescale 1ns / 1ps

module tb_dma_axi_master;

    localparam integer FIFO_DEPTH = 32;

    reg         clk;
    reg         rst_n;
    reg  [31:0] cfg_src_addr;
    reg  [31:0] cfg_dst_addr;
    reg  [31:0] cfg_byte_len;
    reg         cfg_start;

    wire        status_busy;
    wire        status_done;
    wire        status_error;

    wire        fifo_full;
    wire        fifo_empty;
    reg  [5:0]  fifo_count;
    wire        fifo_wr_en;
    wire [31:0] fifo_wdata;
    wire        fifo_rd_en;
    wire        fifo_flush;
    reg  [31:0] fifo_rdata;

    wire [31:0] araddr;
    wire [3:0]  arid;
    wire [7:0]  arlen;
    wire [2:0]  arsize;
    wire [1:0]  arburst;
    wire [2:0]  prot;
    wire        arvalid;
    wire        arready;
    reg  [31:0] rdata;
    reg         rlast;
    reg         rvalid;
    reg  [3:0]  rid;
    reg  [1:0]  rresp;
    wire        rready;

    wire [31:0] awaddr;
    wire [3:0]  awid;
    wire [7:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awvalid;
    wire        awready;
    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire        wlast;
    wire        wvalid;
    wire        wready;
    reg  [3:0]  bid;
    reg  [1:0]  bresp;
    reg         bvalid;
    wire        bready;

    reg         allow_arready;
    reg         allow_awready;
    reg         allow_wready;
    reg         inject_r_error;
    reg  [7:0]  inject_r_error_beat;
    reg         inject_b_error;
    reg         inject_rid_error;
    reg         inject_bid_error;
    reg         inject_early_rlast;
    reg  [7:0]  inject_early_rlast_beat;
    reg         inject_missing_final_rlast;

    reg         read_active;
    reg  [7:0]  read_index;
    reg  [7:0]  read_len;
    reg         write_active;
    reg  [7:0]  write_index;
    reg  [7:0]  write_len;

    integer     ar_handshake_count;
    integer     aw_handshake_count;
    integer     r_handshake_count;
    integer     w_handshake_count;
    integer     done_pulse_count;
    integer     error_pulse_count;

    reg         aw_owned;
    reg         ar_stalled;
    reg  [31:0] araddr_stalled;
    reg  [7:0]  arlen_stalled;
    reg         aw_stalled;
    reg  [31:0] awaddr_stalled;
    reg  [7:0]  awlen_stalled;
    reg         w_stalled;
    reg  [31:0] wdata_stalled;
    reg         wlast_stalled;

    assign arready    = allow_arready;
    assign awready    = allow_awready;
    assign wready     = allow_wready;
    assign fifo_empty = (fifo_count == 6'd0);
    assign fifo_full  = (fifo_count == FIFO_DEPTH);

    dma_axi_master #(.FIFO_DEPTH(FIFO_DEPTH), .ID_WIDTH(4)) u_dut (
        .aclk(clk), .aresetn(rst_n),
        .cfg_src_addr(cfg_src_addr), .cfg_dst_addr(cfg_dst_addr),
        .cfg_byte_len(cfg_byte_len), .cfg_start(cfg_start),
        .status_busy(status_busy), .status_done(status_done),
        .status_error(status_error),
        .fifo_full(fifo_full), .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .fifo_wr_en(fifo_wr_en), .fifo_wdata(fifo_wdata),
        .fifo_rd_en(fifo_rd_en), .fifo_flush(fifo_flush), .fifo_rdata(fifo_rdata),
        .m_axi_araddr(araddr), .m_axi_arid(arid), .m_axi_arlen(arlen),
        .m_axi_arsize(arsize), .m_axi_arburst(arburst), .m_axi_prot(prot),
        .m_axi_arvalid(arvalid), .m_axi_arready(arready),
        .m_axi_rdata(rdata), .m_axi_rlast(rlast), .m_axi_rvalid(rvalid),
        .m_axi_rid(rid), .m_axi_rresp(rresp), .m_axi_rready(rready),
        .m_axi_awaddr(awaddr), .m_axi_awid(awid), .m_axi_awlen(awlen),
        .m_axi_awsize(awsize), .m_axi_awburst(awburst),
        .m_axi_awvalid(awvalid), .m_axi_awready(awready),
        .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wlast(wlast),
        .m_axi_wvalid(wvalid), .m_axi_wready(wready),
        .m_axi_bid(bid), .m_axi_bresp(bresp),
        .m_axi_bvalid(bvalid), .m_axi_bready(bready)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        #200000;
        $fatal(1, "[TIMEOUT] tb_dma_axi_master exceeded 200 us");
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= 6'd0;
            fifo_rdata <= 32'hD000_0000;
        end else if (fifo_flush) begin
            fifo_count <= 6'd0;
        end else begin
            case ({fifo_wr_en && !fifo_full, fifo_rd_en && !fifo_empty})
                2'b10: fifo_count <= fifo_count + 6'd1;
                2'b01: fifo_count <= fifo_count - 6'd1;
                default: fifo_count <= fifo_count;
            endcase
            if (fifo_rd_en && !fifo_empty)
                fifo_rdata <= fifo_rdata + 32'd1;
        end
    end

    // AXI read responder. Response/ID errors retain correct framing, while
    // dedicated controls inject early or missing-final RLAST violations.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_active        <= 1'b0;
            read_index         <= 8'd0;
            read_len           <= 8'd0;
            rdata              <= 32'd0;
            rlast              <= 1'b0;
            rvalid             <= 1'b0;
            rid                <= 4'd0;
            rresp              <= 2'b00;
            ar_handshake_count <= 0;
            r_handshake_count  <= 0;
        end else begin
            if (arvalid && arready) begin
                if (read_active || rvalid)
                    $fatal(1, "[FAIL] Multiple outstanding AR transactions");
                read_active <= 1'b1;
                read_index  <= 8'd0;
                read_len    <= arlen;
                ar_handshake_count <= ar_handshake_count + 1;
            end

            if (read_active && !rvalid) begin
                rvalid <= 1'b1;
                rdata  <= 32'hCAFE_0000;
                rlast  <= (inject_early_rlast &&
                           (inject_early_rlast_beat == 8'd0)) ||
                          (!inject_missing_final_rlast &&
                           (read_len == 8'd0));
                rid    <= (inject_rid_error && (inject_r_error_beat == 8'd0)) ? 4'h1 : 4'h0;
                rresp  <= (inject_r_error && (inject_r_error_beat == 8'd0)) ? 2'b10 : 2'b00;
            end else if (rvalid && rready) begin
                r_handshake_count <= r_handshake_count + 1;
                if (rlast) begin
                    rvalid      <= 1'b0;
                    rlast       <= 1'b0;
                    rid         <= 4'h0;
                    rresp       <= 2'b00;
                    read_active <= 1'b0;
                end else begin
                    read_index <= read_index + 8'd1;
                    rdata      <= rdata + 32'd1;
                    rlast      <= (inject_early_rlast &&
                                   ((read_index + 8'd1) == inject_early_rlast_beat)) ||
                                  (!inject_missing_final_rlast &&
                                   ((read_index + 8'd1) == read_len));
                    rid        <= (inject_rid_error &&
                                   ((read_index + 8'd1) == inject_r_error_beat)) ? 4'h1 : 4'h0;
                    rresp      <= (inject_r_error &&
                                   ((read_index + 8'd1) == inject_r_error_beat)) ? 2'b10 : 2'b00;
                end
            end
        end
    end

    // AXI write responder. W without an accepted AW is a hard failure.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_active       <= 1'b0;
            write_index        <= 8'd0;
            write_len          <= 8'd0;
            bvalid             <= 1'b0;
            bid                <= 4'd0;
            bresp              <= 2'b00;
            aw_handshake_count <= 0;
            w_handshake_count  <= 0;
        end else begin
            if (awvalid && awready) begin
                if (write_active || bvalid)
                    $fatal(1, "[FAIL] Multiple outstanding AW transactions");
                write_active <= 1'b1;
                write_index  <= 8'd0;
                write_len    <= awlen;
                aw_handshake_count <= aw_handshake_count + 1;
            end

            if (wvalid && wready) begin
                if (!write_active)
                    $fatal(1, "[FAIL] W handshake occurred before AW handshake");
                if (wlast !== (write_index == write_len))
                    $fatal(1, "[FAIL] WLAST does not match AWLEN");
                w_handshake_count <= w_handshake_count + 1;
                if (wlast) begin
                    write_active <= 1'b0;
                    bvalid       <= 1'b1;
                    bid          <= inject_bid_error ? 4'h1 : 4'h0;
                    bresp        <= inject_b_error ? 2'b10 : 2'b00;
                end else begin
                    write_index <= write_index + 8'd1;
                end
            end

            if (bvalid && bready) begin
                bvalid <= 1'b0;
                bid    <= 4'h0;
                bresp  <= 2'b00;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_owned          <= 1'b0;
            ar_stalled        <= 1'b0;
            aw_stalled        <= 1'b0;
            w_stalled         <= 1'b0;
            done_pulse_count  <= 0;
            error_pulse_count <= 0;
        end else begin
            if (arvalid && ((arid != 4'h0) || (prot != 3'b001)))
                $fatal(1, "[FAIL] ARID/ARPROT violates the V2.4.1 contract");
            if (awvalid && ((awid != 4'h0) || (prot != 3'b001)))
                $fatal(1, "[FAIL] AWID/AWPROT violates the V2.4.1 contract");

            if (awvalid && awready)
                aw_owned <= 1'b1;
            if (bvalid && bready)
                aw_owned <= 1'b0;

            if (wvalid && !aw_owned)
                $fatal(1, "[FAIL] WVALID asserted before AW handshake");
            if (fifo_rd_en && !aw_owned)
                $fatal(1, "[FAIL] FIFO popped before AW handshake");

            if (arvalid && !arready) begin
                if (ar_stalled && ((araddr !== araddr_stalled) ||
                                   (arlen !== arlen_stalled)))
                    $fatal(1, "[FAIL] AR payload changed while stalled");
                ar_stalled     <= 1'b1;
                araddr_stalled <= araddr;
                arlen_stalled  <= arlen;
            end else begin
                ar_stalled <= 1'b0;
            end

            if (awvalid && !awready) begin
                if (aw_stalled && ((awaddr !== awaddr_stalled) || (awlen !== awlen_stalled)))
                    $fatal(1, "[FAIL] AW payload changed while stalled");
                aw_stalled     <= 1'b1;
                awaddr_stalled <= awaddr;
                awlen_stalled  <= awlen;
            end else begin
                aw_stalled <= 1'b0;
            end

            if (wvalid && !wready) begin
                if (w_stalled && ((wdata !== wdata_stalled) || (wlast !== wlast_stalled)))
                    $fatal(1, "[FAIL] W payload changed while stalled");
                w_stalled     <= 1'b1;
                wdata_stalled <= wdata;
                wlast_stalled <= wlast;
            end else begin
                w_stalled <= 1'b0;
            end

            if (status_done)
                done_pulse_count <= done_pulse_count + 1;
            if (status_error)
                error_pulse_count <= error_pulse_count + 1;
            if (status_done && status_error)
                $fatal(1, "[FAIL] DONE and ERROR asserted together");
        end
    end

    task reset_dut;
        begin
            rst_n = 1'b0;
            cfg_start = 1'b0;
            allow_arready = 1'b1;
            allow_awready = 1'b1;
            allow_wready = 1'b1;
            inject_r_error = 1'b0;
            inject_r_error_beat = 8'd0;
            inject_b_error = 1'b0;
            inject_rid_error = 1'b0;
            inject_bid_error = 1'b0;
            inject_early_rlast = 1'b0;
            inject_early_rlast_beat = 8'd0;
            inject_missing_final_rlast = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk);
            cfg_start = 1'b1;
            @(negedge clk);
            cfg_start = 1'b0;
        end
    endtask

    task wait_for_arvalid;
        integer cycles;
        begin
            cycles = 0;
            while (!arvalid && (cycles < 1000)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (!arvalid)
                $fatal(1, "[TIMEOUT] ARVALID was not asserted");
        end
    endtask

    task wait_for_awvalid;
        integer cycles;
        begin
            cycles = 0;
            while (!awvalid && (cycles < 1000)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (!awvalid)
                $fatal(1, "[TIMEOUT] AWVALID was not asserted");
        end
    endtask

    task wait_for_wvalid;
        integer cycles;
        begin
            cycles = 0;
            while (!wvalid && (cycles < 1000)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (!wvalid)
                $fatal(1, "[TIMEOUT] WVALID was not asserted");
        end
    endtask

    task wait_for_terminal;
        input expect_error;
        integer cycles;
        begin
            cycles = 0;
            while (!(status_done || status_error) && (cycles < 3000)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (!(status_done || status_error))
                $fatal(1, "[TIMEOUT] DMA did not produce a terminal event");
            if (expect_error && !status_error)
                $fatal(1, "[FAIL] Failed transfer produced DONE instead of ERROR");
            if (!expect_error && !status_done)
                $fatal(1, "[FAIL] Successful transfer produced ERROR");
            @(posedge clk);
            #1;
            if (status_done || status_error)
                $fatal(1, "[FAIL] Terminal status event was wider than one cycle");
        end
    endtask

    integer i;
    reg [31:0] held_araddr;
    reg [7:0]  held_arlen;
    reg [31:0] held_awaddr;
    reg [7:0]  held_awlen;
    reg [31:0] held_wdata;
    reg        held_wlast;

    initial begin
        cfg_src_addr = 32'h0000_1000;
        cfg_dst_addr = 32'h0000_2000;
        cfg_byte_len = 32'd64;

        $display("=== TEST 1: AW STALL, W-AFTER-AW, AND PAYLOAD STABILITY ===");
        reset_dut;
        allow_awready = 1'b0;
        pulse_start;
        wait_for_awvalid;
        held_awaddr = awaddr;
        held_awlen  = awlen;
        repeat (6) begin
            @(posedge clk);
            #1;
            if (!awvalid || (awaddr !== held_awaddr) || (awlen !== held_awlen))
                $fatal(1, "[FAIL] AW VALID/payload was not held during stall");
            if (wvalid || fifo_rd_en)
                $fatal(1, "[FAIL] W channel or FIFO pop preceded AW handshake");
        end

        @(negedge clk);
        allow_awready = 1'b1;
        allow_wready = 1'b0;
        wait_for_wvalid;
        held_wdata = wdata;
        held_wlast = wlast;
        repeat (5) begin
            @(posedge clk);
            #1;
            if (!wvalid || (wdata !== held_wdata) || (wlast !== held_wlast))
                $fatal(1, "[FAIL] W VALID/payload was not held during stall");
            if (fifo_rd_en)
                $fatal(1, "[FAIL] FIFO popped while WREADY was low");
        end
        @(negedge clk);
        allow_wready = 1'b1;
        wait_for_terminal(1'b0);
        if ((done_pulse_count != 1) || (error_pulse_count != 0))
            $fatal(1, "[FAIL] Success terminal pulse count is incorrect");
        $display("[PASS] AW/W ordering and payload stability");

        $display("=== TEST 2: AR PAYLOAD STABILITY UNDER STALL ===");
        cfg_byte_len = 32'd64;
        reset_dut;
        allow_arready = 1'b0;
        pulse_start;
        wait_for_arvalid;
        held_araddr = araddr;
        held_arlen  = arlen;
        repeat (6) begin
            @(posedge clk);
            #1;
            if (!arvalid || (araddr !== held_araddr) || (arlen !== held_arlen))
                $fatal(1, "[FAIL] AR VALID/payload was not held during stall");
        end
        @(negedge clk);
        allow_arready = 1'b1;
        wait_for_terminal(1'b0);
        if ((ar_handshake_count != 1) || (done_pulse_count != 1) ||
            (error_pulse_count != 0))
            $fatal(1, "[FAIL] AR stall test terminal/handshake count is incorrect");
        $display("[PASS] AR payload stability");

        $display("=== TEST 3: RRESP ERROR DRAINS ACCEPTED AR AND ABORTS ===");
        cfg_byte_len = 32'd128;
        reset_dut;
        inject_r_error = 1'b1;
        inject_r_error_beat = 8'd3;
        pulse_start;
        wait_for_terminal(1'b1);
        if (ar_handshake_count != 1)
            $fatal(1, "[FAIL] RRESP abort allowed a new AR: count=%0d", ar_handshake_count);
        if (r_handshake_count != 16)
            $fatal(1, "[FAIL] Accepted AR was not drained to RLAST: beats=%0d", r_handshake_count);
        if (!fifo_empty || (done_pulse_count != 0) || (error_pulse_count != 1))
            $fatal(1, "[FAIL] RRESP abort terminal/flush behavior is incorrect");
        $display("[PASS] RRESP error abort, drain, flush, and terminal ERROR");

        $display("=== TEST 4: BRESP ERROR ABORTS WITHOUT A DONE EVENT ===");
        cfg_byte_len = 32'd128;
        reset_dut;
        inject_b_error = 1'b1;
        pulse_start;
        wait_for_terminal(1'b1);
        if (aw_handshake_count != 1)
            $fatal(1, "[FAIL] BRESP abort allowed another AW: count=%0d", aw_handshake_count);
        if (!fifo_empty || (done_pulse_count != 0) || (error_pulse_count != 1))
            $fatal(1, "[FAIL] BRESP abort terminal/flush behavior is incorrect");
        $display("[PASS] BRESP error abort, flush, and terminal ERROR");

        $display("=== TEST 5: RID OWNERSHIP MISMATCH ABORTS ===");
        cfg_byte_len = 32'd64;
        reset_dut;
        inject_rid_error = 1'b1;
        inject_r_error_beat = 8'd2;
        pulse_start;
        wait_for_terminal(1'b1);
        if ((done_pulse_count != 0) || (error_pulse_count != 1) || !fifo_empty)
            $fatal(1, "[FAIL] RID mismatch was not handled as terminal ERROR");
        $display("[PASS] RID ownership validation");

        $display("=== TEST 6: BID OWNERSHIP MISMATCH ABORTS ===");
        cfg_byte_len = 32'd64;
        reset_dut;
        inject_bid_error = 1'b1;
        pulse_start;
        wait_for_terminal(1'b1);
        if ((done_pulse_count != 0) || (error_pulse_count != 1) || !fifo_empty)
            $fatal(1, "[FAIL] BID mismatch was not handled as terminal ERROR");
        $display("[PASS] BID ownership validation");

        $display("=== TEST 7: EARLY RLAST ABORTS FINITELY ===");
        cfg_byte_len = 32'd64;
        reset_dut;
        inject_early_rlast = 1'b1;
        inject_early_rlast_beat = 8'd2;
        pulse_start;
        wait_for_terminal(1'b1);
        if ((ar_handshake_count != 1) || (r_handshake_count != 3))
            $fatal(1, "[FAIL] Early RLAST did not close at the violating beat");
        if (!fifo_empty || (done_pulse_count != 0) ||
            (error_pulse_count != 1) || rready)
            $fatal(1, "[FAIL] Early RLAST abort/flush/terminal behavior is incorrect");
        $display("[PASS] Early RLAST framing violation closes with terminal ERROR");

        $display("=== TEST 8: MISSING FINAL RLAST ABORTS FINITELY ===");
        cfg_byte_len = 32'd64;
        reset_dut;
        inject_missing_final_rlast = 1'b1;
        pulse_start;
        wait_for_terminal(1'b1);
        if ((ar_handshake_count != 1) || (r_handshake_count != 16))
            $fatal(1, "[FAIL] Missing final RLAST did not close after ARLEN+1 beats");
        if (!fifo_empty || (done_pulse_count != 0) ||
            (error_pulse_count != 1) || rready)
            $fatal(1, "[FAIL] Missing final RLAST abort/flush/terminal behavior is incorrect");
        $display("[PASS] Missing final RLAST closes with terminal ERROR");

        $display("[PASS] tb_dma_axi_master V2.4.1 negative regression");
        $finish;
    end

endmodule
