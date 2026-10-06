---
title: Verilog RTL nền tảng trong 60 phút
subtitle: Từ sơ đồ mạch số đến mã RTL có thể tổng hợp
version: Giáo trình lý thuyết cho sinh viên năm 3
---

# Giáo án cho giảng viên

## Mục tiêu của tiết học

Kết thúc 60 phút, sinh viên phải đọc được một module RTL đồng bộ đơn giản và chỉ ra phần cứng tương ứng với từng khối mã. Trọng tâm của tiết học là tư duy mô tả phần cứng, không phải ghi nhớ mọi cú pháp Verilog.

Sinh viên đã biết mạch tổ hợp, mạch tuần tự, flip-flop, thanh ghi, bộ đếm, clock, reset và sơ đồ trạng thái. Tiết học không yêu cầu sinh viên viết mã hoặc chạy công cụ.

## Kết quả học tập

Sinh viên có thể:

1. Giải thích vì sao các khối phần cứng hoạt động song song.
2. Đọc khai báo `module`, cổng, vector bit, `wire` và `reg`.
3. Phân biệt logic tổ hợp với logic tuần tự trong Verilog.
4. Dùng đúng quy tắc blocking `=` và nonblocking `<=` khi đọc mã.
5. Nhận ra latch ngoài ý muốn, multiple drivers và sai độ rộng.
6. Đọc được bộ đếm có reset và enable.
7. Đọc được FSM gồm state register, next-state logic và output logic.

## Phân bổ thời gian

| Thời gian | Nội dung | Điều cần chốt |
|---|---|---|
| 0-5 phút | Từ sơ đồ mạch sang RTL | Verilog mô tả phần cứng hoạt động song song |
| 5-13 phút | `module`, cổng, vector, `wire`, `reg` | Khai báo cho biết kết nối và cách tín hiệu được điều khiển |
| 13-22 phút | Logic tổ hợp | Output phụ thuộc input hiện tại và phải được gán trên mọi nhánh |
| 22-33 phút | Logic tuần tự | State chỉ đổi tại cạnh clock đã khai báo |
| 33-41 phút | Blocking và nonblocking | Tổ hợp dùng `=`, tuần tự dùng `<=` |
| 41-50 phút | Bộ đếm và FSM | Tách nơi lưu state khỏi logic tính state kế tiếp |
| 50-56 phút | RTL có thể tổng hợp | Viết mã với hình dung rõ phần cứng được tạo ra |
| 56-60 phút | Kiểm tra nhanh và tổng kết | Truy hồi sáu quy tắc quan trọng nhất |

## Cách sử dụng giáo trình

Mỗi phần có năm thành phần: kết luận cần chốt, lời giảng gợi ý, sơ đồ hoặc mã mẫu, lỗi thường gặp và câu hỏi kiểm tra nhận thức. Giảng viên trình bày mã trên màn hình và yêu cầu sinh viên dự đoán phần cứng hoặc giá trị tín hiệu bằng lời. Không dành thời gian cho nhập mã, biên dịch hoặc mô phỏng.

Nếu thiếu thời gian, giữ nguyên các phần về logic tổ hợp, logic tuần tự và assignment. Có thể rút ngắn phần toán tử và bảng lỗi. Không bỏ FSM vì đây là điểm nối giữa kiến thức mạch tuần tự và cách tổ chức RTL.

<!-- pagebreak -->

# Phút 0-5: Từ sơ đồ mạch sang RTL

## Kết luận cần chốt

Verilog RTL là cách mô tả phần cứng. Một phép gán có thể biểu diễn dây nối, cổng logic hoặc mạch chọn. Một khối theo cạnh clock có thể biểu diễn các flip-flop. Các phần tử này cùng tồn tại và hoạt động song song.

## Lời giảng gợi ý

Hãy bắt đầu bằng câu hỏi: "Nếu trên sơ đồ có một bộ cộng và một bộ so sánh đặt cạnh nhau, bộ nào chạy trước?" Câu trả lời là không có thứ tự trước sau. Cả hai nhận tín hiệu và phản ứng theo mạch của chúng.

