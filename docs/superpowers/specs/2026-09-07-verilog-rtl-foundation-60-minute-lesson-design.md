# Thiết kế giáo trình Verilog RTL nền tảng trong 60 phút

## Mục tiêu

Giáo trình cung cấp kiến thức Verilog RTL tối thiểu để sinh viên năm 3 đã học mạch tổ hợp và mạch tuần tự có thể đọc, giải thích và bắt đầu viết các module phần cứng đồng bộ. Tiết học kéo dài 60 phút, chỉ giảng lý thuyết và phân tích ví dụ. Sinh viên không viết mã hoặc chạy công cụ trong lớp.

Giáo trình đóng vai trò kiến thức tiên quyết cho các bài thực hành của dự án. Nội dung không giảng trước lời giải, giao thức hoặc cấu trúc của bất kỳ module dự án nào.

## Đối tượng và giả định đầu vào

Người học là sinh viên năm 3 đã biết:

- Đại số Boolean và bảng chân trị.
- Mạch tổ hợp và mạch tuần tự.
- Flip-flop, thanh ghi, bộ đếm, clock và reset ở mức khái niệm.
- Sơ đồ trạng thái hữu hạn.

Người học chưa được giả định biết Verilog hoặc SystemVerilog.

## Kết quả đầu ra

Cuối tiết học, sinh viên phải có thể:

1. Giải thích Verilog RTL mô tả phần cứng hoạt động song song, không phải chuỗi lệnh phần mềm.
2. Đọc cấu trúc một `module`, cổng vào ra, vector bit, `wire` và `reg`.
3. Phân biệt logic tổ hợp viết bằng `assign` hoặc `always @(*)` với logic tuần tự viết bằng `always @(posedge clk)`.
4. Chọn đúng blocking assignment `=` và nonblocking assignment `<=` trong các mẫu RTL cơ bản.
5. Nhận ra latch ngoài ý muốn, multiple drivers, sai độ rộng và việc cập nhật state sai cạnh clock.
6. Đọc được một bộ đếm và một FSM Verilog-2001 đơn giản.
7. Phân biệt cú pháp có thể tổng hợp với cú pháp chỉ dành cho mô phỏng ở mức nhập môn.

## Phương án đã chọn

Giáo trình dùng phương án RTL-first. Mỗi cấu trúc cú pháp được nối trực tiếp với phần cứng mà công cụ tổng hợp dự kiến tạo ra. Phương án này được chọn thay cho cách liệt kê cú pháp hoặc chỉ đi theo một ví dụ dài, vì mục tiêu chính là hình thành mô hình tư duy phần cứng trong thời gian ngắn.

Một ví dụ nhỏ có thể xuất hiện để minh họa từng khái niệm, nhưng ví dụ không trở thành bài thực hành và không lấy từ các module của dự án.

## Phạm vi nội dung

Giáo trình chỉ sử dụng Verilog-2001 và tập trung vào tập con RTL có thể tổng hợp:

- `module`, danh sách cổng và hướng cổng.
- Scalar, vector, literal và quy tắc độ rộng cơ bản.
- `wire`, `reg`, biểu thức và toán tử thông dụng.
- Continuous assignment bằng `assign`.
- Procedural combinational logic bằng `always @(*)`.
- Sequential logic bằng `always @(posedge clk)` và reset.
- Blocking và nonblocking assignment.
- `if`, `case`, giá trị mặc định và cách tránh latch.
- Parameter, local parameter, counter và FSM cơ bản.
- Tư duy synthesizable và các lỗi RTL phổ biến.

## Nội dung ngoài phạm vi

Giáo trình không dạy:

- SystemVerilog, gồm `logic`, `always_comb`, `always_ff`, `enum`, interface và assertion.
- Testbench, UVM, randomization hoặc chạy simulator.
- APB, AXI, firewall, DMA hoặc hành vi của các module dự án.
- Clock-domain crossing, pipeline nâng cao, timing closure, synthesis constraint hoặc physical design.
- Bài tập thực hành trong lớp.

## Cấu trúc tiết học

