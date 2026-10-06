# Thiết kế `fw_axi_address_slice`

> Phân loại: `READY_NOW`. Đây là Stage 1 của Firewall address pipeline. Chưa có Firewall RTL hiện hành được công nhận trong source tree.

## 1. Mục tiêu và phạm vi

`fw_axi_address_slice` nhận AW và AR từ DMA, chốt độc lập từng descriptor vào một elastic slot, tính byte cuối của burst và phát các cờ lỗi profile. Module không quyết định ACL pass hoặc deny. Quyết định quyền thuộc `fw_acl_matcher` ở Stage 2.

Sản phẩm cần có:

- một one-entry elastic slice riêng cho AW;
- một one-entry elastic slice riêng cho AR;
- phép tính range bằng arithmetic mở rộng;
- cờ profile, overflow và crossing 4 KiB;
- payload ổn định dưới Stage 2 backpressure;
- testbench độc lập với checker toán học.

## 2. Trạng thái tài liệu hiện tại

Kiến trúc V2.4.1 đủ để thiết kế hành vi Stage 1, nên module thuộc `READY_NOW`. Hợp đồng cờ lỗi đã được đóng trong `signal_list.csv`. AW dùng:

- `pipe_s1_aw_profile_err`;
- `pipe_s1_aw_overflow_err`;
- `pipe_s1_aw_4kb_err`.

AR dùng ba tên tương ứng: `pipe_s1_ar_profile_err`, `pipe_s1_ar_overflow_err` và `pipe_s1_ar_4kb_err`. Đây là tên canonical phải dùng ở ranh giới Stage 1 sang Stage 2.

Một draft address slice cũ từng được nhắc trong lịch sử tài liệu không được coi là source hiện hành. Không sao chép port hoặc hành vi từ draft đó nếu mâu thuẫn V2.4.1.

## 3. Giao diện logic cần có

### Phía DMA

Mỗi channel AW/AR cần `VALID`, `READY`, `ADDR[31:0]`, `ID[3:0]`, `LEN[7:0]`, `SIZE[2:0]`, `BURST[1:0]`, `PROT[2:0]`.

### Phía Stage 2

Mỗi snapshot cần:

- `valid`, `ready`;
- address đầu và byte cuối;
- ID, LEN, SIZE, BURST, PROT;
- `pipe_s1_aw_profile_err`, `pipe_s1_aw_overflow_err`, `pipe_s1_aw_4kb_err` cho AW;
- `pipe_s1_ar_profile_err`, `pipe_s1_ar_overflow_err`, `pipe_s1_ar_4kb_err` cho AR.

Không tự đổi tên, gộp hoặc suy diễn lại sáu signal canonical này.

## 4. Elastic slice một entry

AW và AR độc lập hoàn toàn. Với mỗi channel:

```text
slot_ready = NOT slot_valid OR downstream_ready
accept     = upstream_valid AND slot_ready
```

Khi `accept=1`, chốt payload mới và đặt `slot_valid=1`. Khi downstream consume slot mà không có replacement cùng cạnh, hạ `slot_valid`. Khi slot full và downstream không ready, upstream ready phải hạ và toàn bộ payload giữ nguyên.

Trường hợp consume và replace cùng cạnh phải được hỗ trợ để đạt một request mỗi chu kỳ khi Stage 2 luôn ready.

Không dùng chung một valid bit cho AW và AR. Một channel bị stall không được chặn channel kia nếu không có lý do tài nguyên chung trong contract.

## 5. Phép tính byte cuối

Với `AxLEN`, `AxSIZE`, `AxADDR`:

```text
beats       = zero_extend(AxLEN, 9) + 1
bytes_beat  = 1 << AxSIZE
span_bytes  = beats * bytes_beat
last_ext    = zero_extend(AxADDR, đủ rộng) + span_bytes - 1
last_byte   = last_ext[31:0]
overflow    = OR các bit trên bit 31 của last_ext
```

Không tính hoàn toàn ở 32 bit. Nếu overflow đã xảy ra, `last_byte` thấp chỉ là phần wrap và không được dùng để làm burst hợp lệ.

`AxSIZE` nằm ngoài profile vẫn phải được xử lý an toàn. Có thể dùng arithmetic đủ rộng cho miền AXI biểu diễn, hoặc chặn shift width bằng logic rõ ràng. Không để shift không kiểm soát làm checker hoặc synthesis diễn giải khác nhau.

## 6. Các cờ lỗi

### Profile error

Trong DMA-constrained profile, lỗi khi bất kỳ điều kiện nào sai:

```text
AxBURST == INCR
AxSIZE  == 4 bytes
AxADDR word-aligned
AxLEN   <= 15
```

`AxID` và `AxPROT` không thuộc `profile_err`. Stage 1 vẫn chốt hai field này nguyên vẹn, còn `fw_acl_matcher` kiểm MID/mask và PROT độc lập để tạo fault mapping đúng.

### Address overflow

Lên khi byte cuối vượt `0xFFFF_FFFF`. Cờ phải dựa vào carry mở rộng, không dựa vào `last_byte < start` cho mọi trường hợp shift lớn.

### Crossing 4 KiB

Với range không overflow:

```text
cross_4kb = AxADDR[31:12] != last_byte[31:12]
```

Nếu overflow, transaction đã lỗi và `4kb_err` cũng phải bằng 1. Vì vậy `overflow_err` và `4kb_err` có thể cùng bằng 1; matcher không được coi đây là hai transaction hoặc bỏ một cờ.

