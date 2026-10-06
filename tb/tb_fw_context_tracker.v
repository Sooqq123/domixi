`timescale 1ns/1ps

module tb_fw_context_tracker;
    reg clk;
    reg rst_n;

    reg         dma_ctx_valid;
    reg  [31:0] dma_ctx_src_addr;
    reg  [31:0] dma_ctx_dst_addr;
    reg  [31:0] dma_ctx_byte_len;
    reg         dma_ctx_done;
    reg         auto_ctx_en;

    wire [31:0] dyn_rgn4_base;
    wire [31:0] dyn_rgn4_limit;
    wire        dyn_rgn4_active;
    wire [31:0] dyn_rgn5_base;
    wire [31:0] dyn_rgn5_limit;
    wire        dyn_rgn5_active;

    wire        ctx_fault_event_valid;
    wire [3:0]  ctx_fault_event_code;
    wire [31:0] ctx_fault_event_addr;
    wire [3:0]  ctx_fault_event_id;

    integer errors = 0;
    integer test_step = 0;

    fw_context_tracker dut (
        .clk(clk),
        .rst_n(rst_n),
        .dma_ctx_valid(dma_ctx_valid),
        .dma_ctx_src_addr(dma_ctx_src_addr),
        .dma_ctx_dst_addr(dma_ctx_dst_addr),
        .dma_ctx_byte_len(dma_ctx_byte_len),
        .dma_ctx_done(dma_ctx_done),
        .auto_ctx_en(auto_ctx_en),
        .dyn_rgn4_base(dyn_rgn4_base),
        .dyn_rgn4_limit(dyn_rgn4_limit),
        .dyn_rgn4_active(dyn_rgn4_active),
        .dyn_rgn5_base(dyn_rgn5_base),
        .dyn_rgn5_limit(dyn_rgn5_limit),
        .dyn_rgn5_active(dyn_rgn5_active),
        .ctx_fault_event_valid(ctx_fault_event_valid),
        .ctx_fault_event_code(ctx_fault_event_code),
        .ctx_fault_event_addr(ctx_fault_event_addr),
        .ctx_fault_event_id(ctx_fault_event_id)
    );

    // Clock generator: 100MHz (10ns period)
    always #5 clk = ~clk;

    task check_assert;
        input condition;
        input [8*120-1:0] msg;
        begin
            if (!condition) begin
                $display("[ERROR] Step %0d at %0t ps: %0s", test_step, $time, msg);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        dma_ctx_valid = 0;
        dma_ctx_src_addr = 32'h0;
        dma_ctx_dst_addr = 32'h0;
        dma_ctx_byte_len = 32'h0;
        dma_ctx_done = 0;
        auto_ctx_en = 1;

        $display("------------------------------------------------------------");
        $display("   STARTING TESTBENCH: tb_fw_context_tracker");
        $display("------------------------------------------------------------");

        // ------------------------------------------------------------
        // TC01: Reset check
        // ------------------------------------------------------------
        test_step = 1;
        #20;
        check_assert(dyn_rgn4_active == 1'b0, "TC01: dyn_rgn4_active must be 0 on reset");
        check_assert(dyn_rgn5_active == 1'b0, "TC01: dyn_rgn5_active must be 0 on reset");
        check_assert(dyn_rgn4_base == 32'h0, "TC01: dyn_rgn4_base must be 0 on reset");
        check_assert(dyn_rgn5_base == 32'h0, "TC01: dyn_rgn5_base must be 0 on reset");
        check_assert(ctx_fault_event_valid == 1'b0, "TC01: fault valid must be 0 on reset");
        check_assert(ctx_fault_event_code == 4'b1000, "TC01: fault code must be 4'b1000");
        check_assert(ctx_fault_event_id == 4'h0, "TC01: fault ID must be 4'h0");

        @(negedge clk);
        rst_n = 1;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC02: Valid context allocation (Normal DMA transfer)
        // ------------------------------------------------------------
        test_step = 2;
        @(negedge clk);
        auto_ctx_en = 1;
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0000_0100; // 256 bytes
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b1, "TC02: dyn_rgn4_active must be 1");
        check_assert(dyn_rgn4_base == 32'h1000_0000, "TC02: dyn_rgn4_base mismatch");
        check_assert(dyn_rgn4_limit == 32'h1000_00ff, "TC02: dyn_rgn4_limit mismatch (expected 0x1000_00ff)");
        check_assert(dyn_rgn5_active == 1'b1, "TC02: dyn_rgn5_active must be 1");
        check_assert(dyn_rgn5_base == 32'h2000_0000, "TC02: dyn_rgn5_base mismatch");
        check_assert(dyn_rgn5_limit == 32'h2000_00ff, "TC02: dyn_rgn5_limit mismatch (expected 0x2000_00ff)");
        check_assert(ctx_fault_event_valid == 1'b0, "TC02: No fault expected for valid context");

        // ------------------------------------------------------------
        // TC03: Normal deallocation via dma_ctx_done
        // ------------------------------------------------------------
        test_step = 3;
        @(negedge clk);
        dma_ctx_done = 1;
        dma_ctx_valid = 0;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b0, "TC03: dyn_rgn4_active must be 0 after done");
        check_assert(dyn_rgn5_active == 1'b0, "TC03: dyn_rgn5_active must be 0 after done");
        check_assert(dyn_rgn4_base == 32'h0, "TC03: dyn_rgn4_base must be zeroed");
        check_assert(dyn_rgn5_base == 32'h0, "TC03: dyn_rgn5_base must be zeroed");

        @(negedge clk);
        dma_ctx_done = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC04: Misaligned Source Address Fault
        // ------------------------------------------------------------
        test_step = 4;
        @(negedge clk);
        dma_ctx_src_addr = 32'h1000_0002; // Misaligned: bit 1 is 1
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0000_0040;
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b1, "TC04: Fault pulse expected for misaligned src");
        check_assert(ctx_fault_event_addr == 32'h1000_0002, "TC04: Fault addr mismatch");
        check_assert(dyn_rgn4_active == 1'b0, "TC04: Region 4 must remain inactive on fault");
        check_assert(dyn_rgn5_active == 1'b0, "TC04: Region 5 must remain inactive on fault");

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b0, "TC04: Fault pulse must deassert after 1 cycle");

        @(negedge clk);
        dma_ctx_valid = 0; // Return to IDLE via CTX_WAIT_LOW
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC05: Misaligned Destination Address Fault
        // ------------------------------------------------------------
        test_step = 5;
        @(negedge clk);
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'h2000_0003; // Misaligned
        dma_ctx_byte_len = 32'h0000_0040;
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b1, "TC05: Fault pulse expected for misaligned dst");
        check_assert(ctx_fault_event_addr == 32'h2000_0003, "TC05: Fault addr mismatch");
        check_assert(dyn_rgn4_active == 1'b0, "TC05: Region 4 must remain inactive");
        check_assert(dyn_rgn5_active == 1'b0, "TC05: Region 5 must remain inactive");

        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC06: Misaligned Byte Length Fault
        // ------------------------------------------------------------
        test_step = 6;
        @(negedge clk);
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0000_0041; // Misaligned
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b1, "TC06: Fault pulse expected for misaligned len");
        check_assert(dyn_rgn4_active == 1'b0, "TC06: Region 4 must remain inactive");

        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC07: Zero Length Fault
        // ------------------------------------------------------------
        test_step = 7;
        @(negedge clk);
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0000_0000; // Zero length
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b1, "TC07: Fault pulse expected for zero len");
        check_assert(dyn_rgn4_active == 1'b0, "TC07: Region 4 must remain inactive");

        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC08: 32-bit Address Overflow Fault (Source)
        // ------------------------------------------------------------
        test_step = 8;
        @(negedge clk);
        dma_ctx_src_addr = 32'hFFFF_FFF0;
        dma_ctx_dst_addr = 32'h1000_0000;
        dma_ctx_byte_len = 32'h0000_0020; // src + len overflows 32-bit
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b1, "TC08: Fault pulse expected for src overflow");
        check_assert(ctx_fault_event_addr == 32'hFFFF_FFF0, "TC08: Fault addr should be src_addr");
        check_assert(dyn_rgn4_active == 1'b0, "TC08: Region 4 must remain inactive");

        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC09: 32-bit Address Overflow Fault (Destination)
        // ------------------------------------------------------------
        test_step = 9;
        @(negedge clk);
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'hFFFF_FF00;
        dma_ctx_byte_len = 32'h0000_0200; // dst + len overflows 32-bit
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(ctx_fault_event_valid == 1'b1, "TC09: Fault pulse expected for dst overflow");
        check_assert(ctx_fault_event_addr == 32'hFFFF_FF00, "TC09: Fault addr should be dst_addr");
        check_assert(dyn_rgn5_active == 1'b0, "TC09: Region 5 must remain inactive");

        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC10: Disabled auto_ctx_en ignores valid context
        // ------------------------------------------------------------
        test_step = 10;
        @(negedge clk);
        auto_ctx_en = 0;
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0000_0100;
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b0, "TC10: Region 4 must remain inactive when auto_ctx_en=0");
        check_assert(dyn_rgn5_active == 1'b0, "TC10: Region 5 must remain inactive when auto_ctx_en=0");
        check_assert(ctx_fault_event_valid == 1'b0, "TC10: No fault event when simply disabled");

        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC11: Runtime revocation via disabling auto_ctx_en
        // ------------------------------------------------------------
        test_step = 11;
        @(negedge clk);
        auto_ctx_en = 1;
        dma_ctx_src_addr = 32'h3000_0000;
        dma_ctx_dst_addr = 32'h4000_0000;
        dma_ctx_byte_len = 32'h0000_0080;
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b1, "TC11: Region 4 active before disable");
        check_assert(dyn_rgn5_active == 1'b1, "TC11: Region 5 active before disable");

        // Now disable mid-flight
        @(negedge clk);
        auto_ctx_en = 0;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b0, "TC11: Region 4 revoked after auto_ctx_en=0");
        check_assert(dyn_rgn5_active == 1'b0, "TC11: Region 5 revoked after auto_ctx_en=0");

        @(negedge clk);
        dma_ctx_valid = 0;
        auto_ctx_en = 1;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC12: End exactly at 0xFFFFFFFF (Boundary Test)
        // ------------------------------------------------------------
        test_step = 12;
        @(negedge clk);
        auto_ctx_en = 1;
        dma_ctx_src_addr = 32'hFFFF_0000;
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0001_0000; // 0xFFFF_0000 + 0x0001_0000 - 1 = 0xFFFF_FFFF
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b1, "TC12: Region 4 must be active for limit=0xFFFFFFFF");
        check_assert(dyn_rgn4_limit == 32'hFFFF_FFFF, "TC12: dyn_rgn4_limit must be 0xFFFFFFFF");
        check_assert(ctx_fault_event_valid == 1'b0, "TC12: No fault event for valid 0xFFFFFFFF boundary");

        // Clear via done
        @(negedge clk);
        dma_ctx_done = 1;
        dma_ctx_valid = 0;
        @(posedge clk); #1;
        @(negedge clk);
        dma_ctx_done = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC13: Same-cycle Done and Valid (Revoke wins over Allocate)
        // ------------------------------------------------------------
        test_step = 13;
        @(negedge clk);
        dma_ctx_src_addr = 32'h1000_0000;
        dma_ctx_dst_addr = 32'h2000_0000;
        dma_ctx_byte_len = 32'h0000_0040;
        dma_ctx_valid = 1;
        dma_ctx_done  = 1; // Simultaneous done and valid!

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b0, "TC13: Revoke must win: Region 4 inactive");
        check_assert(dyn_rgn5_active == 1'b0, "TC13: Revoke must win: Region 5 inactive");

        @(negedge clk);
        dma_ctx_done = 0;
        // Keep valid = 1 to test TC14

        // ------------------------------------------------------------
        // TC14: Valid held high after Done (Wait-Low / One-Shot Protection)
        // ------------------------------------------------------------
        test_step = 14;
        repeat (5) @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b0, "TC14: Region 4 must stay inactive while valid held high");
        check_assert(dyn_rgn5_active == 1'b0, "TC14: Region 5 must stay inactive while valid held high");

        // Now drop valid to 0 to re-arm
        @(negedge clk);
        dma_ctx_valid = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC15: Re-arm after valid drops to 0 (New Allocation Succeeds)
        // ------------------------------------------------------------
        test_step = 15;
        @(negedge clk);
        dma_ctx_src_addr = 32'h5000_0000;
        dma_ctx_dst_addr = 32'h6000_0000;
        dma_ctx_byte_len = 32'h0000_0080;
        dma_ctx_valid = 1;

        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b1, "TC15: Region 4 active on new transfer");
        check_assert(dyn_rgn4_base == 32'h5000_0000, "TC15: dyn_rgn4_base mismatch");
        check_assert(dyn_rgn5_active == 1'b1, "TC15: Region 5 active on new transfer");
        check_assert(dyn_rgn5_base == 32'h6000_0000, "TC15: dyn_rgn5_base mismatch");

        // Clear
        @(negedge clk);
        dma_ctx_done = 1;
        dma_ctx_valid = 0;
        @(posedge clk); #1;
        @(negedge clk);
        dma_ctx_done = 0;
        @(posedge clk); #1;

        // ------------------------------------------------------------
        // TC16: Re-enabling auto_ctx_en does not restore stale descriptor
        // ------------------------------------------------------------
        test_step = 16;
        @(negedge clk);
        auto_ctx_en = 0;
        @(posedge clk); #1;
        @(negedge clk);
        auto_ctx_en = 1;
        @(posedge clk); #1;
        check_assert(dyn_rgn4_active == 1'b0, "TC16: Region 4 must remain 0 after re-enable");
        check_assert(dyn_rgn5_active == 1'b0, "TC16: Region 5 must remain 0 after re-enable");

        // ------------------------------------------------------------
        // Final Summary
        // ------------------------------------------------------------
        #50;
        $display("------------------------------------------------------------");
        if (errors == 0) begin
            $display("PASS: tb_fw_context_tracker (All %0d test steps passed without error)", test_step);
        end else begin
            $display("FAIL: tb_fw_context_tracker (%0d errors detected)", errors);
        end
        $display("------------------------------------------------------------");
        $finish;
    end
endmodule
