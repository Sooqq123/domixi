# Thiết kế `fw_context_tracker`

> Phân loại: `READY_NOW`. Module có thể được thiết kế và unit test bằng sideband driver, ACL snapshot observer và fault logger stub, không phụ thuộc bài nộp của sinh viên.

## 1. Mục tiêu và sản phẩm

`fw_context_tracker` biến sideband descriptor từ DMA thành hai ACL region động:

- Region 4 cho phép đọc nguồn;
- Region 5 cho phép ghi đích.

Quyền chỉ tồn tại trong một lần DMA chạy, được thu hồi đồng bộ khi `dma_ctx_done` đến, và không bị phần mềm sửa qua APB.

Sản phẩm cần có state machine one-shot, validator range, register cho hai dynamic regions, fault event cho context lỗi và testbench chứng minh priority.

## 2. Giao diện logic

### Input từ DMA

- `dma_ctx_valid`
- `dma_ctx_src_addr[31:0]`
- `dma_ctx_dst_addr[31:0]`
- `dma_ctx_byte_len[31:0]`
- `dma_ctx_done`

### Input điều khiển từ Firewall registers

- `auto_ctx_en`
- event hoặc next-value chỉ ra accepted APB write làm `AUTO_CTX_EN` chuyển từ 1 xuống 0

### Output sang ACL matcher

- Region 4 base, limit, active và thuộc tính read-only;
- Region 5 base, limit, active và thuộc tính write-only;
- fixed `SECURE_ONLY=1`, `PRIV_ONLY=1`, `MID=0`, `MID_MASK=0`.

### Output sang fault logger

- context fault valid;
- code `BOUND_ERR`;
- offending address;
- ID cố định 0;
- LEN cố định 0 và SIZE cố định 0 khi top/register logger tạo `FAULT_INFO`.

## 3. State và one-shot arming

Một mô hình rõ ràng gồm:

| State | Ý nghĩa |
|---|---|
| `CTX_IDLE_ARMED` | Chưa active và được phép nhận một valid mới |
| `CTX_ACTIVE` | Region 4/5 đang active |
| `CTX_WAIT_VALID_LOW` | Đã done hoặc reject, chờ nguồn hạ valid trước lần nhận mới |

Có thể biểu diễn bằng state enum hoặc `active` cộng `valid_armed`. Điều bắt buộc là valid giữ cao nhiều chu kỳ chỉ được chấp nhận một lần. Sau done hoặc descriptor lỗi, nguồn phải hạ `dma_ctx_valid` rồi mới được arm lại.

Allocation chỉ được chấp nhận khi `auto_ctx_en=1`. Khi accepted APB write làm `AUTO_CTX_EN` chuyển từ 1 xuống 0, tracker phải xóa đồng bộ Region 4/5 và chặn allocation mới. Re-enable không tự phục hồi descriptor đã bị xóa; cần một sideband acceptance mới sau khi nguồn hoàn thành quy tắc re-arm.

## 4. Validation

Context hợp lệ khi:

```text
src[1:0] == 0
dst[1:0] == 0
len[1:0] == 0
len != 0
src + len không vượt 2^32
dst + len không vượt 2^32
```

Giới hạn inclusive:

```text
src_limit = src + len - 1
dst_limit = dst + len - 1
```

Tính bằng ít nhất 33 bit. Nếu bất kỳ kiểm tra nào sai, cả hai region phải inactive và phát đúng một context fault record. Không được mở một region nếu region còn lại lỗi.

## 5. Dynamic region contract

| Region | Base/limit | Read | Write | Secure | Privileged | MID |
|---|---|---:|---:|---:|---:|---:|
| 4 | Source range | 1 | 0 | 1 | 1 | 0 mask 0 |
| 5 | Destination range | 0 | 1 | 1 | 1 | 0 mask 0 |

`MID_MASK=0` theo baseline nghĩa là exact match toàn bộ ID. Không suy diễn ngược rằng mask 0 là wildcard. Matcher và register map phải dùng cùng định nghĩa mask canonical.