| Thời gian | Nội dung | Kết quả tức thời |
|---|---|---|
| 0-5 phút | Từ sơ đồ mạch sang RTL | Hiểu Verilog mô tả cấu trúc và hành vi song song |
| 5-13 phút | `module`, cổng, vector, `wire`, `reg` | Đọc được phần khai báo của một module |
| 13-22 phút | Logic tổ hợp: `assign`, `always @(*)`, `if`, `case` | Nhận ra mạch tổ hợp và điều kiện gây latch |
| 22-33 phút | Logic tuần tự: clock, reset, enable và state | Nhận ra thanh ghi và thời điểm state thay đổi |
| 33-41 phút | Blocking `=` và nonblocking `<=` | Áp dụng đúng quy tắc assignment nền tảng |
| 41-50 phút | Bộ đếm và FSM Verilog-2001 | Đọc được state register, next-state và output logic |
| 50-56 phút | Synthesizable RTL và lỗi thường gặp | Nhận ra sai độ rộng, multiple drivers và cú pháp mô phỏng |
| 56-60 phút | Sáu câu hỏi kiểm tra nhanh và tổng kết | Xác nhận sáu khái niệm cốt lõi trước khi vào lab |

## Cách trình bày

Mỗi phần dùng cùng một nhịp giảng:

1. Hiển thị một phần tử mạch hoặc sơ đồ tín hiệu.
2. Trình bày đoạn Verilog ngắn tương ứng.
3. Chỉ ra phần cứng được suy ra.
4. Đưa một phiên bản sai phổ biến.
5. Hỏi một câu kiểm tra nhận thức ngắn và giải thích đáp án.

Sinh viên chỉ quan sát, dự đoán và trả lời miệng hoặc bằng phiếu nhanh. Không có bước nhập mã, biên dịch, mô phỏng hoặc sửa lỗi trên máy.

## Nguyên tắc ví dụ mã

Ví dụ phải ngắn, tự chứa và dùng cú pháp Verilog-2001. Mỗi ví dụ chỉ dạy một ý chính. Tên tín hiệu thể hiện vai trò, độ rộng được khai báo rõ và mọi hằng số có kích thước phù hợp.

Các mẫu chuẩn cần có:

- MUX 2:1 bằng `assign`.
- Logic tổ hợp nhiều nhánh bằng `always @(*)` với giá trị mặc định.
- Thanh ghi có reset và enable bằng `always @(posedge clk)`.
- Bộ đếm có điều kiện.
- FSM nhỏ dùng `localparam`, state register và next-state logic.

Ví dụ lỗi cần có:

- Thiếu assignment trên một nhánh và suy ra latch.
- Dùng `=` trong logic tuần tự gây phụ thuộc thứ tự mô phỏng.
- Dùng `<=` trong logic tổ hợp làm khó đọc hành vi.
- Hai `always` block cùng điều khiển một `reg`.
- Hằng số hoặc phép toán sai độ rộng.

## Đầu ra cần soạn

Bộ giáo trình hoàn chỉnh gồm:

1. Giáo án cho giảng viên với lời dẫn và phân bổ thời gian từng phần.
2. Nội dung bài học theo thứ tự trình chiếu, gồm sơ đồ, đoạn mã đúng và đoạn mã sai.
3. Bảng tra cứu Verilog-2001 một trang cho sinh viên.
4. Sáu câu hỏi kiểm tra cuối tiết kèm đáp án và giải thích.
5. Danh sách kiến thức sinh viên cần tự ôn trước khi bắt đầu các bài thực hành đã giao.

## Tiêu chí chất lượng

Giáo trình đạt yêu cầu khi:

- Tổng thời lượng đúng 60 phút và có khoảng đệm trong từng phần.
- Mọi ví dụ dùng Verilog-2001, không lẫn cú pháp SystemVerilog.
- Không chứa nội dung riêng hoặc lời giải của các module dự án.
- Mỗi đoạn mã được giải thích bằng phần cứng tương ứng.
- Không yêu cầu sinh viên thao tác công cụ trong lớp.
- Sáu câu hỏi cuối tiết đo đúng các kết quả đầu ra đã nêu.
- Nội dung đủ để người học đọc một module RTL đồng bộ đơn giản sau tiết học.