Trong phần mềm, câu lệnh thứ hai thường chạy sau câu lệnh thứ nhất. Trong RTL, hai continuous assignment hoặc hai `always` block thường mô tả hai khối phần cứng cùng tồn tại. Thứ tự chúng xuất hiện trong file không phải thứ tự khối phần cứng hoạt động.

```text
 a ----->[ bộ cộng ]-----> sum
 b -----/          

 a ----->[ so sánh ]-----> equal
 b -----/

Hai khối nhận a và b cùng lúc.
```

## Ba mức cần phân biệt

| Mức | Câu hỏi chính | Ví dụ |
|---|---|---|
| Thuật toán | Muốn hệ thống làm gì? | Đếm số sự kiện |
| RTL | Thanh ghi và logic kết hợp ra sao? | Thanh ghi `count` cộng thêm một khi `en=1` |
| Cổng | Công cụ tạo phần cứng nào? | Flip-flop, bộ cộng và mux hồi tiếp |

Trong tiết học này, sinh viên làm việc ở mức RTL nhưng luôn phải trả lời được câu hỏi: "Đoạn mã này tạo dây, mux, logic tổ hợp hay flip-flop?"

## Nhầm lẫn thường gặp

Sai: đọc file từ trên xuống và cho rằng khối viết trước luôn chạy trước.

Đúng: xác định loại khối, tín hiệu đầu vào, tín hiệu đầu ra và sự kiện làm khối cập nhật.

## Kiểm tra nhận thức

Hỏi: "Hai `always @(posedge clk)` trong cùng module có phải khối thứ hai chờ khối thứ nhất chạy xong không?"

Chốt: không. Chúng biểu diễn hai nhóm thanh ghi cùng lấy mẫu tại một cạnh clock. Cách viết assignment quyết định giá trị mà mô phỏng quan sát sau cạnh.

<!-- pagebreak -->

# Phút 5-13: Cấu trúc module và tín hiệu

## Module là ranh giới phần cứng

Một `module` khai báo tên khối, các cổng kết nối và hành vi bên trong. Có thể xem module như một hộp phần cứng có đầu vào và đầu ra rõ ràng.

```verilog
module mux2 (
    input  wire       sel,
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [7:0] y
);
    assign y = sel ? b : a;
endmodule
```

Phần cứng được suy ra là tám mux 2:1 song song. Mỗi bit của `y` chọn bit tương ứng từ `a` hoặc `b`.

```text
 a[7:0] ----0\
               >---- y[7:0]
 b[7:0] ----1/
              ^
             sel
```

## Cổng và vector

| Cú pháp | Ý nghĩa |
|---|---|
| `input wire a` | Một tín hiệu vào có một bit |
| `input wire [7:0] data` | Bus vào tám bit, từ bit 7 đến bit 0 |
| `output wire y` | Output được điều khiển bởi kết nối hoặc `assign` |
| `output reg q` | Output được gán bên trong procedural block |

Khai báo `[7:0]` tạo tám bit. `data[7]` là một bit. `data[7:4]` là lát cắt bốn bit. Hai vế của phép gán nên có độ rộng phù hợp để tránh mất bit hoặc mở rộng không chủ ý.

## Literal có kích thước

Verilog viết hằng số theo dạng `độ_rộng'cơ_số_giá_trị`:

| Literal | Ý nghĩa |
|---|---|
| `1'b0` | Một bit nhị phân bằng 0 |
| `4'b1010` | Bốn bit nhị phân |
| `8'hA5` | Tám bit hệ mười sáu |
| `6'd37` | Sáu bit hệ thập phân |

Ưu tiên literal có kích thước rõ trong RTL. Ví dụ bộ đếm bốn bit nên cộng `4'b0001` thay vì dựa vào một số nguyên không ghi độ rộng.

## `wire` và `reg`

`wire` biểu diễn một net được điều khiển bởi kết nối module hoặc continuous assignment. `reg` là kiểu biến có thể được gán trong `always` block.

Tên `reg` không bảo đảm có flip-flop. Nếu `reg` được gán đầy đủ trong `always @(*)`, phần cứng vẫn là logic tổ hợp. Flip-flop xuất hiện khi cách mô tả yêu cầu lưu giá trị qua thời gian, thường là trong khối theo cạnh clock.

