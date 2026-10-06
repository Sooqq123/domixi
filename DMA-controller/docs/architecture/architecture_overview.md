# ĐẶC TẢ TỔNG QUAN KIẾN TRÚC (ARCHITECTURE OVERVIEW)
## DMA-Aware Bus Firewall IP & DMA Controller Core
**Tài liệu:** Architecture Specification - Single Source of Truth (SSOT)
**Phiên bản:** V2.4.1 DMA-Constrained Clarification & Closure Baseline
**Ngày cập nhật:** 2026-08-23
**Trạng thái:** Canonical Architecture Baseline V2.4.1 — RTL Integrated / Frontend Verified

---

## 1. MỤC TIÊU VÀ PHẠM VI THIẾT KẾ

### 1.1. Bối Cảnh & Mục Tiêu Thiết Kế
Trong các hệ thống SoC (System-on-Chip) hiện đại, bộ điều khiển DMA (Direct Memory Access) là thành phần thiết yếu giúp giải phóng CPU khỏi gánh nặng truyền dữ liệu khối lượng lớn giữa bộ nhớ và ngoại vi. Tuy nhiên, quyền truy cập trực tiếp bus hệ thống của DMA khiến nó trở thành mục tiêu tấn công hàng đầu của tin tặc thông qua các kỹ thuật như:
* **Tấn công Time-of-Check to Time-of-Use (TOCTOU / NDSS 2019 Thunderclap):** Đánh tráo con trỏ bộ đệm hoặc descriptor sau khi quyền hạn đã được CPU xác thực.
* **Tấn công Tràn Ranh Giới 4KB (4KB Page Boundary Violation):** Khai thác hành vi không xác định của bus AXI4 khi truyền burst vượt trang bộ nhớ ảo.
* **Tấn công Từ Chối Dịch Vụ Trên Bus Interconnect (Interconnect Denial-of-Service / DoS):** Gửi các giao dịch vi phạm khiến bus matrix rơi vào trạng thái nghẽn chờ (Deadlock / Starvation).
* **Tấn công Ghi Đè Thanh Ghi Cấu Hình (MMIO Tampering):** Xâm nhập thanh ghi phân quyền truy cập sau giai đoạn khởi động an toàn (Secure Boot).

**DMA-Aware Bus Firewall IP** được thiết kế như một khối bảo vệ phần cứng trực tiếp trên bus dữ liệu (**Inline Hardware Bus Guard**), chèn giữa Master DMA và Interconnect Matrix của SoC. Mục tiêu kiến trúc là chặn mọi giao dịch không thỏa hợp đồng ACL/protocol đã đặc tả và không thêm tầng thanh ghi trên đường dữ liệu của giao dịch hợp lệ. Mức bao phủ lỗi thực tế, độ trễ tổ hợp và tần số đạt được chỉ được công nhận sau verification, synthesis và STA.

---

### 1.2. Phân Định Ranh Giới & Trách Nhiệm Thiết Kế

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 PHẠM VI THIẾT KẾ (DESIGN SCOPE)                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ TRONG PHẠM VI IP (IN-SCOPE):                                                                     │
│  1. DMA Controller Core (AXI4 Read Master, AXI4 Write Master, Synchronous FIFO 32 words, APB).   │
│  2. DMA-Aware Bus Firewall IP (2-Stage Decoupled Address Pipeline, 8-Region Parallel ACL Matcher,│
│     Dedicated DMA Sideband Tracker, Protocol Drain FSMs, APB4 MMIO & Sticky Lock).               │
│  3. Giao diện Dedicated Point-to-Point Sideband Channel (dma_ctx_*).                             │
│                                                                                                  │
│ NGOÀI PHẠM VI IP (OUT-OF-SCOPE - DO HỆ THỐNG SOC CUNG CẤP):                                      │
│  1. AXI4 Multi-Layer Interconnect Crossbar Matrix.                                               │
│  2. System Memory Controllers (DDR4/5 Controller, On-Chip SRAM Controller).                      │
│  3. Secure CPU Core & Root of Trust (RoT) Hardware.                                              │
│  4. Module quản lý nguồn và quản lý xung nhịp (PMU / Clock Gating Unit).                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CÁC QUYẾT ĐỊNH KIẾN TRÚC CỐT LÕI (ARCHITECTURAL DECISIONS)

