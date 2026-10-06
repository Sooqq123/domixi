# KẾ HOẠCH KIỂM CHỨNG TOÀN DIỆN (VERIFICATION TEST PLAN)
## DMA-Aware Bus Firewall IP & DMA Controller Core
**Tài liệu:** Verification Specification & Testbench Guide  
**Phiên bản:** V2.4.1 DMA-Constrained Clarification & Closure Baseline  
**Ngày cập nhật:** 2026-08-23  
**Trạng thái:** Canonical Architecture Baseline V2.4.1 — RTL Integrated / Frontend Verified  
**Chuẩn Tuân Thủ:** IEEE Std 1800-2017 (SystemVerilog) & IEEE Std 1800.2-2020 (UVM)  

---

## 1. MỤC TIÊU & TIÊU CHÍ HOÀN THÀNH KIỂM CHỨNG (VERIFICATION EXIT CRITERIA)

Kế hoạch kiểm chứng này cung cấp chỉ dẫn để triển khai self-checking testbench. Implementation chỉ được sign-off khi:
1. Mọi testcase bắt buộc trong traceability matrix đều PASSED, không có failure bị waive ngầm.
2. Mọi SVA bắt buộc không bị vi phạm trong phạm vi assumptions đã công bố; assumptions/waivers phải được review.
3. Tất cả functional coverage bins bắt buộc (region overlap, Master ID/mask, burst length, 4KB boundary, response error, backpressure và status sequencing) được hit; illegal/ignore bins phải có rationale.
4. Code coverage đạt ngưỡng dự án đã phê duyệt (mặc định: statement/branch/FSM ≥95%) và mọi lỗ hổng còn lại được review; coverage không thay thế protocol/security proof.

---

## 1.1. BỘ KIỂM THỬ BẮT BUỘC THEO BASELINE V2.4.1

Các test dưới đây là điều kiện bắt buộc để chứng minh các quyết định đã đóng trong SSOT V2.4.1. Chúng là yêu cầu kiểm chứng; trạng thái `PASS` chỉ được ghi nhận khi `verification_evidence_manifest.csv` liên kết test với command, tool/version, source revision và artifact tái lập. Test cần Firewall RTL giữ trạng thái `BLOCKED_FIREWALL_RTL` cho đến khi source implementation được tích hợp.

