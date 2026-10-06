---
title: Denied-write exact-beat drain
subtitle: Hướng dẫn thực hành AXI write sink, framing và B response
version: Kiến trúc chuẩn V2.4.1
---

# 1. Bài toán và sản phẩm cần nộp

Write drain xử lý một AW request đã bị Firewall từ chối. Nó không chuyển AW hoặc W tới matrix. Nó nhận và hủy đúng số W beat mà master đã cam kết, sau đó trả một B response local.

Module giải quyết hai mục tiêu cùng lúc:

- Isolation: dữ liệu của request bị deny không đi ra matrix.
- Protocol completion: DMA master vẫn nhận một B response đúng framing nên không bị treo vì Firewall.

Sau bài thực hành, sinh viên phải giải thích được:

1. Vì sao số beat lấy từ AWLEN thay vì WLAST?
2. Counter tăng ở điều kiện nào?
3. Những field nào phải snapshot khi nhận denied owner?
4. Output nào phải giữ ổn định khi `BREADY=0`?

Sản phẩm cần nộp:

- RTL write drain tổng hợp được.
- `tb_fw_write_drain.sv` tự kiểm tra và có timeout.
- Log PASS.
- Waveform early WLAST và BREADY stall.
- Bảng giải thích exact-beat accounting cho LEN 0, 3 và 15.

> [ĐẶC TẢ] Nguồn chuẩn là `fsm_specification.md` mục 3, `signal_list.csv` các dòng drain interface, `firewall_rtl_integration_contract.md` invariant 6 và `verification_test_plan.md` testcase exact beats.

<!-- pagebreak -->

# 2. AXI write từ con số 0

Một AXI write transaction dùng ba channel:

```text
AW: địa chỉ và thuộc tính burst
W : các beat dữ liệu
B : phản hồi sau khi toàn burst đã được nhận
```

Các channel có ready/valid handshake độc lập. Một transfer xảy ra tại cạnh clock khi cả VALID và READY bằng 1.

```text
aw_handshake = AWVALID && AWREADY
w_handshake  = WVALID  && WREADY
b_handshake  = BVALID  && BREADY
```

Firewall đã xử lý AW trước khi write drain hoạt động. `acl_w_fault` là request một chu kỳ báo rằng denied AW snapshot đã được chấp nhận và owner thuộc drain.

## 2.1. Ready/valid

Source sở hữu VALID và payload. Destination sở hữu READY. Khi source đặt VALID=1 mà READY=0, source phải giữ VALID và payload ổn định.

Trong write drain:

- DMA là source của WVALID và WLAST.
- Drain là destination và phát WREADY.
- Drain là source của BVALID, BID và BRESP.
- DMA là destination của B response và phát BREADY.

## 2.2. AWLEN

AXI mã hóa burst length theo beats-minus-one:

| AWLEN | Số W beat |
|---:|---:|
| 0 | 1 |
| 1 | 2 |
| 3 | 4 |
| 15 | 16 |

Nếu counter là index bắt đầu từ 0, final beat có điều kiện:

```text
expected_final = (w_beat_count == latched_awlen)
```

Không cần cộng 1 trong phép so sánh này.

## 2.3. WLAST

WLAST xác nhận framing từ master. Nó phải bằng 1 đúng final beat và bằng 0 ở các beat trước.

```text
expected_wlast = (w_beat_count == latched_awlen)
framing_error  = w_handshake AND (WLAST != expected_wlast)
```

WLAST không thay thế AWLEN làm nguồn ownership. Early WLAST tạo fault nhưng drain tiếp tục nhận đủ AWLEN+1 handshakes. Missing WLAST trên final beat tạo fault nhưng drain vẫn chuyển sang B response sau final handshake.

> [CẢNH BÁO] Nếu thiết kế kết thúc SINK ngay khi thấy WLAST, một WLAST sớm làm B phát sớm. Các W beat còn lại sẽ bị hiểu nhầm thành transaction khác và phá đồng bộ channel.

## 2.4. B response

Sau final W handshake:

- `BID` bằng AWID đã snapshot.
- `BRESP=2'b11` DECERR khi `ERR_MODE=1`.
- `BRESP=2'b00` OKAY honeypot khi `ERR_MODE=0`.
- `BVALID=1` cho tới `BREADY=1`.

Honeypot chỉ đổi response trả về master. Dữ liệu vẫn bị hủy và fault vẫn được log.

<!-- pagebreak -->

# 3. Ownership và ranh giới module

Write drain không tự đánh giá ACL. Matcher chuyển một denied request snapshot qua:

