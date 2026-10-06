---
title: ACL matcher và full-burst containment
subtitle: Hướng dẫn thực hành từ số học địa chỉ đến policy snapshot bất biến
version: Kiến trúc chuẩn V2.4.1
---

# 1. Bài toán và sản phẩm cần nộp

`fw_acl_matcher` quyết định một yêu cầu đọc hoặc ghi có được đi tới AXI matrix hay phải chuyển sang drain. Module đánh giá toàn burst, không chỉ địa chỉ đầu. Nó kiểm tra tám region, master ID, protection attributes và permission.

Sau bài thực hành, sinh viên phải tự giải thích được:

1. Vì sao kiểm tra riêng `AxADDR` không đủ?
2. Region nào tham gia phép AND hạn chế nhất?
3. Bit 1 trong `MID_MASK` mang nghĩa so khớp hay bỏ qua?
4. Policy thay đổi sau address handshake có được đổi decision hiện tại không?

Sản phẩm cần nộp:

- `fw_acl_matcher.v` hoặc `fw_acl_matcher.sv` tổng hợp được.
- `tb_fw_acl_matcher.sv` có pure reference model và scoreboard.
- Log mô phỏng sạch.
- Waveform của partial containment và overlap deny.
- Ma trận test ghi expected fault code cho từng case.

> [ĐẶC TẢ] Nguồn chuẩn là `architecture_overview.md` mục 5.2 đến 5.4, `register_map.csv`, `signal_list.csv`, `firewall_rtl_integration_contract.md` và `verification_test_plan.md`.

## 1.1. Phạm vi bài

Address slice ở Stage 1 đã chốt payload AXI, tính địa chỉ byte cuối và phát các cờ profile. Matcher không nhận live AW hoặc AR bus. Bài này vẫn dạy phép tính `last_byte` để sinh viên kiểm được input và viết reference model.

Matcher không route W/R/B. `fw_data_path_mux` thực hiện routing. Matcher chỉ tạo decision và fault record từ snapshot.

<!-- pagebreak -->

# 2. AXI burst arithmetic từ con số 0

AXI mã hóa độ dài burst theo dạng beats-minus-one:

```text
beats      = AxLEN + 1
bytes_beat = 1 << AxSIZE
last_byte  = AxADDR + beats * bytes_beat - 1
```

Baseline DMA dùng `AxSIZE=3'b010`, nghĩa là 4 byte mỗi beat. `AxLEN<=15`, nên tối đa 16 beat.

## 2.1. Ví dụ một burst hợp lệ

```text
AxADDR = 0x0000_1000
AxLEN  = 3
AxSIZE = 2

beats      = 4
bytes_beat = 4
last_byte  = 0x1000 + 4*4 - 1 = 0x100F
```

Burst chiếm khoảng inclusive `[0x1000, 0x100F]`.

## 2.2. Ví dụ crossing 4 KiB

```text
AxADDR = 0x0000_0FE0
AxLEN  = 15
AxSIZE = 2

last_byte = 0x0FE0 + 16*4 - 1 = 0x101F
```

`start[31:12]` khác `last_byte[31:12]`, nên burst vượt biên 4 KiB. Nó phải bị deny trước ACL permission.

## 2.3. Overflow

Phép cộng phải dùng thêm một bit. Nếu kết quả vượt `0xFFFF_FFFF`, truncation 32 bit có thể làm `last_byte` nhỏ hơn `start`. Cờ overflow phải được Stage 1 chốt và truyền cùng snapshot.

```systemverilog
logic [32:0] extended_last;

extended_last = {1'b0, addr}
              + ((len + 1) << size)
              - 1'b1;

overflow = extended_last[32];
last_byte = extended_last[31:0];
```

Biểu thức minh họa ý định. Khi hiện thực, phải mở rộng `len+1` trước shift để tránh mất bit.

## 2.4. Profile bắt buộc

Baseline chỉ cho phép:

| Thuộc tính | Giá trị hợp lệ |
|---|---|
| `AxBURST` | `2'b01` INCR |
| `AxSIZE` | `3'b010` 4 byte |
| `AxADDR[1:0]` | `2'b00` |
| `AxLEN` | 0 đến 15 |
| Crossing 4 KiB | Không |
| Address overflow | Không |

