# Chuẩn bị thiết kế `fw_read_drain`

> Phân loại: `WAIT_FOR_STUDENTS`. Đây là module con `fw_read_drain` của Gói sinh viên 04. Canonical `fw_drain_fsm` là wrapper instantiate module này cùng `fw_write_drain`.

## 1. Vì sao chưa thiết kế tiếp

Sinh viên 04 đang phụ trách local R response cho denied AR. Thiết kế trước một bản khác sẽ thay bài nộp và có thể làm khác ở counter, RLAST stability hoặc owner clear.

Công việc hiện tại giới hạn ở test infrastructure, interface review và tiêu chí acceptance. Không hiện thực FSM cuối cùng.

## 2. Mục tiêu hành vi

Sau khi nhận denied read request:

- chốt `ARID`, `ARLEN` và error mode;
- tạo đúng `ARLEN+1` R handshakes;
- `RDATA=0` cho mọi beat trong baseline;
- `RRESP=DECERR`, hoặc OKAY trong honeypot mode;
- `RID` bằng snapshot ID;
- `RLAST=1` chỉ ở beat cuối;
- giữ toàn bộ payload ổn định khi `RVALID=1` và `RREADY=0`;
- clear owner chỉ sau final R handshake.

## 3. Gói đầu vào bắt buộc từ sinh viên 04

| Hạng mục | Yêu cầu |
|---|---|
| RTL | Module `fw_read_drain.v` compile độc lập |
| TB | Self-checking với RREADY stall ở mọi vị trí |
| Port list | Request snapshot, R handshake, owner/busy |
| State note | IDLE, GEN và illegal recovery |
| Counter note | Beat index và final-beat equation |
| Logs | LEN sweep và stress PASS |
| Waves | LEN 0, mid-burst stall, final-beat stall |
| Integration note | Bảng port mapping từ `fw_read_drain` vào wrapper `fw_drain_fsm` |

## 4. Interface cần đối chiếu

Canonical signal list có:

- `acl_r_fault`, `acl_r_id`, `acl_r_len`, `acl_r_err_mode`;
- `r_drain_rready`;
- `r_drain_rvalid`, `r_drain_rid`, `r_drain_rdata`, `r_drain_rresp`, `r_drain_rlast`.

Denied AR address không được forward xuống Matrix. Isolation monitor thuộc top/mux integration nhưng phải có test plan ngay từ unit handoff.

## 5. FSM contract

### `IDLE`

Outputs inactive. Nhận một denied request khi không active, chốt metadata và chuyển GEN. `ARLEN=0` nghĩa là một beat.

### `GEN`

Giữ `RVALID=1` trong khi transaction active. Beat index chỉ tăng khi `RVALID && RREADY`. `RLAST` là hàm của beat index hiện tại và latched LEN, vì vậy nếu final beat bị stall thì RLAST phải giữ 1 đến handshake.

Khi final handshake xảy ra, clear owner và trở lại IDLE. Không thêm bubble bắt buộc giữa beats nếu consumer luôn ready.

## 6. Progress và timeout

AXI cho phép RREADY bị hạ không giới hạn về mặt giao thức. Drain không được tăng counter khi stall và không được tự kết thúc theo wall-clock timeout.

Testbench vẫn phải có timeout để tránh simulation treo. Một test giữ RREADY=0 vĩnh viễn nên được phân loại là môi trường không thỏa progress assumption, không phải lý do RTL bịa completion.

## 7. Việc được chuẩn bị trước khi nhận gói

- Driver cấp denied AR snapshot.
- RREADY driver có directed và seeded-random stall.
- Scoreboard dự đoán `LEN+1` beat.
- Stability checker cho RID/RDATA/RRESP/RLAST.
- No-bubble metric khi RREADY luôn 1.
- Matrix isolation monitor.
- Port map từ `fw_read_drain` sang wrapper canonical `fw_drain_fsm`.

## 8. Quyết định chưa được phép khóa

- Không đưa read state vào wrapper; wrapper chỉ instantiate và nối `fw_read_drain`.
- Không tăng beat counter mỗi clock.
- Không pulse RLAST một chu kỳ nếu final beat chưa handshake.
- Không tạo một beat cho mỗi value LEN thay vì LEN+1.
- Không hard-code ID từ DMA profile thay vì trả latched request ID.
- Không thêm transaction timeout.
- Không clear owner khi RLAST lên mà chưa handshake.

## 9. Checklist review

### Beat accounting

- LEN 0 tạo một beat.
- LEN 15 tạo 16 beat.
- Counter chỉ đổi ở handshake.
- Không extra beat sau final.

### Payload

- RID bằng latched ID.
- RDATA bằng 0.
- RRESP theo latched mode.
- RLAST đúng final index.
- Mọi field ổn định dưới stall.

### Ownership

- Request mới bị chặn khi active.
- Owner clear ở final handshake.
- Reset hủy local response và về idle.
- Read drain không phụ thuộc write drain progress.

### Evidence

- Sweep toàn LEN 0 đến 15.
- Stall ở beat đầu, giữa và cuối.
- Random stall seed tái lập được.
- Timeout testbench và explicit PASS marker.

## 10. Acceptance tests

| ID | Tình huống |
|---|---|
| RD-01 | Reset và LEN 0 |
| RD-02 | LEN 1 đến 15 sweep |
| RD-03 | RREADY stall beat đầu |
| RD-04 | Stall giữa burst |
| RD-05 | Stall final beat |
| RD-06 | RREADY luôn 1, không bubble bắt buộc |
| RD-07 | DECERR mode |
| RD-08 | Honeypot OKAY mode |
| RD-09 | Request mới khi active |
| RD-10 | Reset trong GEN |
| RD-11 | Random stalls |
| RD-12 | Matrix isolation monitor |

## 11. Rủi ro khi bắt đầu sớm

| Rủi ro | Hậu quả |
|---|---|
| Counter theo cycle | Mất beat khi backpressure |
| RLAST không stable | Vi phạm AXI và owner kẹt |
| Đặt read state trong wrapper | Mất unit boundary và khó tái chạy test Gói 04 |
| Hard-code ID | Sai nếu Firewall profile mở rộng |
| Timeout RTL | Tạo response không theo handshake |

## 12. Mẫu tiếp tục sau bàn giao

```text
Package: student-04 read drain
RTL boundary:
TB identifier:
LEN sweep result:
Stability result:
No-bubble result:
Canonical port mismatches:
Wrapper port mapping:
Acceptance decision:
```

## 13. Điều kiện chuyển sang `READY_NOW`

- RTL/TB compile và PASS.
- Exact `LEN+1` behavior có sweep evidence.
- Payload stable ở final stall.
- Owner clear đúng final handshake.
- Wrapper `fw_drain_fsm.v` instantiate module mà không sửa semantics unit.
- Isolation test có kế hoạch nối ở mux/top.

## 14. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.4
- `DMA-controller/docs/architecture/fsm_specification.md`, read drain FSM
- `DMA-controller/docs/architecture/signal_list.csv`, `DRAIN_INTERFACE`
- `DMA-controller/docs/architecture/assumptions_and_tbd.md`, progress assumptions
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/04_fw_read_drain_lab_guide.md`