| Input | Độ rộng | Ý nghĩa |
|---|---:|---|
| `acl_w_fault` | 1 | Xung nhận denied owner |
| `acl_w_id` | 4 | AWID snapshot |
| `acl_w_len` | 8 | AWLEN snapshot |
| `acl_w_err_mode` | 1 | Response mode snapshot |
| `w_drain_wvalid` | 1 | WVALID của denied owner |
| `w_drain_wlast` | 1 | WLAST dùng kiểm framing |
| `w_drain_bready` | 1 | BREADY từ DMA |

Output:

| Output | Độ rộng | Ý nghĩa |
|---|---:|---|
| `w_drain_wready` | 1 | Nhận W beat trong SINK |
| `w_drain_bvalid` | 1 | B response hợp lệ trong RESP |
| `w_drain_bid` | 4 | ID đã snapshot |
| `w_drain_bresp` | 2 | DECERR hoặc OKAY |
| `w_framing_fault_valid` | 1 | Xung báo WLAST mismatch |
| `w_framing_fault_code` | 4 | WRITE_ERR cộng PROT_ERR |

`WDATA` và `WSTRB` không cần đi vào state machine vì drain hủy nội dung. Data path mux vẫn phải route WVALID, WLAST và WREADY đúng owner. Isolation khỏi matrix được chứng minh ở integration test của mux/top; unit test write drain chứng minh module không có output WDATA/WVALID hướng matrix.

## 3.1. Snapshot bắt buộc

Khi `acl_w_fault=1` ở IDLE, chốt:

- AWID.
- AWLEN.
- ERR_MODE.

Không đọc live AW bus trong SINK hoặc RESP. APB có thể đổi ERR_MODE trong khi BREADY stall; response hiện tại vẫn dùng mode snapshot.

## 3.2. Single owner

Write drain chỉ giữ một denied owner. Khi state khác IDLE, matcher/top không được cấp `acl_w_fault` mới. Có thể thêm `w_drain_busy` hoặc suy từ state để backpressure owner upstream.

> [BÀI TẬP] Chọn một trong hai interface: `w_drain_busy` output hoặc `acl_w_fault_ready` handshake. Ghi rõ cách top-level ngăn request thứ hai khi drain chưa về IDLE.

<!-- pagebreak -->

# 4. FSM ba trạng thái

```text
                acl_w_fault
        +--------------------------+
        |                          v
     +------+                  +--------+
     | IDLE |                  |  SINK  |
     +------+                  +--------+
        ^                          |
        |                          | W handshake và count == len
        | B handshake              v
        +----------------------+--------+
                               |  RESP  |
                               +--------+
```

## 4.1. IDLE

Outputs:

- `w_drain_wready=0`.
- `w_drain_bvalid=0`.
- framing event bằng 0.

Khi `acl_w_fault=1`:

- Chốt ID, LEN, ERR_MODE.
- Đặt counter bằng 0.
- Chuyển SINK.

## 4.2. SINK

`w_drain_wready=1`. Counter chỉ thay đổi trên `w_drain_wvalid && w_drain_wready`.

Tại mỗi handshake:

1. So sánh WLAST với `count==len`.
2. Nếu khác, phát framing fault một chu kỳ.
3. Nếu `count<len`, tăng counter và giữ SINK.
4. Nếu `count==len`, đã nhận final beat theo AWLEN và chuyển RESP.

Không có handshake thì giữ counter, state và snapshot.

## 4.3. RESP

Outputs:

- `w_drain_wready=0`.
- `w_drain_bvalid=1`.
- `w_drain_bid=id_snapshot`.
- `w_drain_bresp=err_mode_snapshot ? DECERR : OKAY`.

Nếu BREADY=0, giữ nguyên state và toàn payload B. Khi B handshake, chuyển IDLE.

## 4.4. Illegal state

FSM spec yêu cầu về IDLE trong một clock, hạ mọi output và xóa active transaction state. Testbench có thể force state sang mã không hợp lệ để kiểm recovery.

<!-- pagebreak -->

# 5. Exact-beat accounting bằng ví dụ

## 5.1. LEN 0

```text
Snapshot: AWLEN=0

Beat index 0:
  expected_final = 1
  handshake      = 1
  WLAST phải     = 1
  next state     = RESP
```

BVALID không được có trước handshake beat 0.

## 5.2. LEN 3

| Beat index trước handshake | Expected WLAST | Hành động sau handshake |
|---:|---:|---|
| 0 | 0 | count=1, giữ SINK |
| 1 | 0 | count=2, giữ SINK |
| 2 | 0 | count=3, giữ SINK |
| 3 | 1 | chuyển RESP |

