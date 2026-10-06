---
title: Denied-read response generator
subtitle: Hướng dẫn thực hành AXI read drain, backpressure và RLAST chính xác
version: Kiến trúc chuẩn V2.4.1
---

# 1. Bài toán và sản phẩm cần nộp

Read drain xử lý một AR request đã bị Firewall từ chối. Nó không phát AR tới matrix. Thay vào đó, module tự sinh đúng `ARLEN+1` R beat local với dữ liệu 0 và response DECERR hoặc OKAY honeypot.

Module phải thỏa hai mục tiêu:

- Isolation: denied read không tạo matrix-side access.
- Protocol completion: DMA nhận đủ số R beat đã cam kết, với RID và RLAST đúng.

Sau bài thực hành, sinh viên phải giải thích được:

1. Vì sao final beat index bằng ARLEN?
2. Counter tăng ở điều kiện nào?
3. Tại sao RLAST phải giữ nguyên khi RREADY=0?
4. ERR_MODE thay đổi sau acceptance có ảnh hưởng burst hiện tại không?

Sản phẩm cần nộp:

- RTL read drain tổng hợp được.
- `tb_fw_read_drain.sv` tự kiểm tra và có timeout.
- Log PASS.
- Waveform LEN 15 với backpressure ngẫu nhiên.
- Waveform stall tại final beat.

> [ĐẶC TẢ] Nguồn chuẩn là `fsm_specification.md` mục 4, `signal_list.csv` drain interface, `firewall_rtl_integration_contract.md` invariant 7 và 8, cùng `verification_test_plan.md`.

<!-- pagebreak -->

# 2. AXI read từ con số 0

Một AXI read transaction dùng hai channel:

```text
AR: địa chỉ, ID và thuộc tính burst
R : dữ liệu, ID, response và cờ final beat
```

Firewall đã xử lý AR trước khi read drain hoạt động. `acl_r_fault` là xung báo một denied AR snapshot đã được chấp nhận và owner thuộc drain.

## 2.1. Ready/valid

Một R transfer xảy ra tại cạnh clock khi:

```text
r_handshake = RVALID && RREADY
```

Read drain là source của R channel. Nó sở hữu `RVALID`, `RID`, `RDATA`, `RRESP` và `RLAST`. DMA sở hữu `RREADY`.

Khi `RVALID=1` và `RREADY=0`, source phải giữ toàn bộ payload ổn định. Không chỉ RDATA, cả RID, RRESP và RLAST đều phải giữ.

## 2.2. ARLEN

ARLEN dùng beats-minus-one:

| ARLEN | Số R beat | Final index |
|---:|---:|---:|
| 0 | 1 | 0 |
| 1 | 2 | 1 |
| 3 | 4 | 3 |
| 15 | 16 | 15 |

Nếu generator counter bắt đầu từ 0:

```text
RLAST = (r_gen_count == latched_arlen)
```

Counter chỉ tăng sau R handshake không phải final. Sau final handshake, FSM về IDLE.

## 2.3. Local response payload

```text
RID   = accepted ARID snapshot
RDATA = 32'h0000_0000
RRESP = ERR_MODE ? 2'b11 : 2'b00
RLAST = count == ARLEN
```

`2'b11` là DECERR. `2'b00` là OKAY honeypot. Honeypot không cho phép request đi tới matrix và không tắt fault logging.

## 2.4. Wall-clock time và progress

Số chu kỳ hoàn tất phụ thuộc RREADY. Nếu DMA giữ RREADY=0 vô hạn, read drain giữ beat hiện tại vô hạn. Module không có timeout để tự bỏ beat hoặc tự hoàn tất một AXI response chưa handshake.

Testbench có timeout để phát hiện môi trường không tiến triển. Timeout thuộc verification environment, không thuộc protocol completion logic.

<!-- pagebreak -->

# 3. Ownership và ranh giới module

Matcher cấp denied owner bằng bundle:

| Input | Độ rộng | Ý nghĩa |
|---|---:|---|
| `acl_r_fault` | 1 | Xung nhận denied owner |
| `acl_r_id` | 4 | ARID snapshot |
| `acl_r_len` | 8 | ARLEN snapshot |
| `acl_r_err_mode` | 1 | Response mode snapshot |
| `r_drain_rready` | 1 | RREADY từ DMA |

Read drain phát:

