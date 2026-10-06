//testbench for fw_axi_address_slice

`timescale 1ns / 1ps

module tb_fw_axi_address_slice;
    reg clk;
    reg rst_n;
    //AW channel
    reg s_axi_awvalid;
    reg [31:0] s_axi_awaddr;
    reg [3:0] s_axi_awid;
    reg [7:0] s_axi_awlen;
    reg [2:0] s_axi_awsize;
    reg [1:0] s_axi_awburst;
    reg [2:0] s_axi_awprot;
    wire s_axi_awready;
    wire pipe_s1_awvalid;
    wire [31:0] pipe_s1_awend;
    wire [31:0] pipe_s1_awaddr;
    wire [3:0] pipe_s1_awid;
    wire [7:0] pipe_s1_awlen;
    wire [2:0] pipe_s1_awsize;
    wire [1:0] pipe_s1_awburst;
    wire [2:0] pipe_s1_awprot;
    wire pipe_s1_aw_profile_err;
    wire pipe_s1_aw_overflow_err;
    wire pipe_s1_aw_4kb_err;
    reg pipe_s1_awready;

    //AR channel
    reg s_axi_arvalid;
    reg [31:0] s_axi_araddr;
    reg [3:0] s_axi_arid;
    reg [7:0] s_axi_arlen;
    reg [2:0] s_axi_arsize;
    reg [1:0] s_axi_arburst;
    reg [2:0] s_axi_arprot;
    wire s_axi_arready;
    wire pipe_s1_arvalid;
    wire [31:0] pipe_s1_arend;
    wire [31:0] pipe_s1_araddr;
    wire [3:0] pipe_s1_arid;
    wire [7:0] pipe_s1_arlen;
    wire [2:0] pipe_s1_arsize;
    wire [1:0] pipe_s1_arburst;
    wire [2:0] pipe_s1_arprot;
    wire pipe_s1_ar_profile_err;
    wire pipe_s1_ar_overflow_err;
    wire pipe_s1_ar_4kb_err;
    reg pipe_s1_arready;

    integer errors = 0;

    task check_assert;
        input condition;
        input [8*120-1:0] msg;
        begin
            if (!condition) begin
                $display("[ERROR] at %0t ps: %0s", $time, msg);
                errors = errors + 1;
            end
        end
    endtask

    //Tín hiệu nào do DUT phát ra (Output của DUT) Khai báo là wire.
    //Tín hiệu nào do Testbench điều khiển / gán giá trị trong khối initial Bắt buộc khai báo là reg
    fw_axi_address_slice u_fw_axi_address_slice(
        .clk(clk),
        .rst_n(rst_n),
        //AW channel
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awready(s_axi_awready),
        .pipe_s1_awvalid(pipe_s1_awvalid),
        .pipe_s1_awready(pipe_s1_awready),
        .pipe_s1_awend(pipe_s1_awend),
        .pipe_s1_awaddr(pipe_s1_awaddr),
        .pipe_s1_awid(pipe_s1_awid),
        .pipe_s1_awlen(pipe_s1_awlen),
        .pipe_s1_awsize(pipe_s1_awsize),
        .pipe_s1_awburst(pipe_s1_awburst),
        .pipe_s1_awprot(pipe_s1_awprot),
        .pipe_s1_aw_profile_err(pipe_s1_aw_profile_err),
        .pipe_s1_aw_overflow_err(pipe_s1_aw_overflow_err),
        .pipe_s1_aw_4kb_err(pipe_s1_aw_4kb_err),
        //AR channel
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arready(s_axi_arready),
        .pipe_s1_arvalid(pipe_s1_arvalid),
        .pipe_s1_arready(pipe_s1_arready),
        .pipe_s1_arend(pipe_s1_arend),
        .pipe_s1_araddr(pipe_s1_araddr),
        .pipe_s1_arid(pipe_s1_arid),
        .pipe_s1_arlen(pipe_s1_arlen),
        .pipe_s1_arsize(pipe_s1_arsize),
        .pipe_s1_arburst(pipe_s1_arburst),
        .pipe_s1_arprot(pipe_s1_arprot),
        .pipe_s1_ar_profile_err(pipe_s1_ar_profile_err),
        .pipe_s1_ar_overflow_err(pipe_s1_ar_overflow_err),
        .pipe_s1_ar_4kb_err(pipe_s1_ar_4kb_err)
    );
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        // --- BƯỚC 1: KHỞI TẠO & RESET ---
        rst_n           = 1'b0;
        s_axi_awvalid   = 1'b0;
        s_axi_awaddr    = 32'h0;
        s_axi_awid      = 4'h0;
        s_axi_awlen     = 8'h0;
        s_axi_awsize    = 3'b010;
        s_axi_awburst   = 2'b01;
        s_axi_awprot    = 3'b001;
        pipe_s1_awready = 1'b1;  // Matcher luôn sẵn sàng
        s_axi_arvalid   = 1'b0;
        s_axi_araddr    = 32'h0;
        s_axi_arid      = 4'h0;
        s_axi_arlen     = 8'h0;
        s_axi_arsize    = 3'b010;
        s_axi_arburst   = 2'b01;
        s_axi_arprot    = 3'b001;
        pipe_s1_arready = 1'b1;
        #25;
        @(negedge clk);
        rst_n = 1'b1;
        $display("[INFO] Reset da giai tru!");
        // --- CA 1: AW 1 beat hop le tai 0x1000_0000 ---
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        s_axi_awaddr  = 32'h1000_0000;
        s_axi_awlen   = 8'd0;       // 1 beat
        s_axi_awsize  = 3'b010;     // 4 bytes
        s_axi_awburst = 2'b01;      // INCR
        s_axi_awprot  = 3'b001;
        s_axi_awid    = 4'h0;
        @(posedge clk); #1;
        $display("[CHECK S1-02: AW 1-BEAT]  valid=%b, addr=0x%08h, end=0x%08h (Ky vong: 0x10000003)", 
                 pipe_s1_awvalid, pipe_s1_awaddr, pipe_s1_awend);
        check_assert(pipe_s1_awvalid == 1'b1, "CA 1: pipe_s1_awvalid must be 1");
        check_assert(pipe_s1_awaddr == 32'h1000_0000, "CA 1: pipe_s1_awaddr mismatch");
        check_assert(pipe_s1_awend == 32'h1000_0003, "CA 1: pipe_s1_awend mismatch");
        check_assert(pipe_s1_aw_profile_err == 1'b0, "CA 1: No profile error expected");
        check_assert(pipe_s1_aw_overflow_err == 1'b0, "CA 1: No overflow error expected");
        check_assert(pipe_s1_aw_4kb_err == 1'b0, "CA 1: No 4KB error expected");
        @(negedge clk);
        s_axi_awvalid = 1'b0;
        // --- CA 2 (S1-03): AW 16 beats hop le tai 0x2000_0000 ---
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        s_axi_awaddr  = 32'h2000_0000;
        s_axi_awlen   = 8'd15;      // 16 beats
        s_axi_awsize  = 3'b010;     // 4 bytes
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awid    = 4'h1;
        @(posedge clk); #1;
        $display("[CHECK S1-03: AW 16-BEAT] valid=%b, addr=0x%08h, end=0x%08h (Ky vong: 0x2000003f)", 
                 pipe_s1_awvalid, pipe_s1_awaddr, pipe_s1_awend);
        check_assert(pipe_s1_awvalid == 1'b1, "CA 2: pipe_s1_awvalid must be 1");
        check_assert(pipe_s1_awaddr == 32'h2000_0000, "CA 2: pipe_s1_awaddr mismatch");
        check_assert(pipe_s1_awend == 32'h2000_003f, "CA 2: pipe_s1_awend mismatch");
        check_assert(pipe_s1_aw_profile_err == 1'b0, "CA 2: No profile error expected");
        check_assert(pipe_s1_aw_overflow_err == 1'b0, "CA 2: No overflow error expected");
        check_assert(pipe_s1_aw_4kb_err == 1'b0, "CA 2: No 4KB error expected");
        @(negedge clk);
        s_axi_awvalid = 1'b0;
        // --- CA 3 (S1-04): Bat loi tran ranh gioi 4KB tai 0x0000_0FFC ---
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        s_axi_awaddr  = 32'h0000_0FFC;
        s_axi_awlen   = 8'd1;       // 2 beats (8 bytes -> end = 0x1003)
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awid    = 4'h2;
        @(posedge clk); #1;
        $display("[CHECK S1-04: 4KB ERR]    4kb_err=%b (Ky vong: 1), end=0x%08h", 
                 pipe_s1_aw_4kb_err, pipe_s1_awend);
        check_assert(pipe_s1_aw_4kb_err == 1'b1, "CA 3: pipe_s1_aw_4kb_err must be 1");
        check_assert(pipe_s1_awend == 32'h0000_1003, "CA 3: pipe_s1_awend mismatch");
        @(negedge clk);
        s_axi_awvalid = 1'b0;
        // --- CA 4 (S1-05): Bat loi tran khong gian 32-bit tai 0xFFFF_FFFC ---
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        s_axi_awaddr  = 32'hFFFF_FFFC;
        s_axi_awlen   = 8'd1;       // 2 beats
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awprot  = 3'b001;
        s_axi_awid    = 4'h3;
        @(posedge clk); #1;
        $display("[CHECK S1-05: OVERFLOW]   overflow_err=%b (Ky vong: 1), 4kb_err=%b (Ky vong: 1), end=0x%08h", 
                 pipe_s1_aw_overflow_err, pipe_s1_aw_4kb_err, pipe_s1_awend);
        check_assert(pipe_s1_aw_overflow_err == 1'b1, "CA 4: overflow_err must be 1");
        check_assert(pipe_s1_aw_4kb_err == 1'b1, "CA 4: 4kb_err must be 1");
        check_assert(pipe_s1_awend == 32'h0000_0003, "CA 4: pipe_s1_awend wrapped mismatch");
        @(negedge clk);
        s_axi_awvalid = 1'b0;
                // --- CA 5 (S1-06): Vi pham Profile (BURST != INCR) ---
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        s_axi_awaddr  = 32'h3000_0000;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b00;      // FIXED (Vi pham profile!)
        s_axi_awprot  = 3'b001;
        s_axi_awid    = 4'h4;

        @(posedge clk); #1;
        $display("[CHECK S1-06: PROFILE ERR] profile_err=%b (Ky vong: 1)", pipe_s1_aw_profile_err);
        check_assert(pipe_s1_aw_profile_err == 1'b1, "CA 5: profile_err must be 1 for FIXED burst");
        @(negedge clk);
        s_axi_awvalid = 1'b0;
                // --- CA 6 (S1-08): Backpressure / Downstream Stall ---
        @(negedge clk);
        s_axi_awvalid   = 1'b1;
        s_axi_awaddr    = 32'h4000_0000;
        s_axi_awlen     = 8'd0;
        s_axi_awsize    = 3'b010;
        s_axi_awburst   = 2'b01;
        s_axi_awprot    = 3'b001;
        s_axi_awid      = 4'h5;
        pipe_s1_awready = 1'b0;     // Matcher NGHẼN!

        @(posedge clk); #1;
        // Kiểm tra xem DUT có hạ s_axi_awready = 0 để bắt DMA dừng không
        $display("[CHECK S1-08: STALL] s_axi_awready=%b (Ky vong: 0)", s_axi_awready);
        check_assert(s_axi_awready == 1'b0, "CA 6: s_axi_awready must be 0 when stalled");

        // Thử thay đổi địa chỉ DMA trong lúc stall
        @(negedge clk);
        s_axi_awaddr = 32'hDEAD_BEEF;
        @(posedge clk); #1;
        // Kiểm tra xem đầu ra có bị đổi sang DEADBEEF không (phải giữ nguyên 0x4000_0000)
        $display("[CHECK S1-08: STABILITY] pipe_s1_awaddr=0x%08h (Ky vong: 0x40000000 - Khong bi ghi de)", pipe_s1_awaddr);
        check_assert(pipe_s1_awaddr == 32'h4000_0000, "CA 6: pipe_s1_awaddr must remain stable");

        // Nha nghẽn
        @(negedge clk);
        pipe_s1_awready = 1'b1;
        s_axi_awvalid   = 1'b0;
        //thêm một ca kiểm thử cho kênh AR (Đọc) trước dòng $finish
                // --- CA 7: Kiem tra kenh AR (Doc 4 beats tai 0x5000_0000) ---
        @(negedge clk);
        s_axi_arvalid = 1'b1;
        s_axi_araddr  = 32'h5000_0000;
        s_axi_arlen   = 8'd3;       // 4 beats (16 bytes -> end = 0x5000_000F)
        s_axi_arsize  = 3'b010;     // 4 bytes
        s_axi_arburst = 2'b01;      // INCR
        s_axi_arprot  = 3'b001;
        s_axi_arid    = 4'h6;

        @(posedge clk); #1;
        $display("[CHECK AR 4-BEAT] valid=%b, addr=0x%08h, end=0x%08h (Ky vong: 0x5000000f)", 
                 pipe_s1_arvalid, pipe_s1_araddr, pipe_s1_arend);
        check_assert(pipe_s1_arvalid == 1'b1, "CA 7: pipe_s1_arvalid must be 1");
        check_assert(pipe_s1_araddr == 32'h5000_0000, "CA 7: pipe_s1_araddr mismatch");
        check_assert(pipe_s1_arend == 32'h5000_000f, "CA 7: pipe_s1_arend mismatch");
        check_assert(pipe_s1_ar_profile_err == 1'b0, "CA 7: No profile err");
        check_assert(pipe_s1_ar_overflow_err == 1'b0, "CA 7: No overflow err");
        check_assert(pipe_s1_ar_4kb_err == 1'b0, "CA 7: No 4KB err");
        @(negedge clk);
        s_axi_arvalid = 1'b0;
        // --- KET THUC TOAN BO MO PHONG ---
        #50;
        $display("\n========================================================");
        if (errors == 0) begin
            $display("PASS: tb_fw_axi_address_slice");
        end else begin
            $display("FAIL: tb_fw_axi_address_slice (%0d errors detected)", errors);
        end
        $display("========================================================\n");
        $finish;
    end
endmodule