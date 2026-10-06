`timescale 1ns/1ps

//1. DMA gửi thông tin vùng nhớ cần truyền sang cho Firewall:
    //dma_ctx_valid: Báo DMA đang kích hoạt và descriptor có hiệu lực (tín hiệu mức 1-bit).
    //dma_ctx_src_addr: Địa chỉ nguồn 32-bit ([31:0]).
    //dma_ctx_dst_addr: Địa chỉ đích 32-bit ([31:0]).
    //dma_ctx_byte_len: Số lượng byte truyền 32-bit ([31:0]).
    //dma_ctx_done: Xung 1 chu kỳ báo DMA đã hoàn thành hoặc bị dừng đột ngột (abort).
//2. Nhóm Điều khiển từ Thanh ghi Firewall (fw_apb_regs)
    //auto_ctx_en: Cờ 1-bit cho phép tự động mở vùng nhớ động (FW_CONTROL[2], mặc định bằng 1)
//3. Nhóm Xuất sang Bộ so khớp ACL (fw_acl_matcher)
    //Hai vùng nhớ động Region 4 (nguồn) và Region 5 (đích):
    //Region 4: dyn_rgn4_base [31:0], dyn_rgn4_limit [31:0], dyn_rgn4_active (1-bit).
    //Region 5: dyn_rgn5_base [31:0], dyn_rgn5_limit [31:0], dyn_rgn5_active (1-bit).
//4. Nhóm Báo lỗi sang Fault Logger (fw_apb_regs)
    //Khi descriptor của DMA sai quy tắc (misaligned, tràn địa chỉ, len = 0):
    //ctx_fault_event_valid: Xung 1 chu kỳ báo có lỗi descriptor (1-bit).
    //ctx_fault_event_code: Mã lỗi 4-bit ([3:0]), chuẩn kiến trúc quy định 4'b1000 (BOUND_ERR).
    //ctx_fault_event_addr: Địa chỉ gây lỗi 32-bit ([31:0]).
    //ctx_fault_event_id: ID của Master gây lỗi 4-bit ([3:0]), DMA Master cố định là 4'h0.
module fw_context_tracker (
    input clk,
    input rst_n,

    //1. DMA gửi thông tin vùng nhớ cần truyền sang cho Firewall
    input dma_ctx_valid,
    input [31:0] dma_ctx_src_addr,
    input [31:0] dma_ctx_dst_addr,
    input [31:0] dma_ctx_byte_len,
    input dma_ctx_done,

    //2. Nhóm Điều khiển từ Thanh ghi Firewall (fw_apb_regs)
    input auto_ctx_en,

    //3. Nhóm Xuất sang Bộ so khớp ACL (fw_acl_matcher)
    output reg [31:0] dyn_rgn4_base,
    output reg [31:0] dyn_rgn4_limit,
    output reg dyn_rgn4_active,

    output reg [31:0] dyn_rgn5_base,
    output reg [31:0] dyn_rgn5_limit,
    output reg dyn_rgn5_active,

    //4. Nhóm Báo lỗi sang Fault Logger (fw_apb_regs)
    output reg ctx_fault_event_valid,
    output [3:0] ctx_fault_event_code,
    output reg [31:0] ctx_fault_event_addr,
    output [3:0] ctx_fault_event_id
);
    //1. Phép tính giới hạn inclusive 33-bit
    wire [32:0] src_calc_ext = {1'b0, dma_ctx_src_addr} + {1'b0, dma_ctx_byte_len} - 33'd1;
    wire [32:0] dst_calc_ext = {1'b0, dma_ctx_dst_addr} + {1'b0, dma_ctx_byte_len} - 33'd1;

    //2. Các cờ kiểm tra (Condition Flags)
    //khai báo các wire 1-bit để kiểm tra 3 điều kiện:

    //Căn hàng 4-byte (Alignment): Địa chỉ và độ dài phải chia hết cho 4 (tức là 2 bit cuối [1:0] phải bằng 2'b00):
    wire src_aligned = (dma_ctx_src_addr[1:0] == 2'b00);
    wire dst_aligned = (dma_ctx_dst_addr[1:0] == 2'b00);
    wire len_aligned = (dma_ctx_byte_len[1:0] == 2'b00);
    //Độ dài dương:
    wire len_nonzero = (dma_ctx_byte_len != 32'd0);

    //Chống tràn 32-bit:
    wire src_overflow = src_calc_ext[32];
    wire dst_overflow = dst_calc_ext[32];

    wire src_valid        = src_aligned && !src_overflow;
    wire dst_valid        = dst_aligned && !dst_overflow;
    wire len_valid        = len_aligned && len_nonzero;
    wire descriptor_valid = src_valid && dst_valid && len_valid;
    
    assign ctx_fault_event_code = 4'b1000; // Mã lỗi BOUND_ERR
    assign ctx_fault_event_id   = 4'h0;    // Master ID của DMA cố định là 0

    reg [31:0] fault_addr_comb;

    always @(*) begin
        if (!src_valid) begin
            fault_addr_comb = dma_ctx_src_addr;
        end else if (!dst_valid) begin
            fault_addr_comb = dma_ctx_dst_addr;
        end else begin
            // Trường hợp cả nguồn và đích đều hợp lệ nhưng chiều dài lỗi (len == 0 hoặc misaligned)
            fault_addr_comb = dma_ctx_src_addr;
        end
    end
    
    localparam [1:0] CTX_IDLE     = 2'b00;
    localparam [1:0] CTX_ACTIVE   = 2'b01;
    localparam [1:0] CTX_WAIT_LOW = 2'b10;

    parameter CTX_TIMEOUT_CYCLES = 4096;

    reg [1:0]  state_reg, state_next;
    reg [15:0] ctx_watchdog_timer;
    wire       ctx_timeout_tripped = (ctx_watchdog_timer >= (CTX_TIMEOUT_CYCLES - 1));

    always @(*) begin
        // 1. Gán giá trị mặc định để tránh tạo Latch ngoài ý muốn
        state_next = state_reg;

        case (state_reg)
            CTX_IDLE: begin
                // dma_ctx_done hoặc auto_ctx_en bị tắt có ưu tiên cao nhất
                if (dma_ctx_done || !auto_ctx_en) begin
                    state_next = dma_ctx_valid ? CTX_WAIT_LOW : CTX_IDLE;
                end else if (dma_ctx_valid) begin
                    if (descriptor_valid) begin
                        state_next = CTX_ACTIVE;
                    end else begin
                        // Lỗi descriptor: chuyển sang chờ valid hạ xuống 0
                        state_next = CTX_WAIT_LOW;
                    end
                end
            end

            CTX_ACTIVE: begin
                // Thu hồi quyền khi có done, bị disable từ APB, hoặc quá thời hạn Watchdog
                if (dma_ctx_done || !auto_ctx_en) begin
                    state_next = dma_ctx_valid ? CTX_WAIT_LOW : CTX_IDLE;
                end else if (ctx_timeout_tripped) begin
                    state_next = CTX_WAIT_LOW;
                end
            end

            CTX_WAIT_LOW: begin
                // Chỉ quay về IDLE khi DMA đã thực sự hạ dma_ctx_valid về 0
                if (!dma_ctx_valid) begin
                    state_next = CTX_IDLE;
                end
            end

            default: begin
                state_next = CTX_IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= CTX_IDLE;
            dyn_rgn4_base <= 32'h0;
            dyn_rgn4_limit <= 32'h0;
            dyn_rgn4_active <= 1'b0;
            dyn_rgn5_base <= 32'h0;
            dyn_rgn5_limit <= 32'h0;
            dyn_rgn5_active <= 1'b0;
            ctx_fault_event_valid <= 1'b0;
            ctx_fault_event_addr  <= 32'h0;
            ctx_watchdog_timer    <= 16'd0;
        end else begin
            state_reg <= state_next;
            ctx_fault_event_valid <= 1'b0; // Mặc định hạ xung về 0 sau 1 chu kỳ
            if (dma_ctx_done || !auto_ctx_en) begin
                // Thu hồi quyền: Tắt active và xóa sạch base/limit của 2 region
                dyn_rgn4_active       <= 1'b0;
                dyn_rgn5_active       <= 1'b0;
                dyn_rgn4_base         <= 32'h0;
                dyn_rgn4_limit        <= 32'h0;
                dyn_rgn5_base         <= 32'h0;
                dyn_rgn5_limit        <= 32'h0;
                ctx_watchdog_timer    <= 16'd0;
            end else if (state_reg == CTX_ACTIVE && ctx_timeout_tripped) begin
                // Context Watchdog Timeout: tự động đóng cửa sổ động để chống TOCTOU
                dyn_rgn4_active       <= 1'b0;
                dyn_rgn5_active       <= 1'b0;
                dyn_rgn4_base         <= 32'h0;
                dyn_rgn4_limit        <= 32'h0;
                dyn_rgn5_base         <= 32'h0;
                dyn_rgn5_limit        <= 32'h0;
                ctx_fault_event_valid <= 1'b1;            // Báo lỗi timeout context cho CPU
                ctx_fault_event_addr  <= dyn_rgn4_base;   // Địa chỉ vi phạm
                ctx_watchdog_timer    <= 16'd0;
            end else if ((state_reg == CTX_IDLE) && dma_ctx_valid) begin
                ctx_watchdog_timer <= 16'd0;
                if (descriptor_valid) begin
                    dyn_rgn4_base   <= dma_ctx_src_addr;
                    dyn_rgn4_limit  <= src_calc_ext[31:0]; // Limit = src + len - 1
                    dyn_rgn4_active <= 1'b1;
                    dyn_rgn5_base   <= dma_ctx_dst_addr;
                    dyn_rgn5_limit  <= dst_calc_ext[31:0]; // Limit = dst + len - 1
                    dyn_rgn5_active <= 1'b1;
                end else begin
                    dyn_rgn4_active       <= 1'b0;
                    dyn_rgn5_active       <= 1'b0;
                    ctx_fault_event_valid <= 1'b1;            // Phát xung báo lỗi trong đúng 1 chu kỳ!
                    ctx_fault_event_addr  <= fault_addr_comb; // Gán địa chỉ bị vi phạm
                end
            end else if (state_reg == CTX_ACTIVE) begin
                ctx_watchdog_timer <= ctx_watchdog_timer + 1'b1;
            end else if (state_reg == CTX_WAIT_LOW && !dma_ctx_valid) begin
                dyn_rgn4_active <= 1'b0;
                dyn_rgn5_active <= 1'b0;
                ctx_watchdog_timer <= 16'd0;
            end
        end
    end
endmodule
