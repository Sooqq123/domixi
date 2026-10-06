# FIREWALL RTL INTEGRATION CONTRACT

## DMA-Aware Bus Firewall IP

**Tài liệu:** Architecture Specification — Canonical Integration Contract
**Phiên bản:** V2.4.1 DMA-Constrained Clarification & Closure Baseline
**Ngày cập nhật:** 2026-09-17
**Trạng thái:** Canonical Architecture Baseline V2.4.1 — RTL Integrated and Frontend Verified

---

## 1. Phạm vi và trạng thái hiện tại

Production Firewall hiện nằm tại `../../../rtl/`, gồm `dma_bus_firewall.v` và mười hai dependency được liệt kê trong source manifest backend. Contract công khai có 94 cổng và được kiểm tự động với `pinout.csv`.

Bằng chứng hiện hành gồm unit/integration regression dùng source thật, SoC integration với PicoRV32 và DMA, Verilator lint, formal suites và generic synthesis. Phần chưa đóng là functional/code coverage database, gate-level SDF, CDC/RDC sign-off ở boundary tích hợp và toàn bộ physical sign-off. Vì vậy trạng thái đúng là **RTL INTEGRATED / FRONTEND VERIFIED / PHYSICAL PENDING**.

## 2. Thành phần phụ thuộc

| Thành phần | Phụ thuộc Firewall RTL | Trạng thái xác nhận |
| :--- | :--- | :--- |
| DMA AXI master | Cần AW/AR READY, W/R/B response và error framing đúng hợp đồng | Unit và source-built integration PASS |
| DMA context sideband | Cần tracker nhận một lần, cấp Region 4/5 và revoke đúng priority | RTL integration và directed regression PASS |
| SoC AXI interconnect | Chỉ được thấy request đã allow; không được thấy denied W/AR/AW | Matrix model integration PASS; physical interconnect pending |
| Secure CPU/APB bridge | Cần APB4 protection cho firewall và Secure-Privileged aperture cho DMA | APB setup/access sequencing và directed provenance PASS |
| Interrupt controller/SIEM firmware | Cần `sec_irq`, sticky status/count/metadata đúng semantics | RTL IRQ/NMI path PASS; firmware sign-off ngoài IP |
| Verification environment | Bind SVA, đo coverage và chạy negative regression | Simulation/formal PASS; coverage database pending |
| Synthesis/STA/PPA | Cần netlist hoàn chỉnh và target constraints | Generic synthesis PASS; target STA/PPA và physical sign-off pending |

## 3. Module và trách nhiệm bắt buộc

| Module logic | Trách nhiệm tối thiểu |
| :--- | :--- |
| `dma_bus_firewall.v` | Top-level kết nối APB4, DMA-side AXI slave, matrix-side AXI master, context sideband, IRQ và các module con |
| `fw_axi_address_slice.v` | Decoupled Stage 1 cho AW/AR; tính extended `last_byte`, profile/overflow/4 KiB flags; chốt toàn payload và chống ghi đè dưới backpressure |
| `fw_acl_matcher.v` | Full-burst containment, 8-region parallel match, ID/mask, PROT, permission, overlap AND, default deny và immutable decision snapshot |
| `fw_context_tracker.v` | One-shot sideband allocation, Region 4/5 Secure-Privileged fixed-ID, invalid-length fault, revoke/disable priority |
| `fw_data_path_mux.v` | Chỉ route allowed transaction sang matrix; route denied response/data sang drain; không để dữ liệu vượt ACL decision |
| `fw_drain_fsm.v` | Wrapper canonical instantiate hai drain direction độc lập; chỉ nối interface và không serialize read/write |
| `fw_write_drain.v` | Write exact `AWLEN+1`, latched ID/LEN/mode, stable B response và one-cycle framing fault pulse |
| `fw_read_drain.v` | Read exact `ARLEN+1`, latched ID/LEN/mode và stable R response dưới backpressure |
| `fw_apb_regs.v` | APB4 Secure-Privileged register file, RW1S lock, active-region write protection, W1C status, multi-event logger và IRQ |

Tên module/file trong bảng là canonical. Không tạo alias hoặc compatibility wrapper cho APB register block; ranh giới hành vi và toàn bộ cổng quan sát được trong SSOT không được thay đổi nếu chưa phát hành baseline mới.

