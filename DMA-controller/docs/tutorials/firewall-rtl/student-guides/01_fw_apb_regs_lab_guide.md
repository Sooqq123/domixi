---
title: Secure APB register bank và fault logger
subtitle: Hướng dẫn thực hành từ giao thức APB đến unit test tự kiểm tra
version: Kiến trúc chuẩn V2.4.1
---

# 1. Bài toán và sản phẩm cần nộp

`fw_apb_regs` là control plane của Firewall. Module nhận cấu hình từ CPU qua APB4, lưu policy của các region tĩnh, hiển thị region động, ghi nhận fault và phát `sec_irq`. Module không quyết định một burst có được phép hay không. Quyết định đó thuộc `fw_acl_matcher`.

Sau bài thực hành, sinh viên phải tự giải thích được bốn câu hỏi:

1. Một APB access được chấp nhận tại cạnh clock nào?
2. Thanh ghi nào do phần mềm sở hữu, thanh ghi nào do phần cứng sở hữu?
3. Khi W1C và fault mới xảy ra cùng cạnh, giá trị nào thắng?
4. Khi `FW_LOCK=1`, phần mềm còn được phép làm những việc gì?

Sản phẩm cần nộp gồm:

- `fw_apb_regs.v` hoặc `fw_apb_regs.sv` tổng hợp được.
- `tb_fw_apb_regs.sv` tự báo PASS hoặc FAIL và có timeout.
- Một log mô phỏng sạch.
- Hai waveform đại diện: hardware-set cùng W1C và ba fault cùng chu kỳ.
- Một trang ghi chú giải thích state ownership và thứ tự ưu tiên.

> [ĐẶC TẢ] Nguồn chuẩn của bài là `register_map.csv`, `pinout.csv`, `signal_list.csv`, `architecture_overview.md`, `firewall_rtl_integration_contract.md` và `verification_test_plan.md` trong `DMA-controller/docs/architecture/`.

## 1.1. Cách dùng tài liệu

Đọc phần 2 đến phần 7 trước khi viết RTL. Sau mỗi mốc trong phần 8, chạy một nhóm test nhỏ. Khi một test sai, dùng phần 12 để xác định lỗi theo symptom. Không thêm tính năng ngoài profile, vì mỗi tính năng ngoài hợp đồng làm tăng số trạng thái phải chứng minh.

Tài liệu dùng ba nhãn:

| Nhãn | Ý nghĩa |
|---|---|
| ĐẶC TẢ | Hành vi bắt buộc lấy từ kiến trúc V2.4.1 |
| HƯỚNG DẪN | Cách chia module hoặc cách debug được đề nghị |
| BÀI TẬP | Phần sinh viên phải tự hoàn thiện hoặc chứng minh |

<!-- pagebreak -->

# 2. APB từ con số 0

APB là bus điều khiển đơn giản. Một transfer có hai phase liên tiếp. Setup phase đặt địa chỉ, hướng và dữ liệu. Access phase giữ các tín hiệu đó ổn định và bật `PENABLE`.

```text
Chu kỳ       C0          C1          C2
PSEL         0           1           1
PENABLE      0           0           1
PADDR        X         hợp lệ      giữ nguyên
PWRITE       X         hợp lệ      giữ nguyên
PWDATA       X       dữ liệu ghi   giữ nguyên
PREADY       1           1           1
PSLVERR      0           0        kết quả access

             idle      setup       access và hoàn tất
```

Profile của bài đặt `PREADY=1`. Access vì vậy hoàn tất ở cạnh clock có đồng thời `PSEL=1` và `PENABLE=1`. `PREADY=1` chỉ nói slave không chèn wait state. Nó không nói access hợp lệ. `PSLVERR=1` vẫn có thể xuất hiện trong access phase.

Các biểu thức nền tảng:

```systemverilog
wire apb_setup  = s_apb_psel && !s_apb_penable;
wire apb_access = s_apb_psel &&  s_apb_penable;
wire apb_write  = apb_access && s_apb_pwrite;
wire apb_read   = apb_access && !s_apb_pwrite;
```

