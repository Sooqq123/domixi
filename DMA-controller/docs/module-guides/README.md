# Hướng dẫn thiết kế module theo trạng thái phụ thuộc

Bộ tài liệu này giúp người dùng tự thiết kế, kiểm tra và tích hợp các module của DMA-Aware Bus Firewall IP. Hãy chọn module từ [ma trận phân loại](module-classification-matrix.md), sau đó đọc file hướng dẫn tương ứng trước khi viết RTL.

Bộ tài liệu chỉ chứa kiến thức, hợp đồng kỹ thuật, quy trình thiết kế và tiêu chí kiểm tra.

## Ba nhóm phân loại

### `READY_NOW`

Module trong `01-ready-now/` có đủ nguồn kỹ thuật để bắt đầu ngay mà không cần chờ bốn gói bài sinh viên. Một số module DMA đã có source và unit evidence. Với các module đó, hướng dẫn yêu cầu đọc và chạy lại source hiện hành trước khi quyết định sửa hoặc xây lại.

Source của các module Firewall trong nhóm này đang ở trạng thái `MISSING`, nhưng ranh giới hành vi đủ rõ để thiết kế độc lập bằng stub. Stage 1 flags, fault LEN/SIZE, drain wrapper và tên APB register module đã được đóng trong hợp đồng canonical.

### `WAIT_FOR_STUDENTS`

Module trong `02-wait-for-students/` còn phụ thuộc trực tiếp vào đầu ra gói 01, 02, 03 hoặc 04. Tài liệu cho phép chuẩn bị kiến thức, stub, checker, bảng kết nối và tiêu chí tiếp nhận. Tài liệu không cho phép chốt thiết kế tích hợp cuối trước khi nhận và kiểm tra source bàn giao.

Mỗi file ghi định dạng đầu ra cần nhận, điều kiện bắt đầu, phần chưa được quyết định, checklist review và điều kiện chuyển sang `READY_NOW`.

### `UNCLEAR`

`UNCLEAR` là cổng chặn hành động RTL cho tên không có target hiện hành, kể cả khi đã kết luận tên đó là non-module hoặc tên lịch sử. Không tạo source, alias hay wrapper. Chỉ xem xét lại khi xuất hiện consumer thật, port contract và compatibility test.

## Thứ tự sử dụng

1. Mở [ma trận phân loại](module-classification-matrix.md).
2. Xác nhận module, nhóm, dependency và trạng thái tài liệu.
3. Đọc file module từ đầu đến cuối.
4. Mở các nguồn chuẩn được file module liệt kê.
5. Hoàn thành checkpoint trước khi chuyển sang mốc thiết kế kế tiếp.
6. Lưu source, testbench, command, log và waveform theo mục evidence.
7. Chỉ sửa ma trận khi điều kiện chuyển nhóm đã được đáp ứng bằng artifact kiểm tra được.

## Quy tắc nguồn sự thật

Thứ tự authority dùng trong bộ tài liệu:

```text
DMA-controller/docs/architecture/ canonical V2.4.1
    > source RTL và test chạy từ source hiện hành
    > quyết định kỹ thuật đã được phê duyệt
    > bộ hướng dẫn module này
    > tài liệu khóa học, kế hoạch hoặc artifact lịch sử
```

Khi hai nguồn khác nhau, người dùng phải ghi khác biệt và dừng tại quyết định bị ảnh hưởng. Không sửa requirement để hợp thức hóa source chưa đúng. Không coi file `.vvp`, `.vcd` hoặc log không truy được source là evidence hiện hành.

## Hiện trạng cần nhớ

Workspace hiện có bốn module DMA trong `DMA-controller/rtl/` và bốn testbench tương ứng trong `DMA-controller/tb/`. Evidence manifest ghi unit regression của các module này là PASS trong phạm vi unit đã nêu.

Workspace chưa có Firewall RTL trong cây source hiện tại. Trạng thái canonical ghi `MISSING`; một file được tài liệu lịch sử nhắc tới không được coi là source sẵn có.

Bốn gói sinh viên được nhận diện theo số tài liệu:

| Gói | Đầu ra logic |
|---:|---|
| 01 | `fw_apb_regs` |
| 02 | `fw_acl_matcher` |
| 03 | write drain |
| 04 | read drain |

Repo không ghi danh tính người nhận từng gói. Kiến trúc chuẩn chốt `fw_drain_fsm.v` là wrapper instantiate `fw_write_drain.v` và `fw_read_drain.v`; gói 03 và 04 vẫn phải qua unit acceptance và port-mapping review trước khi tích hợp top.

## Quy tắc thay đổi trạng thái

Một module `WAIT_FOR_STUDENTS` chỉ chuyển sang `READY_NOW` khi mọi đầu ra bắt buộc tồn tại, port contract đã review, unit test chạy từ source PASS và không còn blocker được file module liệt kê.

Một tên `UNCLEAR` chỉ được xem xét lại khi có consumer hoặc build target hiện hành, port contract và compatibility test. Nếu không có ba artifact này, disposition giữ nguyên là không tạo RTL.

Ma trận là nơi duy nhất lưu trạng thái phân loại. File module lưu điều kiện và hướng dẫn, không tự tuyên bố đã chuyển nhóm.

## Giới hạn

Bộ tài liệu không sửa kiến trúc V2.4.1, không chứng minh formal, coverage, synthesis, STA hoặc SoC trust closure. Mọi gate vẫn dùng trạng thái PASS, FAIL hoặc BLOCKED theo evidence thực tế trong `DMA-controller/docs/architecture/verification_evidence_manifest.csv`.
