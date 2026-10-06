# LỊCH SỬ THAY ĐỔI & PHIÊN BẢN TÀI LIỆU (CHANGELOG)
## DMA-Aware Bus Firewall IP & DMA Controller Core

---

### [Phiên Bản V2.5.0 — Historical implementation snapshot, superseded for physical status] - 2026-09-14

> Audit lại ngày 2026-09-17 không tái lập được các claim physical bên dưới: workspace không có PDK Sky130A, LEF/SPEF/GDS hoặc rule decks. Các số liệu RTL-to-GDSII của snapshot này chỉ giữ lại cho lịch sử và không phải bằng chứng sign-off hiện hành.

* **Nghiệm thu toàn diện mã nguồn RTL và triển khai vật lý ASIC:**
  - **Claim RTL lịch sử:** Snapshot từng mô tả bảy submodule lá và top `dma_bus_firewall` (87 public ports); source hiện hành đã bổ sung `fw_honeypot_sink` và chốt boundary 94 ports.
  - **Đóng toàn bộ các cổng kiểm chứng RTL (G0–G3):** 13/13 testbench đơn vị và integration harness compile zero-warning, vượt qua toàn bộ các ca kiểm thử chức năng, cơ chế khóa sticky RW1S, bảo vệ phân quyền APB4, priority cùng chu kỳ, drain FSM và error-abort.
  - **Claim physical lịch sử (chưa tái lập):** Snapshot từng ghi nhận OpenLane/OpenROAD trên Sky130A với 8.790 cells, DRC/LVS sạch và STA đạt; audit hiện hành đánh dấu claim này là chưa được chứng minh.
  - **Đồng bộ hóa ma trận truy vết lịch sử:** Snapshot từng đóng các yêu cầu Firewall và `PPA-01`; trạng thái PPA hiện hành đã được hạ về `TBD / BLOCKED` cho đến khi physical collateral được cung cấp.
  - **Nâng cấp tài liệu đặc tả PRD và Microarchitecture:** Cập nhật nội dung đồng bộ với baseline chuẩn, bổ sung sơ đồ vi kiến trúc, dữ liệu layout và thông số PPA thực tế, gỡ bỏ nhãn obsolete.

---

### [Phiên Bản V2.4.1 — Clarification & Closure Baseline] - 2026-08-23

* **Đóng mâu thuẫn P0 còn lại ngoài Firewall RTL:**
  - Phân biệt address acceptance với permission grant; chốt immutable transaction/ACL snapshot và backpressure Stage 2.
  - Sửa abort FSM để VALID đã present không bị rút lại khi abort; request handshake sau đó trở thành committed và phải drain.
  - Chuẩn hóa write drain theo đúng `AWLEN+1`, read drain theo `ARLEN+1`, giữ ID/mode đã chốt và ghi PROT_ERR khi WLAST sai vị trí.
  - Chốt dedicated DMA identity `AxID=0`, trust attributes `AxPROT=001`, Region 4/5 Secure-Privileged và DMA APB aperture Secure-Privileged upstream.
  - Chốt `FW_EN` chỉ bypass ACL; `AUTO_CTX_EN` disable xóa dynamic regions; active-descriptor/base-limit violations trả PSLVERR.
  - Chuẩn hóa multi-source fault logger: status OR mọi event, counter tăng theo số record, first-fault priority `context > write > read`.
  - Sửa rectangular CSV, duplicate testcase/reset expectation và công thức bounded liveness.
  - Thêm document/evidence manifest và Firewall RTL integration contract; ghi chính xác trạng thái Firewall là partial draft/not integrated.
  - Archive triệt để các HTML/PDF/generator V2.1; chúng không còn quyền phê duyệt hay conformance.
  - Đóng remediation model/DMA ngày 2026-08-24: model 46 tests PASS, benchmark 37/37; bốn DMA RTL testbench source-built PASS với zero compile warning. Independent review phát hiện và đã sửa RLAST framing để đối chiếu chính xác `ARLEN+1`, đồng thời bổ sung early/missing-RLAST negative tests và FIFO full scoreboard.

> V2.4.1 supersede V2.4 khi có mâu thuẫn. Đây là clarification/closure release; hạng mục Firewall RTL vẫn do chủ dự án triển khai và mọi evidence phụ thuộc nó giữ `BLOCKED_FIREWALL_RTL`.

---