Dựa trên kết quả mô phỏng tham chiếu ở giai đoạn **Mô hình hóa Mức Hệ thống (System-Level Modeling)**, các quyết định kiến trúc chuẩn mực đã được phê duyệt. Số liệu mô hình không phải kết quả RTL/PPA sign-off.

### 2.1. Cấu Hình Bộ Đệm FIFO (FIFO_DEPTH = 32 Words)
* **Quyết định:** Cố định độ sâu bộ đệm `FIFO_DEPTH = 32 words` (128 bytes) cho `dma_fifo_latch.v`.
* **Cơ sở thực nghiệm:**
  * Ở `FIFO_DEPTH = 16`, workload hiện hành ghi nhận 255 chu kỳ `fifo_full_stall`/1 KiB, thông lượng $0.980\text{ GB/s}$ và bus utilization $30.6\%$.
  * Khi tăng lên `FIFO_DEPTH = 32`, mô hình cho phép Read Engine nạp trước burst $N+1$ trong khi Write Engine đang xả burst $N$.
  * Trong workload tham chiếu 1 KiB, memory latency 1 cycle và clock quy đổi 800 MHz, model V2.4.1 sau khi enforce AW-before-W tăng từ $0.980\text{ GB/s}$ lên $1.410\text{ GB/s}$ (khoảng $43.9\%$), bus utilization từ $30.6\%$ lên $44.1\%$, và `fifo_full_stall_cycles` giảm từ 255 xuống 0.
  * Ở cùng workload, 64 words không cải thiện thông lượng so với 32 words; tác động diện tích thực tế vẫn `TBD` đến khi synthesis.

### 2.2. Kiến Trúc Pipeline Địa Chỉ 2 Tầng (2-Stage Decoupled Address Pipeline)
* **Stage 1 (`fw_axi_address_slice.v`):**
   * Tích hợp bộ cộng có bit mở rộng tính toán `beats = AxLEN + 1`, `bytes_beat = 1 << AxSIZE` và $last\_byte = AxADDR + beats \times bytes\_beat - 1$.
   * Profile chỉ chấp nhận `AxBURST = INCR`, `AxSIZE = 4 bytes`, địa chỉ word-aligned và `AxLEN <= 15`. Stage 1 chốt riêng `profile_err`, `overflow_err` và `4kb_err` cùng descriptor AW/AR; overflow và crossing 4 KiB có thể cùng được ghi nhận.
* **Stage 2 (`fw_acl_matcher.v`):**
   * 8 bộ so sánh song song dùng địa chỉ đầy đủ 32-bit kiểm tra vùng nhớ `[Base, Limit]` inclusive.
  * Kiểm tra Whitelist Master ID & Mask, quyền Read/Write và `AxPROT` (Secure/Privileged) độc lập với Stage 1 profile.
  * Áp dụng quy tắc **Most-Restrictive AND-Logic** khi có vùng nhớ chồng lấn (MITRE CWE-1260).
   * Tại bắt tay địa chỉ phía DMA, chốt descriptor giao dịch và ảnh chụp ACL hiệu lực sau khi đã áp dụng thứ tự ưu tiên context/config. Stage 2 quyết định trên ảnh chụp này; bắt tay nhận yêu cầu không đồng nghĩa với cấp quyền.

### 2.3. Đường Truyền Dữ Liệu Cut-Through Không Thêm Tầng Thanh Ghi
* Khi giao dịch được Stage 2 xác nhận là hợp lệ (`is_allowed = 1`), toàn bộ tín hiệu kênh dữ liệu (`WVALID`, `WDATA`, `WSTRB`, `WLAST`, `WREADY`, `RVALID`, `RDATA`, `RRESP`, `RLAST`, `RREADY`) đi qua multiplexer tổ hợp (**Combinational Cut-Through**) và không thêm latency tuần tự. Độ trễ lan truyền tổ hợp và khả năng timing closure là `TBD` đến STA.
* Khi giao dịch vi phạm an ninh, kênh dữ liệu được ngắt tức thời khỏi Interconnect Matrix và chuyển hướng sang khối **Sink Drain Engine**.