Region 4/5 là hardware-owned và APB read-only. `FW_LOCK` không ngăn context tracker cập nhật hoặc thu hồi chúng.

## 6. Priority cùng cạnh

Kiến trúc yêu cầu thứ tự tổng quát:

```text
dma_ctx_done
  > nhận dma_ctx_valid hợp lệ
  > APB config write
  > ACL snapshot
```

`AUTO_CTX_EN:1->0` là trường hợp APB đặc biệt có semantics revoke. Theo context FSM và verification contract, event disable này phải xóa dynamic regions ở chính cạnh write được chấp nhận và thắng allocation mới. Nếu `done` hoặc disable event trùng với `valid`, revoke thắng. Region phải inactive đối với ACL snapshot của cạnh đó. Không được đóng context cũ rồi mở context mới trong cùng cạnh.

Một allocation hợp lệ phải có hiệu lực cho snapshot cùng cạnh sau khi priority được áp dụng. Điều này thường cần top-level next-state wiring hoặc một interface `effective_*` rõ ràng. Không chỉ xuất register state cũ nếu contract yêu cầu transaction cùng cạnh nhìn thấy allocation mới.

## 7. Fault event

Descriptor invalid tạo một pulse event, không phải level theo `dma_ctx_valid`. Metadata address theo thứ tự:

1. Source nếu source alignment hoặc overflow lỗi.
2. Destination nếu source hợp lệ nhưng destination lỗi.
3. Source cho zero length hoặc length alignment lỗi, trừ khi canonical fault policy quy định khác.

`ctx_fault_event_code` chứa `BOUND_ERR`. `ctx_fault_event_id` bằng 0. Context record không biểu diễn một AXI burst, vì vậy logger dùng LEN bằng 0 và SIZE bằng 0; không chuyển `dma_ctx_byte_len` thành `AxLEN`.

## 8. Reset

Reset phải:

- hạ active của Region 4/5;
- xóa base/limit hoặc đưa về 0;
- xóa fault pulse;
- arm khả năng nhận context đầu tiên sau reset.

Register block reset `AUTO_CTX_EN=1`. Tracker vẫn không được tự mở quyền từ descriptor chưa được chấp nhận sau reset.

## 9. Thiết kế từ đầu theo mốc

### Mốc 1: Validator thuần

Viết function tính hai limit bằng 33 bit và trả validity. Test zero, misalignment, end đúng `0xFFFFFFFF` và overflow.

### Mốc 2: Allocation

Từ idle armed, đưa valid một chu kỳ. Kiểm hai region active, range đúng và permission cố định.

### Mốc 3: One-shot

Giữ valid cao nhiều chu kỳ. Đếm allocation và fault pulse, mỗi thứ tối đa một lần cho một lần arm.

### Mốc 4: Revoke

Phát done khi active. Kiểm active hạ theo contract, payload không còn được matcher coi hợp lệ và valid phải hạ trước lần mới. Lặp lại với accepted disable event và kiểm re-enable không phục hồi range cũ.

### Mốc 5: Priority

Thử done cùng valid, allocation cùng ACL snapshot request và invalid valid cùng các event khác. Dùng observer trên effective region state.

### Mốc 6: Fault event

Tiêm từng lỗi, kiểm một pulse, code và address. Không mở region.

## 10. Test matrix