### [Phiên Bản V2.4 — Canonical Architecture Baseline & Audit Reconciliation] - 2026-08-22
> V2.4 là lịch sử đã được V2.4.1 supersede khi có mâu thuẫn.
* **Đồng bộ hóa Toàn diện Kiến trúc theo Kết quả Kiểm toán Độc lập Codex & Rà soát Đa bên:**
  - **Trạng thái Tiêu chuẩn:** Xác lập trạng thái chính thức `Canonical Architecture Baseline V2.4 — RTL Conformance Pending`. Phân biệt rạch ròi giữa yêu cầu kiến trúc chuẩn mực và trạng thái thực thi hiện tại của RTL.
  - **Khóa Chặt Ngữ Nghĩa `DMA_CTRL.START`:** Access Type là `WO` (Write-Only) Command Pulse; ghi 1 khi `BUSY=0` kích hoạt 1 chu kỳ; ghi khi `BUSY=1` bị bỏ qua (Ignored/No-op); đọc luôn trả về 0 (RAZ/WI); tuyệt đối **KHÔNG tự động xóa ngầm** các cờ `DONE` hoặc `ERROR`.
  - **Khóa Chặt Ngữ Nghĩa `DMA_STATUS`:** `BUSY` (RO), `DONE` và `ERROR` là sticky W1C độc lập; hardware-set thắng W1C cùng chu kỳ. Lỗi hiện tại không phát done-set event nhưng không tự xóa DONE còn lưu từ giao dịch trước. Ngắt `dma_irq = IRQ_EN & (DONE | ERROR)`.
  - **Phân Tầng An Ninh APB (Privilege Partitioning):** `dma_apb_slave` là peripheral APB3 không có chân `pprot` cục bộ; việc kiểm tra đặc quyền Privileged cho DMA MMIO được ủy quyền cho Upstream Interconnect. `fw_apb_slave` có chân `s_apb_pprot` riêng để tự bảo vệ độc lập.
  - **Ràng Buộc Thứ Tự AXI Write Ordering & Backpressure:** Master tuyệt đối **CẤM phát `WVALID` hoặc thực hiện handshake `W` trước khi `AW` handshake thành công (`AWVALID & AWREADY == 1`)**; giữ nguyên payload kênh AW dưới backpressure; tối đa 1 transaction outstanding mỗi kênh.
  - **Giao Thức Error-Abort & Liveness:** Lỗi AXI chốt `abort_pending`, chặn AR/AW mới, drain AR đã nhận, hoàn tất AW đã nhận, sau đó flush FIFO và phát terminal error/context-done. Liveness chỉ được cam kết dưới AXI progress/fairness assumptions; không dùng timeout để fabricates completion.
  - **First-Fault Metadata:** Clear fault bits/IRQ chỉ mở khóa capture; metadata giữ đến lỗi kế tiếp hoặc reset.
  - **Đính chính V2.3:** Loại bỏ transaction-terminating drain timeout 256 cycle vì có thể vi phạm AXI; sửa IRQ_PENDING thành sticky W1C độc lập; loại bỏ `dma_ctx_state` khỏi sideband canonical.
  - **Chuẩn Hóa Ma Trận Truy Vết (Requirements Traceability):** Áp dụng bộ từ vựng chính xác `Specified / Model Verified / RTL Missing / RTL Deviation / Test Planned` để phản ánh đúng hiện trạng triển khai.
  - **Tách Trạng Thái Conformance:** Thêm `implementation_conformance_status.md` để ghi bằng chứng model/RTL/testbench riêng khỏi baseline kiến trúc và ngăn suy diễn test PASS thành implementation approval.
  - **Nâng Cấp Bộ Kiểm Tra spec_lint.py:** Bổ sung kiểm tra version drift live, ngữ nghĩa WO/W1C của START/STATUS, assertion drain `s_axi_wready`, và tính nhất quán phân tầng an ninh APB.

---

### [Phiên Bản V2.3 — Audit Reconciliation, Obsolete/Superseded] - 2026-08-22
> Toàn bộ quyết định V2.3 dưới đây chỉ là lịch sử và bị V2.4 supersede khi có mâu thuẫn; đặc biệt timeout kết thúc transaction, `dma_ctx_state` và ngữ nghĩa IRQ cũ không còn hiệu lực.

