# CÁC GIẢ ĐỊNH KỸ THUẬT, TIÊU CHUẨN THAM CHIẾU & TRẠNG THÁI XÁC NHẬN
## DMA-Aware Bus Firewall IP & DMA Controller Core
**Tài liệu:** Architecture Specification - Single Source of Truth (SSOT)  
**Phiên bản:** V2.4.1 DMA-Constrained Clarification & Closure Baseline  
**Ngày cập nhật:** 2026-09-17  
**Trạng thái:** Canonical Architecture Baseline V2.4.1 — RTL/frontend verified; physical sign-off pending

---

## 1. TÀI LIỆU GIAO THỨC VÀ HƯỚNG DẪN THAM CHIẾU

AXI/APB và SystemVerilog là tài liệu chuẩn giao thức/ngôn ngữ. NIST, CWE và bài báo Thunderclap là nguồn hướng dẫn/rationale an ninh, không phải bằng chứng tự động về compliance của RTL:
1. **AMBA® AXI™ and ACE™ Protocol Specification:** ARM IHI 0022H (Issue H, 2021).
2. **AMBA® APB™ Protocol Specification:** ARM IHI 0024E (v2.0, 2021).
3. **NIST SP 800-193:** Platform Firmware Resiliency Guidelines (Hardware Sticky Lock RW1S Mechanism).
4. **MITRE Common Weakness Enumeration (Hardware CWEs):**
   * *CWE-1260:* Improper Handling of Overlapping Memory Regions.
   * [*CWE-1231: Improper Prevention of Lock Bit Modification*](https://cwe.mitre.org/data/definitions/1231.html).
   * [*CWE-1233: Security-Sensitive Hardware Controls with Missing Lock Bit Protection*](https://cwe.mitre.org/data/definitions/1233.html).
   * [*CWE-1264: Hardware Logic with Insecure De-Synchronization between Control and Data Channels*](https://cwe.mitre.org/data/definitions/1264.html).
5. **NDSS 2019 Thunderclap Research:** Pipelined Direct Memory Access Vulnerabilities & Zero-Delay Window Revocation.
6. **IEEE Std 1800-2017 & IEEE Std 1800.2-2020:** SystemVerilog Language & Universal Verification Methodology (UVM).

---

## 2. GIẢ ĐỊNH, QUYẾT ĐỊNH VÀ TRẠNG THÁI BẰNG CHỨNG

| Mã Giả Định | Mô Tả Giả Định Kỹ Thuật | Bằng Chứng Xác Minh Thực Nghiệm / Nguồn Gốc |
| :--- | :--- | :--- |
| **`ASM-01`** | DMA Core và Firewall IP dùng chung một miền `clk`; baseline AEGIS-RISC yêu cầu 40 MHz (chu kỳ 25 ns) trên Sky130A. | Không có CDC nội bộ theo baseline. Tần số và mọi crossing ngoài boundary IP phải được xác nhận bằng integration/MCMM STA; hiện chưa có PDK/STA sign-off. |
| **`ASM-02`** | Độ sâu FIFO baseline là 32 từ 32-bit (`FIFO_DEPTH = 32`). | Benchmark V2.4.1 gồm 37 record: tại 1 KiB/latency1/800 MHz đạt $1.410\text{ GB/s}$ và $44.1\%$ utilization với 0 full-stall; FIFO16 đạt $0.980\text{ GB/s}$ với 255 full-stall; FIFO64 không cải thiện so với 32. |
| **`ASM-03`** | Đích đến của phản hồi lỗi là chính Master phát lệnh (`AxID` được giữ nguyên khi trả về `BID`/`RID`). | Tuân thủ quy tắc định tuyến giao dịch AXI4 (ARM IHI 0022H Section A5.3). |
| **`ASM-04`** | Kênh Sideband là đường nối đồng bộ point-to-point giữa DMA Core và Firewall. | Descriptor được lấy mẫu/chốt theo cạnh `clk`; không tuyên bố bảo đảm vật lý chống probe/glitch nếu chưa có threat model và physical sign-off. |
| **`ASM-05`** | Giao diện APB4 cấu hình Firewall chỉ chấp nhận truy cập Secure Privileged (`PPROT[1]=0 & PPROT[0]=1`). | Đảm bảo phần mềm người dùng (Non-Secure / Unprivileged) không thể can thiệp vào thanh ghi phân quyền. |
| **`ASM-06`** | Kênh Sideband là kết nối điểm-điểm đồng bộ 5 tín hiệu (`valid`, `src_addr`, `dst_addr`, `byte_len`, `done`). | Xác minh qua kiến trúc miền xung nhịp đơn (ASM-01) và giao thức Sideband V2.4.1. |
| **`ASM-07`** | Phân tầng an ninh APB DMA: `dma_apb_slave` không có cổng `pprot` cục bộ; toàn bộ cửa sổ DMA chỉ được ánh xạ vào aperture Secure-Privileged do Upstream Interconnect/APB Bridge Firewall thực thi. | Bằng chứng IP-level chỉ kiểm địa chỉ/chức năng; sign-off trust provenance cần SoC integration test chứng minh request Non-Secure hoặc Unprivileged không đến được slave. |
| **`ASM-08`** | Giả định Liveness: peer cuối cùng phải cung cấp các VALID/READY cần thiết để mọi burst đã chấp nhận tiến triển đến đủ số beat theo `AxLEN`, `RLAST` và `BVALID`. | Với profile tối đa 16 beats, drain cần không quá 16 data handshakes mỗi burst; số chu kỳ wall-clock không bị chặn nếu peer giữ backpressure hoặc không gửi đủ beat vô hạn. Bounded proof/test phải khai báo riêng các fairness bounds ở §2.2. |
| **`ASM-09`** | DMA là dedicated Secure-Privileged data master với `AxID=4'h0` và `AxPROT=3'b001`. | Kiểm bằng RTL assertion tại IP boundary và SoC integration test; không suy ra provenance chỉ từ giá trị tie-off. |
| **`ASM-10`** | `test_mode` là tín hiệu tĩnh của SoC test controller; chỉ dùng để bypass reset synchronizer trong scan/test mode, không phải runtime control của data path. | `tb_aegis_soc_reset` kiểm tra bypass đồng bộ ở cả SoC top và Firewall; scan clock/chain và DFT stitching vẫn thuộc SoC/backend. |

---

## 2.1. CÁC QUYẾT ĐỊNH CHUẨN HÓA V2.4.1 ĐÃ ĐÓNG (CLOSED BASELINE)

Các điểm từng còn mâu thuẫn giữa tài liệu, model và RTL được chốt cho V2.4.1 như sau:

| Chủ đề | Quyết định chuẩn V2.4.1 |
| :--- | :--- |
| Giao diện | `ID_WIDTH = 4`, `ADDR_WIDTH = 32`, `DATA_WIDTH = 32`; DMA dùng `AxID=0`, `AxPROT=001`; APB dùng địa chỉ hệ thống 32-bit, offset thanh ghi nằm trong cửa sổ 256 byte. |
| AXI profile | DMA-Constrained Profile (`INCR`, `AxSIZE=2`, `AxADDR[1:0]=0`, `AxLEN<=15`, single outstanding). |
| AXI ordering | DMA Master không được phát `WVALID` / không được `W` handshake trước khi `AW` được chấp nhận (`AWVALID & AWREADY = 1`); giữ nguyên payload AW dưới backpressure. |
| DMA MMIO | `DMA_CTRL.START` là `WO` command pulse (ghi 1 khi `BUSY=0` kích hoạt; ghi khi `BUSY=1` bị bỏ qua; đọc trả 0; không tự xóa DONE/ERROR). `DMA_STATUS`: `BUSY` (RO), `DONE` và `ERROR` là sticky W1C độc lập; hardware-set thắng W1C cùng chu kỳ. Descriptor active được chốt tại START, nên ghi SRC/DST/LEN khi busy chỉ ảnh hưởng lần chạy kế tiếp. |
| Error Abort | `RRESP/BRESP != OKAY`, response ID mismatch hoặc RLAST framing mismatch chốt `abort_pending`, chặn AR/AW mới, retire AR đã nhận theo `ARLEN+1`/framing policy, hoàn tất AW đã nhận, rồi flush FIFO và kết thúc với terminal error event. Lỗi hiện tại không phát done event nhưng không tự xóa sticky DONE cũ. Context chỉ revoke ở terminal để các burst đã cam kết còn quyền hoàn tất. |
| Reset | `FW_EN=1` (Fail-Secure Default-Deny), all AXI output READYs = 0, APB `s_apb_pready = 1`, all 8 regions `ACTIVE = 0`. |
| Dynamic Context | Region 4/5 APB `RO` (Hardware-owned), `ACTIVE=0` reset; activation dùng `SECURE_ONLY=1`, `PRIV_ONLY=1`, `MID=0`, `MASK=0`; src/dst/len misaligned, `len=0` hoặc overflow bị từ chối với context `BOUND_ERR`; `AUTO_CTX_EN:1->0` xóa hai region. |
| ACL | `FW_EN=1` dùng `DEFAULT_DENY`; `FW_EN=0` chỉ bypass ACL permission, không bypass profile/4 KiB/framing/logging; full-burst containment bắt buộc; vùng chồng lấn phải đồng thời cho phép; mask dùng `(id & ~mask) == (whitelist_id & ~mask)`. |
| APB/error | Địa chỉ không hợp lệ trả `PREADY=1`, `PSLVERR=1`, `PRDATA=0`; reserved read trả 0 và write bị bỏ qua; `FW_LOCK` không khóa fault status/metadata; `FAULT_COUNT` bão hòa ở `16'hFFFF`. Clear toàn bộ fault bits/IRQ chỉ mở khóa first-fault capture; metadata giữ đến lỗi kế tiếp hoặc reset. |
| Drain | Write nhận chính xác `AWLEN+1` beat và kiểm WLAST tại beat cuối; Read sinh chính xác `ARLEN+1` dummy beat; ID/ERR_MODE được chốt; không có timeout tự bịa completion. |
| IRQ | `IRQ_PENDING` sticky W1C independent flag; `sec_irq = IRQ_EN && IRQ_PENDING`. `dma_irq = IRQ_EN && (DONE \|\| ERROR)`. |
| Priority | `dma_ctx_done > one-shot dma_ctx_valid acceptance > APB write > ACL snapshot`. Snapshot dùng cấu hình hiệu lực sau priority; same-cycle revoke thắng giao dịch mới. |
| APB violation | Khi vi phạm ASM-05 (Non-Secure `PPROT[1]=1` hoặc Unprivileged `PPROT[0]=0`): trả `PSLVERR = 1`, `PRDATA = 0`, ghi bị bỏ qua hoàn toàn. Khi `STICKY_LOCK = 1`: mọi ghi cấu hình trả `PSLVERR = 1` (trừ W1C trên `FAULT_STATUS`). |

## 2.2. FAIRNESS BOUNDS DÙNG CHO BOUNDED VERIFICATION

Các tham số sau thuộc test/formal environment, không phải timeout RTL:

```text
MAX_RVALID_GAP       = số chu kỳ tối đa giữa hai R handshakes có thể tiến triển
MAX_WREADY_LATENCY   = số chu kỳ tối đa trước mỗi W handshake
MAX_BVALID_LATENCY   = số chu kỳ tối đa từ W cuối đến BVALID
MAX_BREADY_LATENCY   = số chu kỳ tối đa trước B handshake
MAX_BURST_BEATS      = 16
FIFO_FLUSH_BOUND     = 1 chu kỳ (synchronous pointer/count clear)

READ_DRAIN_BOUND  = MAX_BURST_BEATS * (MAX_RVALID_GAP + 1)
WRITE_DRAIN_BOUND = MAX_BURST_BEATS * (MAX_WREADY_LATENCY + 1)
                  + (MAX_BVALID_LATENCY + 1)
                  + (MAX_BREADY_LATENCY + 1)
ABORT_BOUND       = READ_DRAIN_BOUND + WRITE_DRAIN_BOUND
                  + FIFO_FLUSH_BOUND + 4
```

Nếu environment không ràng buộc một trong các fairness parameter thì chỉ được chứng minh liveness theo handshake, không được tuyên bố bounded wall-clock completion.

---

## 3. TRẠNG THÁI CÁC MỤC CHỜ XÁC NHẬN (TBD / TBC STATUS)

Các quyết định chức năng của baseline V2.4.1 đã được xác nhận và Firewall RTL đã tích hợp. PPA thực tế cùng timing closure vẫn là `TBD` cho đến khi synthesis, STA và physical implementation chạy trên target technology; không suy đoán các giá trị này từ benchmark mô hình hoặc generic synthesis.

| Mã Hạng Mục | Nội Dung Mở Rộng Kiến Trúc | Trạng Thái | Đánh Giá Tác Động & Hướng Xử Lý |
| :--- | :--- | :---: | :--- |
| **`OPT-01`** | Mở rộng độ rộng bus dữ liệu lên 64-bit (`DATA_WIDTH = 64`). | **TBD / Out of baseline** | Baseline chỉ chốt 32-bit; cần đặc tả lại strobe, alignment, FIFO width và regression trước khi tuyên bố parameterized support. |
| **`OPT-02`** | Mở rộng số lượng Regions từ 8 lên 16 (`NUM_REGIONS = 16`). | **TBD / Out of baseline** | Baseline chốt 8 regions; cần mở rộng register map, address window, matcher và coverage trước khi hỗ trợ. |
| **`PPA-01`** | Diện tích, công suất, timing và mức sử dụng tài nguyên trên công nghệ đích. | **TBD / BLOCKED** | Workspace hiện chỉ có generic synthesis với `tools/synth/cmos_cells.lib`; chưa có PDK Sky130A, LEF/DEF, SPEF, corner Liberty, rule deck DRC/LVS hay bằng chứng vật lý tại `output/evidence/physical_run_final`. Không được tuyên bố ASIC sign-off cho đến khi chạy và lưu đủ các bước physical/MCMM/PV. |