### 2.4. Khối Protocol Drain cho Giao Dịch Bị Từ Chối
* **Wrapper (`fw_drain_fsm.v`):** instantiate `fw_write_drain` và `fw_read_drain`, giữ hai direction độc lập và không serialize tiến trình read/write.
* **Write Drain FSM (`fw_write_drain.v`):** chốt `AWID/AWLEN/ERR_MODE`, nhận và hủy chính xác `AWLEN+1` W handshakes, rồi trả `BID` đã chốt với `BRESP=DECERR` (hoặc `OKAY` trong Honeypot mode). `WLAST` phải đúng ở beat dự kiến cuối; mismatch phát `w_framing_fault_valid` với `WRITE_ERR + PROT_ERR` và không được làm phát B sớm. Firewall top ghép pulse này với `AWADDR/AWID/AWLEN/AWSIZE` từ immutable write-owner metadata.
* **Read Drain FSM (`fw_read_drain.v`):** generates $ARLEN+1$ dummy beats of $0x00000000$ with `RLAST=1` on the final handshaken beat and returns `RRESP=DECERR` (or `OKAY`). Completion is guaranteed only under the AXI progress assumptions in `assumptions_and_tbd.md`; there is no transaction-terminating timeout that fabricates an incomplete AXI response.
 * **Bộ Đếm Vi Phạm Tích Lũy:** Ghi nhận số fault record được chấp nhận vào trường `FAULT_COUNT [31:16]` trong thanh ghi `FAULT_INFO (0x010)` và bão hòa ở `16'hFFFF`. Nếu read, write và context fault cùng chu kỳ, status OR toàn bộ mã lỗi, counter tăng theo số record, còn first-fault metadata chọn `context > write > read`.

### 2.5. Kênh Sideband Động & Thu Hồi Đồng Bộ (Synchronous Context Revocation)
* Giao tiếp Dedicated Point-to-Point nối cứng giữa DMA Core và Firewall (`dma_ctx_*`).
* Tự động cấu hình Region 4 (Read-Only) cho vùng nhớ nguồn và Region 5 (Write-Only) cho vùng nhớ đích khi DMA kích hoạt.
 * `dma_ctx_done` được lấy mẫu đồng bộ; quyền truy cập bị hủy sau cạnh lấy mẫu và trước giao dịch mới ở chu kỳ kế tiếp, ngăn chặn tấn công TOCTOU (NDSS 2019 Thunderclap).

### 2.6. Khóa Cứng Phần Cứng Một Chiều (Hardware Sticky Lock RW1S)
* Cơ chế được thiết kế theo hướng dẫn tăng cường khả năng chống sửa đổi của **NIST SP 800-193**: thanh ghi `FW_LOCK (0x004)` sử dụng **Write-1-to-Set (RW1S)**.
* Sau khi Secure Boot hoàn tất và ghi bit 0 thành 1, thanh ghi bị khóa cứng vĩnh viễn và không thể bị ghi đè bởi bất kỳ phần mềm độc hại nào (kể cả với quyền Root/Kernel) cho đến khi xảy ra Reset cứng của hệ thống (`rst_n = 0`).

---

## 3. NGÂN SÁCH KIẾN TRÚC HIỆU NĂNG VÀ PPA

Baseline hiện hành chỉ nhắm ASIC Sky130A ở 40 MHz. Các mục area và power không có số tuyệt đối trước P&R vì generic synthesis không dùng cell và parasitic của technology đích. Mục tiêu 150 MHz được giữ như exploration riêng và không phải điều kiện PASS của baseline.

| Hạng mục | Sky130A baseline |
| :--- | :---: |
| **Clock chức năng** | **40 MHz** ($T_{\text{clk}} = 25\text{ ns}$) |
| **Băng thông lý thuyết của bus 32-bit** | **160 MB/s** tại một beat mỗi chu kỳ |
| **Throughput reference** | **70.5 MB/s** từ $44.1\%$ utilization của model; không phải RTL hoặc post-route result |
| **Độ trễ tuần tự thêm trên data path** | **0 tầng register** theo contract cut-through |
| **Độ trễ phân giải địa chỉ** | **1 chu kỳ clock** cho Stage 1/2 |
| **Area** | `TBD` đến khi có Sky130A post-route; đánh giá theo `AEGIS_CURRENT` và `FIREWALL_BASE` |
| **Dynamic/leakage power** | `TBD` đến khi có activity và post-route parasitic cùng corner |

---