* **Đồng bộ hóa bộ đặc tả theo Engineering Audit (historical):**
  - **Sink Drain Timeout:** Cố định tham số `DRAIN_TIMEOUT = 256 clock cycles` cho Write Drain FSM (chuyển sang `RESP` trả `DECERR`) và Read Drain FSM (quay về `IDLE`), loại bỏ hoàn toàn rủi ro DoS treo bus khi Master độc hại không gửi `WLAST` hoặc giữ `WVALID` dang dở (đóng TBD).
  - **Chuẩn hóa Tín hiệu Sideband:** Cập nhật đồng bộ tên tín hiệu `dma_ctx_src_addr`, `dma_ctx_dst_addr`, `dma_ctx_byte_len`, bổ sung chỉ báo trạng thái `dma_ctx_state[1:0]` cùng `dma_ctx_valid` và `dma_ctx_done`.
  - **Chuẩn hóa Giao thức APB:** Thống nhất tiền tố `s_apb_*` cho Firewall APB Slave (`s_apb_paddr`, `s_apb_psel`, `s_apb_penable`, `s_apb_pwrite`, `s_apb_pwdata`, `s_apb_pprot`, `s_apb_prdata`, `s_apb_pready`, `s_apb_pslverr`).
  - **Sửa Giá trị Reset của Tín hiệu READY:** Chuẩn hóa toàn bộ AXI READY outputs (`s_axi_awready`, `s_axi_wready`, `s_axi_arready`, `m_axi_bready`, `m_axi_rready`) có giá trị mặc định sau Reset cứng bằng `0`; chỉ duy nhất APB `s_apb_pready` giữ giá trị reset bằng `1`.
  - **Chuẩn hóa Kiểu Ngắt `sec_irq`:** Quy chuẩn duy nhất là ngắt mức tích cực cao (**Level-Sensitive Active-High**: `sec_irq = IRQ_EN && IRQ_PENDING`), loại bỏ hoàn toàn mô tả "pulse". Tín hiệu tự hạ khi toàn bộ cờ lỗi trong `FAULT_STATUS[3:0]` được xóa qua W1C hoặc khi `IRQ_EN = 0`.
  - **Mở rộng Chi tiết Bản đồ Thanh ghi (register_map.csv):** Tách chi tiết từng bit field cho Regions 1–3 và 6–7 tương đồng Region 0; bổ sung quy ước `RAZ/WI` (Read-As-Zero / Write-Ignored) cho tất cả bit Reserved; quy định trả `PSLVERR = 1` khi truy cập địa chỉ ngoài bản đồ, không căn chỉnh 4 bytes, vi phạm quyền Secure/Privileged, hoặc ghi đè sau `STICKY_LOCK = 1`; chốt `FAULT_COUNT` bão hòa tại `16'hFFFF` (no-wrap).
  - **Khôi phục An toàn FSM (Illegal-State Recovery):** Bổ sung nhánh `default -> IDLE` vào toàn bộ 5 bảng chuyển trạng thái FSM, đảm bảo hạ toàn bộ output về 0 và phục hồi trong 1 chu kỳ khi gặp glitch.
  - **Bổ sung Yêu cầu Kỹ thuật & Truy vết:** Thêm `REQ_FW_16` (Sink Drain Timeout Safety) và `REQ_FW_17` (APB Violation Response Security) vào `requirements_traceability.csv`.
  - **Bổ sung Kế hoạch Kiểm chứng & SVA:** Thêm Nhóm 5 (Kiểm chứng An toàn Phần cứng) gồm `TC_DRAIN_TIMEOUT`, `TC_APB_PSLVERR`, `TC_FSM_ILLEGAL_STATE` và các assertions `SVA-05` (Drain Timeout Watchdog), `SVA-06` (APB Invalid Access Response) vào `verification_test_plan.md`.
  - **Bổ sung Giả định Kỹ thuật:** Bổ sung `ASM-06` xác nhận kênh Sideband là kết nối điểm-điểm đồng bộ cùng miền xung nhịp `clk` trong `assumptions_and_tbd.md`.

---

