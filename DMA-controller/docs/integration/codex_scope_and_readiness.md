# Phân quyền và trạng thái sẵn sàng tích hợp

Tài liệu này lưu lại phân quyền của giai đoạn chuẩn bị tích hợp. Trạng thái triển khai hiện hành nằm trong `integration_traceability.csv` và `docs/architecture/implementation_conformance_status.md`. Production Firewall hiện đã có đủ top cùng mười hai dependency tại `../../../rtl/`; các bảng phân quyền bên dưới được giữ làm lịch sử, không phải trạng thái readiness hiện tại.

## Bằng chứng dùng để phân quyền

- Ma trận module xác định bảy module `READY_NOW`.
- Đặc tả bộ hướng dẫn sinh viên giao riêng `fw_apb_regs`, `fw_acl_matcher`, `fw_write_drain` và `fw_read_drain` cho gói 01 đến 04.
- Cùng đặc tả đó ghi `dma_bus_firewall` ngoài phạm vi bốn gói. Hợp đồng canonical quy định `fw_drain_fsm` là wrapper chứa hai leaf drain độc lập.
- Bốn tên `fw_apb_slave`, `dma_top`, `dma32` và `fifo32` là tên lịch sử hoặc non-target; không có quyền tạo RTL cho chúng.
- PicoRV32 và các khối SoC ngoài IP không có phân công trong baseline Firewall hiện hành.

## Bảng phân quyền module lịch sử

Bảng này mô tả điểm xuất phát trước khi nhận và tích hợp các package RTL. Không dùng các nhãn `READY_NOW`, `ASSIGNED_PACKAGE_*` hoặc `BLOCKED_DEPENDENCY` trong bảng để suy ra trạng thái hiện tại.

| Module/hạng mục | Trạng thái | Người phụ trách | Codex được phép làm gì | Dependency | Đầu ra cần có |
|---|---|---|---|---|---|
| `dma_apb_slave` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc interface, chạy lại test | APB aperture phía SoC | RTL và unit evidence của owner |
| `dma_axi_master` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc interface, chạy lại test | FIFO và AXI peer | RTL và unit evidence của owner |
| `dma_fifo_latch` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc interface, chạy lại test | Push/pop/flush | RTL và unit evidence của owner |
| `dma_controller` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc interface, chạy lại test | Ba DMA leaf và Firewall | RTL và unit evidence của owner |
| `fw_axi_address_slice` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc interface, compile/test source owner | Matcher | RTL và unit evidence của owner |
| `fw_context_tracker` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc contract, dùng stub ngoài production | APB control và matcher | RTL và unit evidence của owner |
| `fw_data_path_mux` | `READY_NOW` / Nhóm A | Chủ dự án | Đọc contract, dùng stub ngoài production | Owner state, Matrix và drain | RTL và unit evidence của owner |
| `fw_apb_regs` | Gói 01 / Nhóm B | Sinh viên 01 | BFM, checker và acceptance review bên ngoài module | Register map, context và fault records | RTL, TB, log, waveform, port report |
| `fw_acl_matcher` | Gói 02 / Nhóm B | Sinh viên 02 | Model, driver và acceptance review bên ngoài module | Stage 1 và policy view | RTL, model, TB, seeds, log, port report |
| `fw_write_drain` | Gói 03 / Nhóm B | Sinh viên 03 | Mock test-only và wrapper mapping | Denied AW và W/B | RTL, TB, log, waveform, port report |
| `fw_read_drain` | Gói 04 / Nhóm B | Sinh viên 04 | Mock test-only và wrapper mapping | Denied AR và R | RTL, TB, log, waveform, port report |
| `fw_drain_fsm` | Chuẩn bị tích hợp / Nhóm C | Codex | Viết wrapper cấu trúc và combined test | Hai leaf drain được nghiệm thu | Wrapper production và regression với leaf thật |
| `dma_bus_firewall` | Chờ dependency / Nhóm C | Codex | Chuẩn bị public stub, contract checker và harness; viết top sau port acceptance | Bảy Firewall leaf | Production top và G3 regression |
| `fw_apb_slave` | `UNASSIGNED` | Chưa phân công | Chỉ đọc và giữ nguyên | Consumer, port contract, compatibility test | Quyết định owner hoặc loại khỏi target |
| `dma_top` | `UNASSIGNED` | Chưa phân công | Chỉ đọc và giữ nguyên | Consumer, port contract, compatibility test | Quyết định owner hoặc loại khỏi target |
| `dma32` | `UNASSIGNED` | Chưa phân công | Chỉ đọc và giữ nguyên | Module declaration và build target | Quyết định owner hoặc loại khỏi target |
| `fifo32` | `UNASSIGNED` | Chưa phân công | Chỉ đọc và giữ nguyên | Module declaration và build target | Quyết định owner hoặc loại khỏi target |

## Nhóm C và thứ tự thực hiện lịch sử

1. Khóa bảng phân quyền, contract công khai và trạng thái dependency.
2. Hoàn thiện `fw_drain_fsm` như wrapper cấu trúc, kiểm thử bằng mock có nhãn.
3. Kiểm tra boundary DMA–Firewall bằng public stub fail-secure; không sử dụng kết quả này làm G3.
4. Tự động hóa spec lint, model regression, DMA RTL regression, contract checks và hai test chuẩn bị tích hợp.
5. Ghi evidence, giả định và quy trình thay mock bằng source đã nghiệm thu.
6. Khi bốn gói và ba module Firewall Nhóm A có port list/unit PASS, triển khai `dma_bus_firewall`, bind assertions và chạy G3.
7. Formal, coverage, synthesis/STA/PPA và SoC trust chỉ chạy khi công cụ và external inputs tương ứng có thật.

## Trạng thái source hiện hành

- Bốn module DMA và production Firewall top cùng mười hai dependency đều có source và nằm trong regression hiện hành.
- `dma_bus_firewall.v` khớp contract 94 cổng trong `pinout.csv`; simulation stub dùng cùng contract nhưng vẫn chỉ dành cho test chuẩn bị tích hợp.
- Regression RTL hiện hành dùng source thật cho unit test, DMA-Firewall integration và PicoRV32 SoC integration.
- Formal, lint và generic synthesis đã PASS. Functional/code coverage database, gate-level SDF và physical sign-off vẫn là các scope riêng chưa đóng.

## Quy tắc bằng chứng

Kết quả có mock vẫn chỉ mang nhãn `INTEGRATION_PREP`. Trạng thái RTL hiện hành dựa trên source thật, command tái lập, log PASS và port conformance report. Không đưa file trong `tb/integration/mocks/` vào production source list.
