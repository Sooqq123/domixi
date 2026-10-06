# AEGIS-RISC: Spec Baseline & Architecture Blueprint
> Bio-Inspired Closed-Loop Polymorphic Immune SoC Architecture
> Baseline: DMA Bus Firewall (`d:\domixi\rtl`) + RISC-V PicoRV32 (`d:\domixi\picorv32-main`)

## 1. Giới thiệu & Tầm nhìn Kiến trúc
AEGIS-RISC là kiến trúc vi mạch tự miễn dịch và phòng thủ đa hình đóng kín (Bio-Inspired Closed-Loop Polymorphic Immune SoC) được thiết kế để nâng cấp trực tiếp bộ lọc DMA Bus Firewall hiện hữu tại `d:\domixi\rtl`. Hệ thống biến tường lửa thụ động thành hệ thống phòng thủ phản xạ chủ động 3 lớp:
1. **Lớp 1 (Baseline Deterministic ACL):** Kiểm tra luật cứng địa chỉ, 4KB page crossing, burst alignment, MID & PROT qua `fw_acl_matcher.v` và `fw_axi_address_slice.v`.
2. **Lớp 2 (HDC-Sensing & Moving Target Defense):** Khối `fw_hdc_sense.v` thu thập vi tín hiệu AXI bus và pipeline trong 1 chu kỳ clock, nhận diện các đòn tấn công hành vi (Rowhammer, Bus Flooding, Side-channel probe). Khối `fw_mtd_engine.v` biến hình không gian địa chỉ động (Dynamic Address Scrambling) và điều hướng vào bẫy Honey-pot.
3. **Lớp 3 (Closed-Loop Reflex & Self-Healing):** Kết nối tín hiệu cảnh báo NMI trực tiếp vào vi xử lý PicoRV32, ghi nhận forensics vào `fw_apb_regs.v` và kích hoạt `fw_drain_fsm.v` để dập tắt tấn công mà không làm treo bus.

---

## 2. Đặc tả Giao diện & Tín hiệu Module Mới

### 2.1. Module `fw_hdc_sense.v` (Giác quan Nhận thức Siêu nhẹ)
* **Thông số đầu vào (Inputs):**
  - `clk`, `resetn`: Xung nhịp và reset tích cực mức thấp.
  - `s1_awvalid`, `s1_awaddr [31:0]`, `s1_awlen [7:0]`, `s1_awsize [2:0]`, `s1_awmid [3:0]`
  - `s1_arvalid`, `s1_araddr [31:0]`, `s1_arlen [7:0]`, `s1_arsize [2:0]`, `s1_armid [3:0]`
  - `cpu_telemetry_trap`, `cpu_telemetry_stall`: Tín hiệu trạng thái từ PicoRV32.
* **Thông số đầu ra (Outputs):**
  - `threat_level [1:0]`:
    * `2'b00`: Safe (Bình thường)
    * `2'b01`: Probe / Side-Channel Warning (Cảnh báo thăm dò thời gian)
    * `2'b10`: Active Attack / Rowhammer Hammering (Tấn công dập ô nhớ vật lý)
    * `2'b11`: Critical Breach / Trojan Trigger (Xâm nhập nghiêm trọng)
  - `hdc_anomaly_alert`: Tích cực mức cao khi `threat_level >= 2'b10`.
  - `attack_fingerprint [31:0]`: Mã băm nhị phân ghi nhận đặc trưng cuộc tấn công.

### 2.2. Module `fw_mtd_engine.v` (Mê cung Biến hình Đa hình)
* **Thông số đầu vào (Inputs):**
  - `clk`, `resetn`
  - `threat_level [1:0]`
  - `orig_addr [31:0]`: Địa chỉ gốc từ Address Slice.
  - `orig_valid`: Tín hiệu hợp lệ của request.
* **Cơ chế hoạt động:**
  - Khi `threat_level == 2'b01`: Kích hoạt bộ ngẫu nhiên hóa thời gian (Clock Jitter / Dummy bus cycle request).
  - Khi `threat_level == 2'b10`: Kích hoạt bộ hoán vị địa chỉ động (Dynamic Address Scrambler) bằng khóa ngẫu nhiên xoay vòng ephemeral LFSR key, điều hướng các burst Rowhammering sang vùng đệm bẫy an toàn `HONEY_POT_BASE (0x7F00_0000)` mà không để Master nghi ngờ.
  - Khi `threat_level == 2'b11`: Kích hoạt yêu cầu Drain cho `fw_drain_fsm.v`.
* **Thông số đầu ra (Outputs):**
  - `morph_addr [31:0]`: Địa chỉ đã được bảo vệ/điều hướng.
  - `honey_pot_hit`: Bật lên 1 khi transaction đã bị bẫy vào Honey-pot.
  - `force_drain_req`: Tín hiệu ép xả hủy transaction an toàn.

### 2.3. Module `fw_closed_loop_ctrl.v` (Vòng lặp Phản xạ Đóng kín)
* **Chức năng:**
  - Nhận `hdc_anomaly_alert` và `force_drain_req`.
  - Bắn xung ngắt `aegis_nmi_irq` trực tiếp vào chân ngắt ưu tiên cao nhất của CPU PicoRV32.
  - Giao tiếp với `fw_apb_regs.v` qua các thanh ghi mới:
    * Offset `0x090`: `REG_AEGIS_STATUS` (Cấp độ đe dọa, số lần phát hiện tấn công, trạng thái MTD).
    * Offset `0x094`: `REG_AEGIS_FINGERPRINT` (Mã vân tay cuộc tấn công cuối).
    * Offset `0x098`: `REG_AEGIS_HONEY_COUNT` (Số lượng burst bị tóm vào Honey-pot).

---

## 3. Bản đồ File & Phân công Triển khai
1. `d:\domixi\rtl\fw_hdc_sense.v` [MỚI]
2. `d:\domixi\rtl\fw_mtd_engine.v` [MỚI]
3. `d:\domixi\rtl\fw_closed_loop_ctrl.v` [MỚI]
4. `d:\domixi\rtl\dma_bus_firewall.v` [NÂNG CẤP - Ghép nối các module mới]
5. `d:\domixi\rtl\fw_apb_regs.v` [NÂNG CẤP - Bổ sung thanh ghi forensics]
6. `d:\domixi\tb\tb_aegis_soc.v` [MỚI - Testbench tự kiểm tra toàn diện]