| Output | Độ rộng | Ý nghĩa |
|---|---:|---|
| `r_drain_rvalid` | 1 | Local R beat hợp lệ |
| `r_drain_rid` | 4 | ID đã snapshot |
| `r_drain_rdata` | 32 | Dữ liệu 0 |
| `r_drain_rresp` | 2 | DECERR hoặc OKAY |
| `r_drain_rlast` | 1 | Final beat theo ARLEN |

Read drain không nhận ARADDR vì response generation không cần địa chỉ. Fault logger đã nhận address và code từ matcher ở address phase.

## 3.1. Snapshot bắt buộc

Khi `acl_r_fault=1` ở IDLE, chốt:

- ARID.
- ARLEN.
- ERR_MODE.

Không đọc live AR bus trong GEN. APB có thể đổi ERR_MODE trong khi RREADY stall; burst hiện tại vẫn dùng mode snapshot.

## 3.2. Single owner

Module chỉ giữ một denied read owner. Khi ở GEN, top-level phải giữ request thứ hai. Có thể expose `r_drain_busy` hoặc `acl_r_fault_ready`.

> [BÀI TẬP] Vẽ owner lifecycle từ `acl_r_fault` đến final R handshake. Ghi điều kiện duy nhất làm owner được giải phóng.

## 3.3. Isolation boundary

Read drain không có output AR hướng matrix. `fw_data_path_mux` chịu trách nhiệm giữ `m_axi_arvalid=0` cho denied owner và chọn local R response về DMA.

Unit test chứng minh generator đúng. Integration test chứng minh denied AR không ra matrix và matrix R không trộn với local R.

<!-- pagebreak -->

# 4. FSM hai trạng thái

```text
              acl_r_fault
        +----------------------+
        |                      v
     +------+              +-------+
     | IDLE |              |  GEN  |
     +------+              +-------+
        ^                      |
        | final R handshake    |
        +----------------------+
```

## 4.1. IDLE

Outputs:

- `r_drain_rvalid=0`.
- `r_drain_rlast=0`.
- Payload có thể là reset/default values.

Khi `acl_r_fault=1`:

- Chốt ID, LEN, ERR_MODE.
- Đặt counter bằng 0.
- Chuyển GEN.

## 4.2. GEN

Outputs:

- `r_drain_rvalid=1`.
- `r_drain_rid=id_snapshot`.
- `r_drain_rdata=0`.
- `r_drain_rresp` theo mode snapshot.
- `r_drain_rlast=(count==len_snapshot)`.

Transition:

| Điều kiện | Hành động |
|---|---|
| Không R handshake | Giữ counter và GEN |
| R handshake, count nhỏ hơn len | Tăng counter, giữ GEN |
| R handshake, count bằng len | Hoàn tất final beat, về IDLE |

## 4.3. Illegal state

FSM spec yêu cầu fail-safe về IDLE trong một clock, hạ outputs. Với FSM một bit, synthesis thường không có mã illegal. Nếu encoding mở rộng hai bit để hỗ trợ checker, test force mã chưa dùng. Nếu giữ encoding một bit, ghi rõ illegal-state test không áp dụng ở mức RTL encoding.

<!-- pagebreak -->

# 5. Backpressure bằng ví dụ

## 5.1. LEN 0

Ngay khi vào GEN:

```text
count  = 0
len    = 0
RVALID = 1
RLAST  = 1
```

Nếu RREADY=0, năm tín hiệu R giữ nguyên. Khi RREADY lên 1, final handshake xảy ra và FSM về IDLE.

## 5.2. LEN 3 không stall

| Chu kỳ GEN | Count | RLAST | Handshake | Next |
|---:|---:|---:|---:|---|
| 1 | 0 | 0 | 1 | count 1 |
| 2 | 1 | 0 | 1 | count 2 |
| 3 | 2 | 0 | 1 | count 3 |
| 4 | 3 | 1 | 1 | IDLE |

## 5.3. Stall giữa burst

ARLEN=3, RREADY thấp khi count=1:

```text
cycle       C0  C1  C2  C3  C4  C5
count        0   1   1   1   1   2
RVALID       1   1   1   1   1   1
RREADY       1   0   0   0   1   1
RLAST        0   0   0   0   0   0
handshake    1   0   0   0   1   1
```

Counter đứng yên trong C1 đến C3.

## 5.4. Stall final beat