## 4. MIỀN XUNG NHỊP VÀ RESET (CLOCK & RESET DOMAINS)

* **Clock Domain:** IP sử dụng một miền xung nhịp đồng bộ duy nhất **`clk`** cho DMA Controller Core và DMA-Aware Bus Firewall IP. Baseline backend hiện hành là 40 MHz, tương ứng chu kỳ 25 ns trên Sky130A. Không có CDC nội bộ trong IP; mọi crossing ngoài boundary phải được SoC integration xử lý và kiểm tra riêng. Con số 800 MHz chỉ thuộc benchmark mô hình lịch sử, không phải timing target của RTL.
* **Reset Domain:** Tín hiệu reset không đồng bộ, tích cực mức thấp **`rst_n`** (Asynchronous Assert, Synchronous Deassert) được phân phối đến toàn bộ các phần tử nhớ và thanh ghi trạng thái trong IP.

---

## 5. HỢP ĐỒNG GIAO DIỆN & QUY TẮC CẤU HÌNH V2.4.1 (NORMATIVE CONTRACT)

Các quyết định dưới đây là ràng buộc chuẩn cho RTL, model và verification. Tài liệu
`docs/superpowers/specs/2026-08-13-dma-controller-design.md` là tài liệu lịch sử và
đã được đánh dấu `Obsolete`; tài liệu này không còn có quyền ưu tiên khi có mâu thuẫn.
Trạng thái triển khai Firewall và các gate bị chặn được quản lý tại
`firewall_rtl_integration_contract.md`; V2.4.1 không tuyên bố Firewall RTL đã hoàn thiện.

### 5.1. Hợp đồng giao diện & MMIO DMA Controller

* **DMA-Constrained AXI Profile**: chỉ chấp nhận `AxBURST = 2'b01 (INCR)`, `AxSIZE = 3'b010 (4 Bytes)`, `AxADDR[1:0] == 2'b00 (Word-aligned)`, `AxLEN <= 8'd15 (Max 16 beats)`. Burst ngoài profile hoặc vượt 4 KiB bị từ chối, drain theo hợp đồng dưới đây và ghi `BOUND_ERR`; lỗi framing W/response protocol ghi `PROT_ERR`.
* `ID_WIDTH = 4`, `ADDR_WIDTH = 32`, `DATA_WIDTH = 32` trong cấu hình mặc định.
* DMA là dedicated AXI master với `AWID=ARID=4'h0`, `AWPROT=ARPROT=3'b001` (Secure, Privileged, Data). Firewall vẫn phải giữ và trả đúng ID đã nhận; ràng buộc fixed-ID là profile của DMA chứ không phải lý do rút gọn cổng Firewall.
* APB system address có độ rộng 32-bit; các thanh ghi Firewall sử dụng offset thấp 8-bit trong cửa sổ MMIO 256 bytes (`0x10000000`--`0x100000FF`).
* DMA Controller có `APB_BASE_ADDR = 0x10001000` mặc định và chấp nhận cửa sổ MMIO 32 bytes (`0x10001000`--`0x1000101F`); access ngoài cửa sổ trả `PSLVERR = 1, PRDATA = 0`.
* **APB profile và Phân Tầng An Ninh**: cả hai slave dùng địa chỉ/dữ liệu 32-bit và chỉ hỗ trợ full-word access. `dma_apb_slave` dùng APB3 profile, không có `PPROT/PSTRB`; SoC phải ánh xạ cửa sổ DMA chỉ vào aperture **Secure-Privileged** tại Upstream Interconnect/APB Bridge Firewall. `fw_apb_regs` dùng APB4 protection profile, có `s_apb_pprot[2:0]`; `PSTRB` không được expose và được tích hợp như hằng `4'b1111`, vì vậy byte/halfword write không thuộc baseline.
* **Hợp Đồng Thanh Ghi `DMA_CTRL` (`0x10001000`)**:
  * `START [0]`: `WO` (Write-Only) Command Pulse. Ghi 1 khi `BUSY == 0` tạo xung kích hoạt nội bộ 1 chu kỳ. Ghi 1 khi `BUSY == 1` bị bỏ qua hoàn toàn (Ignored / No-op, không ngắt giao dịch đang chạy). Đọc bit này luôn trả về `0`. `START` **KHÔNG** tự động xóa ngầm các cờ `DONE` hoặc `ERROR` trong `DMA_STATUS`.
  * `IRQ_EN [1]`: `RW` (Read/Write, reset = 0). Bật ngắt `dma_irq`.
  * `RESERVED [31:2]`: `RO` (RAZ/WI).