| Test ID | Hợp đồng cần kiểm tra | Stimulus tối thiểu | Expected result |
| :--- | :--- | :--- | :--- |
| **`TC_AXI_4KB_LAST_BYTE`** | Công thức `last_byte` dùng `AxLEN + 1`, `1 << AxSIZE` và bit mở rộng. | Burst `INCR` sát biên 4KB và burst overflow địa chỉ 32-bit. | Burst crossing/overflow bị từ chối; burst hợp lệ không bị từ chối nhầm. |
| **`TC_W_BEFORE_AW`** | Không cho W handshake trước AW và ACL decision. | Giữ `WVALID` trước khi phát `AWVALID`; thay đổi backpressure. | `WREADY=0` cho đến khi AW được chấp nhận và quyết định hoàn tất; payload W ổn định. |
| **`TC_W_BEFORE_AW_DMA`** | DMA Master không được phát `WVALID` trước khi AW handshake thành công. | DMA Master bắt đầu ghi; kéo dài `m_axi_awready = 0`. | `m_axi_wvalid = 0` và FIFO không pop cho đến khi `AWVALID & AWREADY == 1`. |
| **`TC_RRESP_MID_BURST_ABORT`** | Xử lý lỗi `RRESP != OKAY` giữa burst mà không gây deadlock. | Slave trả `RRESP=SLVERR` ở beat 2/8 đồng thời tạo backpressure hữu hạn; tùy biến có AW đã handshake. | Chốt abort; retire đủ `ARLEN+1` beat với RLAST đúng cuối; không FIFO-push từ beat lỗi trở đi; không handshake AR/AW mới; hoàn tất AW đã nhận; flush residual FIFO; terminal `BUSY=0, ERROR=1, dma_ctx_valid=0`, pulse `dma_ctx_done`. Không phát done-set event. |
| **`TC_BRESP_MULTI_BURST_ABORT`**| Xử lý lỗi `BRESP != OKAY` trong multi-burst transfer. | Slave trả `BRESP=SLVERR` ở burst 1/4 trong khi có/không có AR outstanding. | Chốt abort; không phát địa chỉ mới; retire AR outstanding theo `ARLEN+1`/RLAST policy; flush FIFO; terminal error và pulse `dma_ctx_done`. Không phát done-set event. |
| **`TC_DMA_APB_REG_SEMANTICS`** | Ngữ nghĩa thanh ghi APB DMA: `START` WO/pulse, `STATUS` sticky W1C. | Ghi/đọc `DMA_CTRL.START` và `DMA_STATUS`; tạo hardware-set cùng chu kỳ W1C; giữ DONE cũ rồi tạo lỗi mới. | Đọc START=0; START khi BUSY bị bỏ qua; START không xóa status; hardware-set thắng W1C cùng chu kỳ; lỗi mới không phát done-set và không xóa sticky DONE cũ, nên DONE/ERROR có thể cùng 1 cho đến W1C. |
| **`TC_CFG_WRITE_WHILE_BUSY`** | Descriptor active bất biến trong lúc chạy. | Sau START, ghi giá trị mới vào DMA_SRC/DST/LEN khi BUSY=1. | Giao dịch active và sideband context giữ descriptor đã chốt; giá trị mới chỉ dùng cho START kế tiếp. |
| **`TC_DMA_APB_PROFILE`** | DMA slave dùng APB3 32-bit full-word profile. | Đọc/ghi các offset hợp lệ; thử misaligned và offset 0x14-0x1F. | Offset hợp lệ hoàn tất; misaligned/unmapped trả `PREADY=1, PSLVERR=1, PRDATA=0`; interface không phụ thuộc PPROT/PSTRB. |
| **`TC_DMA_TRUST_UPSTREAM`** | Secure-Privileged DMA MMIO provenance được enforce ngoài IP. | Integration test gửi Secure-Privileged, Non-Secure-Privileged và Secure-Unprivileged access qua APB bridge/firewall. | Chỉ Secure-Privileged access đến `dma_apb_slave`; access bị chặn không tạo side effect. Đây là SoC integration gate chứ không phải unit test cục bộ. |
| **`TC_FIRST_FAULT_RECAPTURE`** | First-fault metadata giữ giá trị và recapture đúng lúc. | Tạo fault A, fault B khi status còn pending, clear toàn bộ fault/IRQ, rồi tạo fault C. | B không ghi đè A; clear không xóa metadata A; C ghi đè metadata sau khi capture lock đã mở. |
| **`TC_START_WHILE_BUSY`** | Ghi đè `START` khi DMA đang bận không làm ngắt giao dịch. | Ghi `DMA_CTRL.START=1` khi `DMA_STATUS.BUSY=1`. | Lệnh ghi bị bỏ qua hoàn toàn, giao dịch đang chạy tiếp tục bình thường đến khi kết thúc. |
| **`TC_SINGLE_OUTSTANDING`** | Mỗi kênh chỉ có một giao dịch outstanding. | Cố phát giao dịch thứ hai khi giao dịch đầu chưa hoàn tất. | Giao dịch thứ hai bị giữ; không trộn ID/địa chỉ/response. |
| **`TC_CTX_REGION_45`** | Region 4 RO, Region 5 WO và thu hồi đồng bộ sau `dma_ctx_done`. | Nạp descriptor source/destination rồi phát `dma_ctx_done` ở cạnh clock. | Region 4/5 đúng quyền trong lúc chạy; bị vô hiệu hóa sau cạnh lấy mẫu và trước giao dịch mới. |
| **`TC_APB_INVALID`** | Hành vi địa chỉ APB không hợp lệ và reserved. | Đọc/ghi địa chỉ ngoài map và field reserved. | `PREADY=1`, `PSLVERR=1`, `PRDATA=0` cho địa chỉ không hợp lệ; reserved read 0/write ignored. |
| **`TC_AXI_PROFILE_CONSTRAINED`** | Verify bursts outside profile: unaligned, non-INCR, burst > 16 beats are rejected and drained. | Send unaligned, non-INCR, or burst > 16 beats. | Rejected and drained. |
| **`TC_LEN_ZERO_OVERFLOW`** | Invalid context range/alignment bị từ chối và ghi BOUND_ERR. | Send src/dst/len misaligned, len=0 hoặc 32-bit range overflow. | Reject activation; tạo đúng một context BOUND_ERR record cho mỗi descriptor được accept. |
| **`TC_FAIL_SECURE_RESET`** | Verify FW_EN=1 out of reset, all regions inactive, DEFAULT_DENY blocks unconfigured access. | Send access out of reset. | FW_EN=1, all regions inactive, DEFAULT_DENY blocks access. |
| **`TC_ACL_SNAPSHOT_STALL`** | ACL decision bất biến sau address acceptance. | Accept AW/AR rồi stall Stage 2/downstream; đồng thời đổi APB config hoặc revoke context. | Giao dịch đã nhận giữ nguyên decision/ID/LEN/mode; giao dịch mới thấy config sau priority. |
| **`TC_DRAIN_EXACT_BEATS_ID`** | Drain dùng latched LEN/ID và exact beat accounting. | Deny AW/AR với LEN 0 và 15; random BREADY/RREADY; early hoặc missing WLAST. | Write chỉ phát B sau `AWLEN+1` W handshakes; read phát `ARLEN+1` beat; BID/RID echo snapshot; payload ổn định khi stall; WLAST mismatch ghi PROT_ERR. |
| **`TC_FAULT_SIMULTANEOUS`** | Logger nhận đồng thời read/write/context faults. | Phát ba record cùng cạnh khi capture đang mở và khi đã khóa. | Status OR mọi code; count tăng 3 và saturate; metadata chọn context với `FAULT_SOURCE=2'b10` và đúng FIRST_FAULT_CODE rồi giữ đến recapture; hardware-set thắng W1C. |
| **`TC_FW_CONTROL_SEMANTICS`** | `FW_EN` và `AUTO_CTX_EN` không tạo bypass ngoài ý muốn. | Tắt FW_EN rồi gửi ACL deny và profile-invalid; tắt AUTO_CTX khi context active. | ACL-only deny được bypass khi FW_EN=0 nhưng profile-invalid vẫn drain/log; AUTO_CTX disable xóa Region 4/5 và chặn allocation mới. |
| **`TC_REGION_ACTIVATION_GUARD`** | Region descriptor chỉ đổi khi inactive và BASE<=LIMIT. | Ghi BASE/LIMIT/PERM/MID khi active; activate với BASE>LIMIT; ghi Region 4/5 RO. | Mỗi access trả PSLVERR và không đổi descriptor/ACTIVE. |
| **`TC_FULL_BURST_CONTAINMENT`** | Region match bao phủ toàn bộ `[start,last_byte]`. | Cấu hình burst bắt đầu trong region nhưng kết thúc ngoài LIMIT và trường hợp chỉ giao nhau một phần. | Không region match đầy đủ nên deny/default-deny; không địa chỉ/data nào ra matrix; ghi BOUND_ERR. |
| **`TC_CTX_PRIORITY_MATRIX`** | Priority `done > one-shot valid > APB write > ACL snapshot`. | Tạo từng tổ hợp đồng thời gồm done+valid+APB+AW và valid+APB+AR; giữ valid cao nhiều chu kỳ. | Revoke thắng mọi event; allocation hợp lệ thắng APB và visible cho same-edge snapshot; valid lặp không reload hoặc đếm fault lặp. |
| **`TC_DMA_RESP_ID_MISMATCH`** | Fixed-ID response ownership. | Sau request `AxID=0`, trả `RID/BID != 0` nếu response ID được expose. | Chốt protocol/terminal error; không nhận dữ liệu sai owner; retire giao dịch theo abort contract. |
| **`TC_DMA_RLAST_FRAMING`** | DMA phải đối chiếu RLAST với `ARLEN+1`. | Với AR đã accept, lần lượt phát RLAST sớm và bỏ RLAST tại expected final beat; kết hợp ARREADY stall để kiểm payload. | Beat mismatch không được push; chốt abort; read channel đóng hữu hạn tại early RLAST hoặc expected final beat; flush và terminal ERROR/no DONE; AR payload giữ ổn định khi stall. |

