# Chuẩn bị thiết kế `fw_write_drain`

> Phân loại: `WAIT_FOR_STUDENTS`. Đây là module con `fw_write_drain` của Gói sinh viên 03. Canonical `fw_drain_fsm` là wrapper instantiate module này cùng `fw_read_drain`.

## 1. Vì sao chưa thiết kế tiếp

Sinh viên 03 đang phụ trách FSM nuốt W beats của một denied AW và tạo B response cục bộ. Viết một write drain khác sẽ thay bài nộp và tạo xung đột khi ghép với read drain.

Trong thời gian chờ, chỉ chuẩn bị port adapter, scoreboard, owner checker và tiêu chí review. Không hiện thực FSM cuối cùng.

## 2. Mục tiêu hành vi

Sau khi nhận một denied write request đã chốt:

1. Lưu `AWID`, `AWLEN` và error mode.
2. Nhận và hủy đúng `AWLEN+1` W handshakes.
3. Kiểm `WLAST` đúng beat cuối dự kiến.
4. Không kết thúc sớm nếu WLAST đến sớm.
5. Sau đủ beat, phát một B response giữ ổn định đến B handshake.
6. Trả `BID` đã chốt và `BRESP=DECERR`, hoặc OKAY theo honeypot mode.
7. Phát framing fault pulse nếu WLAST sai vị trí.

## 3. Gói đầu vào bắt buộc từ sinh viên 03

| Hạng mục | Yêu cầu |
|---|---|
| RTL | Module `fw_write_drain.v` compile độc lập |
| TB | Self-checking với W gaps, B stall và WLAST errors |
| Port list | Request snapshot, W/B handshake, fault pulse, busy/owner |
| State note | IDLE, SINK, RESP và illegal recovery |
| Counter note | Width, expected beats, update chỉ ở handshake |
| Logs | Directed suite PASS và timeout behavior |
| Waves | LEN 0, LEN 15, early/missing WLAST, B stall |
| Integration note | Bảng port mapping từ `fw_write_drain` vào wrapper `fw_drain_fsm` |

## 4. Interface cần đối chiếu

Canonical signal list có:

- `acl_w_fault`, `acl_w_id`, `acl_w_len`, `acl_w_err_mode`;
- `w_drain_wvalid`, `w_drain_wlast`, `w_drain_bready`;
- `w_drain_wready`, `w_drain_bvalid`, `w_drain_bid`, `w_drain_bresp`.

Framing event phải nối về fault logger qua integration contract. Nếu bài nộp dùng tên khác, adapter cần được review, không sửa canonical im lặng.

Write drain phát `w_framing_fault_valid` trong đúng một chu kỳ cho mỗi early hoặc missing-final WLAST handshake. `w_framing_fault_code` bằng `4'b0110`, tức `WRITE_ERR | PROT_ERR`. Module không nhận `AWADDR` hoặc `AWSIZE`; `dma_bus_firewall` giữ các field đó trong immutable write-owner metadata và làm giàu framing pulse trước logger.

## 5. FSM contract

### `IDLE`

Không nhận W và không phát B. Chỉ nhận denied request khi không có owner active. Chốt metadata và đặt expected beat count bằng `AWLEN+1`.

### `SINK`

`WREADY=1` theo khả năng local drain. Counter chỉ tăng khi `WVALID && WREADY`. Expected final là handshake thứ `AWLEN+1`.

WLAST framing:

- WLAST trước expected final: set protocol fault, tiếp tục sink.
- Expected final không có WLAST: set protocol fault, vẫn kết thúc sau beat count.
- WLAST đúng final: bình thường.

Không bịa beat khi master không phát WVALID. Liveness phụ thuộc AXI progress assumption.

### `RESP`

Giữ `BVALID`, `BID`, `BRESP` ổn định đến `BREADY`. Chỉ sau handshake mới clear owner và về IDLE.

## 6. Việc được chuẩn bị trước khi nhận gói

