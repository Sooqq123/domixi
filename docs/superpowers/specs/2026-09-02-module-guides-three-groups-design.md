# Thiết kế bộ hướng dẫn module theo ba nhóm phân loại

## Mục tiêu

Bộ tài liệu cung cấp một hướng dẫn riêng cho từng module sản phẩm được xác nhận trong workspace. Tài liệu chia module thành `READY_NOW`, `WAIT_FOR_STUDENTS` và `UNCLEAR`. Người dùng đọc tài liệu, hoặc cung cấp tài liệu cho một công cụ hỗ trợ, để tự thiết kế module. Nội dung giúp người dùng xác định phần được phép thiết kế, phần chỉ được chuẩn bị, và phần cần làm rõ trước khi quyết định.

Bộ tài liệu nằm tại `DMA-controller/docs/module-guides/`. Cấu trúc này độc lập với giáo trình trong `DMA-controller/docs/tutorials/firewall-rtl/`. Giáo trình, bốn hướng dẫn sinh viên và bốn PDF hiện có không thay đổi.

Tài liệu chỉ chứa kiến thức kỹ thuật, quy trình thiết kế, bài tập, test case, checkpoint và tiêu chí hoàn thành. Tài liệu không chứa prompt điều khiển, persona, lời thoại dựng sẵn hoặc quy tắc vận hành dành riêng cho Antigravity. Người dùng tự quyết định cách cung cấp tài liệu cho công cụ hỗ trợ.

## Phạm vi module

Trong đặc tả này, một module là một khối RTL tổng hợp được hoặc một khối logic mà tài liệu hiện hành giao thành đầu ra RTL riêng. Testbench, assertion bind, coverage collector, script và constraint là artifact kiểm chứng. Các artifact kiểm chứng xuất hiện trong hướng dẫn của module liên quan nhưng không nhận một dòng module sản phẩm riêng trong ma trận.

Các tên chỉ xuất hiện trong tài liệu lịch sử hoặc xuất hiện như alias vẫn có dòng riêng trong nhóm `UNCLEAR`. Dòng đó ngăn người đọc tạo một module mới từ tên không có authority.

## Nguồn sự thật

Tài liệu mới lấy hành vi từ các nguồn chuẩn sau:

- `DMA-controller/docs/architecture/document_manifest.csv`
- `DMA-controller/docs/architecture/architecture_overview.md`
- `DMA-controller/docs/architecture/detailed_block_diagram.md`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/fsm_specification.md`
- `DMA-controller/docs/architecture/assumptions_and_tbd.md`
- `DMA-controller/docs/architecture/pinout.csv`
- `DMA-controller/docs/architecture/signal_list.csv`
- `DMA-controller/docs/architecture/register_map.csv`
- `DMA-controller/docs/architecture/memory_map.csv`
- `DMA-controller/docs/architecture/requirements_traceability.csv`
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/architecture/implementation_conformance_status.md`
- `DMA-controller/docs/architecture/verification_evidence_manifest.csv`

Các nguồn hỗ trợ gồm khóa học Firewall RTL, bốn hướng dẫn sinh viên, kế hoạch triển khai Firewall RTL và source RTL hiện có. Khi nguồn hỗ trợ khác nguồn chuẩn, tài liệu mới ghi khác biệt và dùng nguồn chuẩn.

## Hiện trạng được xác minh

Workspace có bốn module RTL DMA trong `DMA-controller/rtl/`: `dma_apb_slave`, `dma_axi_master`, `dma_fifo_latch` và `dma_controller`. Bốn testbench tương ứng tồn tại trong `DMA-controller/tb/`. Evidence manifest ghi unit regression của bốn module là `PASS` trong phạm vi đã nêu.

Workspace không có source Firewall `.v` hoặc `.sv` trong `DMA-controller/rtl/` hoặc thư mục `rtl/` ở root khi khảo sát. Một số tài liệu chuẩn còn mô tả bản nháp `fw_axi_address_slice.v` từng tồn tại. Bộ hướng dẫn phải ghi đây là sai lệch giữa status document và cây file hiện tại.