## 4. Giao diện tích hợp bắt buộc

### 4.1. Clock/reset

- một `clk` dùng chung cho DMA và Firewall;
- `rst_n` asynchronous assert, synchronous deassert;
- sau reset: `FW_EN=1`, `AUTO_CTX_EN=1`, `ERR_MODE=1`, mọi region inactive, fault/IRQ/count bằng 0, AXI READY/VALID do Firewall phát bằng 0 cho đến cạnh deassert đồng bộ; APB `PREADY=1`.
- Ở `aegis_soc_top`, bridge/DMA dùng `rst_n_synced` của top còn Firewall nhận raw `rst_n` và tự chạy synchronizer hai flip-flop; không nối `rst_n_synced` vào Firewall lần nữa.
- Mọi input dữ liệu/control của IP (APB, AXI, DMA sideband và CPU telemetry) phải synchronous với `clk`; IP không tự xử lý crossing clock-domain. SoC phải cung cấp synchronizer/bridge cho mọi crossing ngoài boundary.
- `test_mode` là tín hiệu tĩnh do SoC test controller điều khiển, phải ổn định trước khi nhả reset và không được đổi giữa burst đang hoạt động. Khi bằng 1, synchronizer reset được bypass có chủ đích; scan clock, scan chain và DFT stitching không thuộc IP này.

### 4.2. DMA-side AXI slave và matrix-side AXI master

- `ADDR_WIDTH=32`, `DATA_WIDTH=32`, `ID_WIDTH=4` trên AW/AR/B/R;
- đầy đủ AW: `ID,ADDR,LEN,SIZE,BURST,PROT,VALID,READY`;
- đầy đủ W: `DATA,STRB,LAST,VALID,READY`;
- đầy đủ B: `ID,RESP,VALID,READY`;
- đầy đủ AR: `ID,ADDR,LEN,SIZE,BURST,PROT,VALID,READY`;
- đầy đủ R: `ID,DATA,RESP,LAST,VALID,READY`;
- DMA phát `AxID=0`, `AxPROT=001`, `AxSIZE=010`, `AxBURST=INCR`, `AxLEN<=15`, word-aligned và không crossing 4 KiB;
- matrix-side `AxCACHE=0000`, `AxLOCK=0`, `AxQOS=0000`, `AxREGION=0000`; các thuộc tính này do Firewall top phát hằng và không cần slave-side input từ dedicated DMA;
- AXI USER signals và ATOP không thuộc baseline V2.4.1;
- Firewall không được rút gọn ID ở boundary và phải echo ID snapshot trên denied responses.

### 4.3. Sideband

Đúng năm tín hiệu đồng bộ:

```text
dma_ctx_valid
dma_ctx_src_addr[31:0]
dma_ctx_dst_addr[31:0]
dma_ctx_byte_len[31:0]
dma_ctx_done
```

Descriptor phải ổn định từ khi `dma_ctx_valid` được assert cho đến terminal. Tracker chỉ lấy một lần khi armed/idle, bỏ qua valid lặp khi active, và không re-arm sau done cho đến khi thấy valid thấp.

### 4.4. APB/IRQ

- Firewall APB: address/data 32-bit, `PPROT[2:0]`, full-word profile, không expose PSTRB;
- chỉ `PPROT[1]=0 && PPROT[0]=1` được truy cập;
- DMA APB: APB3 address/data 32-bit, không PPROT/PSTRB; upstream bắt buộc enforce Secure-Privileged;
- `sec_irq` và `dma_irq` là active-high level theo công thức trong `architecture_overview.md`.

### 4.5. Stage 1 snapshot

- AW snapshot mang `pipe_s1_aw_profile_err`, `pipe_s1_aw_overflow_err` và `pipe_s1_aw_4kb_err`;
- AR snapshot mang `pipe_s1_ar_profile_err`, `pipe_s1_ar_overflow_err` và `pipe_s1_ar_4kb_err`;
- `profile_err` chỉ kiểm BURST, SIZE, address alignment và LEN;
- MID/mask và PROT được matcher kiểm độc lập;
- descriptor cùng ba cờ giữ ổn định khi Stage 2 backpressure.

### 4.6. Fault records

