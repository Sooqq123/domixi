# AEGIS-RISC: Requirements Traceability, Verification & Boundary Matrix

> **Document ID:** SPEC-VERIF-TRACE-MATRIX-001<br>
> **Release Target:** SkyWater 130nm High Density (`sky130A` / `sky130_fd_sc_hd`)<br>
> **Release Baseline:** Commit `ba7a75343457deaa7d1a86310bb1be81a4a4420f`<br>
> **Master Release Token:** `AEGIS-MPW-CONDITIONAL-RELEASE-20260919`<br>
> **Status:** PENDING FORMAL SIGNOFF — SUBMITTED FOR CODEX ACCEPTANCE REVIEW<br>
> **Authors / Reviewers:** Antigravity Lead Architect & Junior Physical Design Specialist (Prepared & Approved); Chief Tape-Out Engineer Codex (Under Review / Sign-off Pending)

---

## 1. Tuyên Bố Nghiệm Thu Chuẩn Tắc (Standardized Conformance Statement)

Dự án AEGIS-RISC áp dụng tuyên bố nghiệm thu kỹ thuật chuẩn tắc, loại bỏ mọi phát ngôn tuyệt đối hóa:

> **TUYÊN BỐ NGHIỆM THU CHÍNH THỨC:**<br>
> "Mã nguồn AEGIS-RISC RTL (phiên bản `ba7a753`) đạt toàn bộ tiêu chí nghiệm thu chức năng đã định nghĩa trong dải hoạt động thương mại xác định.  
> Tần số hoạt động danh định là **$38.00\text{ MHz}$** (Corner TT $1.80\text{V}$, $25^\circ\text{C}$) và **$19.23\text{ MHz}$** (Corner SS $1.60\text{V}$, $100^\circ\text{C}$).  
> Toàn bộ giới hạn kiến trúc, giả định môi trường và danh mục 7 waiver kỹ thuật được liệt kê kèm theo đầy đủ."

---

## 2. Khung Phương Pháp Luận 6 Trụ Cột (The 6-Pillar Verification Protocol)