Khi count bằng len, RLAST=1. Nếu RREADY=0 trong nhiều chu kỳ, RLAST phải giữ 1. Không hạ RLAST vì "đã phát một chu kỳ"; chưa có handshake thì beat chưa được nhận.

## 5.5. Không có bubble bắt buộc

Khi RREADY luôn 1, generator có thể phát một beat mỗi cycle. Không cần chèn bubble giữa các RVALID. Với LEN 15, hoàn tất trong 16 R handshakes liên tiếp.

<!-- pagebreak -->

# 6. Skeleton RTL

```systemverilog
module fw_read_drain (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        acl_r_fault,
    input  wire [3:0]  acl_r_id,
    input  wire [7:0]  acl_r_len,
    input  wire        acl_r_err_mode,

    output wire        r_drain_rvalid,
    input  wire        r_drain_rready,
    output wire [3:0]  r_drain_rid,
    output wire [31:0] r_drain_rdata,
    output wire [1:0]  r_drain_rresp,
    output wire        r_drain_rlast
);

localparam R_IDLE = 1'b0;
localparam R_GEN  = 1'b1;

reg       state, state_next;
reg [3:0] id_q, id_next;
reg [7:0] len_q, len_next;
reg       mode_q, mode_next;
reg [7:0] count_q, count_next;

wire r_handshake;
wire final_beat;

// Bài tập 1: định nghĩa handshake và final_beat.
// Bài tập 2: output decode từ state và snapshot.
// Bài tập 3: next-state tăng count chỉ trên non-final handshake.
// Bài tập 4: final handshake giải phóng owner.
// Bài tập 5: reset đưa toàn bộ state về fail-safe IDLE.

endmodule
```

## 6.1. Combinational outputs

Vì counter chỉ đổi trên handshake, `RLAST=(count_q==len_q)` tự ổn định dưới stall. RID, RRESP lấy từ snapshot. RDATA là hằng 0.

## 6.2. Counter width

ARLEN có 8 bit ở interface. Baseline chỉ chấp nhận 0 đến 15, nhưng drain nhận snapshot field 8 bit. Giữ counter 8 bit tránh truncation. Matcher phải chặn LEN ngoài profile trước khi owner đến drain, nhưng denied profile request vẫn có thể mang AxLEN lớn. Integration contract cho baseline drain của constrained DMA tối đa 16 beat; nếu test direct inject AxLEN lớn hơn 15, expected behavior phải được khóa ở top-level profile contract trước khi unit test.

> [CẢNH BÁO] Không tự clamp LEN trong drain nếu contract không nói. Clamp làm số response beat khác request field và che lỗi ở Stage 1.

<!-- pagebreak -->

# 7. Lộ trình hiện thực

## Mốc 1: LEN 0, RREADY luôn 1

Chứng minh một owner tạo đúng một beat, RLAST=1 và ID echo đúng.

## Mốc 2: LEN 0 đến 15

Thêm counter. Test LEN 1, 3, 15. Scoreboard đếm handshake, không đếm RVALID cycles.

## Mốc 3: Backpressure giữa burst

Randomize RREADY. Counter và payload giữ khi không handshake.

## Mốc 4: Stall final beat

Giữ RREADY=0 khi RLAST=1. Kiểm toàn payload stable rồi cho handshake.

## Mốc 5: DECERR và honeypot

Test mode 1 và 0. Đổi live mode sau acceptance, response hiện tại không đổi.

## Mốc 6: Reset và owner blocking

Reset giữa GEN, kiểm RVALID hạ. Cố cấp owner mới khi GEN, kiểm top/interface không overwrite snapshot.

## Mốc 7: Stress

Chạy 1.000 bursts với LEN 0 đến 15 và RREADY random. Mỗi burst phải có đúng LEN+1 handshake và một RLAST.

<!-- pagebreak -->

# 8. Self-checking testbench

## 8.1. Clock, reset và timeout

```systemverilog
initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
    repeat (10000) @(posedge clk);
    $fatal(1, "TIMEOUT: read drain không hoàn tất");
end
```

## 8.2. Cấp denied AR owner

```systemverilog
task accept_denied_ar;
    input [3:0] id;
    input [7:0] len;
    input       mode;
begin
    @(negedge clk);
    acl_r_id       = id;
    acl_r_len      = len;
    acl_r_err_mode = mode;
    acl_r_fault    = 1'b1;
    @(posedge clk);
    @(negedge clk);
    acl_r_fault    = 1'b0;
end
endtask
```