## 2.1. Ready, error và read data

`s_apb_pready` luôn bằng 1 sau reset theo contract. Trong access phase:

- Access hợp lệ: `PSLVERR=0`; read trả dữ liệu hoặc write cập nhật state tại cạnh clock.
- Access không hợp lệ: `PSLVERR=1`, `PRDATA=0`, write không được thay đổi state.
- Ngoài access phase: giữ `PSLVERR=0`; `PRDATA` có thể giữ 0 để waveform dễ đọc.

Không ghi thanh ghi ở setup phase. Nếu update ở setup phase, master có thể giữ `PSEL` qua hai transfer và module sẽ ghi sai số lần.

## 2.2. Protection attribute

Firewall APB chỉ chấp nhận Secure-Privileged access:

```text
secure_privileged = (PPROT[1] == 0) và (PPROT[0] == 1)
```

`PPROT[2]` phân loại instruction hoặc data nhưng baseline không dùng bit này để cho phép access. Hai trường hợp sau phải bị chặn:

| Trường hợp | PPROT[1] | PPROT[0] | Kết quả |
|---|---:|---:|---|
| Secure, Privileged | 0 | 1 | Có thể tiếp tục kiểm địa chỉ |
| Non-Secure | 1 | X | `PSLVERR=1` |
| Unprivileged | X | 0 | `PSLVERR=1` |

## 2.3. Address decode

Firewall nằm trong cửa sổ MMIO 256 byte. Register hợp lệ dùng offset `0x000` đến `0x09C`. Mọi access phải căn chỉnh 4 byte. Địa chỉ ngoài map hoặc `PADDR[1:0] != 0` trả `PSLVERR=1` và `PRDATA=0`.

Nếu top-level đã trừ base address, module nhận offset thấp. Nếu module nhận địa chỉ hệ thống đầy đủ, top-level phải chốt rõ cách tính offset. Unit test nên điều khiển trực tiếp offset để chỉ kiểm logic register bank.

> [CẢNH BÁO] Không decode bằng riêng `PADDR[7:0]` nếu interface vẫn nhận địa chỉ hệ thống đầy đủ mà chưa kiểm base. Hai địa chỉ ở hai aperture khác nhau có thể alias cùng offset thấp.

<!-- pagebreak -->

# 3. Register semantics

Một register bank đúng cần phân biệt kiểu truy cập. Tên kiểu không phải nhãn trang trí; nó quyết định phương trình next-state.

| Kiểu | Phần mềm đọc | Phần mềm ghi | Phần cứng cập nhật |
|---|---|---|---|
| RW | Đọc state | Ghi giá trị mới | Có nếu contract cho phép |
| RO | Đọc state | Ghi trả lỗi nếu cả register là RO | Có thể |
| RW1S | Đọc state | Ghi 1 để set, ghi 0 không đổi | Reset mới clear |
| W1C | Đọc state | Ghi 1 để clear, ghi 0 không đổi | Fault event set |
| RAZ/WI | Luôn đọc 0 | Bit ghi bị bỏ qua | Không |

## 3.1. `FW_CONTROL` tại `0x000`

Reset toàn register bằng `32'h0000_000D`.

| Bit | Field | Reset | Quy tắc |
|---:|---|---:|---|
| 0 | `FW_EN` | 1 | Bật ACL default deny |
| 1 | `IRQ_EN` | 0 | Cho phép `sec_irq` |
| 2 | `AUTO_CTX_EN` | 1 | Cho phép context tracker cấp Region 4 và 5 |
| 3 | `ERR_MODE` | 1 | 1 trả DECERR, 0 trả OKAY honeypot |
| 31:4 | reserved | 0 | Read-as-zero, write-ignored |

`FW_EN=0` chỉ bypass ACL permission cho quản trị Secure-Privileged. Nó không tắt kiểm tra profile, overflow, crossing 4 KiB, framing hoặc fault logging.