Profile sai luôn deny, kể cả `FW_EN=0`.

> [CẢNH BÁO] `signal_list.csv` hiện chỉ nêu cờ `*_4kb_err`, trong khi integration contract yêu cầu cả profile và overflow flags. Port list phải bổ sung các cờ còn thiếu hoặc dùng một `stage1_fault_code` đủ rộng. Không được làm mất lỗi ở ranh giới Stage 1 đến Stage 2.

<!-- pagebreak -->

# 3. Region và full-burst containment

Mỗi region mô tả khoảng inclusive `[BASE_ADDR, LIMIT_ADDR]`. Một region chỉ cover burst khi:

```text
ACTIVE
AND start_addr >= BASE_ADDR
AND last_byte  <= LIMIT_ADDR
```

## 3.1. Full containment và partial overlap

Giả sử region là `[0x1000, 0x1FFF]`:

| Burst | Start | End | Kết quả cover |
|---|---:|---:|---|
| A | `0x1000` | `0x100F` | Có |
| B | `0x0FF0` | `0x100F` | Không |
| C | `0x1FF0` | `0x200F` | Không |
| D | `0x1000` | `0x1FFF` | Có |
| E | `0x2000` | `0x200F` | Không |

Burst B và C có giao nhau với region nhưng không nằm trọn trong region. Nếu không region nào khác cover toàn burst, hai burst phải nhận BOUND_ERR và channel error.

## 3.2. Descriptor hợp lệ

`fw_apb_regs` và context tracker chịu trách nhiệm không active region có `BASE>LIMIT`. Matcher vẫn nên xử lý fail-secure nếu input descriptor sai: region đó không được cover.

## 3.3. Tám region

- Region 0 đến 3: static.
- Region 4: dynamic source, read-only.
- Region 5: dynamic destination, write-only.
- Region 6 và 7: static mở rộng.

Matcher phải áp dụng cùng một công thức cho cả tám region. Tránh viết tám nhánh `if` khác nhau, vì một nhánh dễ lệch bit permission hoặc mask.

<!-- pagebreak -->

# 4. MID, PROT và permission

## 4.1. Master ID và mask

Mỗi region có `WHITELIST_MID[3:0]` và `MID_MASK[3:0]`. Bit mask bằng 1 nghĩa là bỏ qua bit đó.

```text
id_ok = (id AND NOT mask) == (whitelist_id AND NOT mask)
```

Ví dụ:

```text
whitelist_id = 4'b0100
mask         = 4'b0001

ID 4 = 0100 -> pass
ID 5 = 0101 -> pass vì bit 0 bị bỏ qua
ID 6 = 0110 -> fail
```

## 4.2. Protection attributes

AXI `AxPROT` dùng:

- Bit 0: 1 Privileged, 0 Unprivileged.
- Bit 1: 0 Secure, 1 Non-Secure.
- Bit 2: instruction hoặc data; baseline dedicated DMA phát Data.

Region có `SECURE_ONLY=1` yêu cầu `AxPROT[1]=0`. Region có `PRIV_ONLY=1` yêu cầu `AxPROT[0]=1`.

```text
secure_ok = NOT SECURE_ONLY OR (AxPROT[1] == 0)
priv_ok   = NOT PRIV_ONLY   OR (AxPROT[0] == 1)
```

PROT mismatch set `PROT_ERR` và channel error.

## 4.3. Read và write permission

Read request dùng `READ_EN`. Write request dùng `WRITE_EN`. Permission mismatch set `READ_ERR` hoặc `WRITE_ERR`.

## 4.4. Most-restrictive overlap

Xét mọi region cover toàn burst. Một request được phép khi:

```text
any_cover = OR cover[i]

all_cover_allow = AND với mọi i:
                  nếu cover[i] thì id_ok[i] AND prot_ok[i] AND perm_ok[i]

acl_allowed = any_cover AND all_cover_allow
```

Region không cover không tham gia phép AND. Region cover nhưng cấm permission, sai ID hoặc sai PROT làm toàn decision deny.

Ví dụ chuẩn:

- Region 0 cover `0x1000-0x3000`, read-only.
- Region 1 cover `0x2000-0x4000`, read/write.
- Write tại `0x2500` được cả hai region cover.
- Region 0 cấm write, nên kết quả cuối deny.