## 8.3. RREADY driver

Directed tests điều khiển rõ từng stall. Stress test dùng random nhưng in seed.

```systemverilog
always @(negedge clk) begin
    if (!rst_n)
        r_drain_rready <= 1'b0;
    else if (random_ready_enable)
        r_drain_rready <= $urandom_range(0, 1);
end
```

Để bảo đảm stress có progress, ép RREADY=1 nếu đã thấp liên tiếp quá một bound testbench, ví dụ 8 cycles. Đây là fairness của test, không phải logic DUT.

## 8.4. Scoreboard

Khi nhận owner:

```text
expected_beats = ARLEN + 1
expected_id    = ARID
expected_resp  = mode ? DECERR : OKAY
accepted       = 0
```

Tại mỗi `RVALID && RREADY`:

1. Kiểm RID.
2. Kiểm RDATA bằng 0.
3. Kiểm RRESP.
4. Kiểm RLAST bằng `(accepted == expected_beats-1)`.
5. Tăng accepted.
6. Sau final handshake, kiểm RVALID hạ ở cycle kế tiếp.

## 8.5. Stability monitor

```systemverilog
reg [3:0]  held_id;
reg [31:0] held_data;
reg [1:0]  held_resp;
reg        held_last;
reg        was_stalled;

always @(posedge clk) begin
    if (!rst_n) begin
        was_stalled <= 1'b0;
    end else begin
        if (was_stalled) begin
            if (!r_drain_rvalid || r_drain_rid !== held_id ||
                r_drain_rdata !== held_data || r_drain_rresp !== held_resp ||
                r_drain_rlast !== held_last)
                $fatal(1, "R payload đổi dưới backpressure");
        end

        was_stalled <= r_drain_rvalid && !r_drain_rready;
        held_id      <= r_drain_rid;
        held_data    <= r_drain_rdata;
        held_resp    <= r_drain_rresp;
        held_last    <= r_drain_rlast;
    end
end
```

<!-- pagebreak -->

# 9. Ma trận test bắt buộc

| ID | Stimulus | Expected |
|---|---|---|
| RD-LEN-00 | LEN 0, RREADY 1 | Một beat, RLAST 1 |
| RD-LEN-03 | LEN 3 | Bốn handshakes, RLAST chỉ beat 4 |
| RD-LEN-15 | LEN 15 | Mười sáu handshakes |
| RD-STL-01 | Stall trước beat đầu | Payload đầu giữ ổn định |
| RD-STL-02 | Stall giữa burst | Count giữ, không mất beat |
| RD-STL-03 | Stall final beat | RLAST và payload giữ |
| RD-ID-01 | ID 0, 5, 15 | RID echo snapshot |
| RD-MOD-01 | ERR_MODE 1 | Mọi beat DECERR |
| RD-MOD-02 | ERR_MODE 0 | Mọi beat OKAY, data 0 |
| RD-SNP-01 | Đổi live ID/LEN/mode trong GEN | Burst dùng snapshot cũ |
| RD-RST-01 | Reset giữa burst | Về IDLE, RVALID 0 |
| RD-OWN-01 | Owner thứ hai khi GEN | Không overwrite snapshot |
| RD-XTR-01 | Quan sát cycle sau final handshake | Không có beat dư |
| RD-RND-01 | 1.000 burst random ready | Exact beat và stability PASS |

## 9.1. Test isolation ở integration

Trong `fw_data_path_mux` hoặc top test, bổ sung:

- Denied request không làm `m_axi_arvalid` lên 1.
- `s_axi_r*` lấy từ read drain khi denied owner active.
- `m_axi_r*` không ảnh hưởng local response.
- Không chọn đồng thời matrix R và drain R cho cùng owner.

<!-- pagebreak -->

# 10. Assertions và invariant checkers

```systemverilog
property p_r_stable;
    @(posedge clk) disable iff (!rst_n)
    r_drain_rvalid && !r_drain_rready |=>
      r_drain_rvalid &&
      $stable(r_drain_rid) &&
      $stable(r_drain_rdata) &&
      $stable(r_drain_rresp) &&
      $stable(r_drain_rlast);
endproperty

property p_count_only_on_handshake;
    @(posedge clk) disable iff (!rst_n)
    state == R_GEN && !(r_drain_rvalid && r_drain_rready)
    |=> $stable(count_q);
endproperty

property p_last_position;
    @(posedge clk) disable iff (!rst_n)
    r_drain_rvalid |-> (r_drain_rlast == (count_q == len_q));
endproperty

property p_id_echo;
    @(posedge clk) disable iff (!rst_n)
    r_drain_rvalid |-> (r_drain_rid == id_q);
endproperty
```