## Nhầm lẫn thường gặp

Sai: mọi tín hiệu khai báo `reg` đều là thanh ghi vật lý.

Đúng: loại phần cứng được suy ra từ cách tín hiệu được gán và điều kiện cập nhật.

## Kiểm tra nhận thức

Hỏi: "Output được gán bằng `assign` nên khai báo là gì? Output được gán trong `always` nên khai báo là gì?"

Chốt: trường hợp đầu dùng `wire`; trường hợp sau dùng `reg` trong Verilog-2001.

# Phút 13-22: Logic tổ hợp

## Đặc trưng của logic tổ hợp

Output tổ hợp là hàm của input hiện tại. Nó không cần nhớ giá trị ở chu kỳ trước. Hai mẫu RTL chính là continuous assignment và procedural combinational block.

## Mẫu 1: `assign` cho biểu thức ngắn

```verilog
module compare8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire       equal,
    output wire       greater
);
    assign equal   = (a == b);
    assign greater = (a > b);
endmodule
```

Hai output được tính song song. Dòng `greater` không chờ dòng `equal` hoàn tất.

## Mẫu 2: `always @(*)` cho nhiều nhánh

```verilog
module alu_small (
    input  wire [1:0] op,
    input  wire [7:0] a,
    input  wire [7:0] b,
    output reg  [7:0] y
);
    always @(*) begin
        y = 8'h00;
        case (op)
            2'b00: y = a + b;
            2'b01: y = a - b;
            2'b10: y = a & b;
            2'b11: y = a | b;
            default: y = 8'h00;
        endcase
    end
endmodule
```

`always @(*)` yêu cầu simulator tự đưa mọi tín hiệu được đọc vào sensitivity list. Trong khối tổ hợp, dùng blocking `=` để các bước tính trung gian có thứ tự rõ bên trong cùng một lần đánh giá.

`y = 8'h00` là giá trị mặc định. Mọi nhánh `case` cũng gán `y`, vì vậy mạch không cần nhớ giá trị cũ.

## Phần cứng được suy ra

```text
 a,b --> cộng ---\
 a,b --> trừ ----\
 a,b --> AND -----+--> mux chọn theo op --> y
 a,b --> OR  ----/
```

Các phép toán tạo nhiều nhánh logic. `op` điều khiển mux chọn kết quả.

## Toán tử cốt lõi

| Nhóm | Toán tử | Ghi nhớ |
|---|---|---|
| Số học | `+ -` | Kiểm tra độ rộng kết quả và carry |
| Bitwise | AND, OR, XOR, NOT | Tác động từng bit |
| Logical | AND, OR, NOT điều kiện | Cho kết quả đúng hoặc sai |
| So sánh | `== != < <= > >=` | Chú ý signed và unsigned |
| Ghép bit | `{a, b}` | Nối các vector thành vector lớn hơn |
| Chọn | `cond ? x : y` | Thường tạo mux 2:1 |

```text
Bitwise: &, |, ^, ~
Logical: &&, ||, !
```

Không nhầm `&` với `&&`. `&` thực hiện theo từng bit; `&&` xem mỗi toán hạng như một điều kiện đúng hoặc sai.

# Latch ngoài ý muốn

## Mẫu sai

```verilog
module latch_bad (
    input  wire       en,
    input  wire [7:0] a,
    output reg  [7:0] y
);
    always @(*) begin
        if (en)
            y = a;
    end
endmodule
```

Khi `en=0`, mã không nói `y` phải bằng gì. Để giữ giá trị cũ, phần cứng cần bộ nhớ. Công cụ có thể suy ra latch dù người thiết kế chỉ định viết mạch tổ hợp.

## Mẫu đúng

```verilog
module mux_enable (
    input  wire       en,
    input  wire [7:0] a,
    output reg  [7:0] y
);
    always @(*) begin
        y = 8'h00;
        if (en)
            y = a;
    end
endmodule
```