## 2. DANH MỤC TESTCASES KIỂM CHỨNG CHI TIẾT (TESTCASE SUITE)

### Nhóm 1: Reset, Khởi Tạo & Giao Thức Cơ Bản (Basic Functionality)
| Test ID | Tên Bài Kiểm Thử | Khối Chức Năng | Điều Kiện Đầu Vào & Stimulus | Kết Quả Mong Đợi (Expected Output) | Mức Ưu Tiên |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **`TC_RST_01`** | Asynchronous Reset Recovery | Toàn bộ IP | Kích hoạt `rst_n = 0` ngẫu nhiên giữa lúc đang truyền dữ liệu | Mọi FSM về IDLE sau deassert đồng bộ; AXI VALID/READY và IRQ về 0; `s_apb_pready=dma_apb_pready=1`; PRDATA/PSLVERR về 0; FW_EN/AUTO_CTX_EN/ERR_MODE về 1 | High |
| **`TC_NORM_01`** | Clean DMA Single Burst (64B)| `dma_controller.v` & `dma_bus_firewall.v` | Truyền 64 bytes (16 beats) giữa 2 vùng bộ nhớ hợp lệ trong Region 0 & 1 | Toàn bộ 64 bytes đích khớp nguồn, data path không thêm tầng register, `fault_count = 0` | High |
| **`TC_NORM_02`** | Large Multi-Burst Transfer (4KB)| `dma_controller.v` | Truyền 4096 bytes (64 bursts x 16 beats) liên tục | Dữ liệu toàn vẹn, không crossing 4KB, FIFO không overflow/underflow; throughput RTL chỉ so với budget sau khi clock/test assumptions được ghi rõ | High |