### [Phiên Bản V2.2] - 2026-08-19
* **Đóng các mâu thuẫn chức năng còn lại và xác lập thứ tự ưu tiên tài liệu:**
  - `DMA-controller/docs/architecture/` là SSOT canonical; bản design spec ngày 2026-08-13 trong `docs/superpowers/specs/` được đánh dấu `Obsolete` và không còn là hợp đồng triển khai.
  - Chuẩn hóa interface baseline: `ID_WIDTH = 4`, địa chỉ hệ thống APB 32-bit, dữ liệu 32-bit và sideband V1 chỉ gồm `valid/src/dst/len/done`.
  - Chuẩn hóa kiểm tra AXI: chỉ nhận `INCR`, tính `last_byte` bằng `AxLEN + 1` và `1 << AxSIZE` với bit mở rộng, từ chối burst crossing/overflow 4KB; giới hạn một outstanding cho mỗi kênh và chặn W trước AW/ACL decision.
  - Chuẩn hóa dynamic context/ACL: Region 4 Read-Only, Region 5 Write-Only; thu hồi đồng bộ sau `dma_ctx_done`; `DEFAULT_DENY`, overlap theo AND-logic và mask theo `(id & ~mask) == (whitelist_id & ~mask)`.
  - Chuẩn hóa APB/error: invalid address trả `PREADY=1`, `PSLVERR=1`, `PRDATA=0`; reserved read 0/write ignored; `FW_LOCK` không khóa fault status/metadata; `FAULT_COUNT` saturate ở `16'hFFFF`.
  - PPA/timing thực tế vẫn là `TBD` cho đến synthesis/STA; HTML/PDF sinh từ V2.1 được giữ là generated artifacts lịch sử và cần regenerate sau khi baseline Markdown ổn định.

### [Căn chỉnh triển khai V2.2] - 2026-08-20
* **Chuẩn hóa executable interface với SSOT V2.2:**
  - Đặt mặc định `ID_WIDTH = 4` trong `dma_controller.v` và `dma_axi_master.v`; testbench dùng AXI ID 4-bit.
  - Expose sideband V1 tại top-level `dma_controller.v`: `dma_ctx_valid`, `dma_ctx_src`, `dma_ctx_dst`, `dma_ctx_len`, `dma_ctx_done`; loại bỏ `dma_ctx_state` khỏi model.
  - Giữ `paddr[31:0]`; `dma_apb_slave.v` dùng `APB_BASE_ADDR=0x10001000` và chỉ decode cửa sổ DMA 32 bytes, trả `PREADY=1`, `PSLVERR=1`, `PRDATA=0` ngoài cửa sổ.

---

### [Phiên Bản V2.1] - 2026-08-16
* **Đóng gói Toàn diện Bộ Tài liệu Kiến trúc Chuẩn (SSOT):**
  - Tạo lập cấu trúc chuẩn `docs/architecture/` với đầy đủ 11 tài liệu và script kiểm tra lint tự động.
  - Cố định quyết định kiến trúc `FIFO_DEPTH = 32 words` dựa trên benchmark lịch sử từng báo $+74.3\%$ và 0 full-stall. Số liệu này đã bị V2.4.1 thay thế bởi benchmark protocol-correct mới ($+43.9\%$, 0 full-stall).
  - Chuẩn hóa các bảng tín hiệu `pinout.csv`, `signal_list.csv`, `memory_map.csv`, `register_map.csv` và ma trận truy vết `requirements_traceability.csv`.
  - Đặc tả chi tiết 5 máy trạng thái FSM kèm bảng chuyển đổi và sơ đồ Mermaid trong `fsm_specification.md`.
  - Tích hợp kế hoạch kiểm chứng 13 nhóm kiểm thử và mã SVA trong `verification_test_plan.md`.

---

### [Phiên Bản V2.0] - 2026-08-15
* **Giải Quyết Triệt Để 6 Điểm Mâu Thuẫn & Chưa Rõ Kỹ Thuật:**
  - Áp dụng chính sách Zero-Trust Default Deny (`FW_CONTROL[0]=1`).
  - Thiết kế Dedicated Point-to-Point Sideband Channel với Zero-Delay Revocation.
  - Hiện thực hóa quy tắc Most-Restrictive AND-Logic khi có vùng nhớ chồng lấn (MITRE CWE-1260).
  - Tích hợp Decoupled Deadlock-Free Drain FSMs tiêu thụ $1\text{ beat/cycle}$ và Sticky First-Fault Logger với bộ đếm vi phạm `FAULT_COUNT [31:16]`.

---

### [Phiên Bản V1.0] - 2026-08-15
* Khởi tạo dự án DMA Controller và các yêu cầu ban đầu về an toàn thông tin phần cứng.
