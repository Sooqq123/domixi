# Đề xuất đóng khoảng trống giao diện Firewall

> Trạng thái: `PROPOSED`, chưa phải hợp đồng kiến trúc chuẩn. Tài liệu này chỉ trở thành căn cứ cập nhật baseline sau khi chủ dự án phê duyệt riêng.

## Kết luận

Bốn khoảng trống giao diện được xử lý bằng bốn quyết định duy nhất:

1. Stage 1 xuất riêng cờ profile, overflow và crossing 4 KiB cho AW và AR.
2. Read và write fault record mang đầy đủ ID, LEN và SIZE; context fault dùng giá trị 0 cho ba trường này.
3. `fw_apb_regs` là tên module canonical duy nhất; `fw_apb_slave` không tạo thành module hoặc wrapper.
4. `fw_drain_fsm` là wrapper canonical chứa hai module con độc lập `fw_write_drain` và `fw_read_drain`.

Trạng thái triển khai phải phản ánh đúng cây source: khi chưa có file Firewall RTL, status là `MISSING / BLOCKED_FIREWALL_RTL`, không phải partial draft.

Các tên `dma_top`, `dma32` và `fifo32` không thuộc baseline RTL. Không tạo source hoặc compatibility wrapper cho các tên này khi chưa có consumer hiện hành.

## Phạm vi

Đề xuất này định nghĩa candidate interface và ranh giới module để chủ dự án cùng nhóm sinh viên tự viết Firewall RTL. Nó không tạo RTL, testbench, assertion, script hoặc adapter. Nó không sửa các tài liệu trong `DMA-controller/docs/architecture/`, giáo trình Firewall, hướng dẫn sinh viên hoặc PDF.

Nguồn chuẩn hiện hành vẫn có quyền ưu tiên cho đến khi đề xuất được phê duyệt và phát hành thành một baseline mới.

## Quyết định 1: Cờ lỗi Stage 1

`fw_axi_address_slice` phải chốt ba cờ lỗi độc lập cho mỗi address channel. `fw_acl_matcher` nhận các cờ này cùng snapshot và không tính lại burst arithmetic từ live AXI input.

### Cổng AW

| Signal | Width | Reset | Producer | Consumer | Điều kiện |
|---|---:|---:|---|---|---|
| `pipe_s1_aw_profile_err` | 1 | 0 | `fw_axi_address_slice` | `fw_acl_matcher` | AW không thỏa constrained burst profile |
| `pipe_s1_aw_overflow_err` | 1 | 0 | `fw_axi_address_slice` | `fw_acl_matcher` | Extended last byte vượt `0xFFFF_FFFF` |
| `pipe_s1_aw_4kb_err` | 1 | 0 | `fw_axi_address_slice` | `fw_acl_matcher` | Start và last byte khác page 4 KiB |

### Cổng AR

| Signal | Width | Reset | Producer | Consumer | Điều kiện |
|---|---:|---:|---|---|---|
| `pipe_s1_ar_profile_err` | 1 | 0 | `fw_axi_address_slice` | `fw_acl_matcher` | AR không thỏa constrained burst profile |
| `pipe_s1_ar_overflow_err` | 1 | 0 | `fw_axi_address_slice` | `fw_acl_matcher` | Extended last byte vượt `0xFFFF_FFFF` |
| `pipe_s1_ar_4kb_err` | 1 | 0 | `fw_axi_address_slice` | `fw_acl_matcher` | Start và last byte khác page 4 KiB |

Hai cờ 4 KiB đã có trong `signal_list.csv`. Bốn cờ profile và overflow là phần cần bổ sung khi đề xuất được nâng thành baseline.

### Profile error

`profile_err` bằng 1 nếu bất kỳ điều kiện nào sau sai:

```text
AxBURST == 2'b01
AxSIZE  == 3'b010
AxADDR[1:0] == 2'b00
AxLEN <= 8'd15
```

MID và PROT không thuộc `profile_err`. `fw_acl_matcher` kiểm MID theo region whitelist/mask và kiểm PROT theo region security policy. Cách tách này giữ fault mapping hiện hành:

- profile, overflow hoặc crossing 4 KiB tạo channel error cộng `BOUND_ERR`;
- MID mismatch tạo channel permission error;
- PROT mismatch tạo channel permission error cộng `PROT_ERR`.

Profile errors vẫn bị deny và log khi `FW_EN=0`.

### Arithmetic và stability

Stage 1 tính range bằng arithmetic mở rộng:

```text
beats      = zero_extend(AxLEN, 9) + 1
bytes_beat = 1 << AxSIZE
last_ext   = zero_extend(AxADDR) + beats * bytes_beat - 1
last_byte  = last_ext[31:0]
overflow   = OR-reduction của mọi bit trên bit 31 trong last_ext
cross_4kb  = overflow OR (AxADDR[31:12] != last_byte[31:12])
```

Overflow và crossing 4 KiB được phép cùng bằng 1. Một range vượt không gian địa chỉ 32 bit cũng đã đi qua ranh giới page cuối của không gian địa chỉ.

Descriptor và ba cờ lỗi phải được chốt trong cùng một elastic slot. Khi `pipe_s1_*valid=1` và `pipe_s1_*ready=0`, toàn bộ payload và các cờ giữ ổn định.

### Tiêu chí chấp nhận

- Mỗi accepted AW hoặc AR tạo đúng một snapshot.
- Profile, overflow và 4 KiB errors có directed test riêng.
- `FW_EN=0` không làm profile-invalid request được allow.
- Payload và cờ ổn định dưới backpressure.
- MID và PROT không bị gộp vào `profile_err`.

## Quyết định 2: Fault record LEN và SIZE

`fw_apb_regs` phải nhận LEN và SIZE cùng mỗi read hoặc write fault event. Các field được chốt nguyên tử với valid, code, address và ID.

### Read fault record

| Signal | Width | Reset | Nội dung |
|---|---:|---:|---|
| `r_fault_event_valid` | 1 | 0 | Một read fault record hợp lệ |
| `r_fault_event_code` | 4 | 0 | Bitmask READ, WRITE, PROT, BOUND |
| `r_fault_event_addr` | 32 | 0 | Start address của AR snapshot |
| `r_fault_event_id` | 4 | 0 | ARID snapshot |
| `r_fault_event_len` | 8 | 0 | ARLEN snapshot |
| `r_fault_event_size` | 3 | 0 | ARSIZE snapshot |

### Write fault record

| Signal | Width | Reset | Nội dung |
|---|---:|---:|---|
| `w_fault_event_valid` | 1 | 0 | Một write fault record hợp lệ |
| `w_fault_event_code` | 4 | 0 | Bitmask READ, WRITE, PROT, BOUND |
| `w_fault_event_addr` | 32 | 0 | Start address của AW snapshot |
| `w_fault_event_id` | 4 | 0 | AWID snapshot |
| `w_fault_event_len` | 8 | 0 | AWLEN snapshot |
| `w_fault_event_size` | 3 | 0 | AWSIZE snapshot |

Write framing fault từ drain phải dùng metadata đã chốt từ denied AW request. Nó không được đọc live AW bus khi WLAST mismatch được phát hiện.

`dma_bus_firewall` giữ `AWADDR`, `AWID`, `AWLEN` và `AWSIZE` trong write-owner metadata từ khi denied decision được nhận đến B handshake. Write drain chỉ phát:

| Signal | Width | Nội dung |
|---|---:|---|
| `w_framing_fault_valid` | 1 | Xung một chu kỳ khi WLAST khác vị trí dự kiến |
| `w_framing_fault_code` | 4 | `WRITE_ERR` cộng `PROT_ERR` |

Top dùng pulse này cùng write-owner metadata bất biến để tạo `w_fault_event_*`. Cách này giữ write drain độc lập với address và size, đồng thời bảo đảm framing fault vẫn có metadata đúng nếu phần mềm đã mở lại first-fault capture trong khi drain đang hoạt động.

Matcher phải chuyển `AxLEN` và `AxSIZE` từ Stage 1 snapshot vào read/write deny metadata. Nó không đọc lại live AW hoặc AR bus.

### Context fault record

Context fault tiếp tục dùng:

- `ctx_fault_event_valid`;
- `ctx_fault_event_code`;
- `ctx_fault_event_addr`.

Khi context record được chọn làm first fault:

```text
FAULT_MID  = 4'h0
FAULT_LEN  = 8'h00
FAULT_SIZE = 3'b000
FAULT_TYPE = 1'b0
FAULT_SOURCE = 2'b10
```

Không chuyển `dma_ctx_byte_len` thành `AxLEN`, vì context descriptor không đại diện một AXI burst cụ thể.

### Collision và first-fault capture

Ba record read, write và context vẫn độc lập. Khi nhiều record cùng chu kỳ:

- `FAULT_STATUS` OR mọi fault code;
- `FAULT_COUNT` tăng theo số record được nhận và bão hòa tại `16'hFFFF`;
- first-fault metadata chọn `context > write > read`;
- metadata của record được chọn gồm address, ID, LEN, SIZE, type, source và code;
- hardware-set thắng software W1C cùng cạnh.

### Tiêu chí chấp nhận

- Read fault ghi đúng ARID, ARLEN và ARSIZE.
- Write fault ghi đúng AWID, AWLEN và AWSIZE.
- Write framing fault giữ metadata của AW snapshot.
- Write framing pulse được top làm giàu bằng write-owner metadata, không mở rộng datapath của drain bằng AWADDR hoặc AWSIZE.
- Context fault ghi ID, LEN và SIZE bằng 0, source bằng Context.
- Three-event collision giữ đúng priority và tăng count 3.
- Fault event sau first capture không ghi đè metadata cho đến khi capture được mở lại theo register contract.

## Quyết định 3: Tên module APB Firewall

Tên canonical duy nhất là:

```text
file:   fw_apb_regs.v
module: fw_apb_regs
```

Module sở hữu APB4 access classification, register state, static region configuration, dynamic region readback, fault logger và security IRQ.

`fw_apb_slave` chỉ là tên mô tả đã xuất hiện trong prose. Không tạo `fw_apb_slave.v`, không tạo alias và không tạo compatibility wrapper. Không có consumer hiện hành yêu cầu tên này.

Khi đề xuất được nâng thành baseline, mọi vị trí prose dùng `fw_apb_slave` để chỉ register block phải đổi thành `fw_apb_regs`. Historical documents không bị viết lại; chúng được giữ để truy vết.

### Tiêu chí chấp nhận

- Production RTL manifest chỉ có `fw_apb_regs.v` cho APB Firewall.
- Top instantiate đúng `fw_apb_regs` một lần.
- Không có hai module cùng sở hữu APB decode hoặc register state.
- Gói sinh viên 01 giữ nguyên tên `fw_apb_regs`.

## Quyết định 4: Ranh giới drain

Canonical drain dùng một wrapper và hai module con:

```text
fw_drain_fsm.v
|-- fw_write_drain.v
`-- fw_read_drain.v
```

`dma_bus_firewall` chỉ instantiate `fw_drain_fsm`. Wrapper nối clock, reset, request snapshots, data/response channels và fault event. Wrapper không tạo policy, không serialize read/write và không dùng chung state register giữa hai direction.

### Write drain ownership

`fw_write_drain` sở hữu:

- denied AWID, AWLEN và error mode snapshot;
- exact `AWLEN+1` W handshake counter;
- WLAST framing checker;
- BID, BRESP và BVALID stability;
- write owner release ở B handshake.

### Read drain ownership

`fw_read_drain` sở hữu:

- denied ARID, ARLEN và error mode snapshot;
- exact `ARLEN+1` R handshake counter;
- RID, RDATA, RRESP, RLAST và RVALID stability;
- read owner release ở final R handshake.

### Wrapper ownership

`fw_drain_fsm` chỉ sở hữu kết nối và adaptation giữa canonical interface với hai module con. Nếu cần busy hoặc accept signals, wrapper expose chúng theo owner contract đã chốt; nó không suy busy từ live response signals.

Gói sinh viên 03 và 04 phải được unit-review độc lập trước khi nối wrapper. Combined regression phải chứng minh read và write drain tiến triển đồng thời mà không chặn nhau.

### Tiêu chí chấp nhận

- Unit regression của hai module con PASS trước và sau khi ghép wrapper.
- Denied read và denied write hoạt động đồng thời.
- Read backpressure không chặn write progress.
- Write W gaps hoặc B stall không chặn read progress.
- Wrapper không tạo thêm response hoặc fault record.
- Top không instantiate trực tiếp hai module con.

## Xử lý tên lịch sử

Ba tên sau không tạo RTL:

| Tên | Kết luận |
|---|---|
| `dma_top` | Tên cũ đã được thay bằng `dma_controller`; không có compatibility wrapper |
| `dma32` | Tên artifact mô phỏng, không phải declaration module |
| `fifo32` | Tên artifact mô phỏng; FIFO canonical là `dma_fifo_latch` với depth baseline 32 |

Một tên chỉ được xem xét lại khi có consumer hiện hành, port contract và compatibility test cụ thể.

## Hiệu chỉnh trạng thái source

Cây source hiện hành không có `fw_axi_address_slice.v` hoặc Firewall RTL khác trong `DMA-controller/rtl/` hay thư mục `rtl/` ở repository root. Khi đề xuất được nâng thành baseline:

- `implementation_conformance_status.md` phải ghi Firewall RTL là `MISSING / BLOCKED_FIREWALL_RTL`;
- các dòng `REQ_FW_*` trong `requirements_traceability.csv` không được ghi `PARTIAL DRAFT` khi file được dẫn không tồn tại;
- trạng thái chỉ chuyển sang partial hoặc implemented sau khi source có revision, compile command và evidence truy xuất được;
- artifact `.vvp`, `.vcd` hoặc log cũ không thay thế source.

Đây là hiệu chỉnh tính trung thực của status, không phải yêu cầu tạo RTL sớm.

## Thứ tự áp dụng sau khi được duyệt

1. Bổ sung bốn Stage 1 signals vào candidate internal interface trước khi chốt port address slice và matcher.
2. Bổ sung bốn LEN/SIZE signals vào fault interface trước khi nghiệm thu Gói sinh viên 01 và 02.
3. Đồng bộ tên `fw_apb_regs` trước khi viết top integration.
4. Giữ Gói 03 và 04 độc lập; tạo wrapper sau khi cả hai gói qua unit review.
5. Chạy lại module-guide consistency review trước khi phát hành baseline mới.

Không đợi đến giai đoạn fix bug để đóng bốn quyết định này. Chúng là điều kiện đầu vào của thiết kế và integration, không phải lỗi implementation.

## Tài liệu cần cập nhật nếu đề xuất được phê duyệt

Việc cập nhật chỉ diễn ra trong một công việc riêng sau phê duyệt:

- `DMA-controller/docs/architecture/signal_list.csv`
- `DMA-controller/docs/architecture/architecture_overview.md`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/implementation_conformance_status.md`
- `DMA-controller/docs/architecture/requirements_traceability.csv`
- `DMA-controller/docs/architecture/document_manifest.csv`, nếu manifest yêu cầu thêm artifact
- các hướng dẫn trong `DMA-controller/docs/module-guides/` có nhắc interface gaps hoặc profile membership

Giáo trình, bốn hướng dẫn sinh viên và PDF không nằm trong lượt cập nhật này. Nếu tài liệu sinh viên cần điều chỉnh sau đó, phải mở một phạm vi riêng để không thay đổi bài thực hành ngầm.

## Nguồn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.2, 2.4, 5.1 đến 5.4
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/fsm_specification.md`
- `DMA-controller/docs/architecture/signal_list.csv`
- `DMA-controller/docs/architecture/register_map.csv`, `FAULT_INFO` và `FAULT_SOURCE`
- `DMA-controller/docs/architecture/requirements_traceability.csv`, `REQ_FW_01`, `REQ_FW_02`, `REQ_FW_10`, `REQ_FW_13`, `REQ_FW_14` và `REQ_FW_17`
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/01_fw_apb_regs_lab_guide.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/02_fw_acl_matcher_lab_guide.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/03_fw_write_drain_lab_guide.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/04_fw_read_drain_lab_guide.md`