## 7. Reset và stability

Reset active-low xóa hai valid slots. Payload register có thể về 0 để waveform dễ đọc. Sau reset không được phát snapshot giả.

Khi `slot_valid && !downstream_ready`, các field sau phải ổn định:

- start và end address;
- ID, LEN, SIZE, BURST, PROT;
- mọi cờ lỗi.

Các cờ phải được chốt cùng descriptor, không được tính trực tiếp từ live input sau handshake.

## 8. Cấu trúc file đề xuất

Một file có thể chia thành:

1. Helper function tính range và flags.
2. AW slot combinational ready/accept.
3. AW sequential snapshot.
4. AR slot combinational ready/accept.
5. AR sequential snapshot.

Nếu dùng function chung, phải kiểm width tường minh. Không ghép ACL table hoặc owner state vào Stage 1.

## 9. Thiết kế từ đầu theo mốc

### Mốc 1: Range reference model

Trong testbench, dùng arithmetic rộng hơn 32 bit để tính expected end, overflow và 4 KiB. Sweep LEN 0, 15, 16, SIZE hợp lệ và sai, address quanh `0xFFC` và `0xFFFF_FFFF`.

### Mốc 2: AW slot

Test empty accept, full stall, consume, consume-and-replace và reset. Thêm stability assertion.

### Mốc 3: AR slot

Lặp cùng suite nhưng giữ AW channel hoạt động song song để chứng minh độc lập.

### Mốc 4: Profile flags

Thay từng field một khỏi profile. Một vector chỉ sai một điều kiện giúp xác định checker bị nối nhầm.

### Mốc 5: Throughput và simultaneous channels

Đẩy AW và AR mỗi chu kỳ khi Stage 2 ready. Sau đó stall ngẫu nhiên từng ready độc lập và dùng queue scoreboard.

## 10. Test matrix

| ID cục bộ | Stimulus | Expected |
|---|---|---|
| S1-01 | Reset | Hai output valid bằng 0 |
| S1-02 | AW hợp lệ một beat | End bằng start+3, không lỗi |
| S1-03 | AW 16 beat | End bằng start+63 |
| S1-04 | Start `0x00000FFC`, hai beat | 4 KiB error |
| S1-05 | Start gần `0xFFFFFFFF` | Overflow error |
| S1-06 | BURST, SIZE, alignment, LEN sai | Profile error tương ứng |
| S1-07 | ID hoặc PROT khác baseline | Field được chốt nguyên vẹn; riêng hai field này không làm `profile_err` lên |
| S1-08 | Stage 2 stall | Snapshot ổn định, upstream backpressure |
| S1-09 | Consume và replace cùng cạnh | Không bubble, không mất request |
| S1-10 | AW và AR đồng thời | Cả hai được xử lý độc lập |
| S1-11 | Stall AW, AR vẫn chạy | Không cross-channel blocking |

## 11. Assertion cần có

- Output payload stable khi valid và không ready.
- Slot count cho mỗi channel luôn 0 hoặc 1.
- Số snapshot consumed không vượt số request accepted.
- Mỗi accepted request xuất hiện đúng một lần ở output.
- `last_byte` và flags khớp reference model ở thời điểm accept.
- Reset xóa valid ngay theo reset contract.

## 12. Điểm cần tránh

- Tính byte cuối bằng 32 bit rồi mới đoán overflow.
- Chỉ kiểm low 12 bit để suy ra crossing khi address đã overflow.
- Dùng live AXI input làm Stage 2 payload sau handshake.
- Một slot chung cho AW và AR.
- Rút upstream READY chỉ vì output valid dù downstream đang consume cùng cạnh.
- Gộp hoặc đổi tên sáu cờ đã được `signal_list.csv` chốt.
- Dùng draft cũ để override V2.4.1.

## 13. Rủi ro và cách đóng

| Rủi ro | Cách đóng |
|---|---|
| Nối sai cờ AW/AR | Đối chiếu đúng sáu tên trong signal list và test hai channel đồng thời |
| Width arithmetic sai | Reference model rộng và boundary sweep |
| Mất request khi replace | Queue scoreboard một request vào, một snapshot ra |
| TOCTOU từ live payload | Chốt mọi field và flag cùng handshake |
| Throughput có bubble | Test request liên tục với downstream luôn ready |

## 14. Tiêu chí hoàn thành

- AW và AR elastic behavior PASS độc lập và đồng thời.
- Mọi boundary arithmetic khớp model.
- Payload ổn định dưới backpressure.
- Profile, overflow và 4 KiB error đều có directed test.
- Port list dùng đúng ba cờ AW và ba cờ AR canonical.
- Không có ACL decision hoặc drain state trong module.

## 15. Lộ trình tự triển khai

Trước hết hãy viết model tính range và boundary test. Sau đó hiện thực một AW slot hoàn chỉnh. Khi AW pass toàn bộ stall cases, nhân cấu trúc sang AR nhưng giữ state riêng. Cuối cùng thêm sáu cờ canonical và simultaneous traffic. Chỉ nối sang matcher sau khi unit test chứng minh snapshot stability và các cờ đúng contract.

## 16. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.2, 5.1 và 5.2
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/signal_list.csv`, nhóm `STAGE1_TO_STAGE2`
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/architecture/requirements_traceability.csv`
- `DMA-controller/docs/architecture/fsm_specification.md`
