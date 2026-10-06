# Chuẩn bị thiết kế `fw_apb_regs`

> Phân loại: `WAIT_FOR_STUDENTS`. Module chờ Gói sinh viên 01: `fw_apb_regs` và testbench APB/fault logging tương ứng.

## 1. Vì sao chưa thiết kế tiếp

`fw_apb_regs` sở hữu phần lớn state cấu hình và state ghi lỗi của Firewall. Gói sinh viên 01 đang xác định chi tiết triển khai các semantics khó nhất như APB4 protection, RW1S lock, W1C có hardware-set ưu tiên, first-fault metadata và ba fault event đồng thời.

Nếu thiết kế một bản khác trước khi nhận gói, dự án sẽ có hai nguồn RTL cạnh tranh và rất dễ lệch ở priority hoặc port contract. Vì vậy nhóm này chỉ chuẩn bị interface review, checker, stub và tiêu chí nhận bàn giao. Không viết RTL thay thế cuối cùng.

## 2. Mục tiêu module sau khi được tiếp nhận

Module phải:

- cung cấp APB4 register interface 32 bit cho Firewall;
- reset ở trạng thái fail-secure với `FW_EN=1`;
- quản lý static Regions 0 đến 3 và 6 đến 7;
- chỉ đọc dynamic Regions 4 và 5 từ state hardware;
- thực hiện `FW_LOCK` RW1S một chiều;
- ghi fault status, count, timestamp và first-fault metadata;
- nhận độc lập read, write và context fault record cùng chu kỳ;
- phát `sec_irq` theo IRQ enable và sticky pending;
- từ chối APB access sai aperture, sai alignment hoặc sai protection.

## 3. Gói đầu vào bắt buộc từ sinh viên 01

Không chuyển module sang `READY_NOW` nếu thiếu bất kỳ mục cốt lõi nào sau:

| Hạng mục | Nội dung cần nhận |
|---|---|
| RTL | File `fw_apb_regs.v` hoặc tên đã được owner chấp thuận |
| Testbench | Self-checking TB có timeout và explicit PASS/FAIL |
| Port list | Hướng, width, reset value, producer và consumer của từng port |
| Register mapping | Đối chiếu từng offset với `register_map.csv` |
| Fault interface | Ba record read/write/context; read/write có code, address, ID, LEN, SIZE; context dùng ID/LEN/SIZE bằng 0 |
| Semantics note | RW1S, W1C, RO, reserved bits, hardware priority |
| Test log | Compiler command, simulator version, PASS marker |
| Wave evidence | Ít nhất lock, W1C cùng event, three-fault collision |
| Contract report | Đối chiếu đầy đủ các cổng `*_fault_event_id`, `*_fault_event_len` và `*_fault_event_size` với signal list |

Source nộp phải là text RTL có thể compile, không chỉ screenshot hoặc waveform.

## 4. Register contract phải đối chiếu

Các nhóm thanh ghi tối thiểu:

| Nhóm | Semantics cần xác nhận |
|---|---|
| `FW_CONTROL` | `FW_EN`, IRQ enable, `AUTO_CTX_EN`, error or honeypot mode theo map |
| `FW_LOCK` | Bit lock RW1S, chỉ reset cứng mới xóa |
| `FAULT_STATUS` | Sticky bitmask và IRQ pending W1C |
| Fault metadata | First-fault address, info, timestamp, source |
| Fault count | Saturating 16 bit, tăng theo số record accepted |
| Static regions | RW khi chưa lock, APB readback |
| Dynamic regions | RO, phản ánh context tracker |

Không dùng tên hoặc offset nhớ theo bài học nếu khác `register_map.csv`. CSV canonical thắng tài liệu diễn giải.

`FW_CONTROL` reset về `0x0000_000D`: `FW_EN=1`, `IRQ_EN=0`, `AUTO_CTX_EN=1`, `ERR_MODE=1`. Accepted write làm `AUTO_CTX_EN` chuyển từ 1 xuống 0 phải phát event hoặc effective next-value đủ rõ để context tracker xóa Region 4/5 tại chính cạnh đó. Bật lại không tự phục hồi dynamic descriptor cũ.

