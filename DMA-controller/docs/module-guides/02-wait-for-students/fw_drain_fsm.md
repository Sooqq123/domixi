# Chuẩn bị thiết kế `fw_drain_fsm`

> Phân loại: `WAIT_FOR_STUDENTS`. Canonical module này chờ đồng thời Gói sinh viên 03 và 04.

## 1. Vì sao chưa thể tích hợp

Kiến trúc đã chốt ba module: `fw_write_drain`, `fw_read_drain` và wrapper canonical `fw_drain_fsm`. Wrapper instantiate hai module con và không sở hữu state machine dùng chung.

Module vẫn thuộc `WAIT_FOR_STUDENTS` vì chưa có source được chấp nhận từ Gói 03 và 04. Trong thời gian chờ, chuẩn bị port mapping, compile harness và test chung; không viết lại hai FSM trong wrapper.

## 2. Mục tiêu module canonical

`fw_drain_fsm` phải instantiate:

- write drain nhận denied AW, sink `AWLEN+1` W beats và trả B;
- read drain nhận denied AR, tạo `ARLEN+1` R beats;
- read và write hoạt động đồng thời, state độc lập;
- metadata chốt riêng cho từng direction;
- fault event framing write;
- owner/busy handoff với data path mux;
- reset đưa cả hai direction về idle.

Không có lý do kiến trúc để read deny chặn write deny hoặc ngược lại.

## 3. Đầu vào cần nhận

Từ Gói 03:

- RTL write drain;
- testbench và logs;
- port list;
- framing fault semantics;
- integration note.

Từ Gói 04:

- RTL read drain;
- testbench và logs;
- port list;
- stability evidence;
- integration note.

Từ canonical docs:

- `DRAIN_INTERFACE` signal names;
- response mode semantics;
- fault logger inputs;
- owner lifecycle và isolation requirements.

## 4. Cấu trúc canonical đã chốt

`fw_drain_fsm.v` chỉ làm wrapper và instantiate đúng một `fw_write_drain` cùng đúng một `fw_read_drain`. Hai module con giữ state, counter, metadata snapshot và unit test riêng. Wrapper chịu trách nhiệm clock/reset distribution, port mapping và đưa các signal lên top.

Không merge hai FSM vào wrapper và không serialize read/write. Nếu port bài nộp khác tên canonical, sửa package hoặc dùng mapping tường minh trong wrapper sau review; không đổi semantics để giảm số cổng.

## 5. Interface integration cần khóa

Write request snapshot: valid/fault, ID, LEN, error mode.

Write data/response: WVALID, WLAST, WREADY, BVALID, BID, BRESP, BREADY.

Read request snapshot: valid/fault, ID, LEN, error mode.

Read response: RVALID, RID, RDATA, RRESP, RLAST, RREADY.

Fault event: `w_framing_fault_valid` một chu kỳ và `w_framing_fault_code=4'b0110` cho early hoặc missing-final WLAST. Top giữ AWADDR/AWID/AWLEN/AWSIZE và tạo full write record; drain wrapper không nhận AWADDR hoặc AWSIZE chỉ để log.

Nếu các package có `busy`, `accept` hoặc `done` riêng, phải map chúng vào owner protocol tường minh. Không dựa vào suy luận từ output VALID khi có stall.

## 6. Việc được chuẩn bị trước

- Compile harness có stub ports theo signal list.
- Unit regression runner cho package 03 và 04 độc lập.
- Combined testbench phát denied read/write đồng thời.
- Matrix isolation monitors cho cả hai direction.
- Assertions owner one-at-a-time theo direction.
- Fault logger stub nhận framing pulse.
- Bảng port mapping cho từng module con và wrapper.

## 7. Quyết định chưa được phép khóa

- Không merge source trước khi cả hai package được accepted.
- Không đổi state machine để chúng dùng chung một state register.
- Không serialize read và write để giảm logic.
- Không chuyển state hoặc counter từ hai module con lên wrapper.
- Không đổi port names canonical mà không có adapter/owner decision.
- Không tạo timeout transaction.
- Không bỏ unit TB sau khi ghép.
- Không dùng combined PASS thay cho unit PASS từng direction.

## 8. Checklist review chung

### Tương thích

- Clock/reset giống nhau.
- ID, LEN và data width nhất quán.
- Response mode encoding giống nhau.
- No duplicate driver trong wrapper.

### Độc lập direction

- Read stall không chặn write W/B progress.
- Write W gap không chặn read R generation.
- Reset xử lý đồng thời nhưng state không dùng chung.
- Request ownership riêng.

### Isolation

- Denied AW không đến Matrix.
- Denied AR không đến Matrix.
- W/B và R chỉ nối đúng local drain khi owner DRAIN.

### Fault

- WLAST framing pulse không bị mất.
- Fault metadata lấy từ snapshot.
- Collision với ACL deny record không double-count ngoài contract.
- Framing pulse/code được top làm giàu bằng write-owner metadata, không bằng live AW bus.

## 9. Combined acceptance tests

| ID | Tình huống |
|---|---|
| DFSM-01 | Read deny và write deny đồng thời |
| DFSM-02 | Read final stall trong khi write hoàn tất |
| DFSM-03 | Write W gaps trong khi read chạy liên tục |
| DFSM-04 | B stall và R stall đồng thời |
| DFSM-05 | New request từng direction khi direction đó busy |
| DFSM-06 | One direction idle, direction kia active |
| DFSM-07 | Reset khi cả hai active |
| DFSM-08 | Write framing fault cùng read completion |
| DFSM-09 | DECERR và honeypot mode snapshots khác nhau |
| DFSM-10 | Back-to-back mixed denied traffic |

## 10. Rủi ro khi bắt đầu sớm

| Rủi ro | Hậu quả |
|---|---|
| Viết lại FSM trong wrapper | Khó biết bug thuộc bài nộp hay integration |
| Shared FSM | Read/write chặn nhau không cần thiết |
| Adapter suy diễn owner | Response chọn sai source |
| Double logging | Fault count sai |
| Mất unit traceability | Không tái hiện được evidence sinh viên |

## 11. Mẫu quyết định integration

```text
Student-03 package accepted:
Student-04 package accepted:
Canonical ports frozen:
Wrapper instantiates fw_write_drain:
Wrapper instantiates fw_read_drain:
Port mapping reviewed:
Adapters required:
Unit regressions retained:
Combined regression result:
```

## 12. Điều kiện chuyển sang `READY_NOW`

- Cả Gói 03 và Gói 04 đã accepted riêng.
- Canonical port mapping hoàn chỉnh.
- Owner và fault-event handoff được freeze.
- Wrapper instantiate hai module con đúng cấu trúc canonical.
- Unit regressions vẫn PASS sau adaptation.
- Combined simultaneous test PASS.

## 13. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.4
- `DMA-controller/docs/architecture/fsm_specification.md`
- `DMA-controller/docs/architecture/signal_list.csv`, `DRAIN_INTERFACE`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/verification_test_plan.md`
- Hai student guides 03 và 04 trong `docs/tutorials/firewall-rtl/student-guides`