Khi accepted write đổi `AUTO_CTX_EN` từ 1 xuống 0, context tracker phải xóa Region 4 và 5 tại cạnh đó. `fw_apb_regs` phải xuất event hoặc next value đủ rõ để tracker áp dụng priority. Re-enable không khôi phục descriptor đã xóa.

## 3.2. `FW_LOCK` tại `0x004`

Bit 0 là RW1S:

```text
lock_next = lock_current OR accepted_write_data[0]
```

Ghi 0 không clear. Khi bit đã bằng 1, ghi tiếp vào chính `FW_LOCK` là no-op thành công và bit giữ 1. Chỉ reset clear bit.

Lock bảo vệ `FW_CONTROL` và static Region 0 đến 3, 6 đến 7. Fault status vẫn clear được. Region 4 và 5 do hardware sở hữu và luôn RO qua APB.

## 3.3. `FAULT_STATUS` tại `0x008`

| Bit | Field | Nguồn set | Cách clear |
|---:|---|---|---|
| 0 | `READ_ERR` | Read fault record | W1C |
| 1 | `WRITE_ERR` | Write fault record | W1C |
| 2 | `PROT_ERR` | PROT hoặc framing fault | W1C |
| 3 | `BOUND_ERR` | Profile, range, overflow hoặc containment | W1C |
| 31 | `IRQ_PENDING` | Bất kỳ fault record | W1C riêng |

Phương trình một bit W1C có hardware-set ưu tiên:

```text
clear_mask = accepted_write_to_fault_status ? PWDATA : 0
event_bits = OR của code từ mọi record hợp lệ

status_next = (status_current AND NOT clear_mask) OR event_bits
irq_next    = (irq_current AND NOT clear_mask[31]) OR any_event
```

Nếu software clear và hardware set cùng cạnh, bit sau cạnh bằng 1.

## 3.4. Fault metadata và first-fault capture

Metadata nằm tại:

| Offset | Register | Nội dung |
|---:|---|---|
| `0x00C` | `FAULT_ADDR` | Địa chỉ first fault |
| `0x010` | `FAULT_INFO` | MID, LEN, SIZE, TYPE và count |
| `0x014` | `FAULT_TIMESTAMP` | Cycle counter khi capture |
| `0x018` | `FAULT_SOURCE` | Source và code của record được chọn |

Logger có ba record độc lập: context, write và read. Trong một chu kỳ:

- Status OR code của mọi record.
- Count tăng bằng số record hợp lệ, từ 0 đến 3.
- Count bão hòa tại `16'hFFFF`.
- Nếu capture đang mở, metadata chọn `context > write > read`.
- Khi capture đã khóa, fault mới vẫn cập nhật status và count nhưng không ghi đè metadata.

Capture mở lại khi toàn bộ fault bits và `IRQ_PENDING` đã được clear. Metadata cũ vẫn giữ cho tới record kế tiếp.

> [CẢNH BÁO] `signal_list.csv` hiện liệt kê code, address và ID cho mỗi event nhưng `FAULT_INFO` còn cần LEN và SIZE. Unit interface phải mang hai field này trong event record hoặc nhận chúng từ snapshot bundle. Không thể hiện thực đầy đủ register map nếu interface bỏ hai field. Sinh viên phải ghi rõ lựa chọn interface trong báo cáo.

## 3.5. Region descriptors

Mỗi region chiếm stride `0x10`:

```text
BASE(i)  = 0x020 + 0x10*i
LIMIT(i) = BASE(i) + 0x04
PERM(i)  = BASE(i) + 0x08
MID(i)   = BASE(i) + 0x0C
```

Region 0 đến 3 và 6 đến 7 là static. Chỉ sửa descriptor khi `ACTIVE=0`. Ghi `ACTIVE=1` chỉ thành công khi `BASE <= LIMIT`. Nếu region active, ghi BASE, LIMIT, PERM hoặc MID trả `PSLVERR=1` và không đổi state.

Region 4 là dynamic read-only. Region 5 là dynamic write-only. Mọi register của hai region là RO qua APB. Ghi vào chúng trả `PSLVERR=1`.