## 5.3. Early WLAST

AWLEN=3 nhưng WLAST=1 ở beat index 1:

```text
beat 0: WLAST=0, không fault
beat 1: WLAST=1, phát framing fault, vẫn SINK
beat 2: WLAST=0, vẫn SINK
beat 3: WLAST=1, chuyển RESP
```

## 5.4. Missing final WLAST

AWLEN=3 nhưng WLAST=0 ở beat index 3. Drain phát framing fault và chuyển RESP vì đã nhận đủ bốn W handshake. Nó không chờ thêm WLAST.

## 5.5. WVALID có khoảng trống

Wall-clock cycles không quyết định progress. Nếu WVALID=0 trong mười chu kỳ, counter không đổi. Không dùng timeout nội bộ để tự tăng counter hoặc phát B.

<!-- pagebreak -->

# 6. Skeleton RTL

Skeleton dưới đây cố ý để trống các biểu thức bài tập. Nó xác định state ownership và thứ tự block.

```systemverilog
module fw_write_drain (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       acl_w_fault,
    input  wire [3:0] acl_w_id,
    input  wire [7:0] acl_w_len,
    input  wire       acl_w_err_mode,

    input  wire       w_drain_wvalid,
    input  wire       w_drain_wlast,
    output wire       w_drain_wready,

    output wire       w_drain_bvalid,
    output wire [3:0] w_drain_bid,
    output wire [1:0] w_drain_bresp,
    input  wire       w_drain_bready,

    output reg        w_framing_fault_valid,
    output wire [3:0] w_framing_fault_code
);

localparam W_IDLE = 2'b00;
localparam W_SINK = 2'b01;
localparam W_RESP = 2'b10;

reg [1:0] state, state_next;
reg [3:0] id_q, id_next;
reg [7:0] len_q, len_next;
reg       mode_q, mode_next;
reg [7:0] count_q, count_next;

wire w_handshake;
wire expected_final;

// Bài tập 1: định nghĩa handshake và expected_final.
// Bài tập 2: output decode chỉ phụ thuộc state và snapshot.
// Bài tập 3: next-state có default đầy đủ, không suy latch.
// Bài tập 4: phát framing event đúng một chu kỳ trên mismatch.
// Bài tập 5: sequential block reset fail-safe về IDLE.

endmodule
```

## 6.1. Moore outputs

Đặt `WREADY` theo state SINK và `BVALID` theo state RESP giúp review dễ. BID và BRESP lấy từ snapshot registers nên ổn định dưới stall.

## 6.2. Framing event pulse

Default `w_framing_fault_valid=0` mỗi chu kỳ. Set nó khi có W handshake và WLAST khác expected. Code gồm `WRITE_ERR` và `PROT_ERR`.

Matcher đã phát record cho denial ở address phase. Framing mismatch là record bổ sung ở W phase. Logger có thể đếm cả hai ở hai chu kỳ khác nhau.

<!-- pagebreak -->

# 7. Lộ trình hiện thực

## Mốc 1: LEN 0 không backpressure

Chỉ hỗ trợ một beat, BREADY luôn 1. Chứng minh không B trước W handshake và ID echo đúng.

## Mốc 2: Counter cho LEN 0 đến 15

Thêm count và final compare. Test LEN 1, 3, 15. Đếm handshake, không đếm cycle.

## Mốc 3: WVALID gaps

Driver tạo khoảng trống 0 đến 5 cycles giữa các beat. Counter phải giữ khi không handshake.

## Mốc 4: BREADY stall

Giữ BREADY=0 trong 5 đến 20 cycles. BID, BRESP và BVALID phải ổn định.

## Mốc 5: WLAST framing

Thêm early và missing WLAST. Fault pulse một lần trên mỗi beat mismatch. Early WLAST không làm B sớm.

## Mốc 6: ERR_MODE và reset

Test DECERR, honeypot OKAY, đổi live mode sau snapshot và reset giữa SINK/RESP.

## Mốc 7: Illegal state recovery

Force state sang `2'b11`. Sau một clock, state IDLE và outputs inactive.

<!-- pagebreak -->

# 8. Self-checking testbench

## 8.1. Clock, reset và timeout

```systemverilog
initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
    repeat (10000) @(posedge clk);
    $fatal(1, "TIMEOUT: write drain không hoàn tất");
end
```

## 8.2. Cấp denied owner

