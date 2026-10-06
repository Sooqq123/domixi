`timescale 1ns / 1ps

module tb_dma_apb_slave;

    localparam [31:0] DMA_APB_BASE = 32'h1000_1000;

    // --- Signals ---
    reg clk;
    reg rst_n;
    // APB Signals
    reg         psel, penable, pwrite;
    reg  [31:0] paddr, pwdata;
    wire [31:0] prdata;
    wire        pready, pslverr;
    
    // Internal Signals (Outputs of Slave)
    wire [31:0] cfg_src_addr, cfg_dst_addr, cfg_byte_len;
    wire        cfg_start, irq_en;
    wire        status_done_sticky, status_error_sticky;
    
    // Internal Inputs (Status from Core)
    reg         status_done_event, status_error_event, status_busy;
    reg         cfg_start_seen;
    integer     fail_count;

    // --- Instantiate DUT ---
    dma_apb_slave u_dut (
        .pclk(clk), .presetn(rst_n),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata),
        .pready(pready), .pslverr(pslverr),
        .cfg_src_addr(cfg_src_addr), .cfg_dst_addr(cfg_dst_addr),
        .cfg_byte_len(cfg_byte_len), .cfg_start(cfg_start), .irq_en(irq_en),
        .status_busy(status_busy),
        .status_done_event(status_done_event), .status_error_event(status_error_event),
        .status_done_sticky(status_done_sticky), .status_error_sticky(status_error_sticky)
    );

    // --- Clock Generation ---
    initial clk = 0;
    always #5 clk = ~clk;

    // A hung APB transaction or missing terminal condition must fail the test.
    initial begin
        #20000;
        $fatal(1, "[TIMEOUT] tb_dma_apb_slave exceeded 20 us");
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_start_seen <= 1'b0;
        end else begin
            if (cfg_start) cfg_start_seen <= 1'b1;
        end
    end

    task pulse_status_done_event;
        begin
            @(negedge clk);
            status_done_event = 1'b1;
            @(posedge clk);
            #1 status_done_event = 1'b0;
        end
    endtask

    task pulse_status_error_event;
        begin
            @(negedge clk);
            status_error_event = 1'b1;
            @(posedge clk);
            #1 status_error_event = 1'b0;
        end
    endtask

    // --- APB Tasks ---
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            psel <= 1; pwrite <= 1;
            paddr <= addr; pwdata <= data; penable <= 0;
            @(posedge clk);
            penable <= 1;
            wait(pready);
            @(posedge clk);
            psel <= 0;
            penable <= 0; pwrite <= 0;
        end
    endtask

    task apb_read_and_check(input [31:0] addr, input [31:0] exp_data, input [8*20:1] test_name);
        begin
            @(posedge clk);
            psel <= 1; pwrite <= 0;
            paddr <= addr; penable <= 0;
            @(posedge clk);
            penable <= 1;
            wait(pready);
            #1;
            // Lấy mẫu sau khi ổn định
            if (prdata !== exp_data) begin
                fail_count = fail_count + 1;
                $error("[FAIL] %s - Addr: %h | Exp: %h, Got: %h", test_name, addr, exp_data, prdata);
            end else
                $display("[PASS] %s - Val: %h", test_name, prdata);
            @(posedge clk);
            psel <= 0; penable <= 0;
        end
    endtask

    task apb_read_error_and_check(input [31:0] addr, input [8*20:1] test_name);
        begin
            @(posedge clk);
            psel <= 1; pwrite <= 0;
            paddr <= addr; penable <= 0;
            @(posedge clk);
            penable <= 1;
            #1;
            if ((pready !== 1'b1) || (pslverr !== 1'b1) || (prdata !== 32'b0)) begin
                fail_count = fail_count + 1;
                $error("[FAIL] %s - PREADY=%b PSLVERR=%b PRDATA=%h", test_name, pready, pslverr, prdata);
            end else
                $display("[PASS] %s", test_name);
            @(posedge clk);
            psel <= 0; penable <= 0;
        end
    endtask

    task apb_write_error_and_check(input [31:0] addr, input [31:0] data, input [8*20:1] test_name);
        begin
            @(posedge clk);
            psel <= 1; pwrite <= 1;
            paddr <= addr; pwdata <= data; penable <= 0;
            @(posedge clk);
            penable <= 1;
            #1;
            if ((pready !== 1'b1) || (pslverr !== 1'b1)) begin
                fail_count = fail_count + 1;
                $error("[FAIL] %s - PREADY=%b PSLVERR=%b", test_name, pready, pslverr);
            end else
                $display("[PASS] %s", test_name);
            @(posedge clk);
            psel <= 0; penable <= 0; pwrite <= 0;
        end
    endtask

    task apb_w1c_with_hw_set;
        begin
            // Present a W1C write and both hardware-set events on the same
            // active APB access edge. Hardware-set must win.
            @(negedge clk);
            psel = 1'b1;
            pwrite = 1'b1;
            paddr = DMA_APB_BASE + 32'h10;
            pwdata = 32'h0000_0006;
            penable = 1'b0;
            @(negedge clk);
            penable = 1'b1;
            status_done_event = 1'b1;
            status_error_event = 1'b1;
            @(posedge clk);
            #1;
            status_done_event = 1'b0;
            status_error_event = 1'b0;
            @(negedge clk);
            psel = 1'b0;
            penable = 1'b0;
            pwrite = 1'b0;
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        $dumpfile("apb_slave_wave.vcd");
        $dumpvars(0, tb_dma_apb_slave);
        
        // Init
        rst_n = 0; psel = 0; penable = 0;
        pwrite = 0;
        fail_count = 0;
        status_done_event = 0; status_error_event = 0; status_busy = 0;
        #20; rst_n = 1; #10;

        $display("\n=== TEST 1: GHI/ĐỌC CÁC THANH GHI CẤU HÌNH ===");
        apb_write(DMA_APB_BASE + 32'h04, 32'hAAAA_0000); // Src Addr
        apb_write(DMA_APB_BASE + 32'h08, 32'hBBBB_0000); // Dst Addr
        apb_write(DMA_APB_BASE + 32'h0C, 32'd256);       // Length

        apb_read_and_check(DMA_APB_BASE + 32'h04, 32'hAAAA_0000, "Read Source Addr");
        apb_read_and_check(DMA_APB_BASE + 32'h08, 32'hBBBB_0000, "Read Dest Addr  ");
        apb_read_and_check(DMA_APB_BASE + 32'h0C, 32'd256,       "Read Byte Length");

        $display("\n=== TEST 2: ĐỌC THANH GHI TRẠNG THÁI (STATUS) ===");
        status_busy = 1;
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0001, "Status: Busy=1, Done=0");
        
        status_busy = 0;
        pulse_status_done_event;
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0002, "Status: Busy=0, Done=1");

        pulse_status_error_event;
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0006, "Status: Done=1, Error=1");

        apb_write(DMA_APB_BASE + 32'h10, 32'h0000_0002);
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0004, "Status: Done W1C");
        apb_write(DMA_APB_BASE + 32'h10, 32'h0000_0004);
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0000, "Status: Error W1C");

        $display("\n=== TEST 3: START-WHILE-BUSY, STICKY STATUS, AND IRQ_EN ===");

        // Seed both sticky bits. START while BUSY is a no-op and must not
        // generate cfg_start or clear either sticky bit.
        pulse_status_done_event;
        pulse_status_error_event;
        cfg_start_seen = 1'b0;
        status_busy = 1'b1;
        apb_write(DMA_APB_BASE + 32'h00, 32'h0000_0003);
        @(posedge clk);
        #1;
        if (cfg_start_seen || cfg_start)
            $fatal(1, "[FAIL] START while BUSY generated cfg_start");
        if (!irq_en)
            $fatal(1, "[FAIL] IRQ_EN write was lost while START was ignored");
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0007,
                           "Busy START preserves sticky");

        // START while idle must pulse, but it must still preserve DONE/ERROR.
        status_busy = 1'b0;
        cfg_start_seen = 1'b0;
        apb_write(DMA_APB_BASE + 32'h00, 32'h0000_0003); // Set START (bit 0) va IRQ_EN (bit 1)
        
        @(posedge clk);
        #1;
        if (cfg_start_seen && irq_en)
            $display("[PASS] START pulse and IRQ_EN generated correctly");
        else begin
            fail_count = fail_count + 1;
            $error("[FAIL] START pulse or IRQ_EN failed");
        end

        if (cfg_start === 0)
            $display("[PASS] START pulse auto-cleared");
        else begin
            fail_count = fail_count + 1;
            $error("[FAIL] START pulse did not clear");
        end

        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0006,
                           "Idle START preserves sticky");

        // W1C and hardware-set in the same cycle: hardware-set wins.
        apb_w1c_with_hw_set;
        apb_read_and_check(DMA_APB_BASE + 32'h10, 32'h0000_0006,
                           "Hardware set wins over W1C");

        $display("\n=== TEST 4: APB 32-BIT ADDRESS WINDOW ===");
        apb_read_error_and_check(32'h1000_0004, "Reject wrong APB base address");
        apb_write_error_and_check(32'h1000_0004, 32'hDEAD_BEEF, "Ignore invalid APB write");
        if (cfg_src_addr !== 32'hAAAA_0000) begin
            fail_count = fail_count + 1;
            $error("[FAIL] Invalid APB access changed source address");
        end
             
        // End simulation
        #50;
        if (fail_count != 0)
            $fatal(1, "[FAIL] tb_dma_apb_slave recorded %0d check failures", fail_count);
        $display("[PASS] tb_dma_apb_slave completed with no check failures");
        $finish;
    end // End of initial block

endmodule // End of tb_dma_apb_slave