| PERM bit | Ý nghĩa |
|---:|---|
| 0 | `READ_EN` |
| 1 | `WRITE_EN` |
| 2 | `SECURE_ONLY` |
| 3 | `PRIV_ONLY` |
| 31 | `ACTIVE` |

MID register dùng bits 3:0 cho whitelist ID và bits 7:4 cho mask. Reserved bits đọc 0 và bị bỏ qua khi ghi một register hợp lệ.

<!-- pagebreak -->

# 4. Ranh giới module và state ownership

Một thiết kế dễ kiểm chứng chia dữ liệu thành ba nhóm:

| Nhóm | Owner | Ví dụ |
|---|---|---|
| State phần mềm | `fw_apb_regs` | control, lock, static region |
| State hardware | module chuyên trách | dynamic Region 4 và 5 |
| Event và log state | `fw_apb_regs` | fault status, metadata, count, IRQ |

`fw_apb_regs` nên nhận dynamic region dưới dạng input readback. Nó không nên tự suy ra descriptor từ `dma_ctx_valid`, vì context tracker sở hữu one-shot allocation và revoke priority.

## 4.1. Port contract gợi ý cho unit lab

Đây là boundary dùng cho bài thực hành. Tên cuối phải được đối chiếu với `pinout.csv` và `signal_list.csv` khi tích hợp.

```systemverilog
module fw_apb_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [ADDR_WIDTH-1:0] s_apb_paddr,
    input  wire                  s_apb_psel,
    input  wire                  s_apb_penable,
    input  wire                  s_apb_pwrite,
    input  wire [DATA_WIDTH-1:0] s_apb_pwdata,
    input  wire [2:0]            s_apb_pprot,
    output wire [DATA_WIDTH-1:0] s_apb_prdata,
    output wire                  s_apb_pready,
    output wire                  s_apb_pslverr,

    input  wire                  r_fault_event_valid,
    input  wire [3:0]            r_fault_event_code,
    input  wire [31:0]           r_fault_event_addr,
    input  wire [3:0]            r_fault_event_id,
    input  wire [7:0]            r_fault_event_len,
    input  wire [2:0]            r_fault_event_size,

    input  wire                  w_fault_event_valid,
    input  wire [3:0]            w_fault_event_code,
    input  wire [31:0]           w_fault_event_addr,
    input  wire [3:0]            w_fault_event_id,
    input  wire [7:0]            w_fault_event_len,
    input  wire [2:0]            w_fault_event_size,

    input  wire                  ctx_fault_event_valid,
    input  wire [3:0]            ctx_fault_event_code,
    input  wire [31:0]           ctx_fault_event_addr,

    output wire                  fw_en,
    output wire                  irq_en,
    output wire                  auto_ctx_en,
    output wire                  err_mode,
    output wire                  sec_irq
    // Static region arrays và dynamic readback nối theo integration wrapper.
);
```

> [BÀI TẬP] Bổ sung port cho sáu static region và readback Region 4, 5. Chọn packed arrays nếu dùng SystemVerilog hoặc các port phẳng nếu dùng Verilog-2001. Ghi lựa chọn trong báo cáo.

## 4.2. Invariant phải viết trước RTL

1. APB write chỉ thay đổi state trên accepted access hợp lệ.
2. Access bị lỗi không thay đổi bất kỳ state nào.
3. Lock không chuyển từ 1 về 0 khi chưa reset.
4. Region active không đổi descriptor qua APB.
5. Region 4 và 5 không đổi qua APB.
6. Hardware fault set thắng W1C cùng cạnh.
7. Count không wrap sau `16'hFFFF`.
8. Metadata giữ ổn định khi capture khóa.
9. `sec_irq = irq_en && irq_pending`.
10. Reserved bit luôn đọc 0.

<!-- pagebreak -->

# 5. Kiến trúc RTL được đề nghị

Chia module thành bốn phần trong cùng file:

```text
APB inputs
   |
   v
[access classifier] ---> valid/error/write/read
   |                         |
   |                         +----> read mux
   v
[software write intent]
   |
   v
[next-state logic] <--- fault records và dynamic readback
   |
   v
[sequential state]
   |
   +----> control, static regions, logger, sec_irq
```