## 5. APB access contract

Một access được chấp nhận khi đồng thời:

```text
PSEL AND PENABLE
địa chỉ thuộc cửa sổ Firewall 256 byte
word-aligned
offset được map
PPROT là Secure và Privileged
quyền ghi của register cho phép
lock không cấm nhóm cấu hình được ghi
```

Module không expose `PSTRB`; baseline chỉ hỗ trợ full-word write. Access lỗi trả `PREADY=1`, `PSLVERR=1`, `PRDATA=0` và không tạo side effect. `PSLVERR` chỉ có ý nghĩa ở access phase.

## 6. Fault update contract

Ba record có thể đến cùng chu kỳ. Module cần phân biệt:

- status code: OR mọi code được nhận;
- count: tăng theo số record, bão hòa tại `16'hFFFF`;
- first-fault metadata: chỉ capture nếu chưa có fault, với priority `context > write > read` khi collision đầu tiên;
- IRQ pending: hardware-set thắng software W1C cùng cạnh.

Một phương trình khái niệm:

```text
sticky_next = (sticky_current AND NOT sw_clear) OR hw_set_mask
count_next  = saturating_add(count_current, accepted_record_count)
```

Không được suy luận count chỉ tăng một vì status chỉ có một bitmap.

Read record phải nhận `r_fault_event_id[3:0]`, `r_fault_event_len[7:0]` và `r_fault_event_size[2:0]`. Write record phải nhận `w_fault_event_id[3:0]`, `w_fault_event_len[7:0]` và `w_fault_event_size[2:0]`. Logger ghi LEN và SIZE vào `FAULT_INFO.FAULT_LEN` và `FAULT_INFO.FAULT_SIZE`. Với context record, ID, LEN và SIZE có giá trị 0; `dma_ctx_byte_len` không phải `AxLEN`.

## 7. Việc được chuẩn bị trước khi nhận gói

### 7.1. Port inventory

Tạo bảng producer/consumer từ `signal_list.csv`, register map và context tracker outputs. Dùng đúng width và tên canonical cho ID/LEN/SIZE của read/write record.

### 7.2. APB bus functional model

Chuẩn bị tasks read/write có setup, access, timeout và checker `PSLVERR`. BFM không phụ thuộc nội bộ DUT nên có thể tái sử dụng.

### 7.3. Reference model register

Tạo model ở testbench theo CSV để dự đoán readback, lock, W1C và RO. Model phải độc lập với cấu trúc RTL sinh viên.

### 7.4. Fault stimulus adapter

Tạo interface hoặc task khái niệm để phát read, write và context event. Adapter cuối chỉ nối sau khi port list được freeze.

### 7.5. Compile stub

Có thể tạo stub chỉ để top-level elaboration, mọi output về giá trị fail-secure. Stub phải được ghi nhãn rõ là không có chức năng và không được dùng làm evidence.

## 8. Quyết định chưa được phép khóa

- Không đổi tên canonical `fw_apb_regs` thành `fw_apb_slave` và không tạo wrapper alias.
- Không bỏ hoặc gộp các cổng LEN/SIZE đã được chốt trong fault contract.
- Không hợp nhất ba fault event thành một pulse trước khi review priority.
- Không thay first-fault bằng last-fault.
- Không cho lock chặn dynamic Region 4/5.
- Không giản lược APB protection bằng cách bỏ `PPROT`.
- Không coi `AUTO_CTX_EN` là bit cấu hình thụ động; cạnh disable có side effect thu hồi quyền động.
- Không sửa register offsets để khớp RTL nộp nếu RTL khác CSV.

## 9. Checklist review gói nộp

### Source và cấu trúc

