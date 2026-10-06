# BÁO CÁO MÔ HÌNH HÓA KIẾN TRÚC MỨC HỆ THỐNG (SYSTEM-LEVEL MODELING SPECIFICATION)
## Dự Án: DMA-Aware Bus Firewall IP & DMA Controller Core
**Phiên bản:** V2.1 Historical Snapshot (Obsolete as behavioral contract)  
**Trạng thái tuân thủ:** Supporting historical report — kết quả hiện hành chỉ lấy từ evidence manifest V2.4.1  
**Tập Dữ Liệu Thực Nghiệm:** `benchmark_data/benchmark_results.json` & `benchmark_data/benchmark_results.csv`

> **Status: Supporting historical model report — not canonical.** Architecture and behavioral contracts are governed by Canonical Architecture Baseline V2.4.1 in `DMA-controller/docs/architecture/`. In case of conflict, V2.4.1 supersedes this report. Chỉ benchmark được tái sinh từ source hiện tại và test result được liên kết trong `docs/architecture/verification_evidence_manifest.csv` mới là supporting evidence; mọi tuyên bố V2.1 về implementation completeness không phải conformance evidence.

---

## 1. TỔNG QUAN HỆ THỐNG & MỤC TIÊU MÔ HÌNH HÓA

Một khung mô phỏng mức hệ thống theo chu kỳ/sự kiện được xây dựng trong thư mục `model/`. Mức độ phù hợp từng requirement phải được đánh giá bằng regression hiện hành; sự tồn tại của class/model không đồng nghĩa mô hình đã conform.

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               KIẾN TRÚC TỔNG THỂ MÔ HÌNH HÓA SOC                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                                
       ┌────────────────────────┐                   ┌──────────────────────────────┐
       │ Secure CPU / Software  │                   │ Dedicated DMA Sideband Ch    │
       │ (APB4 Master Mode)     │                   │ (src, dst, len, done, valid) │
       └───────────┬────────────┘                   └──────────────┬───────────────┘
                   │ APB4 (PPROT Check)                            │ Zero-Delay Revocation
                   ▼                                               ▼
       ┌───────────────────────────────────────────────────────────────────────────┐
       │                 DMA-AWARE BUS FIREWALL IP (INLINE GUARD)                  │
       │  ┌─────────────────────────┐     ┌─────────────────────────────────────┐  │
       │  │ Stage 1: Addr Pipeline  │────►│ Stage 2: Parallel ACL Matcher       │  │
       │  │ (Extended Adder & 4KB)  │     │ (8 Regions 32-bit Full Address)     │  │
       │  └─────────────────────────┘     └─────────────────────────────────────┘  │
       │  ┌─────────────────────────┐     ┌─────────────────────────────────────┐  │
       │  │ Deadlock-Free Sink Drain│◄────│ Zero-Latency Data Cut-Through Mux   │  │
       │  │ (1 Beat/Cycle WDATA)    │     │ (0-Cycle Delay for Clean Traffic)   │  │
       │  └─────────────────────────┘     └─────────────────────────────────────┘  │
       └───────────────────▲───────────────────────────────────────┬───────────────┘
                           │ AXI4 Slave Bus                        │ AXI4 Master Bus
       ┌───────────────────┴──────────┐                            ▼
       │      DMA CONTROLLER CORE     │             ┌──────────────────────────────┐
       │ ┌──────────────────────────┐ │             │   AXI4 MULTI-LAYER MATRIX    │
       │ │ AXI Read Master FSM      │ │             │   (Interconnect Crossbar)    │
       │ ├──────────────────────────┤ │             └──────────────┬───────────────┘
       │ │ Synchronous FIFO Buffer  │ │                            │
       │ ├──────────────────────────┤ │             ┌──────────────┴───────────────┐
       │ │ AXI Write Master FSM     │ │             │ System Memory / SRAM / Periph│
       │ └──────────────────────────┘ │             │ (Configurable Wait-States)   │
       └──────────────────────────────┘             └──────────────────────────────┘