Khi `en=0`, `y=0`; khi `en=1`, `y=a`. Mọi trường hợp đều có giá trị xác định, nên phần cứng là mux chứ không phải latch.

## Quy tắc đọc khối tổ hợp

Khi gặp `always @(*)`, hãy kiểm tra theo thứ tự:

1. Output nào được gán trong khối?
2. Mỗi output có giá trị mặc định không?
3. Mọi nhánh `if` và `case` có để lại đường không gán không?
4. Có dùng blocking `=` không?
5. Có output nào bị một khối khác cùng điều khiển không?

## Giá trị mặc định không phải giá trị reset

Giá trị mặc định ở đầu `always @(*)` được tính lại bất cứ khi nào input thay đổi. Nó không phải reset và không lưu qua chu kỳ. Reset chỉ có ý nghĩa với state được lưu trong logic tuần tự.

## Kiểm tra nhận thức

Hỏi: "Nếu bỏ dòng `y = 8'h00` nhưng không thêm `else`, phần cứng cần làm gì khi `en=0`?"

Chốt: phải giữ giá trị trước đó, nên latch xuất hiện.

<!-- pagebreak -->

# Phút 22-33: Logic tuần tự

## State thay đổi tại cạnh clock

Logic tuần tự lưu thông tin. Một khối `always @(posedge clk)` mô tả các thanh ghi lấy mẫu ở cạnh lên của clock.

```verilog
module register_enable (
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    input  wire [7:0] d,
    output reg  [7:0] q
);
    always @(posedge clk) begin
        if (rst)
            q <= 8'h00;
        else if (en)
            q <= d;
    end
endmodule
```

Phần cứng gồm tám flip-flop, mux chọn dữ liệu mới và reset đồng bộ. `q` chỉ đổi ở cạnh lên. Khi `rst=0` và `en=0`, không có assignment mới nên flip-flop giữ giá trị cũ. Việc giữ state trong khối clocked là hành vi mong muốn, khác với thiếu assignment trong khối tổ hợp.

```text
                +----------------+
 d ------------>|1               |
 q hồi tiếp ---->|0   mux theo en |----> D của flip-flop ----> q
                +----------------+
                                   ^
                                  clk
```

## Reset đồng bộ và reset bất đồng bộ

Mẫu trên là reset đồng bộ vì `rst` chỉ được kiểm tra tại `posedge clk`.

Một reset bất đồng bộ có thể được mô tả bằng:

```verilog
always @(posedge clk or posedge rst) begin
    if (rst)
        q <= 8'h00;
    else
        q <= d;
end
```

Reset bất đồng bộ có thể tác động mà không chờ cạnh clock. Khi làm thiết kế thật, phải dùng đúng reset contract của hệ thống và không tự ý đổi kiểu reset giữa các module.

## Clock enable không phải clock mới

`en` trong nhánh `else if` điều khiển mux trước flip-flop. Nó không tạo clock mới. Người mới học nên tránh dùng dữ liệu thông thường làm clock, ví dụ `always @(posedge en)`, vì cách đó tạo thêm miền clock và kéo theo yêu cầu timing phức tạp.

## Cách đọc khối tuần tự

1. Sự kiện nào kích hoạt khối?
2. Tín hiệu nào là state được lưu?
3. Reset đưa state về giá trị nào?
4. Điều kiện nào cho phép state cập nhật?
5. Khi không có assignment, state nào được giữ?

## Kiểm tra nhận thức

Hỏi: "Nếu `en=0` trong năm cạnh clock liên tiếp, `q` có trở thành không xác định không?"

Chốt: không. Flip-flop giữ giá trị đã lưu. Đây là state có chủ ý.

# Phút 33-41: Blocking và nonblocking

## Quy tắc an toàn

Trong tập con RTL của bài học:

- Dùng blocking `=` trong `always @(*)`.
- Dùng nonblocking `<=` trong `always @(posedge clk)`.
- Không để cùng một biến được điều khiển bởi nhiều procedural block.

## Vì sao nonblocking cần cho thanh ghi

Hai thanh ghi pipeline phải cùng lấy mẫu giá trị có trước cạnh clock:

```verilog
always @(posedge clk) begin
    q1 <= d;
    q2 <= q1;
end
```