Bốn gói hướng dẫn sinh viên có thứ tự vận hành như sau:

1. Gói 01 tạo `fw_apb_regs`.
2. Gói 02 tạo `fw_acl_matcher`.
3. Gói 03 tạo phần write drain.
4. Gói 04 tạo phần read drain.

Repo không ghi tên hoặc danh tính người nhận từng gói. Tài liệu dùng số gói thay cho tên sinh viên. Kiến trúc chuẩn yêu cầu một file `fw_drain_fsm.v`, nên kết quả gói 03 và 04 cần một bước hợp nhất sau bàn giao.

## Cấu trúc đầu ra

```text
DMA-controller/docs/module-guides/
|-- README.md
|-- module-classification-matrix.md
|-- 01-ready-now/
|   |-- dma_apb_slave.md
|   |-- dma_axi_master.md
|   |-- dma_fifo_latch.md
|   |-- dma_controller.md
|   |-- fw_axi_address_slice.md
|   |-- fw_context_tracker.md
|   `-- fw_data_path_mux.md
|-- 02-wait-for-students/
|   |-- fw_apb_regs.md
|   |-- fw_acl_matcher.md
|   |-- fw_write_drain.md
|   |-- fw_read_drain.md
|   |-- fw_drain_fsm.md
|   `-- dma_bus_firewall.md
`-- 03-unclear/
    |-- fw_apb_slave.md
    |-- dma_top.md
    |-- dma32.md
    `-- fifo32.md
```

`README.md` là điểm vào duy nhất. File này giải thích ý nghĩa ba nhóm, thứ tự đọc và quy tắc chuyển trạng thái. Ma trận giữ danh mục đầy đủ và liên kết tới từng tài liệu module.

## Ma trận phân loại thiết kế

| Module ID | Module | Phân loại | Căn cứ |
|---|---|---|---|
| DMA-01 | `dma_apb_slave` | `READY_NOW` | Source, testbench và evidence unit PASS tồn tại. |
| DMA-02 | `dma_axi_master` | `READY_NOW` | Source, testbench và evidence unit PASS tồn tại. |
| DMA-03 | `dma_fifo_latch` | `READY_NOW` | Source, testbench và evidence unit PASS tồn tại. |
| DMA-04 | `dma_controller` | `READY_NOW` | Source, testbench và evidence unit PASS tồn tại. |
| FW-01 | `fw_axi_address_slice` | `READY_NOW` | Hành vi độc lập đã được đặc tả; cần chốt bốn cờ nội bộ bằng cập nhật tài liệu trước khi đóng port list. |
| FW-02 | `fw_context_tracker` | `READY_NOW` | Sideband năm tín hiệu, FSM, dynamic regions và fault behavior đã được đặc tả. |
| FW-03 | `fw_data_path_mux` | `READY_NOW` | Routing, isolation, AXI boundary và drain interface đã được đặc tả; unit test dùng stub owner và stub drain. |
| FW-04 | `fw_apb_regs` | `WAIT_FOR_STUDENTS` | Đây là đầu ra của gói sinh viên 01. |
| FW-05 | `fw_acl_matcher` | `WAIT_FOR_STUDENTS` | Đây là đầu ra của gói sinh viên 02. |
| FW-06 | `fw_write_drain` | `WAIT_FOR_STUDENTS` | Đây là khối logic đầu ra của gói sinh viên 03. |
| FW-07 | `fw_read_drain` | `WAIT_FOR_STUDENTS` | Đây là khối logic đầu ra của gói sinh viên 04. |
| FW-08 | `fw_drain_fsm` | `WAIT_FOR_STUDENTS` | File chuẩn phải hợp nhất hoặc bao hai đầu ra của gói 03 và 04. |
| FW-09 | `dma_bus_firewall` | `WAIT_FOR_STUDENTS` | Top cần đủ APB regs, matcher, drain, address slice, context tracker và mux. |
| UNC-01 | `fw_apb_slave` | `UNCLEAR` | Tên xuất hiện trong một đoạn mô tả APB nhưng module chuẩn là `fw_apb_regs`. |
| UNC-02 | `dma_top` | `UNCLEAR` | Tên chỉ xuất hiện trong tài liệu hỗ trợ hoặc lịch sử, không có source chuẩn hiện tại. |
| UNC-03 | `dma32` | `UNCLEAR` | Tên chỉ xuất hiện trong tài liệu hỗ trợ hoặc lịch sử, không có source chuẩn hiện tại. |
| UNC-04 | `fifo32` | `UNCLEAR` | Tên chỉ xuất hiện trong tài liệu hỗ trợ hoặc lịch sử; module chuẩn hiện tại là `dma_fifo_latch`. |