* **Hợp Đồng Thanh Ghi `DMA_STATUS` (`0x10001010`)**:
  * `BUSY [0]`: `RO` (Read-Only). Tích cực mức 1 khi DMA đang truyền.
  * `DONE [1]`: `W1C` (Write-1-to-Clear) Sticky. Được phần cứng set lên 1 khi giao dịch hiện tại hoàn tất không có lỗi. Chỉ xóa khi phần mềm ghi 1.
  * `ERROR [2]`: `W1C` (Write-1-to-Clear) Sticky. Được set lên 1 khi: (1) Cấu hình không hợp lệ (`src[1:0]!=0`, `dst[1:0]!=0`, `len[1:0]!=0`, `len==0`, tràn 32-bit); (2) phản hồi AXI `RRESP/BRESP != OKAY`; (3) `RID/BID != 0`; hoặc (4) `RLAST` không xuất hiện đúng beat `ARLEN+1`. Chỉ xóa khi phần mềm ghi 1.
  * **Độ ưu tiên Error theo sự kiện**: nếu một giao dịch kết thúc bằng lỗi, phần cứng phát sự kiện set `ERROR` và không phát sự kiện set `DONE` cho giao dịch đó. Hai bit là sticky độc lập; `DONE` còn lưu từ giao dịch trước không bị phần cứng xóa bởi `START` hoặc bởi lỗi mới, vì vậy hai bit có thể đồng thời bằng 1 cho đến khi phần mềm W1C. Hardware-set event thắng W1C nếu cùng chu kỳ.
  * `dma_irq = DMA_CTRL[1] (IRQ_EN) & (DMA_STATUS[1] (DONE) | DMA_STATUS[2] (ERROR))`.
* Kênh Sideband V2.4.1 gồm đúng 5 tín hiệu chuyên dụng: `dma_ctx_valid` (1-bit), `dma_ctx_src_addr[31:0]`, `dma_ctx_dst_addr[31:0]`, `dma_ctx_byte_len[31:0]`, `dma_ctx_done` (1-bit). Không có tín hiệu trạng thái phụ.
* Tín hiệu APB Firewall Slave sử dụng tiền tố `s_apb_*`. Tín hiệu APB DMA Slave sử dụng tiền tố `dma_apb_*`.
* **AXI Write Ordering & Backpressure (Normative)**: DMA Master **tuyệt đối KHÔNG ĐƯỢC phát `WVALID` hoặc thực hiện handshake `W` trước khi `AW` handshake thành công (`AWVALID & AWREADY == 1`)**. Dưới backpressure (`AWREADY=0`), toàn bộ payload của `AW` phải được giữ nguyên ổn định.
* Hệ thống sử dụng tối đa một giao dịch đọc và một giao dịch ghi AXI outstanding cho mỗi kênh.
* DMA Controller chia nhỏ burst truyền theo công thức: $\text{burst\_len} = \min(16, \text{beats\_left}, \text{beats\_to\_4KB\_boundary})$ để không bao giờ vượt quá biên trang 4KB.
* **Error-Abort & Liveness**:
  * Tại AR handshake, Read Engine chốt `expected_r_beats = ARLEN+1` và đếm mọi R handshake. `RLAST` chỉ hợp lệ trên expected final beat. Khi `RRESP != OKAY`, engine chốt `abort_pending`, discard beat lỗi và mọi beat sau nó, nhưng vẫn retire burst đúng số beat đã chốt nếu framing còn hợp lệ. Khi `RLAST` sớm hoặc không có ở expected final beat, đó là protocol fault: beat mismatch không được push vào FIFO và read channel được đóng hữu hạn tại observed early `RLAST` hoặc expected final beat; engine không chờ một tín hiệu bổ sung từ peer đã vi phạm hợp đồng. Nếu một AW đã handshake, phải hoàn tất đủ W beats và nhận B cho burst đã cam kết trước khi flush FIFO; không phát AW mới. Dữ liệu đã ghi trước lỗi không được rollback.
  * Khi gặp `BRESP != OKAY`: chốt `abort_pending`, chặn AR/AW mới; nếu có AR outstanding thì tiếp tục retire theo `ARLEN+1` và RLAST framing policy nhưng không giữ dữ liệu mới; sau đó flush FIFO.
  * Chỉ sau khi mọi AR/AW đã chấp nhận được kết thúc đúng giao thức và FIFO residual đã flush, coordinator mới phát terminal error event, hạ `BUSY` và `dma_ctx_valid`, đồng thời pulse `dma_ctx_done` đúng một chu kỳ. Sự kiện terminal không set `DONE`; giá trị sticky `DONE` cũ, nếu có, vẫn tuân theo W1C-only.
  * Liveness được đánh giá theo số handshake và theo bound kiểm chứng có giả định fairness; không có cam kết số chu kỳ tuyệt đối nếu AXI peer giữ READY/VALID vô hạn.