Giả sử trước cạnh clock: `d=8'hAB`, `q1=8'h12`, `q2=8'h34`.

Sau cạnh clock: `q1=8'hAB`, `q2=8'h12`. Mỗi vế phải đọc giá trị cũ, sau đó các thanh ghi cùng nhận giá trị mới.

```text
 d ---->[ q1 ]---->[ q2 ]
           ^          ^
           +--- clk --+
```

## Phiên bản sai trong RTL tuần tự

```verilog
always @(posedge clk) begin
    q1 = d;
    q2 = q1;
end
```

Trong mô phỏng procedural, dòng đầu đổi `q1` ngay; dòng sau có thể đọc giá trị mới. Kết quả mô phỏng trở thành `q1=8'hAB`, `q2=8'hAB`, không còn thể hiện ý định pipeline hai tầng.

## Vì sao blocking phù hợp với tổ hợp

```verilog
always @(*) begin
    temp = a + b;
    y    = temp ^ mask;
end
```

Trong một lần đánh giá logic tổ hợp, `y` cần dùng `temp` vừa tính. Blocking làm quan hệ này rõ. `temp` và `y` vẫn là logic tổ hợp, không phải hai thao tác chạy qua hai chu kỳ.

## Bảng quyết định nhanh

| Khối | Phần cứng dự kiến | Assignment chính |
|---|---|---|
| `assign` | Dây và logic tổ hợp | `assign y = expr;` |
| `always @(*)` | Logic tổ hợp | Blocking `=` |
| `always @(posedge clk)` | Flip-flop và state | Nonblocking `<=` |

## Kiểm tra nhận thức

Hỏi: "Đổi thứ tự hai dòng nonblocking trong ví dụ pipeline có đổi phần cứng mong muốn không?"

Chốt: không. Cả hai vế phải dùng state cũ. Tuy vậy, nên giữ thứ tự mã dễ đọc và không dựa vào mẹo mô phỏng.

# Phút 41-50: Bộ đếm

## Bộ đếm là thanh ghi cộng với hồi tiếp

```verilog
module counter4 (
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    output reg  [3:0] count
);
    always @(posedge clk) begin
        if (rst)
            count <= 4'b0000;
        else if (en)
            count <= count + 4'b0001;
    end
endmodule
```

Phần cứng gồm bốn flip-flop, một bộ cộng bốn bit và mux hồi tiếp. Counter chỉ tăng tại cạnh clock có `en=1`.

```text
               +---------+
 count --------| cộng 1   |----+
               +---------+    |
                              v
 count giữ ---------------->[ mux ]---->[ thanh ghi count ]----+
                              ^                               |
                              en                              |
                                                              +--- hồi tiếp
```

## Tràn số

`count` có bốn bit nên biểu diễn từ 0 đến 15. Khi đang là `4'b1111` và cộng một, kết quả chỉ giữ bốn bit thấp, vì vậy counter quay về `4'b0000`. Đây là modulo 16 do độ rộng phần cứng, không phải một ngoại lệ tự động.

Nếu muốn bão hòa tại 15, ý định phải được mô tả rõ:

```verilog
always @(posedge clk) begin
    if (rst)
        count <= 4'b0000;
    else if (en && count != 4'b1111)
        count <= count + 4'b0001;
end
```

## Độ rộng biểu thức

Hãy đọc cả độ rộng đầu vào, độ rộng phép toán và độ rộng đích. Nếu muốn giữ carry của phép cộng hai số tám bit, output cần chín bit và toán hạng phải được mở rộng rõ:

```verilog
assign sum9 = {1'b0, a} + {1'b0, b};
```

## Kiểm tra nhận thức

Hỏi: "Bộ đếm bốn bit đang bằng 15. Sau một cạnh có `en=1`, giá trị là gì?"

Chốt: với mẫu modulo, giá trị là 0. Với mẫu bão hòa, giá trị giữ 15.

<!-- pagebreak -->

# Phút 41-50: FSM bằng Verilog-2001

## Ba phần của FSM

Một FSM dễ đọc thường tách thành:

1. State register: lưu trạng thái hiện tại tại cạnh clock.
2. Next-state logic: tính trạng thái kế tiếp từ state và input.
3. Output logic: tạo output từ state, hoặc từ state và input tùy loại FSM.

```verilog
module simple_controller (
    input  wire clk, rst, start, done,
    output reg  busy
);
    localparam IDLE = 1'b0, RUN = 1'b1;
    reg state, next_state;
    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    always @(*) begin
        next_state = state;
        busy = 1'b0;
        case (state)
            IDLE: begin
                if (start)
                    next_state = RUN;
            end
            RUN: begin
                busy = 1'b1;
                if (done)
                    next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
                busy = 1'b0;
            end
        endcase
    end
endmodule
```

## Đọc FSM theo ba câu hỏi

State được lưu ở đâu? Biến `state` được cập nhật trong `always @(posedge clk)`.

State đổi khi nào? Chỉ tại cạnh lên của `clk`, hoặc về `IDLE` khi reset được lấy mẫu.

Điều kiện transition là gì? Từ `IDLE` sang `RUN` khi `start=1`; từ `RUN` về `IDLE` khi `done=1`.

## Sơ đồ trạng thái tương ứng

```text
                 start=1
           +----------------->
        +------+           +-----+
        | IDLE |           | RUN |
        |busy=0|           |busy=1|
        +------+           +-----+
           ^                  |
           +------------------+
                 done=1
```

Khi không có điều kiện transition, `next_state = state` giữ FSM ở trạng thái hiện tại. Nhánh `default` đưa FSM về trạng thái an toàn nếu state có giá trị không được định nghĩa.

## Nhầm lẫn thường gặp

- Gán `state` trong cả khối clocked và khối tổ hợp, tạo multiple drivers.
- Không đặt `next_state = state` mặc định, làm suy ra latch.
- Quên reset state về một trạng thái hợp lệ.
- Dùng blocking để cập nhật state register.
- Trộn quá nhiều output và transition khiến khó thấy ownership của từng tín hiệu.

## Kiểm tra nhận thức

Hỏi: "Nếu FSM đang ở `RUN`, `done=0` và có một cạnh clock, state kế tiếp là gì?"

Chốt: vẫn là `RUN` vì mặc định `next_state = state` và không có điều kiện quay về `IDLE`.

# Phút 50-56: Tư duy RTL có thể tổng hợp

## Câu hỏi quan trọng nhất

Trước khi chấp nhận một đoạn RTL, hãy hỏi: "Tôi muốn công cụ tạo phần cứng nào?" Nếu không thể trả lời bằng dây, mux, cổng logic, bộ cộng, bộ so sánh, latch hoặc flip-flop, đoạn mã cần được xem lại.

## Những lỗi cần nhận ra

| Dấu hiệu trong mã | Điều có thể xảy ra | Cách viết an toàn trong bài học |
|---|---|---|
| Thiếu assignment ở một nhánh tổ hợp | Suy ra latch | Đặt mặc định và bao phủ mọi nhánh |
| Dùng `=` cho state trong khối clocked | Kết quả phụ thuộc thứ tự mô phỏng | Dùng `<=` cho thanh ghi |
| Dùng `<=` trong khối tổ hợp | Luồng tính khó đọc và dễ lệch mô phỏng | Dùng `=` trong `always @(*)` |
| Hai khối cùng gán một `reg` | Multiple drivers | Mỗi state chỉ có một owner |
| Literal không rõ độ rộng | Mất bit hoặc mở rộng ngoài ý muốn | Dùng literal có kích thước |
| Trộn signed và unsigned | So sánh hoặc mở rộng dấu sai ý định | Khai báo và chuyển đổi có chủ ý |
| Thiếu `default` trong `case` tổ hợp | Có đường không gán | Đặt mặc định trước `case` và thêm `default` |
| Dùng delay `#` trong RTL sản phẩm | Không biểu diễn phần cứng đồng bộ theo mẫu học | Chỉ dùng clock và điều kiện dữ liệu |
| Dùng `initial` để khởi tạo state | Khả năng tổng hợp phụ thuộc công nghệ | Khởi tạo state bằng reset |

