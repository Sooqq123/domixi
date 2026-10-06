# Đề cương 12 bài DMA AXI Firewall RTL

## Đối tượng và điều kiện đầu vào

Người học biết cú pháp Verilog cơ bản, always block, nonblocking assignment và simulation clock/reset. Không yêu cầu đã biết UVM hoặc formal verification.

## Phương pháp

Mỗi bài đi theo chu trình:

```text
truy hồi kiến thức → giải thích khái niệm → viết test failing
→ viết RTL tối thiểu → chạy test → phân tích lỗi → đóng exit gate
```

Antigravity không chuyển bài nếu người học chưa tự giải thích được invariant chính và chưa có evidence được yêu cầu.

## Danh sách bài

| Bài | Chủ đề | Sản phẩm chính | Exit gate |
|---:|---|---|---|
| 00 | [Định hướng, SSOT và verification gates](lessons/bai-00-ssot-va-baseline.html) | Baseline report và source manifest | G0 baseline hiểu đúng |
| 01 | [AXI handshake, burst arithmetic và address slice](lessons/bai-01-fw-axi-address-slice.html) | `fw_axi_address_slice.v` + unit TB | G1/G2 Address Slice |
| 02 | [Context one-shot và same-cycle priority](lessons/bai-02-fw-context-tracker.html) | `fw_context_tracker.v` + unit TB | G1/G2 Context |
| 03 | [Secure APB register bank và fault logger](lessons/bai-03-fw-apb-regs.html) | `fw_apb_regs.v` + unit TB | G1/G2 APB |
| 04 | [ACL matcher và full-burst containment](lessons/bai-04-fw-acl-matcher.html) | `fw_acl_matcher.v` + unit TB | G1/G2 Matcher |
| 05 | [Denied-write exact-beat drain](lessons/bai-05-write-drain.html) | Write half của `fw_drain_fsm.v` + TB | G1/G2 Write Drain |
| 06 | [Denied-read generation và response stability](lessons/bai-06-read-drain.html) | Read half của `fw_drain_fsm.v` + TB | G1/G2 Read Drain |
| 07 | [Allowed/denied isolation và data-path mux](lessons/bai-07-fw-data-path-mux.html) | `fw_data_path_mux.v` + unit TB | G1/G2 Mux |
| 08 | [Transaction ownership và top-level integration](lessons/bai-08-dma-bus-firewall-top.html) | `dma_bus_firewall.v` + top TB | G3 Firewall integration |
| 09 | [DMA–Firewall subsystem regression và traceability](lessons/bai-09-dma-firewall-regression.html) | SoC TB + regression script | G3 Subsystem |
| 10 | [SVA và formal security properties](lessons/bai-10-sva-va-formal.html) | Property modules + reports | G4 hoặc BLOCKED_TOOLING |
| 11 | [Coverage, synthesis/STA, CDC và release evidence](lessons/bai-11-coverage-va-signoff.html) | Coverage/PPA/evidence package | G5–G7 PASS/BLOCKED chính xác |

## Dependency graph

```text
B00
 └─ B01 address slice
     ├─ B02 context tracker
     ├─ B03 APB regs
     └─ B04 ACL matcher
         ├─ B05/B06 drain FSM
         └─ B07 data-path mux
             └─ B08 top integration
                 └─ B09 subsystem regression
                     ├─ B10 formal
                     └─ B11 sign-off
```

## Cách đánh giá từng bài

Mỗi bài được chấm trên bốn trục, mỗi trục 0–2 điểm:

- **Giải thích:** nói đúng invariant bằng lời của mình.
- **Thiết kế:** module boundary và state/data ownership đúng SSOT.
- **Kiểm chứng:** test tự kiểm tra có negative case và timeout.
- **Bằng chứng:** lệnh, log và source revision truy xuất được.

Điểm tối thiểu để qua bài là 7/8 và không được 0 ở bất kỳ trục nào.

## Nhịp học khuyến nghị

- Một bài module: 60–120 phút lý thuyết/lab, có thể chia nhiều phiên.
- Sau mỗi ba bài: một phiên retrieval không mở tài liệu trong 15 phút.
- Sau B08: rerun toàn bộ unit suite trước khi bắt đầu verification nâng cao.
- Không tối ưu area/timing trước khi G3 sạch.
