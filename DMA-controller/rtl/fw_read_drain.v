`timescale 1ns/1ps

// Tệp: rtl/fw_read_drain.v
// Chức năng: Module xả dữ liệu đọc (Read Drain) giả lập phản hồi cho yêu cầu bị Firewall từ chối.
// Tuân thủ: 04_fw_read_drain_lab_guide.pdf

module fw_read_drain (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        acl_r_fault,
    input  wire [3:0]  acl_r_id,
    input  wire [7:0]  acl_r_len,
    input  wire        acl_r_err_mode,
    input  wire        r_drain_rready,
    output wire        r_drain_rvalid,
    output wire [3:0]  r_drain_rid,
    output wire [31:0] r_drain_rdata,
    output wire [1:0]  r_drain_rresp,
    output wire        r_drain_rlast
);

    // FSM Encoding (1-bit theo Spec mục 4.3 và 6)
    localparam R_IDLE = 1'b0;
    localparam R_GEN  = 1'b1;

    // Khai báo các thanh ghi (Registers)
    reg        state_q, state_next;
    reg [3:0]  id_q, id_next;
    reg [7:0]  len_q, len_next;
    reg        mode_q, mode_next;
    reg [7:0]  count_q, count_next;

    // Các tín hiệu nội bộ (Combinational)
    wire r_handshake;
    wire final_beat;

    // Bài tập 1: Định nghĩa handshake và final_beat
    assign r_handshake     = r_drain_rvalid && r_drain_rready;
    assign final_beat      = (count_q == len_q);

    // Bài tập 2: Output decode từ state và snapshot
    assign r_drain_rvalid = (state_q == R_GEN);
    assign r_drain_rid    = id_q;
    assign r_drain_rdata  = 32'h0000_0000;
    assign r_drain_rresp  = mode_q ? 2'b11 : 2'b00; // 2'b11=DECERR, 2'b00=OKAY
    assign r_drain_rlast  = final_beat;

    // Logic tuần tự cập nhật thanh ghi (Sequential block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= R_IDLE;
            id_q    <= 4'd0;
            len_q   <= 8'd0;
            mode_q  <= 1'b0;
            count_q <= 8'd0;
        end else begin
            state_q <= state_next;
            id_q    <= id_next;
            len_q   <= len_next;
            mode_q  <= mode_next;
            count_q <= count_next;
        end
    end

    // Logic tính toán trạng thái tiếp theo (Combinational next-state)
    always @(*) begin
        // Giá trị mặc định (tránh latch)
        state_next = state_q;
        id_next    = id_q;
        len_next   = len_q;
        mode_next  = mode_q;
        count_next = count_q;

        case (state_q)
            R_IDLE: begin
                // Transition: Nhận owner mới
                if (acl_r_fault) begin
                    state_next = R_GEN;
                    id_next    = acl_r_id;
                    len_next   = acl_r_len;
                    mode_next  = acl_r_err_mode;
                    count_next = 8'd0; // Counter always starts at 0
                end
            end

            R_GEN: begin
                // Chỉ xử lý logic nếu có handshake
                if (r_handshake) begin
                    if (final_beat) begin
                        // Final handshake giải phóng owner
                        state_next = R_IDLE;
                    end else begin
                        // Non-final handshake tăng count
                        count_next = count_q + 1'b1;
                    end
                end else begin
                    // Once RVALID is asserted, AXI requires the response
                    // payload to remain valid until RREADY arrives.  Do not
                    // silently drop it on response-channel backpressure:
                    // the top-level owner is released only by the final
                    // RVALID && RREADY && RLAST handshake.
                end
            end
            
            // Cơ chế fail-safe cho Illegal State theo Spec 4.3
            default: begin
                state_next = R_IDLE;
            end
        endcase
    end
endmodule