## 5.1. Access classifier

Tạo các tín hiệu tổ hợp:

```systemverilog
wire access_phase = s_apb_psel && s_apb_penable;
wire aligned      = (s_apb_paddr[1:0] == 2'b00);
wire secure_priv  = !s_apb_pprot[1] && s_apb_pprot[0];
wire offset_known = /* decode toàn register hợp lệ */;
wire access_ok    = access_phase && aligned && secure_priv && offset_known;
```

`offset_known` chưa đủ để cho write. Write còn phải qua access policy của register: RO, lock, active guard và activation validity.

## 5.2. Read mux

Read mux là logic tổ hợp. Mặc định `PRDATA=0`. Mỗi offset hợp lệ chọn đúng state. Reserved bits không được copy từ `PWDATA`; chúng luôn đọc 0.

```systemverilog
always @* begin
    prdata_next = 32'h0;
    case (offset)
        8'h00: prdata_next = {28'h0, err_mode, auto_ctx_en, irq_en, fw_en};
        8'h04: prdata_next = {31'h0, sticky_lock};
        // Sinh viên ánh xạ fault và region registers theo register_map.csv.
        default: prdata_next = 32'h0;
    endcase
end
```

## 5.3. Next-state

Next-state bắt đầu bằng giá trị hiện tại. Sau đó áp dụng software clear/write hợp lệ. Cuối cùng áp dụng hardware event để bảo đảm hardware-set thắng W1C.

```text
next = current

if accepted software write:
    apply RW, RW1S hoặc W1C intent

apply hardware fault records:
    OR status bits
    set IRQ_PENDING
    saturating add count
    capture metadata nếu capture mở
```

Không dựa vào việc một nonblocking assignment nằm thấp hơn trong file. Viết phương trình next-state làm priority nhìn thấy được trong review.

## 5.4. Saturating add

Số record mới mỗi chu kỳ là tổng ba bit valid, có miền 0 đến 3.

```text
new_records = ctx_valid + write_valid + read_valid

if fault_count > 0xFFFF - new_records:
    count_next = 0xFFFF
else:
    count_next = fault_count + new_records
```

Dùng biểu thức mở rộng 17 bit cũng hợp lệ. Test phải chứa `0xFFFE + 3` và `0xFFFF + 1`.

## 5.5. Reset

Reset assert không đồng bộ và deassert đồng bộ do hạ tầng cung cấp. Trong module:

- `FW_CONTROL = 0x0000_000D`.
- `FW_LOCK = 0`.
- Static regions inactive, các field bằng 0.
- Fault status, metadata, count, timestamp và capture state bằng 0 hoặc trạng thái mở theo phương trình thiết kế.
- `sec_irq=0`.

<!-- pagebreak -->

# 6. Lộ trình hiện thực theo mốc

## Mốc 1: APB shell

Chỉ hiện thực `PREADY=1`, access classifier, `PSLVERR` và `PRDATA=0`. Viết test valid setup/access, misaligned, invalid offset, Non-Secure và Unprivileged. Chưa thêm register state.

Exit nhỏ: mọi access lỗi trả `PSLVERR=1` đúng access phase và không báo lỗi ở setup phase.

## Mốc 2: Control và lock

Thêm `FW_CONTROL`, `FW_LOCK`, readback và reset. Test từng bit, reserved bits, RW1S, write sau lock và read sau lock.

Exit nhỏ: lock set một lần và không thể clear bằng write.

## Mốc 3: Một static region

Hiện thực Region 0 trước. Test BASE, LIMIT, PERM, MID, activate hợp lệ, activate với `BASE>LIMIT`, write khi active và deactivate. Sau khi sạch, nhân bản bằng arrays hoặc generate cho Region 1 đến 3, 6 và 7.

Exit nhỏ: loop test đi qua mọi static region, không viết sáu test copy-paste khác nhau.

## Mốc 4: Dynamic readback

Nối Region 4 và 5 làm input read-only. Test mọi write trả `PSLVERR=1`, read phản ánh input hardware.

