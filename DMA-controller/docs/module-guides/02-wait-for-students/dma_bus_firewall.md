# Chuẩn bị thiết kế `dma_bus_firewall`

> Phân loại: `WAIT_FOR_STUDENTS`. Top Firewall chờ cả bốn gói sinh viên và các module `READY_NOW` đã qua unit acceptance.

## 1. Vì sao top chưa được thiết kế cuối

`dma_bus_firewall` là nơi mọi interface trở thành wiring thật. Top cần APB regs, ACL matcher, write drain, read drain, address slice, context tracker và data path mux. Tên Stage 1 flags, fault LEN/SIZE, drain wrapper và APB register module đã được chốt, nhưng bốn module logic quan trọng vẫn đang chờ bài nộp.

Viết top final trước khi nhận source sẽ buộc phải đoán timing cụ thể của port và adapter bài nộp. Công việc hiện tại chỉ là lập integration matrix, tạo stubs có kiểm soát và chuẩn bị testbench. Không viết top production RTL.

## 2. Mục tiêu top sau khi đủ đầu vào

Top phải ghép:

```text
DMA AXI
  -> Stage 1 address slice
  -> Stage 2 ACL matcher
  -> owner-based data path mux
       -> Matrix khi allowed
       -> drain khi denied

DMA context -> context tracker -> dynamic Region 4/5
APB -> register block -> static policy/control/fault state
fault sources -> register block -> security IRQ
```

Top chịu trách nhiệm wiring, priority-visible effective state, tie-offs, reset distribution, isolation và không tạo combinational loops.

## 3. Dependency gate

| Dependency | Điều kiện cần |
|---|---|
| `fw_axi_address_slice` | Unit PASS với sáu interface flags canonical |
| `fw_context_tracker` | Unit PASS, effective-state priority defined |
| `fw_data_path_mux` | Owner truth table và G3 PASS |
| Student 01 `fw_apb_regs` | Accepted register/fault RTL |
| Student 02 `fw_acl_matcher` | Accepted policy RTL/model |
| Student 03 write drain | Accepted exact-beat sink |
| Student 04 read drain | Accepted stable dummy response |
| `fw_drain_fsm` | Hai module con accepted và wrapper port mapping reviewed |

Top chỉ chuyển sang thiết kế khi tất cả dependency có version identifier và port list.

## 4. Bốn gói sinh viên phải bàn giao

### Gói 01

RTL/TB register block, APB protection, lock, fault logging, dynamic readback, logs và port conformance report.

### Gói 02

RTL/TB matcher, pure model, random seeds, Stage 1 flag mapping và decision/fault payload.

### Gói 03

Write drain RTL/TB, WLAST framing event, owner handshake và integration note.

### Gói 04

Read drain RTL/TB, payload stability, owner handshake và integration note.

Không nhận một ảnh PASS thay cho source, commands và logs.

## 5. Interface matrix phải lập trước RTL

Mỗi signal cần các cột:

```text
name, width, direction, producer, consumer, reset/default,
valid condition, stability rule, owner, canonical source, conformance status
```

Nhóm bắt buộc:

- upstream DMA AXI;
- downstream Matrix AXI;
- Stage 1 to Stage 2 snapshots;
- matcher decisions;
- write/read drain interfaces;
- context sideband và dynamic regions;
- APB register policy state;
- read/write/context fault records;
- security IRQ;
- tie-off attributes.

Không nối bằng tên giống nhau mà bỏ qua semantics. Hai signal cùng width vẫn có thể khác timing contract.

## 6. Priority tại top

Same-cycle priority canonical:

```text
context revoke
  > context allocation
  > APB config write
  > ACL snapshot
```

Top phải bảo đảm matcher snapshot thấy effective state sau priority, không đơn giản nối register outputs cũ nếu sequential update xảy ra cùng cạnh. Cần một trong các cách được review:

- next-state policy bus;
- combinational effective-state overlay;
- transaction acceptance scheduling chứng minh tương đương.

Không chọn cách chỉ vì ít code; phải có same-cycle tests.

Accepted APB write làm `AUTO_CTX_EN` chuyển từ 1 xuống 0 là revoke-class event đặc biệt. Top phải đưa event hoặc effective next-value đến context tracker để Region 4/5 inactive tại chính cạnh write đó. Event này chặn allocation cùng cạnh, và re-enable không được tự phục hồi descriptor cũ.

## 7. Ownership và G3

Write owner và read owner độc lập. Allowed owner chỉ set khi address đã được downstream Matrix nhận. Drain owner set khi denied request đã được local drain nhận.

Top giữ immutable write-owner `AWADDR`, `AWID`, `AWLEN` và `AWSIZE` từ denied decision acceptance đến B handshake. Metadata không được lấy lại từ live AW bus và không được xóa khi WLAST mismatch xảy ra.

G3 bắt buộc:

- W không đi xuống Matrix trước allowed AW handshake;
- W không đi vào drain trước denied owner acceptance;
- denied address/data không chạm Matrix;
- response chỉ đến từ owner source;
- owner clear ở B handshake hoặc final R handshake.

## 8. Fault aggregation

Nguồn gồm matcher write deny, matcher read deny, write framing và context invalid. Top phải map metadata vào ba logical record inputs của register block.

Read/write records mang address, ID, LEN và SIZE từ immutable snapshots. Context record dùng ID, LEN và SIZE bằng 0. Khi `fw_drain_fsm` phát `w_framing_fault_valid` với code `4'b0110`, top ghép pulse với write-owner AWADDR/AWID/AWLEN/AWSIZE đang giữ để tạo `w_fault_event_*`. Write drain không nhận AWADDR hoặc AWSIZE.