Một checker thủ tục nên đếm tổng handshake để bắt lỗi duplicate hoặc missing beat mà property cục bộ không thấy.

<!-- pagebreak -->

# 11. Debug theo triệu chứng

## LEN 0 tạo hai beat

Kiểm transition final. Với count khởi tạo 0 và len 0, handshake đầu phải về IDLE ngay.

## RLAST lên sau final beat

Kiểm có so `count+1 == len` hay không. Khi counter là beat index, final condition là `count==len`.

## Counter tăng trong stall

Kiểm update có điều kiện theo state GEN thay vì R handshake. Counter phải giữ khi RREADY=0.

## RLAST chớp một cycle rồi hạ khi RREADY=0

Kiểm RLAST được tạo từ pulse hoặc next-state. Nó phải là hàm của stable count và stable len, nên giữ tới handshake.

## RID hoặc RRESP đổi giữa burst

Kiểm output đang đọc live `acl_r_id` hoặc live ERR_MODE. Dùng snapshot registers.

## Có bubble giữa mọi beat

Kiểm RVALID có bị hạ sau từng handshake rồi set lại hay không. Trong GEN, RVALID có thể giữ 1 liên tục; chỉ payload index thay đổi sau handshake.

## Test treo khi RREADY luôn 0

Đây là vi phạm progress assumption của environment. Testbench timeout phải báo rõ. DUT không được tự bỏ response.

# 12. Câu hỏi tự kiểm tra và đáp án

## Câu 1

ARLEN=15 có final beat index bằng bao nhiêu?

Đáp án: 15, với tổng cộng 16 beat.

## Câu 2

RVALID=1, RREADY=0 có tăng counter không?

Đáp án: không.

## Câu 3

Khi stall final beat, RLAST phải bằng gì?

Đáp án: giữ bằng 1 cho tới final handshake.

## Câu 4

Honeypot mode trả dữ liệu gì?

Đáp án: RDATA vẫn bằng 0; RRESP đổi từ DECERR sang OKAY. Request vẫn bị isolate và log.

## Câu 5

Read drain cần ARADDR để sinh response không?

Đáp án: không. Nó cần ID, LEN và mode. Matcher/logger sở hữu address fault metadata.

## Câu 6

Vì sao không dùng timeout trong DUT để kết thúc burst?

Đáp án: AXI transfer chỉ hoàn tất bằng handshake. Timeout tự bỏ beat sẽ tạo response không đúng giao thức. Watchdog của hệ thống là cơ chế riêng.

# 13. Rubric và exit gate

| Hạng mục | Điểm | Điều kiện đạt trọn điểm |
|---|---:|---|
| Ready/valid và exact beat | 2.5 | Counter chỉ theo handshake, LEN 0/15 đúng |
| FSM và snapshot | 2.0 | ID, LEN, mode ổn định, owner rõ |
| R payload | 1.5 | Data, response, RLAST và ID đúng |
| Backpressure | 1.5 | Toàn payload stable, final stall đúng |
| Verification | 2.0 | Directed, random, timeout, scoreboard, assertions |
| Bằng chứng | 0.5 | Log, seed, waveform và giải thích |

Exit gate:

- LEN 0, 3 và 15 PASS.
- Số R handshake đúng ARLEN+1.
- RLAST chỉ có trên final beat.
- Toàn R payload ổn định dưới stall.
- Không có beat dư sau final handshake.
- 1.000 stress bursts PASS.

# 14. Checklist nộp bài

- [ ] RTL read drain.
- [ ] Self-checking testbench có timeout.
- [ ] Directed matrix và stress seed.
- [ ] Waveform LEN 15 với random ready.
- [ ] Waveform stall final beat.
- [ ] Bảng exact beat cho LEN 0, 3, 15.
- [ ] Sơ đồ owner lifecycle.
- [ ] Lệnh compile và log PASS.

# 15. Tài liệu nguồn

- `DMA-controller/docs/architecture/fsm_specification.md`, mục 4
- `DMA-controller/docs/architecture/signal_list.csv`, drain interface
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`, invariant 7 và 8
- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.4
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/lessons/bai-06-read-drain.html`