* Các thanh ghi `DMA_SRC`, `DMA_DST`, `DMA_LEN` là cấu hình cho lần chạy kế tiếp. Descriptor active được chốt nguyên tử khi chấp nhận `START`; ghi các thanh ghi cấu hình trong lúc `BUSY=1` không thay đổi descriptor/context đang chạy.

### 5.2. Quy tắc AXI và kiểm tra biên 4KB

Firewall chỉ chấp nhận burst `INCR`. Với mỗi giao dịch:

```text
beats      = AxLEN + 1
bytes_beat = 1 << AxSIZE
last_byte  = AxADDR + beats * bytes_beat - 1
```

Phép tính phải dùng đủ bit mở rộng để phát hiện address overflow. Giao dịch bị từ chối nếu phép tính có carry ra ngoài 32-bit hoặc `start_addr[31:12] != last_byte[31:12]`. Overflow làm `overflow_err=1` và đồng thời được xem là crossing page đối với `4kb_err`.

Mỗi channel dùng ba cờ snapshot riêng: `pipe_s1_aw_profile_err`, `pipe_s1_aw_overflow_err`, `pipe_s1_aw_4kb_err` cho AW và các cờ `pipe_s1_ar_*` tương ứng cho AR. `profile_err` chỉ bao gồm BURST, SIZE, address alignment và LEN. MID cùng PROT được Stage 2 kiểm riêng để giữ đúng fault mapping.

Nếu W channel đến trước AW channel, Firewall giữ `s_axi_wready = 0` cho đến khi AW
được chấp nhận và quyết định ACL hoàn tất. Master phải giữ dữ liệu ổn định theo quy tắc AXI.

Mỗi bắt tay `s_axi_awvalid & s_axi_awready` hoặc `s_axi_arvalid & s_axi_arready` nhận đúng một yêu cầu vào secure pipeline. Ở cạnh này, Stage 1 chốt toàn bộ payload `Ax*`, `last_byte`, ba cờ profile/overflow/4 KiB và một ảnh chụp logic của ACL hiệu lực. Stage 2 chỉ dùng dữ liệu đã chốt để phát quyết định allow/fault; các thay đổi APB/context sau cạnh nhận không được đổi quyết định của burst. `s_axi_AxREADY=1` chỉ biểu thị còn chỗ nhận yêu cầu, không biểu thị yêu cầu đã được cho phép. Backpressure Stage 2 phải truyền ngược tới Stage 1 để không ghi đè slot đang giữ.

Full-burst containment là bắt buộc: một region chỉ được tính là match khi `start_addr >= BASE_ADDR` **và** `last_byte <= LIMIT_ADDR`. Giao dịch chỉ giao nhau một phần với region không được coi là match; nếu không còn region match đầy đủ thì áp dụng default deny. `FW_EN=0` chỉ bypass phép so ACL/permission cho quản trị Secure-Privileged; kiểm tra AXI profile, overflow, 4 KiB, framing và fault logging không bị tắt.

### 5.3. Dynamic context và ACL