## Mốc 5: Fault status và IRQ

Hiện thực W1C, event set và `sec_irq`. Test clear fault bits không tự clear IRQ_PENDING. Test IRQ_EN tắt làm `sec_irq=0` nhưng không xóa pending.

## Mốc 6: Metadata, count và priority

Thêm cycle counter, capture lock, three-source priority và saturating count. Test từng source, hai source, ba source, capture locked, recapture và hardware-set cùng W1C.

<!-- pagebreak -->

# 7. Self-checking testbench từ con số 0

Testbench tốt không yêu cầu nhìn waveform để biết PASS. Waveform chỉ dùng để chẩn đoán khi checker báo lỗi.

## 7.1. Clock, reset và timeout

```systemverilog
initial clk = 1'b0;
always #5 clk = ~clk;

task apply_reset;
begin
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
end
endtask

initial begin
    repeat (5000) @(posedge clk);
    $fatal(1, "TIMEOUT: tb_fw_apb_regs không kết thúc");
end
```

## 7.2. APB write task

Task phải tạo setup rồi access. Giữ payload ổn định qua hai phase.

```systemverilog
task apb_write;
    input [31:0] addr;
    input [31:0] data;
    input [2:0]  prot;
    output       got_error;
begin
    @(negedge clk);
    s_apb_psel   = 1'b1;
    s_apb_penable= 1'b0;
    s_apb_pwrite = 1'b1;
    s_apb_paddr  = addr;
    s_apb_pwdata = data;
    s_apb_pprot  = prot;

    @(negedge clk);
    s_apb_penable= 1'b1;
    @(posedge clk);
    got_error = s_apb_pslverr;

    @(negedge clk);
    s_apb_psel   = 1'b0;
    s_apb_penable= 1'b0;
    s_apb_pwrite = 1'b0;
end
endtask
```

Viết `apb_read` tương tự và trả cả `PRDATA` lẫn `PSLVERR`.

## 7.3. Checker

```systemverilog
integer errors = 0;

task expect32;
    input [8*48-1:0] name;
    input [31:0] got;
    input [31:0] expected;
begin
    if (got !== expected) begin
        $display("FAIL %-48s got=%08h expected=%08h", name, got, expected);
        errors = errors + 1;
    end else begin
        $display("PASS %-48s value=%08h", name, got);
    end
end
endtask
```

Kết thúc test:

```systemverilog
if (errors == 0) begin
    $display("TB PASS");
    $finish;
end else begin
    $fatal(1, "TB FAIL: %0d lỗi", errors);
end
```

## 7.4. Phát fault event

Event valid nên là xung một chu kỳ. Set payload trước cạnh lấy mẫu, assert valid qua cạnh, rồi hạ sau cạnh.

```systemverilog
task pulse_write_fault;
    input [3:0] code;
    input [31:0] addr;
begin
    @(negedge clk);
    w_fault_event_code  = code;
    w_fault_event_addr  = addr;
    w_fault_event_valid = 1'b1;
    @(posedge clk);
    @(negedge clk);
    w_fault_event_valid = 1'b0;
end
endtask
```

Để tạo simultaneous faults, set cả ba valid trong cùng negedge và giữ qua cùng posedge.

<!-- pagebreak -->

# 8. Ma trận test bắt buộc

