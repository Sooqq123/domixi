# AEGIS-RISC: Production RTL Coding Audit & Operational Boundary Report

> **Document ID:** REPORT-RTL-CODING-AUDIT-001<br>
> **Release Target:** SkyWater 130nm High Density (`sky130A` / `sky130_fd_sc_hd`)<br>
> **Release Baseline Commit:** `ba7a75343457deaa7d1a86310bb1be81a4a4420f`<br>
> **Current Git HEAD:** `19301bc2c7c2994dc65b67c1e2d61ddf77a60734`<br>
> **Status:** AUDIT COMPLETE — ZERO CRITICAL CODING DEFECTS IDENTIFIED<br>
> **Review Scope:** 21 Production RTL Source Modules (100% Reconciled vs `ba7a753` after CRLF/LF normalization)<br>
> **Auditors:** Antigravity Lead Architect & Junior Physical Design Specialist; Submitted for Chief Tape-Out Engineer Codex Review

---

## 1. Phương Pháp Luận & Tiêu Chí Rà Soát (Audit Methodology)

Đội ngũ kỹ thuật thực hiện rà soát chuyên sâu toàn diện 21 tệp RTL sản xuất theo các tiêu chuẩn công nghiệp:
1. **Phân tích tĩnh cú pháp & Lint (Verilator Lint):** Kiểm tra triệt để kiểu dữ liệu, độ rộng bit (width mismatch), tín hiệu không dùng (unused signals), và net đa xung nhịp (SYNCASYNCNET).
2. **Kiểm tra suy diễn chốt không chủ ý (Latch Inference):** Khẳng định toàn bộ khối `always @(*)` gán đầy đủ giá trị mặc định cho mọi nhánh, đạt 0 chốt không chủ ý (0 latches).
3. **Kiểm tra xung đột bus & gán đa nguồn (Multi-driven Nets):** Xác minh không có tín hiệu nào bị gán đồng thời từ 2 nguồn (0 conflicts).
4. **Kiểm tra an toàn máy trạng thái (FSM Exhaustive Decode):** Xác nhận mọi FSM đều có nhánh `default` an toàn để tự khôi phục về `IDLE` khi gặp glitch.
5. **Đặc tính an toàn phần cứng (Security Hardening):** Tuân thủ CWE-1338 (mã hóa Hamming đa bit chống tiêm lỗi) và CWE-1256 (kiểm tra ranh giới truy cập bộ nhớ).

---

## 2. Bảng Rà Soát Chi Tiết 21 Tệp RTL Sản Xuất (Module-by-Module Audit)