## Cú pháp mô phỏng và RTL sản phẩm

Các lệnh như `#`, `$display` và `$finish` hữu ích trong môi trường mô phỏng. Chúng không thuộc tập con RTL sản phẩm của tiết học này. Sinh viên sẽ gặp chúng khi học kiểm chứng, nhưng không dùng chúng để mô tả datapath hoặc state machine ở đây.

## Signed và unsigned

Vector Verilog mặc định thường được đọc như unsigned nếu không khai báo khác. Khi xử lý số có dấu, phải thể hiện ý định bằng `signed` và kiểm tra cách mở rộng dấu. Trong bài học cấp tốc, quy tắc an toàn là không trộn hai cách biểu diễn trong cùng phép toán nếu chưa kiểm tra độ rộng và dấu.

## Checklist đọc một module RTL

1. Xác định cổng, độ rộng và hướng dữ liệu.
2. Khoanh mọi `assign`, đây là logic tổ hợp liên tục.
3. Khoanh mọi `always @(*)`, kiểm tra assignment đầy đủ.
4. Khoanh mọi khối theo cạnh clock, xác định state và reset.
5. Kiểm tra `=` với tổ hợp, `<=` với tuần tự.
6. Tìm mỗi tín hiệu được gán ở bao nhiêu nơi.
7. Kiểm tra literal, phép nối bit, lát cắt và độ rộng đích.
8. Với FSM, vẽ lại state và transition bằng một sơ đồ nhỏ.

# Phút 56-60: Tổng kết đứng lớp

## Sáu câu cần nói lại

1. RTL mô tả phần cứng hoạt động song song.
2. `wire` nhận kết nối hoặc continuous assignment; `reg` được gán trong procedural block.
3. Logic tổ hợp phải gán output trên mọi đường điều khiển.
4. State tuần tự chỉ đổi tại sự kiện clock đã khai báo.
5. Quy tắc nền tảng là tổ hợp dùng `=`, tuần tự dùng `<=`.
6. FSM gồm nơi lưu state và logic quyết định state kế tiếp.

## Kịch bản bốn phút cuối

Phút 56-58: đặt sáu câu hỏi ở cuối tài liệu, mỗi câu cho sinh viên suy nghĩ khoảng mười giây rồi gọi một câu trả lời ngắn.

Phút 58-59: chiếu bảng tra cứu một trang và chỉ cách đọc từ loại khối sang mẫu mã.

Phút 59-60: nhắc sinh viên khi đọc RTL hãy luôn chuyển mã trở lại thành hình dung phần cứng. Nếu chưa hình dung được mux, cổng hoặc thanh ghi tương ứng, chưa nên chuyển sang chi tiết tiếp theo.

<!-- pagebreak -->

## Bảng tra cứu Verilog-2001 một trang

| Mục đích | Mẫu tối thiểu | Phần cứng |
|---|---|---|
| Dây tổ hợp | `assign y = a & b;` | Cổng AND |
| Chọn dữ liệu | `assign y = sel ? b : a;` | Mux 2:1 |
| Tổ hợp nhiều nhánh | `always @(*) begin y=0; if(en) y=a; end` | Logic và mux, không latch |
| Thanh ghi | `always @(posedge clk) q <= d;` | Flip-flop |
| Reset đồng bộ | `if (rst) q <= 0; else q <= d;` | Reset qua mux vào D |
| Enable | `else if (en) q <= d;` | Mux hồi tiếp giữ state |
| State encoding | `localparam IDLE=1'b0, RUN=1'b1;` | Mã bit cho state |

| Thành phần | Ghi nhớ |
|---|---|
| `wire` | Được điều khiển bởi kết nối hoặc `assign` |
| `reg` | Được gán trong `always`; không tự động có nghĩa là flip-flop |
| `[7:0]` | Vector tám bit |
| `8'hA5` | Literal tám bit hệ mười sáu |
| `{a, b}` | Ghép các vector |
| `bus[7:4]` | Lấy một lát cắt |
| `=` | Dùng cho logic tổ hợp trong bài học |
| `<=` | Dùng cho state trong khối theo cạnh clock |