```systemverilog
task accept_denied_aw;
    input [3:0] id;
    input [7:0] len;
    input       mode;
begin
    @(negedge clk);
    acl_w_id       = id;
    acl_w_len      = len;
    acl_w_err_mode = mode;
    acl_w_fault    = 1'b1;
    @(posedge clk);
    @(negedge clk);
    acl_w_fault    = 1'b0;
end
endtask
```

Checker phải xác nhận DUT chỉ nhận request khi IDLE. Nếu interface có ready, task chờ ready với timeout.

## 8.3. Gửi một W beat

```systemverilog
task send_w_beat;
    input last;
    input integer gap_cycles;
    integer k;
begin
    for (k = 0; k < gap_cycles; k = k + 1)
        @(posedge clk);

    @(negedge clk);
    w_drain_wvalid = 1'b1;
    w_drain_wlast  = last;

    while (!w_drain_wready)
        @(posedge clk);
    @(posedge clk);

    @(negedge clk);
    w_drain_wvalid = 1'b0;
    w_drain_wlast  = 1'b0;
end
endtask
```

Thêm timeout cho loop chờ WREADY để lỗi state không treo toàn test.

## 8.4. B monitor

Monitor đếm W handshakes. Nếu thấy BVALID khi count nhỏ hơn expected beats, báo fatal. Khi BVALID stall, lưu payload và so ở từng clock.

```systemverilog
always @(posedge clk) begin
    if (!rst_n) begin
        accepted_w_beats <= 0;
    end else begin
        if (w_drain_wvalid && w_drain_wready)
            accepted_w_beats <= accepted_w_beats + 1;

        if (w_drain_bvalid && accepted_w_beats < expected_beats)
            $fatal(1, "BVALID sớm: got %0d expected %0d",
                   accepted_w_beats, expected_beats);
    end
end
```

Chú ý nonblocking assignment: trong chu kỳ final handshake, monitor thấy giá trị counter cũ. Có thể so `accepted_w_beats + 1` khi W handshake cùng cạnh hoặc kiểm BVALID từ chu kỳ kế tiếp.

<!-- pagebreak -->

# 9. Ma trận test bắt buộc

| ID | Stimulus | Expected |
|---|---|---|
| WD-LEN-00 | LEN 0, một W beat | B sau đúng một handshake |
| WD-LEN-03 | LEN 3, bốn W beat | B sau handshake thứ 4 |
| WD-LEN-15 | LEN 15, mười sáu W beat | B sau handshake thứ 16 |
| WD-GAP-01 | WVALID gaps ngẫu nhiên | Counter chỉ tăng trên handshake |
| WD-ELS-01 | Early WLAST | Framing fault, không B sớm |
| WD-MIS-01 | Missing WLAST final | Framing fault và vẫn B đúng beat count |
| WD-BST-01 | BREADY thấp 10 cycles | B payload ổn định |
| WD-ID-01 | ID lần lượt 0, 5, 15 | BID echo đúng snapshot |
| WD-MOD-01 | ERR_MODE 1 | BRESP DECERR |
| WD-MOD-02 | ERR_MODE 0 | BRESP OKAY, fault vẫn có |
| WD-SNP-01 | Đổi live ID/LEN/mode trong SINK | Transaction dùng snapshot cũ |
| WD-SNP-02 | Đổi live mode trong RESP stall | BRESP giữ nguyên |
| WD-RST-01 | Reset giữa SINK | Về IDLE, output inactive |
| WD-RST-02 | Reset giữa RESP | BVALID hạ, về IDLE |
| WD-ILL-01 | Force illegal state | Recovery IDLE trong một clock |
| WD-XTR-01 | WVALID khi RESP | WREADY 0, không nhận beat dư |

## 9.1. Stress test

Chạy 1.000 denied bursts với LEN ngẫu nhiên 0 đến 15, WVALID gaps và BREADY stalls. WLAST đúng trong stress chính. Chạy một suite riêng chèn early hoặc missing WLAST để expected fault rõ ràng.

In seed vào log. Scoreboard phải kết thúc mỗi burst trước khi cấp owner mới.

<!-- pagebreak -->

# 10. Assertions và invariant checkers

```systemverilog
property p_no_early_b;
    @(posedge clk) disable iff (!rst_n)
    state == W_SINK && count_q < len_q |-> !w_drain_bvalid;
endproperty

property p_b_stable;
    @(posedge clk) disable iff (!rst_n)
    w_drain_bvalid && !w_drain_bready |=>
      w_drain_bvalid &&
      $stable(w_drain_bid) &&
      $stable(w_drain_bresp);
endproperty

property p_id_echo;
    @(posedge clk) disable iff (!rst_n)
    w_drain_bvalid |-> (w_drain_bid == id_q);
endproperty

property p_count_only_on_handshake;
    @(posedge clk) disable iff (!rst_n)
    state == W_SINK && !(w_drain_wvalid && w_drain_wready)
    |=> $stable(count_q);
endproperty
```