---

### Nhóm 2: Kiểm Chứng 4 Kịch Bản Tấn Công An Ninh Cốt Lõi (Security Attack Vectors)
| Test ID | Tên Kịch Bản Tấn Công | Vector Tấn Công Chi Tiết | Phản Ứng Của Firewall | Tiêu Chí Đánh Giá Pass |
| :--- | :--- | :--- | :--- | :---: |
| **`TC_CROSS_BOUND`** | Tấn công Tràn Ranh Giới 4KB (4KB Wrap-around) | AXI Master phát burst xuất phát tại `0x0000_0FE0` với $AWLEN=15$ ($End\_Addr = 0x0000_101F$, vượt biên 4KB) | Stage 1 phát hiện vi phạm, chặn không cho ra Interconnect, kích hoạt Write Drain FSM nuốt dữ liệu, chốt cờ `FAULT_STATUS[3]=1` và phát `sec_irq = 1` | **PASS khi địa chỉ không lọt ra Matrix và sec_irq bật** |
| **`TC_TAMPER_LOCK`** | Tấn công Ghi Đè MMIO Sau Khởi Động (MMIO Tampering) | Ghi bit 0 vào `FW_LOCK (0x004)`. Sau đó CPU độc hại cố ghi đè thanh ghi cấu hình vùng `RGN_BASE_0 (0x020)` | Thanh ghi giữ nguyên giá trị cũ, Firewall trả về lỗi `PSLVERR = 1` trên bus APB4 | **PASS khi giá trị không đổi và trả về PSLVERR** |
| **`TC_TOCTOU_FORGERY`**| Tấn công TOCTOU / Thu Hồi Quyền Muộn (NDSS 2019 Thunderclap) | Master độc hại cố truy cập vùng nhớ nguồn cũ sau khi DMA đã phát xung `dma_ctx_done` | Dynamic Context Tracker xóa Region 4 & 5 sau cạnh clock lấy mẫu. Truy cập mới ở chu kỳ kế tiếp bị chặn với lỗi `DEFAULT_DENY` và phản hồi `DECERR` | **PASS khi truy cập bị chặn ngay chu kỳ kế tiếp** |
| **`TC_DEADLOCK_STRESS`**| Tấn công Bơm DoS Làm Nghẽn Interconnect (Deadlock Stress) | Bơm 1,000 burst ghi vi phạm dài 1-16 beats; random backpressure với `MAX_READY_LATENCY=16` và luôn gửi WLAST đúng hợp đồng | Write Drain FSM chỉ tiến triển trên handshake, giữ ổn định khi stall, hoàn tất từng burst mà không phát B sớm | **PASS khi 1,000 bursts xả sạch, FSM về IDLE và latency nằm trong bound suy ra từ fairness assumption** |