* Region 4 is Read-Only, Region 5 is Write-Only; both are APB `RO` (Hardware-owned). `ACTIVE = 0` after reset. Khi được cấp phát, cả hai region dùng `SECURE_ONLY=1`, `PRIV_ONLY=1`, `MID=4'h0`, `MID_MASK=4'h0`.
* `src[1:0]!=0`, `dst[1:0]!=0`, `len[1:0]!=0`, `len=0` hoặc 32-bit address overflow ($src+len-1 < src$ hoặc $dst+len-1 < dst$) làm context tracker từ chối activation (`ACTIVE=0`) và phát một context `BOUND_ERR` record.
* Region 6 và 7 là static/expansion regions, cấu hình qua APB4 giống Region 0-3; không được tự động nạp từ Sideband. Dự phòng cho mở rộng hệ thống hoặc cấu hình bảo vệ vùng nhớ bổ sung.
* `FW_LOCK` only protects Static Regions (0–3, 6–7) and `FW_CONTROL`. Sideband hardware channel updates Region 4/5 normally after `FW_LOCK = 1`.
* **Simultaneous-Event Priority**: `dma_ctx_done (Revoke) > dma_ctx_valid acceptance (Dynamic Alloc) > APB Config Write > ACL Snapshot`. Priority áp dụng trên cùng cạnh clock. Vì vậy giao dịch được nhận cùng cạnh với `dma_ctx_done` nhìn thấy Region 4/5 đã bị revoke; giao dịch cùng cạnh với cấp phát hợp lệ nhìn thấy region mới. `dma_ctx_valid` chỉ được chấp nhận một lần khi tracker idle; khi active nó bị bỏ qua, và sau `done` nguồn phải hạ `valid` trước lần cấp phát mới.
* **Atomic Permission Snapshot**: descriptor giao dịch và ACL hiệu lực được chốt nguyên tử tại address handshake ($AxVALID \ \& \ AxREADY = 1$) sau khi áp dụng priority trên, rồi bất biến trong toàn bộ burst.
* Khi `FW_EN = 1`, không khớp region là `DEFAULT_DENY`.
* Nếu một giao dịch khớp nhiều region, giao dịch chỉ được phép khi mọi region khớp đều cho phép quyền truy cập.
* Master ID match dùng công thức `(id & ~mask) == (whitelist_id & ~mask)`.
* `BASE_ADDR` và `LIMIT_ADDR` là địa chỉ 32-bit đầy đủ và khoảng địa chỉ là inclusive.
* CẤM sửa đổi BASE, LIMIT, PERM, MID khi Region đang ở trạng thái ACTIVE = 1. Vi phạm trả `PSLVERR=1` và không đổi descriptor. Phần mềm bắt buộc phải deactivate (ghi ACTIVE = 0), cập nhật cấu hình descriptor, rồi mới activate (ghi ACTIVE = 1) trở lại. Ghi `ACTIVE=1` khi `BASE_ADDR > LIMIT_ADDR` trả `PSLVERR=1` và region vẫn inactive.
* `AUTO_CTX_EN=0` chặn cấp phát mới và đồng bộ xóa Region 4/5 ở cạnh chấp nhận APB write đó; việc tắt tự động context không được để lại quyền động cũ. Re-enable không tự phục hồi descriptor đã xóa.
* Drain FSM giữ đúng framing AXI dưới progress assumptions đã công bố. Nếu peer giữ backpressure hoặc không hoàn tất burst vô hạn, watchdog chỉ được báo/escalate; chính sách isolation/reset của SoC nằm ngoài IP baseline và còn `TBD` ở integration, không được giả lập AXI completion.

### 5.4. Hợp đồng APB và trạng thái lỗi