- write record dùng `w_fault_event_id`, `w_fault_event_len` và `w_fault_event_size` từ immutable AW snapshot;
- read record dùng `r_fault_event_id`, `r_fault_event_len` và `r_fault_event_size` từ immutable AR snapshot;
- context first-fault dùng ID, LEN và SIZE bằng 0, source bằng Context;
- write drain phát `w_framing_fault_valid` và `w_framing_fault_code=WRITE_ERR|PROT_ERR`;
- `dma_bus_firewall` ghép framing pulse với write-owner `AWADDR/AWID/AWLEN/AWSIZE` giữ đến B handshake trước khi gửi `w_fault_event_*` vào `fw_apb_regs`.

## 5. Invariant tích hợp

1. Không AW/AR nào ra matrix trước quyết định allow đã chốt.
2. Không W nào ra matrix nếu AW tương ứng chưa được allow và handshake downstream.
3. Không nhận giao dịch thứ hai trên cùng channel khi transaction trước còn outstanding.
4. Thay đổi APB/context sau address acceptance không đổi decision/ID/LEN/mode của transaction đó.
5. Same-cycle `dma_ctx_done` thắng allocation/APB/snapshot; giao dịch cùng cạnh không dùng quyền vừa revoke.
6. Denied write không ra matrix và chỉ trả B sau đúng `AWLEN+1` W handshakes.
7. Denied read không ra matrix và trả đúng `ARLEN+1` R handshakes.
8. Payload VALID phải ổn định trong mọi chu kỳ bị backpressure.
9. `FW_EN=0` không được tắt profile, overflow, 4 KiB, framing hoặc logging checks.
10. Lock/config/fault semantics phải đúng `register_map.csv`, kể cả simultaneous hardware-set thắng W1C.
11. MID và PROT không được gộp vào Stage 1 `profile_err`.
12. `fw_drain_fsm` không dùng chung owner hoặc state register giữa read và write direction.

## 6. Trình tự tích hợp đề nghị

1. Chốt top-level port list bằng `pinout.csv` và internal contract bằng `signal_list.csv`.
2. Hoàn tất/lint address slice độc lập với directed profile/overflow/backpressure tests.
3. Tích hợp ACL snapshot và context tracker; chạy overlap, containment, revoke/allocate priority tests.
4. Unit-review `fw_write_drain` và `fw_read_drain`, sau đó tích hợp qua `fw_drain_fsm` wrapper với exact beat, ID, simultaneous direction, stall stability và early/missing WLAST tests.
5. Tích hợp APB register/logger/IRQ; chạy access protection, lock, active-region, W1C và simultaneous-event tests.
6. Tích hợp DMA–Firewall–matrix top; chạy normal, deny, response error, abort, backpressure và reset tests.
7. Bind SVA, đạt functional/code coverage, rồi mới chạy synthesis/STA/PPA.

## 7. Tiêu chí nghiệm thu Firewall RTL

Firewall RTL chỉ được xác nhận hoàn tất khi đồng thời đạt:

- source lint/elaboration sạch, không implicit net, undriven output, width truncation hoặc latch ngoài chủ ý;
- mọi requirement `REQ_FW_*` có RTL evidence và self-checking test PASS;
- SVA cho ordering, snapshot, containment, exact beat, ID, stable-under-stall, lock và priority đều PASS;
- negative regression gồm profile sai, 4 KiB, no-match, overlap, PROT/ID, early/missing WLAST, backpressure, reset và simultaneous faults;
- functional coverage đạt 100% mandatory requirement bins/crosses; code coverage waiver được review riêng;
- end-to-end DMA transfer allowed PASS và denied transfer không tạo matrix-side access;
- trust-provenance test chứng minh Non-Secure/Unprivileged không cấu hình được DMA/Firewall;
- synthesis/STA không có unconstrained path và đạt target đã được người dùng cung cấp; PPA được ghi là measured, không lấy từ model projection;
- `verification_evidence_manifest.csv` liên kết command, source revision, result và artifact mới.

## 8. Các mục còn mở

Các mục sau chưa được suy rộng từ kết quả RTL hiện hành:

- functional coverage và code coverage database với waiver được review;
- gate-level equivalence và simulation có SDF;
- CDC/RDC sign-off tại boundary SoC và sau DFT;
- technology-specific STA, timing cut-through, area và power;
- physical verification và tuyên bố tapeout-ready.

Các mục này không hạ trạng thái RTL regression đã PASS, nhưng phải đóng trước sign-off tương ứng.