---

### Nhóm 3: Kiểm Chứng Phân Quyền Nâng Cao & Chế Độ Đánh Lừa (Advanced Security)
| Test ID | Tên Bài Kiểm Thử | Kịch Bản Stimulus | Kết Quả Mong Đợi |
| :--- | :--- | :--- | :--- |
| **`TC_CWE_1260`** | Most-Restrictive Overlap Resolution | Cấu hình Region 0 (0x1000-0x3000, Read-Only) chồng lấn Region 1 (0x2000-0x4000, Read/Write). Gửi lệnh ghi vào địa chỉ 0x2500 | Giao dịch ghi bị từ chối vì Region 0 cấm ghi (Quy tắc Most-Restrictive AND-Logic) |
| **`TC_HONEYPOT_01`** | Deceptive Defense Mode Verification | Đặt `FW_CONTROL[3] = 0` (Honeypot Mode). Gửi lệnh ghi độc hại | Dữ liệu ghi bị Drain FSM nuốt và tiêu hủy, nhưng trả về phản hồi ngụy trang `BRESP = OKAY (2'b00)` |
| **`TC_MID_MASK_01`** | Whitelist Master ID & Mask Resolution | Cấu hình Whitelist `MID = 4'h4`, `Mask = 4'h1` (cho phép Master ID 4 và 5). Thử nghiệm truy cập từ Master 4, 5, 6 | Master 4 và 5 truy cập thành công; Master 6 bị deny và ghi READ_ERR hoặc WRITE_ERR theo loại giao dịch |

---

### Nhóm 4: Kiểm Chứng Backpressure, FIFO & Hiệu Năng (Performance & Stress)
| Test ID | Tên Bài Kiểm Thử | Kịch Bản Stimulus | Kết Quả Mong Đợi |
| :--- | :--- | :--- | :--- |
| **`TC_PERF_FIFO32`** | FIFO32 Model Benchmark Reproduction | Chạy workload mô hình 1024 bytes với `FIFO_DEPTH=32`, memory latency=1 và clock quy đổi 800 MHz | Tái lập khoảng 1.410 GB/s, 44.1% utilization và `fifo_full_stall_cycles=0`; metadata/hash khớp source hiện tại; không dùng làm RTL timing/PPA sign-off |
| **`TC_FIFO_RTL_UNIT`** | FIFO depth/count/full/empty | Chạy `tb/tb_dma_fifo_latch.v` với DEPTH=32; push/pop đến empty/full và simultaneous access | Compile/elaborate sạch; count trong 0-32; không overflow/underflow; dữ liệu theo thứ tự; test self-checking PASS |
| **`TC_BACKPRESSURE`** | Random Wait-States Insertion | Bộ nhớ đích chèn ngẫu nhiên 1 đến 5 chu kỳ `m_axi_wready = 0` | DMA FIFO đệm dữ liệu an toàn, không xảy ra Underflow/Overflow, dữ liệu đích toàn vẹn |

---