| ID cục bộ | Tình huống | Expected |
|---|---|---|
| CTX-01 | Reset | Region 4/5 inactive, armed |
| CTX-02 | Context hợp lệ | Cả hai active, range inclusive đúng |
| CTX-03 | Valid giữ cao | Chỉ một acceptance |
| CTX-04 | Source hoặc destination misaligned | Không active, một BOUND fault |
| CTX-05 | Length 0 hoặc misaligned | Không active, một BOUND fault |
| CTX-06 | End đúng `0xFFFFFFFF` | Hợp lệ |
| CTX-07 | 33-bit overflow | Reject |
| CTX-08 | Done | Revoke cả hai, done thắng |
| CTX-09 | Done cùng valid | Không reallocate cùng cạnh |
| CTX-10 | `AUTO_CTX_EN:1->0` khi active | Xóa Region 4/5 tại cạnh accepted write |
| CTX-11 | Disable cùng valid mới | Không allocate |
| CTX-12 | Re-enable | Không tự phục hồi descriptor cũ |
| CTX-13 | Valid mới chưa hạ sau done | Bị bỏ qua |
| CTX-14 | Hạ valid rồi đưa lần mới | Allocation mới được nhận |
| CTX-15 | `FW_LOCK=1` ở môi trường | Context vẫn allocate/revoke bình thường khi auto context còn enabled |

## 11. Checker hữu ích

- Region 4 active bằng Region 5 active trong baseline atomic pair.
- Khi active, Region 4 read-only và Region 5 write-only.
- Limit không nhỏ hơn base cho context hợp lệ.
- Context fault kéo theo hai active bằng 0.
- Một armed interval có tối đa một accept.
- Done kéo theo effective active bằng 0 cho ACL snapshot ưu tiên sau nó.
- Accepted auto-context disable kéo theo effective active bằng 0 và chặn allocation cùng cạnh.
- Dynamic base/limit không đổi do APB data write trực tiếp hoặc lock.

## 12. Điểm cần tránh

- Nhận `dma_ctx_valid` mỗi chu kỳ nó giữ cao.
- Tính limit bằng 32 bit rồi bỏ sót wrap.
- Mở source region nhưng bỏ destination do lỗi, hoặc ngược lại.
- Cho APB ghi trực tiếp base/limit của Region 4/5, hoặc cho `FW_LOCK` chặn hardware update.
- Bỏ qua semantics clear của `AUTO_CTX_EN:1->0`.
- Tự phục hồi descriptor cũ khi `AUTO_CTX_EN` được bật lại.
- Để ACL snapshot thấy state cũ khi done cùng cạnh.
- Ghi fault event dạng level và làm counter tăng nhiều lần.
- Chuyển `dma_ctx_byte_len` thành `AxLEN` hoặc dùng SIZE khác 0 cho context record.

## 13. Rủi ro và cách đóng

| Rủi ro | Kiểm tra |
|---|---|
| TOCTOU do priority sai | Same-cycle done/allocation/snapshot tests |
| Disable không revoke | Same-cycle accepted write và active-region observer |
| Reaccept valid giữ cao | One-shot counter |
| Arithmetic wrap | 33-bit boundary vectors |
| Permission đảo source/destination | Directed read/write ACL observer |
| Context metadata bị hiểu như AXI burst | Checker yêu cầu ID, LEN và SIZE đều bằng 0 |

## 14. Tiêu chí hoàn thành

- Validator PASS mọi boundary.
- Allocation và revoke atomic cho cả hai region.
- Valid one-shot được chứng minh.
- Priority cùng cạnh khớp V2.4.1.
- Disable auto context xóa quyền động và re-enable không tự restore.
- Fault pulse, code, address và encoding ID/LEN/SIZE bằng 0 đúng contract.
- Module unit test không cần `fw_apb_regs` hoặc matcher thật.

## 15. Lộ trình tự triển khai

Viết validator và test trước. Sau đó hiện thực state `armed/active`, chưa nối ACL. Khi one-shot ổn định, thêm dynamic region fields và observer. Cuối cùng thêm priority same-cycle và fault event. Đừng ghép APB write path vào module vì Region 4/5 thuộc hardware.

## 16. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.5 và 5.3
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/fsm_specification.md`, context lifecycle
- `DMA-controller/docs/architecture/signal_list.csv`, `DYN_CONTEXT` và context fault
- `DMA-controller/docs/architecture/register_map.csv`, Region 4/5
- `DMA-controller/docs/architecture/verification_test_plan.md`