- Module name, parameter và port compile độc lập.
- Không implicit net hoặc width truncation.
- Reset active-low đúng baseline.
- Không có latch ngoài chủ đích.

### APB

- Setup không tạo side effect.
- Access hợp lệ hoàn tất với `PREADY=1`.
- Invalid aperture, alignment, offset và protection trả lỗi.
- Read-only write và locked write trả lỗi, state không đổi.
- Reserved bits đọc 0 và ghi bị bỏ qua đúng contract.

### Register state

- `FW_EN=1` sau reset.
- Toàn bộ `FW_CONTROL` reset về `0x0000_000D`.
- Lock chỉ set, không clear bằng software.
- Static và dynamic ownership đúng.
- Disable auto context phát handoff đủ để tracker xóa dynamic regions cùng cạnh.
- Readback từng field khớp CSV.

### Fault logging

- W1C không làm mất hardware event cùng cạnh.
- Three-fault collision OR code và tăng count 3.
- Count saturate, không wrap.
- Metadata đầu tiên không bị event sau ghi đè.
- Priority context, write, read đúng ở first collision.
- Read/write first-fault ghi đúng ID, LEN và SIZE; context first-fault ghi ba field này bằng 0.

### Evidence

- Log có command, seed nếu random, PASS marker.
- Wave có signal tên đọc được và event marker.
- Báo cáo liệt kê test ID, expected và observed.

## 10. Test acceptance tối thiểu

| ID | Nội dung |
|---|---|
| APBR-01 | Reset fail-secure |
| APBR-02 | Mọi mapped register readback |
| APBR-03 | Secure privileged legal write |
| APBR-04 | Non-secure và unprivileged rejection |
| APBR-05 | Aperture, alignment và unmapped rejection |
| APBR-06 | Lock RW1S và post-lock writes |
| APBR-07 | Dynamic region RO readback |
| APBR-08 | W1C từng bit và hardware collision |
| APBR-09 | Read, write, context simultaneous fault |
| APBR-10 | First-fault retention |
| APBR-11 | Saturating count |
| APBR-12 | IRQ enable, pending và clear |
| APBR-13 | `AUTO_CTX_EN:1->0` handoff và re-enable không restore |

## 11. Rủi ro khi bắt đầu sớm

| Rủi ro | Hậu quả |
|---|---|
| Bỏ LEN/SIZE đã chốt | `FAULT_INFO` không phản ánh immutable address snapshot |
| Tạo `fw_apb_slave` alias | Top có hai module cùng vai trò |
| Priority khác bài nộp | Lost fault hoặc metadata không deterministic |
| Tin unit PASS không review CSV | Register software contract bị lệch |
| Stub bị dùng như RTL thật | Hệ thống trông compile được nhưng không fail-secure |

## 12. Mẫu tiếp tục công việc sau bàn giao

Khi gói đến, tạo một phiếu review gồm:

```text
Package: student-01 fw_apb_regs
Commit or archive ID:
RTL file:
TB file:
Compile command:
PASS log:
Canonical mismatches:
Missing ports or metadata:
Required fixes:
Acceptance decision:
```

Đây là biểu mẫu kỹ thuật để lưu dấu vết bàn giao và quyết định tiếp nhận.

## 13. Điều kiện chuyển sang `READY_NOW`

- Có RTL và TB chạy được.
- Register offsets và semantics khớp canonical CSV.
- Port list fault logging khớp signal list, gồm ID/LEN/SIZE của read và write record.
- Directed tests quan trọng PASS.
- Mismatch đã được sửa hoặc có quyết định owner bằng văn bản.
- Module nộp dùng tên canonical `fw_apb_regs` và không tạo `fw_apb_slave` wrapper.

## 14. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 5.1, 5.3 và 5.4
- `DMA-controller/docs/architecture/register_map.csv`
- `DMA-controller/docs/architecture/memory_map.csv`
- `DMA-controller/docs/architecture/signal_list.csv`, `FAULT_LOGGING`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/01_fw_apb_regs_lab_guide.md`