### Nhóm 5: Kiểm Chứng An Toàn Phần Cứng (Safety & Robustness)
| Test ID | Tên Bài Kiểm Thử | Kịch Bản Stimulus | Kết Quả Mong Đợi |
| :--- | :--- | :--- | :--- |
| **`TC_UNALIGNED_ADDR`** | Unaligned Address Rejection | Send `AWADDR[1:0] != 2'b00` | Firewall rejects, triggers Write Drain, asserts `BOUND_ERR`. |
| **`TC_NON_INCR_BURST`** | Non-INCR Burst Rejection | Send `AxBURST = WRAP (2'b10)` or `FIXED (2'b00)` | Rejected, assertions pass. |
| **`TC_BURST_GT_16`** | Burst > 16 Beats Rejection | Send `AxLEN > 15` | Rejected with `BOUND_ERR`. |
| **`TC_CTX_RANGE_INVALID`** | Chi tiết Zero Length / Overflow Rejection của `TC_LEN_ZERO_OVERFLOW` | Sideband lần lượt gửi len=0 và overflow tại source hoặc destination | Tracker giữ inactive; mỗi accepted descriptor tạo đúng một context BOUND_ERR record và không đếm lặp khi valid giữ cao. |
| **`TC_SAME_CYCLE_REVOKE`** | Same-cycle Context Revocation | `dma_ctx_done` pulses at same cycle as new `AWVALID` | Transaction evaluated after revocation (denied). |
| **`TC_APB_RO_REGIONS`** | APB RO Regions Write Attempt | CPU attempts write to Region 4/5 registers | Returns `PSLVERR=1`, write ignored. |
| **`TC_IRQ_STICKY_W1C`** | IRQ Sticky & W1C | Fault sets `IRQ_PENDING=1`; clearing `FAULT_STATUS[3:0]` | leaves `sec_irq` asserted until `IRQ_PENDING` is cleared. |
| **`TC_APB_PSLVERR`** | APB Violation Response | Gửi giao dịch đến địa chỉ > 0x09F; gửi giao dịch misaligned (PADDR[1:0]!=0); gửi Non-Secure (PPROT[1]=1); gửi Unprivileged (PPROT[0]=0); ghi cấu hình khi STICKY_LOCK=1. | Tất cả trường hợp trả PSLVERR=1 và PRDATA=0. Ghi bị bỏ qua. |
| **`TC_FSM_ILLEGAL_STATE`** | FSM Illegal State Recovery | Force/deposit FSM vào trạng thái không hợp lệ (ví dụ: 2'b11 cho FSM 2-bit). | FSM quay về IDLE trong đúng 1 clock cycle, hạ toàn bộ output về 0. |

---

## 3. ĐẶC TẢ SYSTEMVERILOG ASSERTIONS (SVA PROTOCOL CHECKS)

Các ràng buộc phần cứng (Assertions) bắt buộc phải được gắn trực tiếp vào RTL và Testbench:

```systemverilog
// 1. SVA-01: AW Channel Protocol Stability
property p_axi_aw_stable;
    @(posedge clk) disable iff (!rst_n)
    (m_axi_awvalid && !m_axi_awready) |=> 
    ($stable(m_axi_awvalid) && $stable(m_axi_awaddr) && $stable(m_axi_awid) && 
     $stable(m_axi_awlen) && $stable(m_axi_awsize) && $stable(m_axi_awburst) && $stable(m_axi_awprot));
endproperty
assert_aw_stable: assert property (p_axi_aw_stable);

// 2. SVA-02: AR Channel Protocol Stability
property p_axi_ar_stable;
    @(posedge clk) disable iff (!rst_n)
    (m_axi_arvalid && !m_axi_arready) |=> 
    ($stable(m_axi_arvalid) && $stable(m_axi_araddr) && $stable(m_axi_arid) && 
     $stable(m_axi_arlen) && $stable(m_axi_arsize) && $stable(m_axi_arburst) && $stable(m_axi_arprot));
endproperty
assert_ar_stable: assert property (p_axi_ar_stable);

// 3. SVA-03: R & B Channel Backpressure Stability (Firewall Drain Responses to Master & Interconnect Responses)
property p_axi_s_r_stable;
    @(posedge clk) disable iff (!rst_n)
    (s_axi_rvalid && !s_axi_rready) |=> 
    ($stable(s_axi_rvalid) && $stable(s_axi_rdata) && $stable(s_axi_rresp) && $stable(s_axi_rlast) && $stable(s_axi_rid));
endproperty
assert_s_r_stable: assert property (p_axi_s_r_stable);

property p_axi_s_b_stable;
    @(posedge clk) disable iff (!rst_n)
    (s_axi_bvalid && !s_axi_bready) |=> 
    ($stable(s_axi_bvalid) && $stable(s_axi_bresp) && $stable(s_axi_bid));
endproperty
assert_s_b_stable: assert property (p_axi_s_b_stable);

property p_axi_m_r_stable;
    @(posedge clk) disable iff (!rst_n)
    (m_axi_rvalid && !m_axi_rready) |=> 
    ($stable(m_axi_rvalid) && $stable(m_axi_rdata) && $stable(m_axi_rresp) && $stable(m_axi_rlast) && $stable(m_axi_rid));
endproperty
assert_m_r_stable: assert property (p_axi_m_r_stable);

property p_axi_m_b_stable;
    @(posedge clk) disable iff (!rst_n)
    (m_axi_bvalid && !m_axi_bready) |=> 
    ($stable(m_axi_bvalid) && $stable(m_axi_bresp) && $stable(m_axi_bid));
endproperty
assert_m_b_stable: assert property (p_axi_m_b_stable);

// 4. SVA-04: Synchronous Revocation
property p_sync_revocation;
    @(posedge clk) disable iff (!rst_n)
    dma_ctx_done |=> (!dyn_rgn4_active && !dyn_rgn5_active);
endproperty
assert_sync_revocation: assert property (p_sync_revocation);

// 5. SVA-05: Sticky Lock Immutability
property p_sticky_lock_immutable;
    @(posedge clk) disable iff (!rst_n)
    fw_lock_reg[0] |=> fw_lock_reg[0];
endproperty
assert_sticky_lock_immutable: assert property (p_sticky_lock_immutable);

// 6. SVA-06: Write drain completes from the latched AWLEN count, never early.
property p_write_drain_exact_completion;
    @(posedge clk) disable iff (!rst_n)
    (w_drain_state == W_DRAIN_SINK && w_drain_wvalid && w_drain_wready &&
     (w_beat_count == w_drain_len)) |=>
        (w_drain_state == W_DRAIN_RESP && w_drain_bvalid);
endproperty
assert_write_drain_exact_completion: assert property (p_write_drain_exact_completion);

property p_write_drain_no_early_b;
    @(posedge clk) disable iff (!rst_n)
    (w_drain_state == W_DRAIN_SINK && (w_beat_count < w_drain_len)) |-> !w_drain_bvalid;
endproperty
assert_write_drain_no_early_b: assert property (p_write_drain_no_early_b);

property p_apb_error_response;
    @(posedge clk) disable iff (!rst_n)
    (s_apb_psel && s_apb_penable && (!addr_in_range || misaligned || non_secure || unprivileged || locked_write || dyn_rgn_write)) 
    |-> (s_apb_pslverr && (s_apb_prdata == 32'h0));
endproperty
assert_apb_error_response: assert property (p_apb_error_response);

// 7. SVA-07: DMA Master No WVALID Before AW Acceptance.
// aw_accepted is set only by an AW handshake and cleared on B handshake/reset.
property p_dma_no_w_before_aw;
    @(posedge clk) disable iff (!rst_n)
    m_axi_wvalid |-> aw_accepted;
endproperty
assert_dma_no_w_before_aw: assert property (p_dma_no_w_before_aw);

// 8. SVA-08: Terminal event mutual exclusion.
// Sticky DONE from an older transfer is intentionally not required to clear.
property p_dma_terminal_event_mutex;
    @(posedge clk) disable iff (!rst_n)
    !(done_set_event && error_set_event);
endproperty
assert_dma_terminal_event_mutex: assert property (p_dma_terminal_event_mutex);

// 9. SVA-09: DMA Context Done Pulse Width Invariant
property p_dma_ctx_done_pulse;
    @(posedge clk) disable iff (!rst_n)
    dma_ctx_done |=> !dma_ctx_done;
endproperty
assert_dma_ctx_done_pulse: assert property (p_dma_ctx_done_pulse);

// 10. SVA-10: Bounded abort completion under the testbench fairness contract.
// The environment constrains each term. These are verification parameters only.
// READ_DRAIN_BOUND  = 16 * (MAX_RVALID_GAP + 1)
// WRITE_DRAIN_BOUND = 16 * (MAX_WREADY_LATENCY + 1)
//                   + (MAX_BVALID_LATENCY + 1)
//                   + (MAX_BREADY_LATENCY + 1)
// ABORT_BOUND       = READ_DRAIN_BOUND + WRITE_DRAIN_BOUND
//                   + FIFO_FLUSH_BOUND + 4; FIFO_FLUSH_BOUND = 1.
property p_dma_abort_eventually_terminal;
    @(posedge clk) disable iff (!rst_n)
    $rose(abort_pending) |-> ##[1:ABORT_BOUND]
        (!status_busy && !dma_ctx_valid && dma_ctx_done && error_set_event);
endproperty
assert_dma_abort_eventually_terminal: assert property (p_dma_abort_eventually_terminal);

// 11. SVA-11: Denied response preserves the accepted transaction ID.
property p_write_drain_id_stable;
    @(posedge clk) disable iff (!rst_n)
    w_drain_bvalid |-> (w_drain_bid == w_fault_id_snapshot);
endproperty
assert_write_drain_id_stable: assert property (p_write_drain_id_stable);

property p_read_drain_id_stable;
    @(posedge clk) disable iff (!rst_n)
    r_drain_rvalid |-> (r_drain_rid == r_fault_id_snapshot);
endproperty
assert_read_drain_id_stable: assert property (p_read_drain_id_stable);

// 12. SVA-12: No denied address reaches the matrix.
property p_denied_address_isolated;
    @(posedge clk) disable iff (!rst_n)
    (acl_w_fault || acl_r_fault) |-> !(m_axi_awvalid || m_axi_arvalid);
endproperty
assert_denied_address_isolated: assert property (p_denied_address_isolated);

// 13. SVA-13: fixed DMA trust attributes.
property p_dma_fixed_aw_trust_profile;
    @(posedge clk) disable iff (!rst_n)
    dma_awvalid |-> (dma_awid == 4'h0 && dma_awprot == 3'b001);
endproperty
assert_dma_fixed_aw_trust_profile: assert property (p_dma_fixed_aw_trust_profile);

property p_dma_fixed_ar_trust_profile;
    @(posedge clk) disable iff (!rst_n)
    dma_arvalid |-> (dma_arid == 4'h0 && dma_arprot == 3'b001);
endproperty
assert_dma_fixed_ar_trust_profile: assert property (p_dma_fixed_ar_trust_profile);

// 14. SVA-14: accepted read burst uses exact ARLEN+1 framing.
property p_dma_r_last_position;
    @(posedge clk) disable iff (!rst_n)
    (m_axi_rvalid && m_axi_rready) |->
        (m_axi_rlast == (read_beat_count + 1'b1 == read_expected_beats));
endproperty
assert_dma_r_last_position: assert property (p_dma_r_last_position);
```

---

## 4. TIÊU CHÍ BỔ SUNG V2.4.1 (EXIT CRITERIA ADDENDUM)

Tất cả SVA-01 đến SVA-14 phải PASS trong regression suite với assumptions được công bố. `ABORT_BOUND` phải được tính và ghi trong test configuration từ bốn fairness bounds ở trên; không được dùng bounded-liveness assertion khi environment cho phép backpressure vô hạn. Các tên helper signal trong snippet là normative intent; bind file phải map chúng vào tên hierarchy thực tế và được lưu như evidence.