* `FW_EN = 1` after reset (Fail-Secure Default-Deny enabled out of reset).
* `IRQ_PENDING` (bit 31) is an independent sticky W1C flag; `sec_irq = FW_CONTROL[1] && FAULT_STATUS[31]`. Deasserts only when `IRQ_PENDING` is cleared via W1C or `IRQ_EN = 0`.
* Địa chỉ register không hợp lệ trả `PREADY = 1`, `PSLVERR = 1`, `PRDATA = 0`.
* Khi CPU gửi giao dịch Non-Secure (`PPROT[1]=1`) hoặc Unprivileged (`PPROT[0]=0`) đến Firewall APB, trả `PSLVERR = 1` và ghi bị chặn hoàn toàn.
* Khi `STICKY_LOCK = 1`, mọi ghi vào thanh ghi cấu hình (FW_CONTROL, Region 0-7) trả `PSLVERR = 1`; chỉ cho phép W1C trên `FAULT_STATUS`.
* Ghi vào thanh ghi toàn phần `RO` (fault metadata/count/timestamp/source hoặc Region 4/5) trả `PSLVERR=1` và không đổi state. Bit reserved nằm trong một thanh ghi ghi được đọc về 0 và bit ghi tương ứng bị bỏ qua mà không làm hỏng các field hợp lệ cùng access.
* `FW_LOCK` khóa `FW_CONTROL` và static region configuration, nhưng không khóa fault status/metadata.
* `FW_LOCK.STICKY_LOCK` là RW1S: ghi 1 set bit; ghi 0 không có tác dụng; khi đã set, mọi ghi tiếp theo vào chính `FW_LOCK` hoàn tất như no-op và bit chỉ clear bởi reset.
* `FAULT_COUNT` saturate tại `16'hFFFF`.
* Logger có ba nguồn record độc lập `context`, `write`, `read` và chấp nhận đồng thời. `FAULT_STATUS` OR mọi bit lỗi; `FAULT_COUNT` tăng 0–3 theo số record trong chu kỳ và bão hòa. Khi first-fault capture đang mở mà có nhiều record cùng chu kỳ, metadata chọn `context > write > read`; `FAULT_SOURCE (0x018)` ghi rõ source và code của record được chọn. Các record còn lại vẫn cập nhật status/count. Clear toàn bộ fault bits và IRQ chỉ mở lại first-fault capture cho chu kỳ kế tiếp, vì hardware-set thắng W1C cùng chu kỳ.
* Read và write fault records mang `ADDR/ID/LEN/SIZE` từ immutable address snapshot; LEN và SIZE được ghi vào `FAULT_INFO.FAULT_LEN` cùng `FAULT_INFO.FAULT_SIZE`. Context first-fault dùng `ID=0`, `LEN=0`, `SIZE=0`, `FAULT_TYPE=0` và `FAULT_SOURCE=Context`; `dma_ctx_byte_len` không được chuyển thành `AxLEN`.
* Khi write drain phát `w_framing_fault_valid`, `dma_bus_firewall` dùng write-owner metadata giữ từ denied decision đến B handshake để tạo full write fault record. Write drain không nhận `AWADDR` hoặc `AWSIZE`.
* `FAULT_STATUS` dùng W1C. Khi toàn bộ fault bits và `IRQ_PENDING` đã được clear, khóa first-fault được mở để lỗi kế tiếp ghi đè; metadata hiện tại vẫn giữ nguyên trong `FAULT_ADDR/INFO/TIMESTAMP` cho đến lỗi kế tiếp hoặc reset.

| Nguyên nhân fault | Code bits được set cho record |
| :--- | :--- |
| ACL no-match hoặc permission/MID deny | `READ_ERR` hoặc `WRITE_ERR` theo channel |
| Secure/Privileged mismatch | `PROT_ERR` + `READ_ERR/WRITE_ERR` theo channel |
| Non-INCR, narrow, unaligned, `AxLEN>15`, overflow hoặc crossing 4 KiB | `BOUND_ERR` + `READ_ERR/WRITE_ERR` theo channel |
| Burst chỉ giao một phần nhưng không được region nào contain đầy đủ | `BOUND_ERR` + `READ_ERR/WRITE_ERR` theo channel |
| WLAST sai vị trí hoặc response-ID mismatch | `PROT_ERR` + `WRITE_ERR` hoặc channel tương ứng |
| Context len zero/misaligned/overflow | `BOUND_ERR`; source=`Context` trong `FAULT_SOURCE` |

### 5.5. Trạng thái PPA

Các chỉ tiêu PPA hiện là architecture budgets. Giá trị thực tế phải được cập nhật sau
synthesis, timing và power analysis; các bản PRD/microarchitecture V2.1 xuất trước đó
không được dùng để override baseline chức năng V2.4.1.

### 5.6. Bảng Tie-Off Tín Hiệu Không Dùng

* `PSTRB`: không expose; APB integration chỉ phát full-word write và xử lý nội bộ như `4'b1111`.
* `AxCACHE`: Tied off to `4'b0000` (Device Non-bufferable).
* `AxLOCK`: Tied off to `1'b0` (Normal access).
* `AxQOS`: Tied off to `4'b0000` (Default QoS).
* `AxREGION`: Unused (Firewall performs internal 8-region decoding).