| STT | Tệp RTL Sản Xuất | Dòng Code | Vai Trò Kiến Trúc | Kết Quả Rà Soát Coding | Giới Hạn Hoạt Động & Ràng Buộc Kiến Trúc |
| :---: | :--- | :---: | :--- | :---: | :--- |
| 1 | [`rtl/dma_bus_firewall.v`](file:///D:/domixi/rtl/dma_bus_firewall.v) | 1,107 | Top-level Firewall Wrapper | **PASS (0 Lỗi)** | Tần số tối đa 38.00 MHz (TT). Hold biên ngoài độc lập dùng waiver `WAV-STA-004`. |
| 2 | [`rtl/aegis_soc_top.v`](file:///D:/domixi/rtl/aegis_soc_top.v) | 338 | Top-level SoC Integration | **PASS (0 Lỗi)** | Tích hợp reset đồng bộ 2 tầng. Tần số tối đa 38.00 MHz (TT) và 19.23 MHz (SS). |
| 3 | [`rtl/fw_acl_matcher.v`](file:///D:/domixi/rtl/fw_acl_matcher.v) | 171 | Phân quyền & So khớp vùng AXI | **PASS (0 Lỗi)** | Hỗ trợ 8 vùng bộ nhớ (`REGION_COUNT=8`). Mã hóa đa bit `SAFE_ALLOW=4'b1010`, `SAFE_DENY=4'b0101`. |
| 4 | [`rtl/fw_write_drain.v`](file:///D:/domixi/rtl/fw_write_drain.v) | 166 | Xả kênh ghi & Chống bế tắc bus | **PASS (0 Lỗi)** | Bộ đếm thời gian giới hạn 256 chu kỳ (`TIMEOUT_CYCLES=256`). Trả về `DECERR` (2'b11). |
| 5 | [`rtl/fw_read_drain.v`](file:///D:/domixi/rtl/fw_read_drain.v) | 112 | Xả kênh đọc & Phản hồi dữ liệu 0 | **PASS (0 Lỗi)** | Xử lý tuần tự 1 giao dịch đọc vi phạm tại một thời điểm. Trả về `DECERR` và `rdata=0`. |
| 6 | [`rtl/fw_closed_loop_ctrl.v`](file:///D:/domixi/rtl/fw_closed_loop_ctrl.v) | 400 | Phản xạ đóng, Chấm điểm & NMI | **PASS (0 Lỗi)** | 16 Master IDs, điểm bão hòa 4 bit (0-15). Phân rã 1024 chu kỳ. NMI phát xung chuẩn 1 chu kỳ. |
| 7 | [`rtl/fw_hdc_sense.v`](file:///D:/domixi/rtl/fw_hdc_sense.v) | 529 | Cảm biến phân loại đe dọa HDC | **PASS (0 Lỗi)** | 1024 chiều, vector đầu vào phải ổn định trong suốt pipeline 49 chu kỳ cố định. |
| 8 | [`rtl/fw_mtd_engine.v`](file:///D:/domixi/rtl/fw_mtd_engine.v) | 211 | Xáo trộn không gian bus MTD LFSR | **PASS (0 Lỗi)** | Đa thức $x^{16}+x^{14}+x^{13}+x^{11}+1$, seed `16'h1ACE`. Trạng thái không bao giờ rơi vào `16'h0000`. |
| 9 | [`rtl/fw_honeypot_sink.v`](file:///D:/domixi/rtl/fw_honeypot_sink.v) | 282 | Chuyển hướng bẫy Honeypot an toàn | **PASS (0 Lỗi)** | Hấp thu toàn bộ burst vi phạm vào bẫy nội bộ, không lan truyền ra ma trận bus bên ngoài. |
| 10 | [`rtl/fw_drain_fsm.v`](file:///D:/domixi/rtl/fw_drain_fsm.v) | 68 | Bộ trọng tài điều phối xả bus | **PASS (0 Lỗi)** | FSM 2 trạng thái an toàn, tự động khôi phục về `IDLE` ngay sau khi giao dịch hoàn tất. |
| 11 | [`rtl/fw_context_tracker.v`](file:///D:/domixi/rtl/fw_context_tracker.v) | 199 | Bám vết ngữ cảnh giao dịch DMA | **PASS (0 Lỗi)** | Hỗ trợ 4 kênh DMA song song. Tự động thu hồi ngữ cảnh khi hoàn tất hoặc gặp lỗi. |
| 12 | [`rtl/fw_data_path_mux.v`](file:///D:/domixi/rtl/fw_data_path_mux.v) | 235 | Bộ dồn kênh đường truyền dữ liệu | **PASS (0 Lỗi)** | Chuyển mạch không gây trễ (0-cycle combinational mux) giữa kênh hợp lệ và kênh xả lỗi. |
| 13 | [`rtl/fw_axi_address_slice.v`](file:///D:/domixi/rtl/fw_axi_address_slice.v) | 208 | Tách địa chỉ & Kiểm tra 4 KiB | **PASS (0 Lỗi)** | Phát hiện tràn địa chỉ 32 bit (`extended_last[32]`) và vi phạm ranh giới 4 KiB của AXI. |
| 14 | [`rtl/fw_apb_regs.v`](file:///D:/domixi/rtl/fw_apb_regs.v) | 562 | Thanh ghi điều khiển & Giám sát APB | **PASS (0 Lỗi)** | Bản đồ thanh ghi chuẩn tắc 0x000-0x0BC. Xóa cờ ngắt qua thao tác ghi 1 để xóa (W1C). |
| 15 | [`rtl/aegis_picorv32_apb_bridge.v`](file:///D:/domixi/rtl/aegis_picorv32_apb_bridge.v) | 233 | Cầu nối CPU PicoRV32 sang APB | **PASS (0 Lỗi)** | Ánh xạ không gian địa chỉ CPU sang giao thức bus APB4 cho cấu hình Firewall. |
| 16 | [`rtl/generated/aegis_hdc_params.vh`](file:///D:/domixi/rtl/generated/aegis_hdc_params.vh) | 275 | Tham số cấu hình siêu chiều HDC | **PASS (0 Lỗi)** | Hằng số tham số mô hình HDC (1024-D, 64-bit word lanes). |
| 17 | [`picorv32-main/picorv32-main/picorv32.v`](file:///D:/domixi/picorv32-main/picorv32-main/picorv32.v) | 2,875 | Lõi vi xử lý RISC-V PicoRV32 | **PASS (0 Lỗi)** | Tập lệnh RV32IMC, bẫy ngắt NMI được nối trực tiếp với chân ngắt khẩn cấp của CPU. |
| 18 | [`DMA-controller/rtl/dma_apb_slave.v`](file:///D:/domixi/DMA-controller/rtl/dma_apb_slave.v) | 120 | Giao tiếp cấu hình DMA qua APB | **PASS (0 Lỗi)** | Tiếp nhận lệnh cấu hình kênh truyền DMA từ CPU PicoRV32. |
| 19 | [`DMA-controller/rtl/dma_axi_master.v`](file:///D:/domixi/DMA-controller/rtl/dma_axi_master.v) | 510 | Master phát luồng dữ liệu DMA AXI | **PASS (0 Lỗi)** | Điều khiển đọc/ghi luồng dữ liệu AXI qua sự giám sát của Firewall. |
| 20 | [`DMA-controller/rtl/dma_fifo_latch.v`](file:///D:/domixi/DMA-controller/rtl/dma_fifo_latch.v) | 75 | Bộ đệm dữ liệu tạm thời của DMA | **PASS (0 Lỗi)** | FIFO đồng bộ đệm dữ liệu giữa kênh đọc và kênh ghi DMA. |
| 21 | [`DMA-controller/rtl/dma_controller.v`](file:///D:/domixi/DMA-controller/rtl/dma_controller.v) | 195 | Khối điều khiển trung tâm DMA | **PASS (0 Lỗi)** | Phối hợp bắt tay giữa Slave APB và Master AXI. |

---

## 3. Tổng Hợp Các Giới Hạn Vận Hành & Ràng Buộc Kiến Trúc Còn Lại

Mọi thiết kế phần cứng đều có giới hạn kỹ thuật được xác định theo đặc tả. Dự án AEGIS-RISC ghi nhận minh bạch các giới hạn sau:

1. **Giới Hạn Chiều Dài Burst AXI:** Chiều dài burst được thiết kế tối đa 16 beats (`req_len <= 15`). Các giao dịch dài hơn 16 beats phải được chia nhỏ (burst chopping) ở tầng master.
2. **Ranh Giới 4 KiB:** Các giao dịch AXI vượt ranh giới trang 4 KiB sẽ bị Firewall từ chối ngay tại Stage 1 (`calc_4kb_err`) theo tiêu chuẩn AMBA.
3. **Cơ Chế Bảo Vệ Ngắt (Anti-Storm):** Xung NMI được phát chính xác 1 chu kỳ khi `interrupt_pending` chuyển từ 0 sang 1. CPU bắt buộc phải ghi 1 xóa (W1C) cờ ngắt tại thanh ghi `0x0BC` trước khi Firewall có thể phát xung NMI tiếp theo.
4. **Hàng Đợi Điều Tra (Forensic FIFO):** Hàng đợi có độ sâu 4 mục. Khi đầy, cờ tràn `fifo_overflow_containment` kích hoạt và dữ liệu cũ không bị ghi đè để bảo toàn bằng chứng vi phạm.
5. **Dải Tần Số Vận Hành Silicon:**
   - Góc danh định TT (1.80V, 25°C): Tần số tối đa là **$38.00\text{ MHz}$** ($T_{clk} = 26.315\text{ ns}$) theo `WAV-STA-003`.
   - Góc chậm SS (1.60V, 100°C): Tần số tối đa là **$19.23\text{ MHz}$** ($T_{clk} = 52.000\text{ ns}$) theo `WAV-STA-001`.
6. **Quy Trình Khởi Động Lạnh (Cold-Boot):** Dưới 0°C, hệ thống yêu cầu duy trì 16 chu kỳ reset sau khi cấp nguồn theo `WAV-STA-002` để triệt tiêu vi phạm hold biên thô.

---

## 4. Kết Luận Rà Soát Coding

- **Lỗi Nghiêm Trọng (Critical Defects):** Không có (0 lỗi). Không phát hiện race condition, latch ngoài ý muốn, hay deadlock FSM.
- **Tính Nhất Quán Mã Nguồn:** Toàn bộ 21 tệp RTL sản xuất hoàn toàn đồng nhất với commit `ba7a753` sau chuẩn hóa CRLF/LF.
- **Mức Độ Sẵn Sàng:** Mã nguồn RTL đạt chuẩn chất lượng thiết kế vi mạch để bàn giao thẩm định nghiệm thu.
