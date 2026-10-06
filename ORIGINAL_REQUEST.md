# Original User Request

## 2026-09-14T10:24:12Z

Thiết kế và hiện thực hóa Hệ vi mạch tự miễn dịch và phòng thủ đa hình đóng kín (Bio-Inspired Closed-Loop Polymorphic Immune SoC — Tên mã: AEGIS-RISC) nâng cấp trực tiếp bộ lọc DMA Bus Firewall và lõi RISC-V PicoRV32 tại `d:\domixi\rtl`. Hệ thống tích hợp Giác quan nhận thức siêu nhẹ (HDC-Sense), Bộ mê cung biến hình đa hình (MTD-Morph Engine & Honey-Pot) và Vòng phản xạ đóng kín khẩn cấp (NMI Closed-Loop Link) để triệt tiêu hoàn toàn các đòn tấn công DMA Rowhammer, Kênh kề thời gian (Timing Side-Channel), Bus Flooding và Trojan kích hoạt chuỗi.

Working directory: d:\domixi
Integrity mode: development

## Requirements

### R1. Khối Giác quan Nhận thức Siêu nhẹ (`fw_hdc_sense.v`)
- Thu thập tín hiệu vi kiến trúc thời gian thực từ kênh AXI (`AxADDR`, `AxLEN`, `AxSIZE`, `AxMID`, timing delta giữa các burst) và telemetry từ pipeline PicoRV32 (trap, branch, memory stalls).
- Áp dụng mô hình Hyperdimensional Computing (HDC) nhị phân 1024-bit bằng 100% logic tổ hợp thuần túy (Zero-DSP, Zero-MAC unit), đánh giá cấp độ đe dọa (Threat Level 0: Safe, Level 1: Probe, Level 2: Active Attack, Level 3: Critical Breach) trong đúng 1 chu kỳ clock.

### R2. Khối Mê cung Biến hình Đa hình (`fw_mtd_engine.v`)
- Cơ chế Moving Target Defense (MTD) thích ứng theo cấp độ đe dọa:
  * Threat Level 1: Kích hoạt bộ ngẫu nhiên hóa thời gian (Clock Jitter / Dummy Transaction Generator) làm phẳng đồ thị thời gian, chống tấn công kênh kề đo lường độ trễ bus.
  * Threat Level 2: Kích hoạt cơ chế tráo đổi không gian địa chỉ động (Dynamic Address Scrambling) bằng khóa xoay vòng ephemeral, bí mật chuyển hướng luồng burst Rowhammering sang vùng đệm bẫy an toàn (Honey-pot Buffer) mà không để kẻ tấn công phát hiện.
  * Threat Level 3: Kích hoạt cờ báo động khẩn cấp và chuyển giao dịch cho `fw_drain_fsm.v`.

### R3. Vòng lặp Phản xạ Đóng kín với CPU PicoRV32 (`fw_closed_loop_ctrl.v` & `fw_apb_regs.v`)
- Tích hợp đường truyền ngắt phi mặt nạ (NMI - Non-Maskable Interrupt) trực tiếp từ Firewall tới PicoRV32 khi phát hiện xâm nhập cấp 3.
- Bổ sung các thanh ghi lưu vết pháp y số (Forensic Fingerprint Registers) trên giao diện APB trong `fw_apb_regs.v` để ghi nhận mẫu mã vạch tấn công, ID kẻ xâm nhập và thời điểm vi phạm.

### R4. Hệ thống Testbench Kiểm chứng Toàn diện & Báo cáo PPA
- Xây dựng Testbench Verilog tự kiểm tra (`tb_aegis_soc.v`) tái hiện:
  1. Kịch bản tấn công DMA Rowhammer (5000+ burst xen kẽ vào 2 hàng nhớ).
  2. Kịch bản tấn công Kênh kề thời gian (Timing Probe / Bus Contention).
  3. Kịch bản truyền dữ liệu DMA tuần tự thông thường (Normal DMA transfers).
- Xuất file dạng sóng `.vcd` hiển thị rõ chuyển mạch đa hình MTD, bẫy Honey-pot và tín hiệu NMI.
- Chạy tổng hợp logic đo lường PPA: Chi phí diện tích bổ sung <= 5% tổng firewall; tần số Fmax suy giảm <= 3%.

## Acceptance Criteria

### Tính năng Bảo mật & Phát hiện Tấn công
- [ ] Khối `fw_hdc_sense` phân loại chính xác 100% các chuỗi tấn công Rowhammer và Side-channel probe trong testbench trong vòng <= 1 chu kỳ clock.
- [ ] Cơ chế `fw_mtd_engine` chuyển hướng thành công các burst Rowhammer vào Honey-pot buffer mà không gây lỗi giao thức AXI và không làm treo bus.
- [ ] Tín hiệu ngắt NMI kích hoạt chính xác trong vòng <= 2 chu kỳ clock kể từ khi phát hiện vi phạm cấp 3.
- [ ] Tỷ lệ False Positive = 0 trên toàn bộ luồng truyền DMA hợp lệ thông thường.

### Hiệu năng & Ràng buộc Vi mạch (PPA)
- [ ] Thời gian trễ suy luận của HDC: Đúng 1 chu kỳ clock (Single-cycle decision).
- [ ] Diện tích cổng logic / số lượng LUTs bổ sung của các module mới <= 5% tổng diện tích DMA Bus Firewall ban đầu.
- [ ] Tần số hoạt động Fmax của hệ thống không giảm quá 3% so với baseline hiện hành.

## 2026-09-14T11:30:12Z

CHỈ THỊ TRỰC TIẾP TỪ NGƯỜI DÙNG: Chỉ tập trung hoàn thiện toàn bộ thiết kế RTL (Front-end design gồm: fw_hdc_sense.v, fw_mtd_engine.v, fw_closed_loop_ctrl.v, tích hợp vào dma_bus_firewall.v và testbench). KHÔNG THỰC HIỆN CÁC QUÁ TRÌNH PHÍA SAU ĐÓ (bỏ qua các bước physical design, backend PPA iterations kéo dài hoặc signoff phức tạp). Sau khi hoàn thiện thiết kế RTL sạch sẽ, tổng hợp được và có testbench thì dừng lại và đóng gói bàn giao thiết kế.