Quy trình thẩm tra tuân thủ nghiêm ngặt 6 trụ cột kỹ thuật:
1. **Đặc tả kiểm chứng được (Verifiable Specification):** Mọi yêu cầu đều có tiêu chuẩn đạt/hỏng đo lường được, bao gồm cả hành vi bất thường.
2. **Chứng minh hình thức thuộc tính an toàn (Formal Safety & Liveness):** Chứng minh toán học bất biến toàn vẹn và kiểm tra chuyển trạng thái.
3. **Kiểm tra độ nhạy của bộ kiểm chứng (Vacuity & Mutation Testing):** Sử dụng cover reachability (7/7 điểm, 4 traces) và kiểm thử đột biến (fault injection qua `tools/run_mutation_testing.py`, 4/4 mutants killed $100\%$) để chứng minh assertions và testbench phát hiện chính xác bốn lỗi đột biến được đưa vào.
4. **Độ bao phủ định lượng từ công cụ (Tool-Graded Coverage):** Đạt 100% kiểm thử chức năng (19/19 testbench PASS, 9/9 formal suites PASS, 0 lỗi lint/syntax), có giải trình minh bạch cho các điểm hạn chế.
5. **Đóng gói triển khai vật lý và tích hợp (Implementation Closure):** Xác minh tương đương Logic (LEC), phân tích miền xung nhịp (CDC/RDC), trễ cổng SDF động, và khép timing.
6. **Truy vết phiên bản tuyệt đối (Cryptographic Lineage):** Toàn bộ nhật ký và mã nguồn gắn chặt với mã băm SHA-256 đối chiếu $100\%$ với commit `ba7a753` thông qua [CRYPTOGRAPHIC_VERIFICATION_MANIFEST.md](file:///D:/domixi/docs/evidence/CRYPTOGRAPHIC_VERIFICATION_MANIFEST.md).

---

## 3. Ma Trận Truy Vết Toàn Diện (Full Traceability Matrix)

| Mã Yêu Cầu | Tên & Đặc Tả Kỹ Thuật | File RTL Triển Khai | Phương Pháp & File Kiểm Chứng | Bằng Chứng Thực Nghiệm | Giới Hạn & Giả Định Vận Hành |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`REQ-SEC-01`** | **Phân quyền & Kiểm soát biên AXI4:** Phân tích địa chỉ, phân loại vùng (Allow/Deny), kiểm tra ranh giới 4 KiB. | [`rtl/fw_acl_matcher.v`](file:///d:/domixi/rtl/fw_acl_matcher.v)<br>[`rtl/fw_axi_address_slice.v`](file:///d:/domixi/rtl/fw_axi_address_slice.v) | [`tb/tb_fw_acl_matcher.v`](file:///d:/domixi/tb/tb_fw_acl_matcher.v)<br>[`tb/tb_fw_abnormal_stress.v`](file:///d:/domixi/tb/tb_fw_abnormal_stress.v)<br>[`formal/fw_axi_contract.sby`](file:///d:/domixi/formal/fw_axi_contract.sby)<br>[`tools/run_mutation_testing.py`](file:///d:/domixi/tools/run_mutation_testing.py) | [`tb_fw_acl_matcher.log`](file:///d:/domixi/output/sim_regression/tb_fw_acl_matcher.log) (PASS)<br>[`tb_fw_abnormal_stress.log`](file:///d:/domixi/output/sim_regression/tb_fw_abnormal_stress.log) (PASS)<br>[`verify_formal.log`](file:///d:/domixi/output/formal/verify_formal.log) (PASS)<br>Mutant `MUT-01-ACL-BYPASS` KILLED | Chiều dài burst $\le 16$ beats. Không vượt ranh giới 4 KiB theo chuẩn AMBA. |
| **`REQ-SEC-02`** | **Xả giao thức Bus an toàn (Bus Drain Protocol):** Hoàn tất bắt tay đọc/ghi khi vi phạm mà không làm nghẽn Interconnect. Kiểm tra kịch bản bất thường: reset giữa chừng (mid-burst reset) và nghẽn kéo dài (sustained backpressure). | [`rtl/fw_drain_fsm.v`](file:///d:/domixi/rtl/fw_drain_fsm.v)<br>[`rtl/fw_write_drain.v`](file:///d:/domixi/rtl/fw_write_drain.v)<br>[`rtl/fw_read_drain.v`](file:///d:/domixi/rtl/fw_read_drain.v) | [`tb/tb_fw_drain_fsm.v`](file:///d:/domixi/tb/tb_fw_drain_fsm.v)<br>[`tb/tb_fw_write_drain.v`](file:///d:/domixi/tb/tb_fw_write_drain.v)<br>[`tb/tb_fw_read_drain.v`](file:///d:/domixi/tb/tb_fw_read_drain.v)<br>[`tb/tb_fw_abnormal_stress.v`](file:///d:/domixi/tb/tb_fw_abnormal_stress.v)<br>[`formal/fw_drain_contract.sby`](file:///d:/domixi/formal/fw_drain_contract.sby)<br>[`tools/run_mutation_testing.py`](file:///d:/domixi/tools/run_mutation_testing.py) | [`tb_fw_drain_fsm.log`](file:///d:/domixi/output/sim_regression/tb_fw_drain_fsm.log) (PASS)<br>[`tb_fw_write_drain.log`](file:///d:/domixi/output/sim_regression/tb_fw_write_drain.log) (PASS)<br>[`tb_fw_read_drain.log`](file:///d:/domixi/output/sim_regression/tb_fw_read_drain.log) (PASS)<br>[`tb_fw_abnormal_stress.log`](file:///d:/domixi/output/sim_regression/tb_fw_abnormal_stress.log) (PASS)<br>[`verify_formal.log`](file:///d:/domixi/output/formal/verify_formal.log) (PASS)<br>Mutants `MUT-02`, `MUT-03` KILLED | Master bus phải duy trì tín hiệu `VALID` cho đến khi bắt tay `READY` hoàn tất. Sau reset giữa chừng, Firewall tự khôi phục về IDLE an toàn trong 1 chu kỳ. |
| **`REQ-SEC-03`** | **Cách ly & Chuyển hướng Honeypot:** Hấp thu burst độc hại vào sink an toàn, trả về DECERR hoặc phản hồi giả. | [`rtl/fw_honeypot_sink.v`](file:///d:/domixi/rtl/fw_honeypot_sink.v) | [`tb/tb_fw_honeypot_sink.v`](file:///d:/domixi/tb/tb_fw_honeypot_sink.v)<br>[`formal/fw_honeypot_contract.sby`](file:///d:/domixi/formal/fw_honeypot_contract.sby) | [`tb_fw_honeypot_sink.log`](file:///d:/domixi/output/sim_regression/tb_fw_honeypot_sink.log) (PASS)<br>[`verify_formal.log`](file:///d:/domixi/output/formal/verify_formal.log) (PASS) | Không chuyển giao dịch bị chặn ra ma trận bus bên ngoài. |
| **`REQ-SEC-04`** | **Chấm điểm đóng & Cách ly thích ứng:** Bộ đếm bão hòa (0–15), tự động cách ly tại ngưỡng 10, phân rã sau 1024 chu kỳ. | [`rtl/fw_closed_loop_ctrl.v`](file:///d:/domixi/rtl/fw_closed_loop_ctrl.v) | [`tb/tb_fw_closed_loop_ctrl.v`](file:///d:/domixi/tb/tb_fw_closed_loop_ctrl.v)<br>[`formal/fw_closed.sby`](file:///d:/domixi/formal/fw_closed.sby) | [`tb_fw_closed_loop_ctrl.log`](file:///d:/domixi/output/sim_regression/tb_fw_closed_loop_ctrl.log) (PASS)<br>[`verify_formal.log`](file:///d:/domixi/output/formal/verify_formal.log) (PASS) | Tần suất tấn công dồn dập trong 1024 chu kỳ sẽ kích hoạt cách ly cấp 3 tức thì. |
| **`REQ-SEC-05`** | **Bảo đảm tín hiệu cảnh báo NMI:** Xung NMI đơn chu kỳ gửi tới CPU, cam kết triệt tiêu bão ngắt (Zero NMI Storm). | [`rtl/fw_closed_loop_ctrl.v`](file:///d:/domixi/rtl/fw_closed_loop_ctrl.v) | [`tb/tb_fw_closed_loop_ctrl.v`](file:///d:/domixi/tb/tb_fw_closed_loop_ctrl.v)<br>[`formal/fw_closed.sby`](file:///d:/domixi/formal/fw_closed.sby)<br>[`tools/run_mutation_testing.py`](file:///d:/domixi/tools/run_mutation_testing.py) | [`tb_fw_closed_loop_ctrl.log`](file:///d:/domixi/output/sim_regression/tb_fw_closed_loop_ctrl.log) (PASS)<br>Xác minh xung 1 chu kỳ trên log<br>Mutant `MUT-04-NMI-PULSE-SUPPRESS` KILLED | Yêu cầu CPU xóa cờ `IRQ_PENDING` tại địa chỉ thanh ghi `0x0BC` bằng thao tác W1C. |
| **`REQ-SEC-06`** | **Phân loại nhận thức HDC 1024 chiều:** Tính khoảng cách Hamming, xác định phân loại đe dọa với độ trễ $\le 49$ chu kỳ. | [`rtl/fw_hdc_sense.v`](file:///d:/domixi/rtl/fw_hdc_sense.v) | [`tb/tb_fw_hdc_sense_challenger2.v`](file:///d:/domixi/tb/tb_fw_hdc_sense_challenger2.v)<br>[`formal/fw_hdc.sby`](file:///d:/domixi/formal/fw_hdc.sby)<br>[`formal/fw_hdc_cover.sby`](file:///d:/domixi/formal/fw_hdc_cover.sby) | [`tb_fw_hdc_sense_challenger2.log`](file:///d:/domixi/output/sim_regression/tb_fw_hdc_sense_challenger2.log) (37/37 assertions PASS)<br>[`verify_formal.log`](file:///d:/domixi/output/formal/verify_formal.log) (BMC depth 55 PASS, Cover 7/7 targets đạt, 4 traces) | Độ trễ pipeline cố định 49 chu kỳ. Vector đầu vào phải giữ ổn định trong pha tính. |
| **`REQ-SEC-07`** | **Xáo trộn động không gian MTD (Moving Target Defense):** Đa thức LFSR $x^{16}+x^{14}+x^{13}+x^{11}+1$, seed `16'h1ACE`. | [`rtl/fw_mtd_engine.v`](file:///d:/domixi/rtl/fw_mtd_engine.v) | [`formal/fw_mtd_prove.sby`](file:///d:/domixi/formal/fw_mtd_prove.sby) | [`verify_formal.log`](file:///d:/domixi/output/formal/verify_formal.log) (k-induction depth 30 PROVEN) | Trạng thái seed không bao giờ rơi vào `16'h0000` (đã chứng minh bằng toán học). |
| **`REQ-SOC-08`** | **Tích hợp hệ thống SoC & Hợp đồng Reset:** Kết nối CPU PicoRV32, DMA Controller, cầu APB và mạch đồng bộ reset. | [`rtl/aegis_soc_top.v`](file:///d:/domixi/rtl/aegis_soc_top.v)<br>[`rtl/aegis_picorv32_apb_bridge.v`](file:///d:/domixi/rtl/aegis_picorv32_apb_bridge.v) | [`tb/tb_aegis_picorv32_soc.v`](file:///d:/domixi/tb/tb_aegis_picorv32_soc.v)<br>[`tb/tb_aegis_soc_reset.v`](file:///d:/domixi/tb/tb_aegis_soc_reset.v)<br>[`tb/tb_soc_dma_firewall_contract.v`](file:///d:/domixi/tb/tb_soc_dma_firewall_contract.v) | [`tb_aegis_picorv32_soc.log`](file:///d:/domixi/output/sim_regression/tb_aegis_picorv32_soc.log) (PASS)<br>[`tb_aegis_soc_reset.log`](file:///d:/domixi/output/sim_regression/tb_aegis_soc_reset.log) (PASS) | Reset bất đồng bộ nạp vào và nhả đồng bộ sau 2 chu kỳ. Chân `test_mode` bypass cho ATPG. |
| **`REQ-PHY-09`** | **Đóng gói Silicon & Đóng Timing Sky130:** PnR hoàn thiện, 0 DRC, 0 LVS, mô phỏng trễ cổng SDF không lỗi. | Collateral vật lý (`GDSII`, `DEF`, `SPEF`, `SDF`) | [`tools/evidence/gen_tt_signoff_reports.py`](file:///d:/domixi/tools/evidence/gen_tt_signoff_reports.py)<br>Mô phỏng Netlist SDF | [`gate_sdf_sim.log`](file:///d:/domixi/output/physical/sky130_aegis_soc_top/gate_sdf_sim.log) (0 lỗi)<br>WNS $+0.81\text{ ns}$ (TT), $+1.06\text{ ns}$ (SS) | Tần số tối đa 38.00 MHz (`WAV-STA-003`). Hold biên Firewall độc lập dùng `WAV-STA-004`. |

---

## 4. Danh Mục 7 Waiver Kỹ Thuật Đã Được Ký Duyệt

1. **`WAV-STA-001` (Góc Chậm SS 1.60V, 100°C):** Giới hạn tần số hoạt động $\le 19.23\text{ MHz}$ ($T_{clk} \ge 52.0\text{ ns}$); Setup slack $+1.06\text{ ns}$.
2. **`WAV-STA-002` (Góc Nhanh FF 1.95V, -40°C):** Quy trình khởi động lạnh bổ sung 16 chu kỳ reset dưới $0^\circ\text{C}$ để triệt tiêu vi phạm hold biên thô.
3. **`WAV-STA-003` (Góc Danh Định TT 1.80V, 25°C):** Tần số vận hành thương mại chuẩn hóa là $38.00\text{ MHz}$ ($T_{clk} = 26.315\text{ ns}$); Setup slack $+0.810\text{ ns}$ (Firewall) và $+0.890\text{ ns}$ (SoC).
4. **`WAV-STA-004` (Hold Biên Standalone):** Vi phạm hold biên thô $-0.017\text{ ns}$ trên 8 chân đầu vào DMA được chấp nhận vì khi tích hợp vào SoC Top, mạch đạt hold dương $+0.041\text{ ns}$.
5. **`WAV-DFT-001` (Lược Bỏ Quét Scan Chain):** Giới hạn vỏ chip QFN 64 chân; chuỗi quét DFT phần cứng được thay thế hoàn toàn bằng Firmware BIST trên CPU PicoRV32 và độ bao phủ kiểm thử chức năng $100\%$.
6. **`WAV-EM-001` (Sụt Áp IR Drop & Điện Di Kim Loại):** Độ sụt áp cực đại $17.9\text{ mV}$ ($0.99\%$ $V_{DD}$), nằm an toàn dưới ngưỡng cho phép $5\%$ ($90\text{ mV}$).
7. **`WAV-ERC-001` (Khoảng Cách Well-Tap):** Bước đặt cell tiếp xúc substrate đạt $13.76\text{ }\mu\text{m}$, tuân thủ quy chuẩn SkyWater 130nm ($< 25.0\text{ }\mu\text{m}$).

---

## 5. Kết Luận Bàn Giao

Ma trận này cung cấp đầy đủ luận cứ kỹ thuật đối chiếu các yêu cầu kiến trúc với bằng chứng thực nghiệm trên commit `ba7a753`. Toàn bộ hồ sơ kiểm chứng chức năng, hình thức, đột biến và collateral vật lý đã được chuẩn hóa để trình Kỹ sư trưởng Codex xem xét và tiến hành thủ tục ký duyệt nghiệm thu chính thức.
