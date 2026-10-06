`timescale 1ns/1ps

//Clock & Reset toàn cục:

//clk: Xung clock hệ thống.
//rst_n: Reset tích cực mức thấp (active-low asynchronous reset).
//Giao diện Upstream từ DMA (Kênh AW - Write Address):

//DMA gửi yêu cầu ghi: awvalid, awaddr, awid, awlen, awsize, awburst, awprot.
//Phản hồi cho DMA: awready.
//Gợi ý tiền tố: Dùng s_axi_aw* (đóng vai trò Slave nhận từ DMA).
//Giao diện Downstream sang Matcher (Kênh AW Snapshot - Stage 1 to Stage 2):

//Stage 1 gửi sang Matcher: pipe_s1_awvalid, pipe_s1_awaddr, pipe_s1_awend (địa chỉ byte cuối), pipe_s1_awid, pipe_s1_awlen, pipe_s1_awsize, pipe_s1_awburst, pipe_s1_awprot.
//3 cờ lỗi canonical: pipe_s1_aw_profile_err, pipe_s1_aw_overflow_err, pipe_s1_aw_4kb_err.
//Matcher phản hồi ngược về: pipe_s1_awready.
//Kênh Đọc (AR - Read Address):
//Tương tự như kênh AW nhưng đổi tiền tố thành ar:
//Phía DMA: s_axi_ar*.
//Phía Matcher: pipe_s1_ar* (bao gồm pipe_s1_arend và 3 cờ lỗi pipe_s1_ar_*).

module fw_axi_address_slice (
    input clk,
    input rst_n,
    //Kênh AW - Write Address:
    input s_axi_awvalid,
    input [31:0] s_axi_awaddr,
    input [3:0] s_axi_awid,
    input [7:0] s_axi_awlen,
    input [2:0] s_axi_awsize,
    input [1:0] s_axi_awburst,
    input [2:0] s_axi_awprot,
    output s_axi_awready,
    //Kênh AW - Write Address Snapshot:
    output pipe_s1_awvalid,
    output [31:0] pipe_s1_awend,
    output [31:0] pipe_s1_awaddr,
    output [3:0] pipe_s1_awid,
    output [7:0] pipe_s1_awlen,
    output [2:0] pipe_s1_awsize,
    output [1:0] pipe_s1_awburst,
    output [2:0] pipe_s1_awprot,
    output pipe_s1_aw_profile_err,
    output pipe_s1_aw_overflow_err,
    output pipe_s1_aw_4kb_err,
    input pipe_s1_awready,
    //Kênh AR - Read Address:
    input s_axi_arvalid,
    input [31:0] s_axi_araddr,
    input [3:0] s_axi_arid,
    input [7:0] s_axi_arlen,
    input [2:0] s_axi_arsize,
    input [1:0] s_axi_arburst,
    input [2:0] s_axi_arprot,
    output s_axi_arready,
    //Kênh AR - Read Address Snapshot:
    output pipe_s1_arvalid,
    output [31:0] pipe_s1_araddr,
    output [31:0] pipe_s1_arend,
    output [3:0] pipe_s1_arid,
    output [7:0] pipe_s1_arlen,
    output [2:0] pipe_s1_arsize,
    output [1:0] pipe_s1_arburst,
    output [2:0] pipe_s1_arprot,
    output pipe_s1_ar_profile_err,
    output pipe_s1_ar_overflow_err,
    output pipe_s1_ar_4kb_err,
    input pipe_s1_arready
);
    //Kênh AW - Write Address:
    reg [31:0] awaddr_reg;
    reg [3:0] awid_reg;
    reg [7:0] awlen_reg;
    reg [2:0] awsize_reg;
    reg [1:0] awburst_reg;
    reg [2:0] awprot_reg;
    reg [31:0] awend_reg;
    //Kênh AR - Read Address Snapshot:
    reg [31:0] araddr_reg;
    reg [3:0] arid_reg;
    reg [7:0] arlen_reg;
    reg [2:0] arsize_reg;
    reg [1:0] arburst_reg;
    reg [2:0] arprot_reg;
    reg [31:0] arend_reg;
    // 1. Thanh ghi trạng thái slot (0: rỗng, 1: đang giữ snapshot)
    reg aw_valid_reg;
    reg ar_valid_reg;
    // 2. Logic sẵn sàng: Sẵn sàng nhận nếu slot rỗng HOẶC Matcher đang lấy đi ở chu kỳ này
    wire aw_ready = !aw_valid_reg || pipe_s1_awready;
    wire ar_ready = !ar_valid_reg || pipe_s1_arready;
    assign s_axi_awready = aw_ready;
    assign s_axi_arready = ar_ready;
    // 3. Tín hiệu bắt tay thành công để chốt descriptor mới
    wire aw_success = aw_ready && s_axi_awvalid;
    wire ar_success = ar_ready && s_axi_arvalid;
    // 4. Thanh ghi cờ lỗi
    reg aw_profile_err_reg;
    reg aw_overflow_err_reg;
    reg aw_4kb_err_reg;
    reg ar_profile_err_reg;
    reg ar_overflow_err_reg;
    reg ar_4kb_err_reg;

    // 1. Tính số beat và độ dài byte của burst
    wire [8:0]  aw_beats      = {1'b0, s_axi_awlen} + 9'd1;
    wire [15:0] aw_span_bytes = (s_axi_awsize <= 3'd7) ? ({7'd0, aw_beats} << s_axi_awsize) : 16'hFFFF;
    // 2. Tính byte cuối trên 34-bit
    wire [33:0] aw_last_ext   = {2'b00, s_axi_awaddr} + {18'd0, aw_span_bytes} - 34'd1;
    wire [31:0] aw_calc_end   = aw_last_ext[31:0];
    // 3. Tính 3 cờ lỗi
    wire aw_calc_overflow = |aw_last_ext[33:32];
    wire aw_calc_4kb      = aw_calc_overflow || (s_axi_awaddr[31:12] != aw_calc_end[31:12]);
    wire aw_calc_profile  = (s_axi_awburst != 2'b01)  || (s_axi_awsize  != 3'b010) || (s_axi_awaddr[1:0] != 2'b00) || (s_axi_awlen   >  8'd15);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_valid_reg        <= 1'b0;
            awaddr_reg          <= 32'd0;
            awend_reg           <= 32'd0;
            awid_reg            <= 4'd0;
            awlen_reg           <= 8'd0;
            awsize_reg          <= 3'd0;
            awburst_reg         <= 2'd0;
            awprot_reg          <= 3'd0;
            aw_profile_err_reg  <= 1'b0;
            aw_overflow_err_reg <= 1'b0;
            aw_4kb_err_reg      <= 1'b0;
        end else if (aw_success) begin
            // Bắt tay thành công: Chốt toàn bộ descriptor và các cờ lỗi
            aw_valid_reg        <= 1'b1;
            awaddr_reg          <= s_axi_awaddr;
            awend_reg           <= aw_calc_end;
            awid_reg            <= s_axi_awid;
            awlen_reg           <= s_axi_awlen;
            awsize_reg          <= s_axi_awsize;
            awburst_reg         <= s_axi_awburst;
            awprot_reg          <= s_axi_awprot;
            aw_profile_err_reg  <= aw_calc_profile;
            aw_overflow_err_reg <= aw_calc_overflow;
            aw_4kb_err_reg      <= aw_calc_4kb;
        end else if (pipe_s1_awready) begin
            // Downstream đã lấy snapshot đi và không có yêu cầu mới cùng chu kỳ -> slot rỗng
            aw_valid_reg        <= 1'b0;
        end
    end
    //nối các thanh ghi _reg ra các cổng output pipe_s1_* bằng các lệnh assign
    assign pipe_s1_awvalid = aw_valid_reg;
    assign pipe_s1_awend = awend_reg;
    assign pipe_s1_awaddr = awaddr_reg;
    assign pipe_s1_awid = awid_reg;
    assign pipe_s1_awlen = awlen_reg;
    assign pipe_s1_awsize = awsize_reg;
    assign pipe_s1_awburst = awburst_reg;
    assign pipe_s1_awprot = awprot_reg;
    assign pipe_s1_aw_profile_err = aw_profile_err_reg;
    assign pipe_s1_aw_overflow_err = aw_overflow_err_reg;
    assign pipe_s1_aw_4kb_err = aw_4kb_err_reg;
    assign pipe_s1_arvalid = ar_valid_reg;
    assign pipe_s1_araddr = araddr_reg;
    assign pipe_s1_arend = arend_reg;
    assign pipe_s1_arid = arid_reg;
    assign pipe_s1_arlen = arlen_reg;
    assign pipe_s1_arsize = arsize_reg;
    assign pipe_s1_arburst = arburst_reg;
    assign pipe_s1_arprot = arprot_reg;
    assign pipe_s1_ar_profile_err = ar_profile_err_reg;
    assign pipe_s1_ar_overflow_err = ar_overflow_err_reg;
    assign pipe_s1_ar_4kb_err = ar_4kb_err_reg;
    //Thêm khối tính toán tổ hợp cho AR (tương tự như AW)
    wire [8:0]  ar_beats      = {1'b0, s_axi_arlen} + 9'd1;
    wire [15:0] ar_span_bytes = (s_axi_arsize <= 3'd7) ? ({7'd0, ar_beats} << s_axi_arsize) : 16'hFFFF;
    wire [33:0] ar_last_ext   = {2'b00, s_axi_araddr} + {18'd0, ar_span_bytes} - 34'd1;
    wire [31:0] ar_calc_end   = ar_last_ext[31:0];
    wire ar_calc_overflow = |ar_last_ext[33:32];
    wire ar_calc_4kb      = ar_calc_overflow || (s_axi_araddr[31:12] != ar_calc_end[31:12]);
    wire ar_calc_profile  = (s_axi_arburst != 2'b01)  || (s_axi_arsize  != 3'b010) || (s_axi_araddr[1:0] != 2'b00) || (s_axi_arlen   >  8'd15);
    //Thêm khối always @(posedge clk or negedge rst_n) cho AR (chỉ cần copy khối AW và đổi aw thành ar)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_valid_reg        <= 1'b0;
            araddr_reg          <= 32'd0;
            arend_reg           <= 32'd0;
            arid_reg            <= 4'd0;
            arlen_reg           <= 8'd0;
            arsize_reg          <= 3'd0;
            arburst_reg         <= 2'd0;
            arprot_reg          <= 3'd0;
            ar_profile_err_reg  <= 1'b0;
            ar_overflow_err_reg <= 1'b0;
            ar_4kb_err_reg      <= 1'b0;
        end else if (ar_success) begin
            ar_valid_reg        <= 1'b1;
            araddr_reg          <= s_axi_araddr;
            arend_reg           <= ar_calc_end;
            arid_reg            <= s_axi_arid;
            arlen_reg           <= s_axi_arlen;
            arsize_reg          <= s_axi_arsize;
            arburst_reg         <= s_axi_arburst;
            arprot_reg          <= s_axi_arprot;
            ar_profile_err_reg  <= ar_calc_profile;
            ar_overflow_err_reg <= ar_calc_overflow;
            ar_4kb_err_reg      <= ar_calc_4kb;
        end else if (pipe_s1_arready) begin
            ar_valid_reg        <= 1'b0;
        end
    end
endmodule