## Nội dung tài liệu `READY_NOW`

Mỗi file trong `01-ready-now/` có các mục sau:

1. Trạng thái và căn cứ phân loại.
2. Mục tiêu module và vấn đề module giải quyết.
3. Vị trí trong hệ thống và module phụ thuộc.
4. Input, output, tham số và reset contract.
5. Luồng xử lý chính và state ownership.
6. Cấu trúc file đề xuất.
7. Interface hoặc data contract.
8. Quy trình thiết kế từ đầu theo mốc nhỏ.
9. Testbench, reference model, test case và checker.
10. Điểm cần tránh và triệu chứng lỗi thường gặp.
11. Rủi ro kỹ thuật và cách kiểm tra.
12. Tiêu chí hoàn thành và evidence cần lưu.
13. Lộ trình để người dùng tự triển khai từng bước.
14. Nguồn chuẩn cho từng nhóm hành vi.

Tài liệu của bốn module DMA phân biệt source đã tồn tại với quy trình xây lại từ đầu. Hướng dẫn ưu tiên đọc, chạy unit regression và xác nhận contract trước khi sửa. Tài liệu không trình bày source hiện tại như bằng chứng cho Firewall integration.

Tài liệu `fw_axi_address_slice` ghi điều kiện tiền xử lý tài liệu: `signal_list.csv` phải biểu diễn `profile_err` và `overflow_err` cho AW và AR. Điều kiện này không phụ thuộc đầu ra sinh viên nên module vẫn thuộc `READY_NOW`.

## Nội dung tài liệu `WAIT_FOR_STUDENTS`

Mỗi file trong `02-wait-for-students/` có các mục sau:

1. Trạng thái chờ và lý do phân loại.
2. Mục tiêu module trong sản phẩm.
3. Đầu ra sinh viên mà module cần.
4. Định dạng source, port contract, test log, waveform và báo cáo cần nhận.
5. Điều kiện đủ để bắt đầu thiết kế hoặc tích hợp.
6. Phần có thể chuẩn bị trước bằng stub, checker, wrapper hoặc checklist.
7. Phần chưa được quyết định trước khi nhận đầu ra.
8. Template tiếp tục thiết kế sau bàn giao.
9. Checklist review source, interface, reset, handshake, test và evidence.
10. Rủi ro khi thiết kế sớm.
11. Tiêu chí chuyển từ `WAIT_FOR_STUDENTS` sang `READY_NOW`.
12. Nguồn chuẩn liên quan.

`fw_apb_regs` yêu cầu gói 01 xử lý register map, fault logger và hai gap interface liên quan `LEN/SIZE`. `fw_acl_matcher` yêu cầu gói 02 xử lý full-burst containment, eight-region overlap và Stage 1 error flags. Hai tài liệu drain định nghĩa đầu ra riêng cho gói 03 và 04. Tài liệu `fw_drain_fsm` định nghĩa cách đánh giá hai đầu ra trước khi hợp nhất.

`dma_bus_firewall` chỉ được chuyển nhóm sau khi đủ bốn gói sinh viên và ba module Firewall thuộc `READY_NOW` có unit evidence. Tài liệu cho phép chuẩn bị top port list, compile harness, stubs và bảng kết nối. Tài liệu không được chốt adapter cuối hoặc tuyên bố G3 trước khi kiểm tra source bàn giao.