| ID | Stimulus | Expected result |
|---|---|---|
| APB-RST-01 | Reset rồi đọc toàn map | Control `0xD`, lock/fault/regions reset đúng |
| APB-SEC-01 | `PPROT[1]=1` | Error, read 0, write không đổi state |
| APB-SEC-02 | `PPROT[0]=0` | Error, read 0, write không đổi state |
| APB-ADR-01 | Address misaligned | Error và không alias |
| APB-ADR-02 | Offset trên `0x09C` | Error, PRDATA 0 |
| APB-RSV-01 | Ghi 1 vào reserved bits của RW register | Field hợp lệ đổi, reserved đọc 0 |
| APB-RO-01 | Ghi metadata RO | Error, state không đổi |
| APB-RO-02 | Ghi Region 4 hoặc 5 | Error, dynamic readback không đổi |
| APB-LCK-01 | Ghi lock bit 1 | Lock set |
| APB-LCK-02 | Ghi lock bit 0 sau khi set | Lock giữ 1 |
| APB-LCK-03 | Ghi control/static region sau lock | Error, state giữ nguyên |
| APB-RGN-01 | Activate với BASE nhỏ hơn LIMIT | ACTIVE set |
| APB-RGN-02 | Activate với BASE lớn hơn LIMIT | Error, ACTIVE giữ 0 |
| APB-RGN-03 | Ghi descriptor khi ACTIVE=1 | Error, descriptor giữ nguyên |
| APB-W1C-01 | Fault set rồi ghi 1 clear một bit | Chỉ bit được chọn clear |
| APB-W1C-02 | Clear fault bits nhưng không clear bit 31 | IRQ_PENDING giữ 1 |
| APB-CON-01 | W1C và cùng bit hardware-set một cạnh | Bit sau cạnh bằng 1 |
| APB-CON-02 | Read, write, context cùng cạnh | Status OR, count +3, metadata chọn context |
| APB-CNT-01 | Count `0xFFFE`, nhận ba record | Count bão hòa `0xFFFF` |
| APB-CAP-01 | Fault mới khi capture khóa | Metadata cũ giữ, count tăng |
| APB-CAP-02 | Clear toàn bộ rồi tạo fault mới | Metadata recapture record mới |
| APB-IRQ-01 | Pending 1, IRQ_EN 0 rồi 1 | `sec_irq` theo phép AND, pending không mất |

## 8.1. Coverage tối thiểu

Sinh viên có thể không dùng covergroup, nhưng test matrix phải chỉ ra bằng chứng cho:

- Mọi register offset hợp lệ.
- Mọi kiểu access RW, RO, RW1S, W1C và RAZ/WI.
- Sáu static regions và hai dynamic regions.
- Ba nguồn fault riêng và đồng thời.
- Count increment 0, 1, 2, 3 và saturation.
- Capture open, capture locked và recapture.

<!-- pagebreak -->

# 9. Assertions và checker gợi ý

Nếu simulator hỗ trợ SVA, thêm các property sau. Nếu không, viết checker thủ tục tại mỗi posedge.

```systemverilog
property p_lock_sticky;
    @(posedge clk) disable iff (!rst_n)
    sticky_lock |=> sticky_lock;
endproperty

property p_sec_irq_formula;
    @(posedge clk) disable iff (!rst_n)
    sec_irq == (irq_en && irq_pending);
endproperty

property p_error_access_no_write;
    @(posedge clk) disable iff (!rst_n)
    (s_apb_psel && s_apb_penable && s_apb_pwrite && s_apb_pslverr)
    |=> $stable(fw_control_state);
endproperty
```

Property cuối chỉ kiểm một state ví dụ. Unit test hoàn chỉnh phải kiểm tất cả state có thể bị write.

# 10. Debug theo triệu chứng

## `PSLVERR` lên ở setup phase

Kiểm biểu thức output có dùng `PSEL` mà thiếu `PENABLE` hay không. Error chỉ có ý nghĩa trong access phase.

## Một APB write cập nhật hai lần

Kiểm sequential block có update khi `PSEL=1` ở cả setup và access hay không. Điều kiện update phải chứa `PENABLE=1`.

## Lock set nhưng control vẫn đổi

Kiểm write permission được tính trước khi cập nhật control. Đừng chỉ mask readback; state thật phải giữ nguyên và access phải trả error.

## W1C làm mất fault cùng cạnh

Quan sát `clear_mask`, `event_bits`, `status_current` và `status_next`. Nếu code dùng hai nonblocking assignment vào cùng register, chuyển sang phương trình next-state rõ ràng.

## Fault count wrap về 0

Kiểm độ rộng phép cộng. Dùng 17 bit hoặc so sánh trước cộng. Test tại `0xFFFE` và `0xFFFF`.