- Driver cấp denied owner với ID/LEN/mode biết trước.
- W driver có khoảng trống và WLAST pattern tùy chọn.
- BREADY random stall driver.
- Scoreboard đếm handshake, không đếm chu kỳ.
- Stability monitor cho B payload.
- Matrix isolation monitor bảo đảm denied write không đi xuống Matrix.
- Port map từ `fw_write_drain` sang wrapper canonical `fw_drain_fsm`.

## 7. Quyết định chưa được phép khóa

- Không đưa write state vào wrapper; wrapper chỉ instantiate và nối `fw_write_drain`.
- Không chuyển early WLAST thành kết thúc sớm.
- Không thêm transaction timeout tạo B response khi chưa nhận đủ W beats.
- Không clear owner khi BVALID lên.
- Không bỏ error mode hoặc hard-code mọi response khi contract còn mode.
- Không nối trực tiếp live AW fields thay vì snapshot.
- Không thêm AWADDR hoặc AWSIZE vào write drain; hai field này thuộc write-owner metadata ở top.

## 8. Checklist review

### Handshake và counting

- LEN 0 tạo đúng một W handshake.
- LEN 15 tạo đúng 16 handshakes.
- Counter không đổi khi WVALID thấp.
- Counter không đổi nếu WREADY thấp.
- Không nhận W ngoài SINK.

### Framing

- Early WLAST không phát B sớm.
- Missing final WLAST vẫn tạo B sau đủ beat và log protocol error.
- Fault event là pulse hoặc record acceptance đúng contract.
- `w_framing_fault_code` giữ `4'b0110` khi pulse valid.

### Response

- BID bằng denied AWID snapshot.
- BRESP theo mode snapshot.
- B payload ổn định dưới stall.
- Owner clear chỉ sau B handshake.

### Robustness

- Reset giữa SINK và RESP về idle an toàn.
- Request mới bị chặn khi owner active.
- Illegal state recovery không phát response giả.
- Testbench có timeout nhưng RTL không bịa timeout response.

## 9. Acceptance tests

| ID | Tình huống |
|---|---|
| WD-01 | Reset và request LEN 0 |
| WD-02 | LEN 1 đến 15 sweep |
| WD-03 | WVALID gaps |
| WD-04 | Early WLAST ở nhiều vị trí |
| WD-05 | Missing final WLAST |
| WD-06 | Correct WLAST final |
| WD-07 | BREADY stall dài |
| WD-08 | DECERR và honeypot mode |
| WD-09 | Request mới khi busy |
| WD-10 | Reset trong SINK/RESP |
| WD-11 | Random W gaps và B stalls |
| WD-12 | Matrix isolation integration monitor |

## 10. Rủi ro khi bắt đầu sớm

| Rủi ro | Hậu quả |
|---|---|
| Đặt write state trong wrapper | Mất unit boundary và khó tái chạy test Gói 03 |
| Đếm cycle thay handshake | Sai khi WVALID có gap |
| B sớm do WLAST | AXI transaction bị cắt không hợp lệ |
| Timeout trong RTL | Tạo response cho transaction chưa hoàn chỉnh |
| BID lấy live | Response sai transaction |

## 11. Mẫu tiếp tục sau bàn giao

```text
Package: student-03 write drain
RTL boundary:
TB identifier:
LEN sweep result:
WLAST framing result:
B stability result:
Canonical port mismatches:
Wrapper port mapping:
Acceptance decision:
```

## 12. Điều kiện chuyển sang `READY_NOW`

- Gói RTL/TB compile và PASS.
- Exact beat accounting được chứng minh cho LEN 0 đến 15.
- WLAST error behavior khớp canonical.
- B response stable và owner lifecycle đúng.
- Wrapper `fw_drain_fsm.v` instantiate module mà không sửa semantics unit.
- `w_framing_fault_valid` và code `4'b0110` nối được tới top; AWADDR/AWSIZE vẫn do top giữ.

## 13. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.4
- `DMA-controller/docs/architecture/fsm_specification.md`, write drain FSM
- `DMA-controller/docs/architecture/signal_list.csv`, `DRAIN_INTERFACE`
- `DMA-controller/docs/architecture/assumptions_and_tbd.md`, progress assumptions
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/03_fw_write_drain_lab_guide.md`