```

### Các Khối Đã Được Mô Hình Hóa Chi Tiết:
1. **`DMACore` (`model/soc_components.py`):** Bộ điều khiển DMA với FSM Read Burst, FSM Write Burst, bộ đệm Synchronous FIFO, thanh ghi cấu hình APB và cổng xuất Sideband Context `dma_ctx_*`.
2. **`DMAAwareBusFirewall` (`model/firewall_model.py`):**
   * **Stage 1 Pipeline:** Tính $last\_byte = AxADDR + (AxLEN+1)\times(1\ll AxSIZE)-1$ bằng phép cộng mở rộng để phát hiện overflow và crossing 4KB.
   * **Stage 2 Parallel ACL Matcher:** 8 bộ so sánh địa chỉ đầy đủ 32-bit, phân giải quyền truy cập Most-Restrictive (MITRE CWE-1260), Whitelist Master ID & Mask.
   * **Dynamic Context Tracker:** Tự động mở Region 4 (Read-Only) và Region 5 (Write-Only) từ Sideband và thu hồi quyền tức thời $0\text{-delay}$ khi nhận xung `done`.
   * **Deadlock-Free Sink Drain FSMs:** Write Drain FSM nuốt dữ liệu độc hại $1\text{ beat/cycle}$, Read Drain FSM sinh dữ liệu ngụy trang $RDATA=0$, chuyển đổi linh hoạt chế độ Honeypot (OKAY) vs Fail-Secure (DECERR).
   * **Secure APB4 MMIO Register File:** Khóa một chiều `FW_LOCK` (RW1S - NIST SP 800-193), First-Fault Sticky Capture, bộ đếm vi phạm tích lũy `FAULT_COUNT`.
3. **`GoldenFirewallEngine` (`model/golden_ref.py`):** Mô hình tham chiếu thuật toán chuẩn (Golden Algorithm) độc lập với chu kỳ clock.

---

## 2. KẾT QUẢ ĐO LƯỜNG ĐỊNH LƯỢNG & BENCHMARK THỰC NGHIỆM

Từ việc thực thi `model/run_benchmark.py`, 37 tập tham số cấu hình đã được quét và ghi nhận tự động vào `benchmark_data/`:

### 2.1. Phân Tích Độ Sâu FIFO (FIFO Depth Sweep) @ 800 MHz (Payload = 1024 Bytes)

| FIFO Depth (Words) | Mem Latency (Cycles) | Total Execution Cycles | Throughput (MB/s) | Effective Bus Utilization (%) | Peak FIFO Occupancy | FIFO Full Stall Cycles |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **4** | 0 | 964 | 849.8 | 26.6% | 4 | 315 |
| **4** | 1 | 1028 | 796.9 | 24.9% | 4 | 315 |
| **4** | 5 | 1284 | 638.0 | 19.9% | 4 | 315 |
| **8** | 0 | 868 | 943.8 | 29.5% | 8 | 279 |
| **8** | 1 | 900 | 910.2 | 28.4% | 8 | 279 |
| **8** | 5 | 1028 | 796.9 | 24.9% | 8 | 279 |
| **16** | 0 | 820 | 999.0 | 31.2% | 16 | 255 |
| **16** | **1 (Typical)** | **836** | **979.9** | **30.6%** | **16** | **255** |
| **16** | 5 | 900 | 910.2 | 28.4% | 16 | 255 |
| **32 (Baseline)**| **0** | **565** | **1,449.9** | **45.3%** | **16** | **0** |
| **32 (Baseline)**| **1 (Typical)** | **581** | **1,410.0** | **44.1%** | **16** | **0** |
| **32 (Baseline)**| **5** | **645** | **1,270.1** | **39.7%** | **16** | **0** |
| **64** | 1 | 581 | 1,410.0 | 44.1% | 16 | 0 |
| **64** | 5 | 645 | 1,270.1 | 39.7% | 16 | 0 |

---

## 3. PHÁT HIỆN ĐIỂM NGHẼN KIẾN TRÚC & ĐỀ XUẤT TỐI ƯU HÓA

### 3.1. Phân Tích Điểm Nghẽn Ping-Pong Stall ở FIFO Depth = 16
* **Hiện tượng:** Ở cấu hình `FIFO Depth = 16`, tổng thời gian truyền 1 KiB mất 836 chu kỳ clock, trong đó có **255 chu kỳ full stall**.
* **Nguyên nhân:** Do FIFO chỉ đủ chứa đúng 1 burst 16 beats. Read Engine phải dừng hoàn toàn để chờ Write Engine xả hết 16 words sang bộ nhớ đích thì mới có thể xin phát burst đọc tiếp theo (hiện tượng Ping-Pong Blocking).
* **Hiệu suất:** Băng thông mô hình đạt $30.6\%$ ($0.980\text{ GB/s} / 3.2\text{ GB/s}$).

### 3.2. Bước Nhảy Hiệu Năng Vượt Trội ở FIFO Depth = 32 (Double-Buffering Sweet Spot)
* **Hiện tượng:** Khi nâng `FIFO Depth` từ 16 lên **32 words**, thông lượng tăng từ $979.9\text{ MB/s}$ lên **$1,410.0\text{ MB/s}$ (khoảng +43.9%)**, mức sử dụng bus tăng từ $30.6\%$ lên **$44.1\%$**, và full-stall giảm về **0 chu kỳ**.
* **Nguyên nhân:** Độ sâu 32 words kích hoạt cơ chế **Double-Buffering (Ping-Pong không độ trễ)**: Trong lúc Write Engine đang xả burst $N$ (16 words), Read Engine đã có thể song song nạp trước burst $N+1$ (16 words) vào nửa còn lại của FIFO mà không bị cản trở.
* **So sánh với FIFO Depth = 64:** Model giữ nguyên $1,410.0\text{ MB/s}$ ở workload này. Tác động diện tích thực tế của 64 so với 32 vẫn `TBD` đến synthesis; không suy ra “gấp đôi” nếu chưa có implementation report.

> [!TIP]
> **ĐỀ XUẤT KIẾN TRÚC RTL TỐI ƯU:**  
> Thiết kế phần cứng RTL Verilog cho `dma_fifo_latch.v` nên được cố định ở tham số mặc định **`FIFO_DEPTH = 32`** (Dual-Burst Ping-Pong Buffer) để đạt điểm cân bằng Pareto tối ưu nhất giữa diện tích silicon ($A$) và hiệu năng thông lượng ($P$).

---

## 4. MA TRẬN KẾT QUẢ LỊCH SỬ & 4 ATTACK VECTORS

Các kết quả dưới đây là ghi nhận lịch sử V2.1. Chúng không được dùng làm trạng thái hiện hành; số lượng test, command và PASS/FAIL mới nhất nằm trong evidence manifest V2.4.1:

| Mã Kịch Bản | Vector Tấn Công & Chuẩn Đối Chiếu | Cơ Chế Bảo Vệ Của Firewall | Kết Quả Thực Nghiệm |
| :--- | :--- | :--- | :---: |
| **TC_NORMAL** | Truyền DMA hợp lệ (Memory Copy 256B/1KB) | Cut-Through 0-cycle data latency, dữ liệu khớp 100% | **PASSED (100% Match)** |
| **TC_CROSS_BOUND** | Tấn công Burst tràn ranh giới 4KB (AMBA AXI4 A3.4.1) | Stage 1 phát hiện, bẫy lỗi `FAULT_STATUS[3]=1`, kích hoạt `sec_irq` | **PASSED (Trapped)** |
| **TC_TAMPER_LOCK** | Cố tình ghi đè MMIO sau Secure Boot (NIST SP 800-193) | Hardware Sticky Lock RW1S từ chối và trả về `PSLVERR=1` | **PASSED (Locked)** |
| **TC_TOCTOU_FORGERY**| Khai thác TOCTOU sau khi DMA hoàn tất (NDSS 2019 Thunderclap)| Dynamic Context Tracker hủy quyền Region 4 & 5 trong $0\text{-delay}$ | **PASSED (Revoked)** |
| **TC_DEADLOCK_STRESS**| Bơm 1,000 Burst vi phạm liên tiếp gây nghẽn DoS | Write Drain FSM nuốt 1 beat/cycle, 0 cycle deadlock | **PASSED (0 Deadlock)** |

---

## 5. HƯỚNG DẪN TÁI LẬP HỖ TRỢ (REPRODUCIBILITY GUIDE)

Người dùng hoặc kỹ sư kiểm chứng có thể tái lập toàn bộ kết quả mô hình hóa bất kỳ lúc nào bằng các lệnh sau:

```bash
# 1. Chạy toàn bộ Unit Tests & Integration Tests hiện hành
python -m unittest discover -s model -p "test_*.py" -v

# 2. Chạy quét tham số hiệu năng toàn diện và xuất file JSON/CSV
python model/run_benchmark.py
```

Sau mỗi run phải cập nhật command, tool version, source revision, timestamp và artifact path trong `docs/architecture/verification_evidence_manifest.csv`; console output không được lưu thì không phải sign-off evidence.
