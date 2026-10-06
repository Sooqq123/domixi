# Thiết kế bộ tài liệu thực hành Firewall RTL cho sinh viên

## Mục tiêu

Bộ tài liệu gồm bốn PDF độc lập cho bốn sinh viên thiết kế song song các module `fw_apb_regs`, `fw_acl_matcher`, `fw_write_drain` và `fw_read_drain`. Mỗi PDF cung cấp đủ kiến thức nền, hợp đồng RTL, quy trình thiết kế, hướng dẫn kiểm chứng và tiêu chí nghiệm thu để người học không cần đọc ba PDF còn lại.

Các PDF tổ chức lại kiến thức để dạy và thực hành. Đặc tả trong `DMA-controller/docs/architecture/` vẫn là nguồn chuẩn khi có khác biệt. Giáo trình hiện có trong `DMA-controller/docs/tutorials/firewall-rtl/` là nguồn định hướng bài học, không thay thế đặc tả.

## Phạm vi

| Tài liệu | Module hoặc phần RTL | Sản phẩm sinh viên phải nộp |
|---|---|---|
| `01_fw_apb_regs_lab_guide.pdf` | `fw_apb_regs.v` | RTL, unit testbench tự kiểm tra, log mô phỏng và ghi chú thiết kế |
| `02_fw_acl_matcher_lab_guide.pdf` | `fw_acl_matcher.v` | RTL, reference model, unit testbench, log và ma trận test |
| `03_fw_write_drain_lab_guide.pdf` | Phần write của `fw_drain_fsm.v` | RTL write drain, unit testbench, waveform đại diện và log |
| `04_fw_read_drain_lab_guide.pdf` | Phần read của `fw_drain_fsm.v` | RTL read drain, unit testbench, waveform đại diện và log |

`fw_axi_address_slice.v`, `fw_context_tracker.v`, `fw_data_path_mux.v` và `dma_bus_firewall.v` nằm ngoài phạm vi. Mỗi tài liệu chỉ giải thích giao tiếp với các module đó ở mức cần thiết để xác định input, output và ownership.

## Phương án tổ chức

Ba phương án đã được xem xét:

1. Bốn PDF tự chứa hoàn toàn. Mỗi tài liệu lặp lại phần kiến thức nền cần thiết và cho phép giao trực tiếp cho một sinh viên.
2. Một PDF nền tảng chung cộng bốn PDF module. Phương án này giảm nội dung lặp nhưng tạo thêm một tài liệu bắt buộc và tăng nguy cơ bỏ sót prerequisite.
3. Bốn bài nối tiếp. Phương án này giảm độ dài từng tài liệu nhưng tạo phụ thuộc giữa bốn sinh viên.

Bộ tài liệu dùng phương án đầu tiên. Chi phí là một số khái niệm AXI, cách đọc handshake và quy tắc viết testbench xuất hiện trong nhiều PDF. Lợi ích là mỗi bài có thể bắt đầu, đánh giá và bàn giao độc lập.

## Đối tượng và giả định

Người học biết cú pháp Verilog cơ bản, `always` block, nonblocking assignment, clock, reset và cách chạy một mô phỏng đơn giản. Đây là điều kiện đầu vào được ghi trong `DMA-controller/docs/tutorials/firewall-rtl/SYLLABUS.md`.

Mỗi PDF phải giải thích từ đầu phần giao thức riêng của module. Tài liệu APB giải thích setup và access phase. Hai tài liệu drain giải thích ready/valid, burst length và backpressure. Tài liệu ACL giải thích địa chỉ đầu, địa chỉ byte cuối, containment và policy snapshot.

Tài liệu không giả định người học biết UVM, formal verification hoặc kiến trúc Firewall V2.4.1. Testbench dùng Verilog hoặc SystemVerilog thủ tục đơn giản, task, checker, scoreboard và timeout.

## Cấu trúc chung của mỗi PDF

Mỗi tài liệu dùng cùng thứ tự dưới đây để người hướng dẫn có thể chấm theo một rubric chung:

1. Bìa, mục tiêu và sản phẩm phải nộp.
2. Bản đồ học tập và cách dùng tài liệu.
3. Kiến thức Verilog và giao thức cần cho module.
4. Vai trò của module trong đường dữ liệu hoặc control plane.
5. Thuật ngữ, tham số và bảng tín hiệu.
6. Hợp đồng hành vi và các invariant.
7. Sơ đồ khối, FSM, timing và ví dụ tính toán.
8. Quy trình thiết kế RTL theo các mốc nhỏ có thể mô phỏng.
9. Skeleton module với vị trí cần hoàn thiện.
10. Reference model hoặc pseudocode quyết định.
11. Cấu trúc self-checking testbench.
12. Ma trận test dương, test âm và corner case.
13. Assertions hoặc checker bổ sung.
14. Cách chạy mô phỏng, đọc log và xem waveform.
15. Lỗi thường gặp và quy trình chẩn đoán.
16. Câu hỏi tự kiểm tra kèm đáp án giải thích.
17. Rubric 10 điểm, exit gate và checklist nộp bài.
18. Phụ lục công thức, bảng tra cứu và nguồn đặc tả.