Không dùng quy tắc first-match-wins. Thứ tự index của region không được đổi kết quả.

<!-- pagebreak -->

# 5. Thứ tự quyết định và fault code

Decision nên đi theo thứ tự sau:

1. Kiểm tra Stage 1 profile, overflow và 4 KiB flags.
2. Nếu một cờ Stage 1 lỗi, deny bất kể `FW_EN`.
3. Nếu `FW_EN=0` và profile hợp lệ, bypass ACL permission.
4. Nếu `FW_EN=1`, tính cover vector cho tám region.
5. Nếu không region cover, default deny.
6. Nếu có cover, áp dụng ID, PROT, channel permission và overlap AND.
7. Chốt pass/fault, code, ID, LEN và `ERR_MODE` cho owner.

## 5.1. Fault mapping

| Nguyên nhân | Read code | Write code |
|---|---|---|
| No cover hoặc permission deny | `READ_ERR` | `WRITE_ERR` |
| MID mismatch | `READ_ERR` | `WRITE_ERR` |
| PROT mismatch | `READ_ERR + PROT_ERR` | `WRITE_ERR + PROT_ERR` |
| Profile, overflow, crossing 4 KiB | `READ_ERR + BOUND_ERR` | `WRITE_ERR + BOUND_ERR` |
| Partial containment không có full cover | `READ_ERR + BOUND_ERR` | `WRITE_ERR + BOUND_ERR` |

Nếu nhiều nguyên nhân đúng, code là bitwise OR. Chọn priority cho metadata reason nếu giao diện cần một enum riêng, nhưng không được làm mất bitmask.

## 5.2. `FW_EN=0`

Khi `FW_EN=0`, một ACL-only deny được bypass. Các lỗi sau vẫn deny và log:

- Non-INCR.
- Narrow hoặc sai `AxSIZE`.
- Unaligned.
- `AxLEN>15`.
- Address overflow.
- Crossing 4 KiB.
- Framing fault ở drain.

<!-- pagebreak -->

# 6. Snapshot và transaction ownership

APB hoặc context có thể đổi trong lúc transaction bị backpressure. Decision hiện tại phải bất biến sau address acceptance.

```text
Cạnh N:
  AxVALID && AxREADY
  chốt Ax payload
  chốt effective policy sau same-cycle priority

Sau cạnh N:
  APB write hoặc context revoke có thể đổi live policy
  decision hiện tại vẫn dùng snapshot cũ
  request mới dùng policy mới
```

Same-cycle priority từ kiến trúc:

```text
dma_ctx_done
    > accepted dma_ctx_valid allocation
    > accepted APB config write
    > ACL snapshot
```

Transaction cùng cạnh revoke thấy Region 4 và 5 inactive. Transaction cùng cạnh allocation hợp lệ được phép thấy region mới.

## 6.1. Boundary được đề nghị

Stage 1 đã có slot AW và AR riêng. Matcher nên có một decision slot cho mỗi channel hoặc phát decision vào owner slot do top-level sở hữu. Bất kể file nào giữ register, bundle sau phải bất biến cho tới terminal handshake:

- allow hoặc deny.
- fault code.
- ID.
- LEN.
- ERR_MODE.
- Descriptor cần cho routing hoặc logging.

> [BÀI TẬP] Vẽ một sơ đồ chỉ rõ register nào thuộc Stage 1, matcher và top owner. Mỗi register chỉ có một owner. Ghi điều kiện set và clear cạnh register.

<!-- pagebreak -->

# 7. Port contract gợi ý

SystemVerilog arrays làm bài dễ đọc. Nếu tool chỉ hỗ trợ Verilog-2001, flatten các arrays nhưng giữ cùng ý nghĩa.