## Metadata bị ghi đè bởi fault thứ hai

Kiểm capture lock. Status và count luôn cập nhật, metadata chỉ cập nhật khi capture mở.

## Region active vẫn nhận write

Tách `offset_known` khỏi `write_allowed`. Decode đúng offset không có nghĩa write được phép.

<!-- pagebreak -->

# 11. Câu hỏi tự kiểm tra và đáp án

## Câu 1

Vì sao `PREADY=1` không có nghĩa access thành công?

Đáp án: `PREADY` chỉ kết thúc access mà không chèn wait state. `PSLVERR` báo access có hợp lệ hay không. Một access có thể hoàn tất với `PREADY=1` và thất bại với `PSLVERR=1`.

## Câu 2

W1C và RW1S khác nhau thế nào?

Đáp án: W1C ghi 1 để clear bit đang set. RW1S ghi 1 để set bit và software không clear được. `FAULT_STATUS` dùng W1C; `FW_LOCK` dùng RW1S.

## Câu 3

Nếu software clear `READ_ERR` và read fault mới đến cùng cạnh, bit sau cạnh bằng gì?

Đáp án: bằng 1, vì hardware-set thắng W1C.

## Câu 4

Vì sao clear fault status không xóa metadata ngay?

Đáp án: metadata giữ bằng chứng first fault cho tới fault kế tiếp. Clear toàn bộ status và pending chỉ mở lại quyền capture.

## Câu 5

Tại sao Region 4 và 5 phải RO qua APB?

Đáp án: context tracker sở hữu hai descriptor động. Cho software ghi đồng thời sẽ tạo hai owner cho cùng state và phá one-shot allocation cùng revoke priority.

## Câu 6

Nếu `IRQ_EN=0` trong khi `IRQ_PENDING=1`, `sec_irq` và pending bằng gì?

Đáp án: `sec_irq=0`, pending vẫn bằng 1. Bật lại IRQ_EN sẽ làm `sec_irq=1` nếu pending chưa được W1C.

# 12. Rubric và exit gate

| Hạng mục | Điểm | Điều kiện đạt trọn điểm |
|---|---:|---|
| Hiểu APB và register semantics | 2.0 | Giải thích đúng access edge, RW1S, W1C và RO |
| RTL state ownership | 2.0 | Decode, next-state, read mux và sequential state tách rõ |
| Lock và region guard | 1.5 | Lock một chiều, active guard, dynamic RO đúng |
| Fault logger | 2.0 | Multi-event, priority, saturation, capture và IRQ đúng |
| Verification | 2.0 | Self-checking, timeout, negative tests và concurrent tests |
| Bằng chứng và giải thích | 0.5 | Log, waveform, source revision và ghi chú ngắn gọn |

Exit gate:

- Compile và elaborate không warning về width, latch hoặc implicit net.
- Toàn bộ test trong ma trận bắt buộc PASS.
- Không có writable reserved bit.
- Hardware-set thắng W1C được chứng minh bằng checker.
- Sinh viên trả lời được sáu câu tự kiểm tra mà không mở RTL.

# 13. Checklist nộp bài

- [ ] RTL module và mọi package hoặc include cần thiết.
- [ ] Self-checking testbench có timeout.
- [ ] Script hoặc lệnh compile chính xác.
- [ ] Log PASS sạch.
- [ ] Waveform hardware-set cùng W1C.
- [ ] Waveform ba fault cùng chu kỳ.
- [ ] Bảng map port unit lab sang `pinout.csv` và `signal_list.csv`.
- [ ] Ghi chú về cách mang LEN và SIZE vào fault event record.
- [ ] Không thay đổi register offset hoặc reset value.

# 14. Tài liệu nguồn

- `DMA-controller/docs/architecture/register_map.csv`
- `DMA-controller/docs/architecture/pinout.csv`
- `DMA-controller/docs/architecture/signal_list.csv`
- `DMA-controller/docs/architecture/architecture_overview.md`, mục 5.3 và 5.4
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`, mục 4.4 và invariant 10
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/lessons/bai-03-fw-apb-regs.html`