Mỗi PDF chứa skeleton, pseudocode, phương trình, chuyển trạng thái và ví dụ testbench. PDF không chứa nguyên mẫu RTL đáp án hoàn chỉnh. Ranh giới này giữ giá trị thực hành trong khi vẫn cung cấp đủ dữ liệu để người học tự hoàn thiện module.

## Nội dung riêng của `fw_apb_regs`

Tài liệu giải thích APB setup phase, access phase, `PSEL`, `PENABLE`, `PWRITE`, `PREADY`, `PSLVERR` và điều kiện handshake. Quy tắc Secure-Privileged phải dùng đúng `PPROT` theo hợp đồng tích hợp Firewall.

Phần register semantics bao gồm RW, RO, RW1S, W1C, reset value, reserved bit, `FW_LOCK`, tám region descriptor, Region 4 và Region 5 động, active-region write guard, fault metadata, fault count và IRQ sticky. Bảng register đầy đủ phải được lấy từ `DMA-controller/docs/architecture/register_map.csv` thay vì sao chép từ trí nhớ hoặc từ ví dụ rút gọn.

Phần kiểm chứng phải bao phủ reset, read/write hợp lệ, địa chỉ không thẳng hàng, offset không hợp lệ, `PPROT` bị cấm, ghi vào RO, lock một chiều, ghi sau lock, W1C, hardware-set cùng cạnh W1C, nhiều fault cùng cạnh, metadata priority, count và IRQ. Hành vi hardware-set thắng W1C phải có checker riêng.

## Nội dung riêng của `fw_acl_matcher`

Tài liệu xây dựng quyết định ACL từ descriptor và policy snapshot. Người học phải tính `last_byte`, kiểm tra overflow, kiểm tra toàn burst nằm trong region và phân biệt full containment với partial overlap.

Matcher đánh giá tám region theo cùng một quy tắc. Khi nhiều region cùng match, permission cuối dùng phép AND hạn chế nhất. Tài liệu giải thích MID exact, MID mask, Secure-Privileged attributes, read/write permission, no-match default deny và phạm vi bypass của `FW_EN=0`.

Phần kiểm chứng phải dùng pure reference model trong testbench. Ma trận test bao gồm một region, không match, chạm biên, vượt limit một byte, overflow, crossing 4 KiB, overlap có quyền khác nhau, MID exact, MID masked, PROT mismatch, policy thay đổi sau acceptance và bypass. Decision đã snapshot phải ổn định trong suốt transaction owner.

## Nội dung riêng của `fw_write_drain`

Tài liệu giải thích quan hệ AW và W, ý nghĩa `AWLEN`, số beat bằng `AWLEN+1`, handshake `WVALID && WREADY`, `WLAST`, B response và backpressure. Write drain chốt AWID, AWLEN và error mode khi nhận denied owner.

FSM dùng ba trạng thái logic: IDLE, SINK và RESP. Counter chỉ thay đổi trên W handshake. `WLAST` sớm hoặc thiếu tạo framing fault nhưng không thay thế AWLEN làm nguồn xác định số beat. `BVALID`, `BID` và `BRESP` phải ổn định khi `BREADY=0`.

Phần kiểm chứng bao gồm LEN 0, LEN 15, khoảng trống ngẫu nhiên trên WVALID, stall WREADY, WLAST sớm, thiếu WLAST, BREADY stall, DECERR, honeypot OKAY, reset giữa trạng thái và kiểm tra không có W beat bị deny nào đi ra matrix.

## Nội dung riêng của `fw_read_drain`

Tài liệu giải thích quan hệ AR và R, ý nghĩa `ARLEN`, số beat bằng `ARLEN+1`, handshake `RVALID && RREADY`, RLAST và backpressure. Read drain chốt ARID, ARLEN và error mode khi nhận denied owner.

FSM dùng hai trạng thái logic: IDLE và GEN. Counter chỉ thay đổi trên R handshake. `RID`, `RDATA`, `RRESP` và `RLAST` phải ổn định khi `RREADY=0`. Final beat có chỉ số bằng ARLEN vì ARLEN dùng dạng beats-minus-one.

Phần kiểm chứng bao gồm LEN 0, LEN 15, RREADY ngẫu nhiên, stall tại beat đầu, stall tại final beat, DECERR, honeypot OKAY, reset giữa burst và kiểm tra denied AR không được phát ra matrix.