```systemverilog
module fw_acl_matcher #(
    parameter REGION_COUNT = 8,
    parameter ID_WIDTH     = 4
) (
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic                     req_valid,
    output logic                     req_ready,
    input  logic                     req_is_write,
    input  logic [31:0]              req_start,
    input  logic [31:0]              req_last,
    input  logic [7:0]               req_len,
    input  logic [2:0]               req_size,
    input  logic [2:0]               req_prot,
    input  logic [ID_WIDTH-1:0]      req_id,
    input  logic                     req_profile_err,
    input  logic                     req_overflow_err,
    input  logic                     req_4kb_err,

    input  logic                     fw_en,
    input  logic                     err_mode,
    input  logic [31:0]              rgn_base   [REGION_COUNT],
    input  logic [31:0]              rgn_limit  [REGION_COUNT],
    input  logic                     rgn_active [REGION_COUNT],
    input  logic                     rgn_read   [REGION_COUNT],
    input  logic                     rgn_write  [REGION_COUNT],
    input  logic                     rgn_secure [REGION_COUNT],
    input  logic                     rgn_priv   [REGION_COUNT],
    input  logic [ID_WIDTH-1:0]      rgn_mid    [REGION_COUNT],
    input  logic [ID_WIDTH-1:0]      rgn_mask   [REGION_COUNT],

    output logic                     decision_valid,
    input  logic                     decision_ready,
    output logic                     decision_allow,
    output logic [3:0]               decision_fault_code,
    output logic [ID_WIDTH-1:0]      decision_id,
    output logic [7:0]               decision_len,
    output logic                     decision_err_mode
);
```

Port contract này gom read và write vào một request unit để dạy thuật toán. Integration có thể dùng hai instance hoặc hai channel logic trong một module. Nếu dùng một shared matcher, phải chứng minh arbitration không làm AW và AR ảnh hưởng ownership của nhau.

Baseline cho phép một outstanding read và một outstanding write. Hai decision path độc lập thường dễ kiểm chứng hơn shared state.

<!-- pagebreak -->

# 8. Thiết kế RTL theo từng mốc

## Mốc 1: Một region, một request read

Hiện thực `cover`, `id_ok`, `prot_ok`, `read_ok`. Test inside, below base, above limit, exact base và exact limit.

## Mốc 2: Write channel

Thêm `req_is_write` và `WRITE_EN`. Test cùng descriptor với read pass, write deny.

## Mốc 3: Tám region

Dùng loop tổ hợp để tạo vectors:

```systemverilog
integer i;
always_comb begin
    cover_vec = '0;
    allow_vec = '0;
    for (i = 0; i < REGION_COUNT; i = i + 1) begin
        // Bài tập: tính cover_vec[i] và allow_vec[i].
        // Region không cover không được kéo kết quả AND xuống 0.
    end
end
```

## Mốc 4: Most-restrictive reduction

Khởi tạo `any_cover=0`, `all_cover_allow=1`. Với mỗi region cover, set any và AND điều kiện allow. Test đổi thứ tự descriptor mà kết quả giữ nguyên.

## Mốc 5: Fault classification

Tách profile faults khỏi ACL faults. Viết expected code table trước RTL. Test mỗi nguyên nhân riêng rồi test tổ hợp.

## Mốc 6: `FW_EN` bypass

Test ACL-only deny với `FW_EN=1` và 0. Sau đó giữ `FW_EN=0` nhưng bật profile error; request vẫn deny.

## Mốc 7: Decision register và backpressure

Chốt bundle khi `req_valid && req_ready`. Khi `decision_valid && !decision_ready`, giữ toàn bộ bundle ổn định. Không nhận request mới khi slot đầy.

<!-- pagebreak -->

# 9. Pure reference model trong testbench

Reference model phải độc lập với cách viết RTL. Không copy cùng vòng lặp rồi chỉ đổi tên biến.

Pseudocode:

```text
function evaluate(request, policy):
    if request.stage1_error:
        return DENY, channel_error OR BOUND_ERR

    if policy.fw_en == 0:
        return ALLOW, 0

    covered = []
    for region in policy.regions:
        if region.active and request.start >= region.base
                         and request.last <= region.limit:
            covered.append(region)

    if covered is empty:
        return DENY, channel_error OR BOUND_ERR_if_partial

    fault = 0
    for region in covered:
        if id mismatch:         fault OR= channel_error
        if protection mismatch: fault OR= channel_error OR PROT_ERR
        if permission mismatch: fault OR= channel_error

    return ALLOW when fault == 0, fault
```

Để phát hiện partial containment, model có thể tính thêm `any_overlap`:

```text
overlap = active AND start <= limit AND last >= base
partial = any_overlap AND NOT any_cover
```

No cover do ở ngoài mọi region là default deny. No full cover nhưng có partial overlap thêm BOUND_ERR.

## 9.1. Scoreboard

Mỗi request tạo expected record trước khi drive. Khi DUT phát `decision_valid && decision_ready`, scoreboard so sánh mọi field.

```systemverilog
if (decision_valid && decision_ready) begin
    expect_bit("allow", decision_allow, expected_allow);
    expect4("fault_code", decision_fault_code, expected_code);
    expect4("id snapshot", decision_id, expected_id);
    expect8("len snapshot", decision_len, expected_len);
end
```

## 9.2. Policy mutation test

1. Cấu hình request được allow.
2. Handshake request vào matcher.
3. Giữ `decision_ready=0`.
4. Đổi region permission, MID và `FW_EN`.
5. Kiểm decision bundle vẫn ổn định.
6. Handshake decision.
7. Gửi request mới và kiểm nó thấy policy mới.

<!-- pagebreak -->

# 10. Ma trận test bắt buộc

| ID | Cấu hình | Expected |
|---|---|---|
| ACL-BND-01 | Start bằng BASE, end trong region | Cover |
| ACL-BND-02 | End bằng LIMIT | Cover |
| ACL-BND-03 | Start nhỏ hơn BASE một byte | Không cover |
| ACL-BND-04 | End lớn hơn LIMIT một byte | Không cover, BOUND_ERR nếu partial |
| ACL-NOM-01 | Không region active | Default deny |
| ACL-PRM-01 | Read trong read-only region | Allow |
| ACL-PRM-02 | Write trong read-only region | WRITE_ERR |
| ACL-MID-01 | MID exact đúng và sai | Pass rồi deny |
| ACL-MID-02 | MID 4, mask 1, test ID 4,5,6 | Allow, allow, deny |
| ACL-PRO-01 | Secure-only với Non-Secure request | Channel error + PROT_ERR |
| ACL-PRO-02 | Priv-only với Unprivileged request | Channel error + PROT_ERR |
| ACL-OVL-01 | RO overlap RW, write vùng chồng | Deny |
| ACL-OVL-02 | Hai region đều allow | Allow |
| ACL-OVL-03 | Đổi index hai region | Kết quả không đổi |
| ACL-PRF-01 | Non-INCR | Channel error + BOUND_ERR |
| ACL-PRF-02 | LEN 16 hoặc lớn hơn | Channel error + BOUND_ERR |
| ACL-PRF-03 | Crossing 4 KiB | Channel error + BOUND_ERR |
| ACL-PRF-04 | Address overflow | Channel error + BOUND_ERR |
| ACL-BYP-01 | ACL-only deny, `FW_EN=0` | Allow |
| ACL-BYP-02 | Profile error, `FW_EN=0` | Deny và log |
| ACL-SNP-01 | Đổi policy khi decision stall | Decision cũ ổn định |
| ACL-SNP-02 | Request mới sau policy change | Dùng policy mới |
| ACL-BKP-01 | `decision_ready=0` nhiều chu kỳ | Payload ổn định |
| ACL-OWN-01 | Request thứ hai khi slot đầy | `req_ready=0` |

## 10.1. Random tests có kiểm soát

Sau directed tests, chạy ít nhất 1.000 request ngẫu nhiên. Randomize:

- Start và length trong miền nhỏ dễ debug.
- Active vector.
- Base và limit hợp lệ.
- Permission, MID và mask.
- PROT.
- Backpressure trên decision.

Seed phải in ra log để tái lập lỗi.

<!-- pagebreak -->

# 11. Assertions và invariant checkers

```systemverilog
property p_decision_stable;
    @(posedge clk) disable iff (!rst_n)
    decision_valid && !decision_ready |=>
      decision_valid &&
      $stable(decision_allow) &&
      $stable(decision_fault_code) &&
      $stable(decision_id) &&
      $stable(decision_len) &&
      $stable(decision_err_mode);
endproperty

property p_no_overwrite;
    @(posedge clk) disable iff (!rst_n)
    decision_valid && !decision_ready |-> !req_ready;
endproperty

property p_profile_error_denied;
    @(posedge clk) disable iff (!rst_n)
    decision_valid && saved_stage1_error |-> !decision_allow;
endproperty
```