## Nội dung tài liệu `UNCLEAR`

Mỗi file trong `03-unclear/` ghi:

1. Tên được tìm thấy và vị trí nguồn.
2. Lý do tên không đủ authority để triển khai.
3. Module chuẩn có khả năng liên quan, nếu nguồn chuẩn nêu rõ.
4. Thông tin còn thiếu.
5. Người hoặc quyết định cần để đóng blocker.
6. Hành động bị cấm trước khi có quyết định.
7. Tiêu chí chuyển sang `READY_NOW`, `WAIT_FOR_STUDENTS` hoặc loại khỏi baseline.

Tài liệu không biến alias thành module mới. Một tên lịch sử chỉ được chuyển nhóm khi source chuẩn hoặc quyết định kiến trúc xác nhận vai trò, interface và owner.

## Quy tắc dữ liệu và liên kết

Ma trận sở hữu trạng thái phân loại, lý do, dependency và đường dẫn tài liệu. File module sở hữu hướng dẫn chi tiết. README chỉ tóm tắt quy trình và liên kết đến ma trận.

Mỗi file module liên kết bằng đường dẫn tương đối tới nguồn chuẩn. Các giá trị width, reset, offset, test ID và fault semantics phải truy được về file nguồn. Tài liệu ghi rõ nơi canonical sources đang mâu thuẫn với cây file hoặc với nhau.

Không có tài liệu nào sửa ngầm kiến trúc V2.4.1. Một gap của nguồn chuẩn xuất hiện dưới dạng blocker hoặc điều kiện tiền xử lý. Tài liệu không tự tạo port, module hoặc policy mới để lấp gap.

## Kiểm tra chất lượng

Lượt kiểm tra cuối gồm:

1. Đếm 17 dòng module trong ma trận và đối chiếu với 17 file module.
2. Kiểm tra mỗi module chỉ xuất hiện trong một nhóm.
3. Kiểm tra mọi link Markdown nội bộ tồn tại.
4. Kiểm tra mọi tài liệu `READY_NOW` có đủ 14 mục nội dung.
5. Kiểm tra mọi tài liệu `WAIT_FOR_STUDENTS` có đủ 12 mục và điều kiện chuyển nhóm.
6. Kiểm tra mọi tài liệu `UNCLEAR` có đủ bảy mục và không chứa quyết định chưa có nguồn.
7. Tìm tên module lệch, placeholder không được yêu cầu và đường dẫn tuyệt đối theo máy.
8. Tìm em dash, en dash và chuỗi ` -- ` trong phần văn xuôi.
9. Kiểm tra giáo trình, student guides, PDF và production RTL không bị sửa.
10. Chạy `git diff --check` trên toàn bộ file mới.

## Tiêu chí hoàn thành

Bộ tài liệu hoàn thành khi có README, ma trận và 17 hướng dẫn module theo đúng ba thư mục. Mỗi phân loại có căn cứ và điều kiện thay đổi trạng thái. Các module chờ sinh viên có hợp đồng đầu ra cụ thể. Các module chưa rõ giữ blocker nhìn thấy được.

Báo cáo bàn giao liệt kê file đã đọc, file đã tạo, bảng phân loại, blocker, kiểm tra đã chạy và một prompt ngắn để dùng bộ tài liệu. Báo cáo không tuyên bố RTL hoặc verification gate đã hoàn thành.

Prompt ngắn chỉ xuất hiện trong báo cáo trò chuyện theo yêu cầu đầu ra ban đầu. Prompt không được ghi vào bất kỳ file nào trong bộ tài liệu.

## Phê duyệt thiết kế

- 2026-09-02, người dùng phê duyệt cấu trúc ba nhóm và yêu cầu giữ bộ tài liệu ngoài giáo trình.
- 2026-09-02, người dùng xác nhận tài liệu không chứa prompt điều khiển Antigravity; nội dung chỉ hỗ trợ người dùng tự thiết kế module.