```verilog
always @(*) begin
    next = current;
    if (condition)
        next = value;
end

always @(posedge clk) begin
    if (rst)
        current <= RESET_VALUE;
    else
        current <= next;
end
```

Quy tắc tự kiểm: gán đủ trong tổ hợp, một owner cho mỗi state, literal đúng độ rộng, reset về trạng thái hợp lệ và luôn hình dung phần cứng được suy ra.

<!-- pagebreak -->

## Câu hỏi kiểm tra cuối tiết

### Câu 1

Câu hỏi: Hai `always @(posedge clk)` đặt liên tiếp trong file có chạy lần lượt như hai lệnh phần mềm không?

Đáp án: Không. Chúng mô tả các nhóm thanh ghi cùng lấy mẫu ở cạnh clock.

Giải thích: RTL biểu diễn phần cứng song song. Không được dùng vị trí trước sau của hai block để tạo thứ tự phần cứng.

### Câu 2

Câu hỏi: Output được gán bằng `assign` và output được gán trong `always @(*)` nên khai báo lần lượt là gì?

Đáp án: `wire` và `reg`.

Giải thích: Trong Verilog-2001, continuous assignment điều khiển net; procedural assignment cần biến kiểu `reg`.

### Câu 3

Câu hỏi: Đoạn mã tổ hợp chỉ gán `y=a` khi `en=1` nhưng không gán khi `en=0` có thể tạo phần cứng gì ngoài ý muốn?

Đáp án: Latch.

Giải thích: Muốn giữ giá trị cũ khi một nhánh không gán, mạch phải có bộ nhớ. Logic tổ hợp phải xác định output trên mọi đường.

### Câu 4

Câu hỏi: Trong thanh ghi có enable, nếu `en=0` qua nhiều cạnh clock thì output thay đổi thế nào?

Đáp án: Output giữ giá trị đã lưu.

Giải thích: Không gán trong nhánh clocked nghĩa là flip-flop giữ state, đây là hành vi tuần tự có chủ ý.

### Câu 5

Câu hỏi: Vì sao pipeline hai thanh ghi nên dùng nonblocking `<=`?

Đáp án: Để mọi thanh ghi lấy giá trị có trước cạnh clock và cập nhật kết quả cùng nhau.

Giải thích: Blocking `=` có thể làm dòng sau đọc giá trị vừa bị dòng trước thay đổi trong cùng procedural block.

### Câu 6

Câu hỏi: FSM đang ở `RUN`, `done=0`. Với `next_state = state` làm mặc định, state sau cạnh clock là gì?

Đáp án: Vẫn là `RUN`.

Giải thích: Không có điều kiện transition nào thay đổi `next_state`, nên state register nạp lại giá trị hiện tại.

## Kiến thức cần tự ôn trước bài thực hành

- [ ] Tôi giải thích được sự khác nhau giữa phần mềm tuần tự và RTL song song.
- [ ] Tôi đọc được tên module, hướng cổng và độ rộng vector.
- [ ] Tôi biết khi nào dùng `wire`, khi nào dùng `reg`.
- [ ] Tôi nhận ra `assign` và `always @(*)` là logic tổ hợp.
- [ ] Tôi kiểm tra được output tổ hợp có được gán trên mọi nhánh hay không.
- [ ] Tôi nhận ra khối theo cạnh clock và xác định state được lưu.
- [ ] Tôi phân biệt reset đồng bộ, reset bất đồng bộ và clock enable.
- [ ] Tôi nhớ quy tắc `=` cho tổ hợp và `<=` cho tuần tự.
- [ ] Tôi đọc được bộ đếm modulo và bộ đếm bão hòa.
- [ ] Tôi chỉ ra state register, next-state logic và transition của FSM.
- [ ] Tôi kiểm tra được literal, phép nối, lát cắt và độ rộng đích.
- [ ] Tôi phát hiện được latch ngoài ý muốn và multiple drivers.

Hoàn thành checklist nghĩa là sinh viên đã có nền tảng để bắt đầu đọc RTL đồng bộ và tiếp tục học phần kiểm chứng ở các buổi sau.