## Nguồn và quy tắc sự thật

Các tài liệu phải phân biệt ba loại nội dung:

| Nhãn | Ý nghĩa |
|---|---|
| Đặc tả | Hành vi lấy từ tài liệu kiến trúc chuẩn trong repo |
| Hướng dẫn | Cách chia nhỏ công việc hoặc cách debug do bộ tài liệu đề xuất |
| Bài tập | Phần sinh viên phải tự thiết kế hoặc chứng minh |

Nguồn chính gồm:

- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md` cho module boundary, AXI/APB profile và invariant tích hợp.
- `DMA-controller/docs/architecture/fsm_specification.md` cho FSM read drain và write drain.
- `DMA-controller/docs/architecture/register_map.csv` cho register offset, field, reset và access semantics.
- `DMA-controller/docs/architecture/signal_list.csv` và `pinout.csv` cho tên, hướng và độ rộng tín hiệu.
- `DMA-controller/docs/architecture/architecture_overview.md` cho ACL, context, priority và fault semantics.
- `DMA-controller/docs/architecture/verification_test_plan.md` cho test bắt buộc và expected result.
- Bài 03 đến bài 06 trong `DMA-controller/docs/tutorials/firewall-rtl/lessons/` cho lộ trình thực hành hiện có.

Khi các nguồn khác nhau không thống nhất, tài liệu phải nêu khác biệt và lấy `DMA-controller/docs/architecture/` làm nguồn chuẩn theo `DMA-controller/docs/tutorials/firewall-rtl/README.md`.

## Định dạng và khả năng đọc

PDF dùng khổ A4, font hỗ trợ đầy đủ tiếng Việt, lề đủ để in hai mặt và code font monospace. Heading, bảng, code block, cảnh báo, bài tập và exit gate có style nhất quán giữa bốn tài liệu.

Mỗi trang có tên module ở header và số trang ở footer. Bảng dài lặp lại hàng tiêu đề khi sang trang. Code block không bị cắt ở mép trang. Sơ đồ và waveform phải đọc được khi in đen trắng.

Độ dài không bị khóa theo số trang. Mỗi nội dung chỉ xuất hiện khi giúp người học thiết kế, kiểm tra hoặc debug module. Ước tính mỗi PDF dài khoảng 30 đến 45 trang với bố cục A4; con số thực tế phụ thuộc số bảng tín hiệu và ví dụ timing.

## Artefact nguồn và đầu ra

Nguồn chỉnh sửa được đặt trong `DMA-controller/docs/tutorials/firewall-rtl/student-guides/`. Script tạo PDF được đặt trong `DMA-controller/docs/tutorials/firewall-rtl/tools/` và tạo cả bốn tài liệu trong một lệnh.

PDF cuối được đặt trong `output/pdf/`:

```text
output/pdf/
├── 01_fw_apb_regs_lab_guide.pdf
├── 02_fw_acl_matcher_lab_guide.pdf
├── 03_fw_write_drain_lab_guide.pdf
└── 04_fw_read_drain_lab_guide.pdf
```

Ảnh render dùng cho kiểm tra đặt trong `tmp/pdfs/` và không phải đầu ra bàn giao.

## Kiểm tra chất lượng

Mỗi PDF phải qua bốn nhóm kiểm tra:

1. Kiểm tra nội dung: không có mục chưa hoàn thiện, chỗ trống chờ điền hoặc tên tín hiệu không truy được về nguồn.
2. Kiểm tra cấu trúc: đủ mục tiêu, kiến thức nền, thiết kế, testbench, debug, rubric và checklist.
3. Kiểm tra PDF: mở lại bằng `pypdf` hoặc `pdfplumber`, xác nhận số trang, text extract được và không có trang rỗng ngoài chủ ý.
4. Kiểm tra trực quan: render toàn bộ trang sang PNG, xem trang bìa, trang có bảng dài, code block, FSM, waveform và trang cuối của từng PDF.

PDF chỉ được bàn giao khi không có chữ chồng, chữ bị cắt, glyph tiếng Việt lỗi, bảng vượt lề, code quá nhỏ hoặc header/footer che nội dung.

## Tiêu chí hoàn thành

Bộ tài liệu hoàn thành khi có đúng bốn PDF theo tên đã định, bốn nguồn chỉnh sửa được, một lệnh build tái tạo được kết quả và báo cáo kiểm tra xác nhận cả bốn PDF đọc được.

Mỗi PDF phải cho phép người học trả lời bốn câu hỏi trước khi viết RTL: module sở hữu trạng thái nào, dữ liệu nào phải snapshot, counter thay đổi ở handshake nào và điều kiện terminal là gì. Rubric phải chấm riêng hiểu biết, thiết kế, kiểm chứng, bằng chứng và chất lượng giải thích.