Nếu internal saved signals không expose, bind assertion vào hierarchy hoặc tạo checker trong testbench.

# 12. Debug theo triệu chứng

## Burst vượt LIMIT vẫn pass

Kiểm matcher có dùng `req_last` hay chỉ dùng `req_start`. In `cover_vec` và cả hai địa chỉ.

## Overlap write pass sai

Kiểm reduction có dùng OR của `allow_vec` hay không. Kiến trúc yêu cầu mọi region cover đều cho phép, nên reduction là most-restrictive AND.

## MID mask ngược nghĩa

Kiểm bit mask bằng 1 phải bỏ qua. Dùng công thức có `~mask` ở cả hai vế.

## `FW_EN=0` cho profile lỗi đi qua

Kiểm bypass được áp dụng sau Stage 1 error gate. Không đặt `if (!fw_en) allow=1` ở đầu thuật toán.

## Decision đổi khi APB write

Kiểm output đang tính trực tiếp từ live region arrays. Thêm snapshot hoặc owner register và giữ đến handshake terminal.

## Latch warning trong matcher

Kiểm mọi vector và output tổ hợp có default trước loop/case. Bất kỳ nhánh thiếu assignment nào có thể suy latch.

<!-- pagebreak -->

# 13. Câu hỏi tự kiểm tra và đáp án

## Câu 1

Với `AxLEN=15`, burst có bao nhiêu beat?

Đáp án: 16 beat, vì AxLEN dùng beats-minus-one.

## Câu 2

Region `[0x1000,0x1FFF]` có cover burst `[0x1FF0,0x200F]` không?

Đáp án: không. Burst chỉ giao một phần và end vượt LIMIT.

## Câu 3

MID `4'b0100`, mask `4'b0001` cho phép ID nào trong 4, 5 và 6?

Đáp án: 4 và 5 pass; 6 fail.

## Câu 4

Vì sao first-match-wins sai?

Đáp án: khi hai region overlap, một region có thể hạn chế hơn region kia. Kết quả phải là AND của mọi region cover, không phụ thuộc index.

## Câu 5

`FW_EN=0` bỏ qua crossing 4 KiB không?

Đáp án: không. Nó chỉ bypass ACL permission. Profile, overflow, 4 KiB, framing và logging vẫn hoạt động.

## Câu 6

Policy đổi sau request handshake có đổi decision hiện tại không?

Đáp án: không. Request dùng effective policy snapshot đã chốt tại address acceptance.

# 14. Rubric và exit gate

| Hạng mục | Điểm | Điều kiện đạt trọn điểm |
|---|---:|---|
| Burst arithmetic và containment | 2.0 | Boundary, overflow và partial overlap đúng |
| Region policy | 2.0 | MID, PROT, permission và default deny đúng |
| Overlap resolution | 1.5 | Most-restrictive AND, không phụ thuộc index |
| Snapshot và handshake | 1.5 | Decision giữ ổn định, không overwrite slot |
| Verification | 2.5 | Reference model, directed, random, timeout, scoreboard |
| Bằng chứng | 0.5 | Log, seed và waveform truy xuất được |

Exit gate:

- Tám region dùng cùng rule.
- Full-burst containment có negative tests.
- Overlap AND có checker.
- `FW_EN` bypass không bỏ profile checks.
- Decision bundle ổn định dưới stall.
- Directed suite và 1.000 random requests PASS.

# 15. Checklist nộp bài

- [ ] RTL và package/type definitions.
- [ ] Self-checking testbench.
- [ ] Pure reference model.
- [ ] Directed test matrix và random seed log.
- [ ] Waveform partial containment.
- [ ] Waveform overlap deny.
- [ ] Sơ đồ state ownership và snapshot.
- [ ] Ghi chú xử lý interface gap của profile/overflow flags.

# 16. Tài liệu nguồn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 5.2 đến 5.4
- `DMA-controller/docs/architecture/register_map.csv`
- `DMA-controller/docs/architecture/signal_list.csv`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`, invariant 1, 4, 9
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/lessons/bai-04-fw-acl-matcher.html`