## 9. Việc được chuẩn bị trước khi nhận đủ gói

### 9.1. Top port list

Có thể lập port list ngoài module RTL từ architecture docs: APB, DMA AXI, Matrix AXI, context và IRQ.

### 9.2. Stub library

Tạo stubs cho compile harness với default fail-secure, gắn nhãn simulation-only. Stub không được thay policy acceptance hoặc tạo evidence functional.

### 9.3. Integration testbench

Chuẩn bị DMA master driver hoặc nối DMA core thật, Matrix memory model, APB BFM, context driver, monitors và global timeout.

### 9.4. Assertions

Chuẩn bị assertion file cho isolation, owner, response source, payload stability, G3 và priority.

### 9.5. Traceability table

Map requirement sang module, unit test, integration test và expected evidence.

## 10. Quyết định chưa được phép khóa

- Không viết adapter final trước port freeze.
- Không đổi tên canonical `fw_apb_regs` và không tạo `fw_apb_slave` alias hoặc wrapper.
- Không hợp nhất owner state vào matcher hoặc mux; top sở hữu owner lifecycle.
- Không bỏ Stage 1 flags hoặc fault metadata để giảm cổng.
- Không bypass drain bằng cách trả DECERR ngay ở address channel.
- Không serialize read/write nếu AXI cho phép độc lập.
- Không tuyên bố zero-latency hay timing closure khi chưa synthesis/STA.
- Không dùng stubs trong regression sign-off.

## 11. Review checklist trước integration

### Dependency acceptance

- Từng module có version/source ID.
- Unit test commands chạy lại được.
- Port và reset notes đầy đủ.
- Known source mismatches hoặc blockers có owner và quyết định.

### Structural

- Một driver cho mỗi net.
- Không implicit net hoặc width mismatch.
- Không combinational loop READY.
- Tie-offs đúng architecture.
- Clock/reset thống nhất.

### Security behavior

- Reset default deny.
- Dynamic context priority đúng.
- Atomic policy snapshot.
- Most-restrictive decision.
- Denied traffic isolated.
- Lock và APB protection đúng.

### Protocol

- Address payload stable.
- G3 AW-before-W.
- Drain exact beats.
- Response ID và last đúng.
- Progress assumptions được phân biệt với timeout testbench.

### Fault and IRQ

- Mọi source đến logger.
- Collision count/priority đúng.
- First-fault metadata stable.
- Read/write record giữ đúng ID/LEN/SIZE; context dùng ID/LEN/SIZE bằng 0.
- Framing fault dùng retained write-owner metadata, không dùng live AW bus.
- W1C cùng hardware event đúng.
- IRQ equation đúng.

## 12. Integration test tối thiểu

| ID | Tình huống |
|---|---|
| TOP-01 | Reset và no-match default deny |
| TOP-02 | Static region allowed read/write |
| TOP-03 | Dynamic source read và destination write |
| TOP-04 | Reverse dynamic permissions bị deny |
| TOP-05 | Context done same-cycle new address |
| TOP-06 | Auto-context disable same-cycle allocation/address snapshot |
| TOP-07 | Overlap most-restrictive deny |
| TOP-08 | Profile, overflow và 4 KiB deny |
| TOP-09 | Denied write exact drain và B response |
| TOP-10 | Denied read exact dummy beats |
| TOP-11 | Allowed path under random backpressure |
| TOP-12 | Denied traffic không xuất hiện ở Matrix |
| TOP-13 | Read/write/context fault collision |
| TOP-14 | Lock, W1C và IRQ |
| TOP-15 | Simultaneous read/write mixed owners |
| TOP-16 | DMA core end-to-end through Firewall |
| TOP-17 | Re-enable auto context không phục hồi dynamic range cũ |

## 13. Rủi ro khi bắt đầu sớm

| Rủi ro | Hậu quả |
|---|---|
| Port guess | Adapter churn và nối nhầm semantics |
| Priority không explicit | Same-cycle TOCTOU |
| Stubs bị giữ lại | False PASS |
| Owner inference từ live ACL | Data route đổi giữa burst |
| Fault fields bị hard-code | Software log sai |
| Unit failures che trong top | Debug rất khó |

## 14. Mẫu phiếu khởi động integration

```text
Address slice accepted version:
Context tracker accepted version:
Data path mux accepted version:
Student packages 01 to 04 accepted versions:
Drain wrapper port mapping:
Canonical interface conformance:
Top port matrix reviewed:
Unit regression baseline:
Integration branch or workspace:
First integration test:
```

## 15. Điều kiện chuyển sang `READY_NOW`

- Bốn gói sinh viên được accepted.
- Ba module Firewall `READY_NOW` có unit evidence.
- `fw_drain_fsm` wrapper và hai module con có source accepted cùng port mapping.
- Mọi source nộp khớp module names và interface contract đã chốt.
- Port matrix được review.
- Stubs có kế hoạch thay thế và không nằm trong sign-off path.
- Integration testbench tối thiểu compile trước với các stub được ghi nhãn rõ.

## 16. Nguồn chuẩn

- Toàn bộ `DMA-controller/docs/architecture/` theo `document_manifest.md`
- `DMA-controller/docs/architecture/architecture_overview.md`
- `DMA-controller/docs/architecture/detailed_architecture_diagram.md`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/signal_list.csv`
- `DMA-controller/docs/architecture/verification_test_plan.md`
- Bốn guides trong `DMA-controller/docs/tutorials/firewall-rtl/student-guides/`