Integration assertions thuộc mux/top:

- Denied owner không làm `m_axi_awvalid` hoặc `m_axi_wvalid` lên 1.
- `s_axi_wready` lấy từ drain khi denied owner active.
- Response owner chọn drain B, không chọn matrix B.

<!-- pagebreak -->

# 11. Debug theo triệu chứng

## BVALID xuất hiện sau AWLEN thay vì AWLEN+1 beat

Kiểm định nghĩa counter. Nếu counter lưu số beat đã nhận thay vì index hiện tại, final compare phải khác. Chọn một quy ước và ghi rõ.

## Counter tăng khi WVALID=0

Kiểm update có điều kiện bằng state SINK thay vì W handshake. Counter chỉ tăng khi cả VALID và READY bằng 1.

## Early WLAST làm FSM sang RESP

Kiểm transition có dùng WLAST. Transition terminal phải dùng `count==len` trên handshake. WLAST chỉ tạo framing fault.

## B response đổi khi BREADY=0

Kiểm BID/BRESP đang lấy từ live `acl_w_*` hoặc live ERR_MODE. Chuyển sang snapshot registers.

## LEN 0 bị treo

Counter khởi tạo 0 và final condition phải đúng ngay handshake đầu. Đừng đợi counter tăng đến 1 rồi mới so với LEN 0.

## Framing fault kéo dài nhiều chu kỳ

Phát event từ handshake mismatch, không từ điều kiện level `WLAST != expected` khi chưa handshake.

## Test treo khi master ngừng WVALID

Đó là môi trường không đáp ứng progress assumption. Testbench phải timeout và báo nguồn không cấp đủ beat. DUT không được tự tạo completion.

# 12. Câu hỏi tự kiểm tra và đáp án

## Câu 1

AWLEN=15 cần bao nhiêu W handshake?

Đáp án: 16.

## Câu 2

WVALID=1, WREADY=0 có tăng counter không?

Đáp án: không, vì chưa có handshake.

## Câu 3

WLAST=1 tại beat index 2 khi AWLEN=7 có kết thúc burst không?

Đáp án: không. Nó tạo framing fault và drain tiếp tục tới beat index 7.

## Câu 4

WLAST=0 tại final beat có làm drain chờ thêm beat không?

Đáp án: không. Drain ghi framing fault và chuyển RESP sau khi đủ AWLEN+1 handshakes.

## Câu 5

ERR_MODE đổi trong BREADY stall có đổi BRESP không?

Đáp án: không. Mode đã snapshot khi owner được cấp.

## Câu 6

Honeypot OKAY có nghĩa fault không được log không?

Đáp án: không. Nó chỉ đổi response nhìn thấy bởi master.

# 13. Rubric và exit gate

| Hạng mục | Điểm | Điều kiện đạt trọn điểm |
|---|---:|---|
| Ready/valid và exact beat | 2.5 | Counter và terminal chỉ theo handshake |
| FSM và snapshot | 2.0 | ID, LEN, mode sở hữu rõ và stable |
| WLAST framing | 1.5 | Early/missing fault đúng, không B sớm |
| B response | 1.5 | ID, mode và stall stability đúng |
| Verification | 2.0 | Directed, stress, timeout và assertions |
| Bằng chứng | 0.5 | Log, seed, waveform và giải thích |

Exit gate:

- LEN 0, 3 và 15 PASS.
- Không B trước handshake thứ AWLEN+1.
- Early và missing WLAST không đổi exact-beat completion.
- B payload ổn định dưới stall.
- Không nhận owner thứ hai khi busy.
- 1.000 stress bursts PASS.

# 14. Checklist nộp bài

- [ ] RTL write drain.
- [ ] Self-checking testbench có timeout.
- [ ] Directed matrix và stress seed.
- [ ] Waveform early WLAST.
- [ ] Waveform BREADY stall.
- [ ] Bảng exact beat cho LEN 0, 3, 15.
- [ ] Ghi chú owner backpressure interface.
- [ ] Lệnh compile và log PASS.

# 15. Tài liệu nguồn

- `DMA-controller/docs/architecture/fsm_specification.md`, mục 3
- `DMA-controller/docs/architecture/signal_list.csv`, drain interface
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`, invariant 6 và 8
- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.4
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/lessons/bai-05-write-drain.html`
