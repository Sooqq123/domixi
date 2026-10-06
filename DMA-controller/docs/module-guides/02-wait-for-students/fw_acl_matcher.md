# Chuẩn bị thiết kế `fw_acl_matcher`

> Phân loại: `WAIT_FOR_STUDENTS`. Module chờ Gói sinh viên 02: matcher RTL, reference model, testbench và evidence.

## 1. Vì sao chưa thiết kế tiếp

`fw_acl_matcher` là điểm ra quyết định bảo mật của Firewall. Bài nộp sinh viên 02 phải hiện thực full-burst containment, eight-region parallel policy, MID/PROT/permission và most-restrictive overlap. Viết một matcher thứ hai lúc này sẽ làm mờ nguồn quyết định và có thể vô tình thay đổi policy.

Có thể chuẩn bị model review, interface conformance list và integration stubs. Không viết RTL matcher cuối cùng trước khi nhận và đánh giá gói.

## 2. Mục tiêu module sau bàn giao

Matcher nhận snapshot AW/AR từ Stage 1 cùng effective ACL snapshot, rồi tạo quyết định bất biến:

- allowed transaction đi tới Matrix;
- denied transaction đi tới drain;
- fault code phản ánh profile, permission, protection và boundary;
- descriptor và policy dùng cho quyết định là snapshot nguyên tử.

Một address handshake vào Firewall chỉ là nhận yêu cầu để đánh giá, không phải cấp quyền.

## 3. Gói đầu vào bắt buộc từ sinh viên 02

| Hạng mục | Yêu cầu |
|---|---|
| RTL | `fw_acl_matcher.v` compile độc lập |
| TB | Directed và constrained-random self-checking |
| Pure model | Function/model không sao chép structure RTL |
| Port list | Stage 1 fields, region fields, decisions và fault metadata |
| Policy note | MID mask, PROT, permissions, overlap, FW_EN |
| Seeds | Danh sách seed random tái lập được |
| Logs | PASS/FAIL và test count |
| Wave | Stall snapshot, overlap deny, boundary/profile deny |
| Contract report | Đối chiếu sáu Stage 1 flags canonical và LEN/SIZE fault metadata |

## 4. Input contract cần review

Mỗi AW/AR snapshot cần start, end, LEN, SIZE, BURST, PROT, ID và ba cờ lỗi. AW dùng `pipe_s1_aw_profile_err`, `pipe_s1_aw_overflow_err`, `pipe_s1_aw_4kb_err`; AR dùng ba tên `pipe_s1_ar_*` tương ứng. Matcher không được tính lại từ live AXI signals.

Mỗi trong tám regions cần:

- active;
- base và inclusive limit;
- read permission;
- write permission;
- secure-only;
- privileged-only;
- master ID và mask.

Region 4/5 là state động sau priority context. Regions khác đến từ APB state sau priority config. Snapshot transaction phải thấy đúng effective policy tại handshake.

## 5. Full-burst containment

Một region match địa chỉ khi:

```text
region_active
AND start >= base
AND end <= limit
AND region descriptor hợp lệ
```

Kiểm start-only là sai. Burst bắt đầu trong vùng nhưng kết thúc ngoài limit phải bị deny. Partial overlap từ ngoài vào trong cũng không match.

Descriptor có base lớn hơn limit không được cấp quyền. Cách ghi nhận config invalid phải theo APB contract, nhưng matcher tuyệt đối không coi vùng đó hợp lệ.

## 6. ID, protection và permission

MID match phải theo định nghĩa mask canonical. Testbench cần vector phân biệt exact match, wildcard bit và all bits. Không suy đoán convention mask từ một implementation.

Protection cần kiểm:

- Secure nếu region yêu cầu secure;
- Privileged nếu region yêu cầu privileged;
- Data profile theo `AxPROT=3'b001` của DMA baseline.

MID/mask và PROT là các kiểm tra độc lập ở matcher. Chúng không thuộc Stage 1 `profile_err`, vốn chỉ bao gồm BURST, SIZE, address alignment và LEN.

Write chỉ pass nếu mọi region match liên quan đều cho write. Read tương tự với read permission.

## 7. Most-restrictive overlap

Khi burst nằm trọn trong nhiều region active, kết quả là AND mọi constraint của các region match. Một region cho phép và một region từ chối phải cho kết quả deny.

Không dùng first match, lowest index wins hoặc OR permission. Random model phải tạo overlap có chủ đích và thay đổi từng permission để chứng minh reduction.

## 8. `FW_EN` và profile errors

Khi `FW_EN=1`, không match region là default deny.

Khi `FW_EN=0`, policy region có thể bypass theo canonical control, nhưng lỗi AXI profile, overflow hoặc crossing 4 KiB không được tự động trở thành giao dịch hợp lệ. Bypass security policy không phải bypass protocol safety.

Fault mapping cần đối chiếu bitmask canonical:

- read permission error;
- write permission error;
- protection or protocol error;
- boundary or profile error.

Không tự gộp lỗi nếu register map cần nhiều bit cùng lên.

## 9. Việc được chuẩn bị trước khi nhận gói

### 9.1. Golden model độc lập

Viết bảng truth hoặc script model dựa trên canonical equations, không nhìn cấu trúc RTL nộp. Model nhận một transaction snapshot và mảng tám region rồi trả pass/fault.

### 9.2. Stage 1 driver

Tạo driver phát snapshot đã tính sẵn với đúng sáu cờ canonical profile/overflow/4 KiB. Điều này cho phép test matcher không phụ thuộc address slice RTL.

### 9.3. Policy generator

Sinh region hợp lệ, invalid, disjoint và overlapping với seed cố định. Luôn log đầy đủ policy khi mismatch.

### 9.4. Decision sink

Tạo sink có ready stall để kiểm matcher giữ decision và metadata ổn định.

### 9.5. Interface contract ledger

Ghi rõ producer, consumer, width và stability của sáu Stage 1 flags. Với denied transaction, chuyển ID, LEN và SIZE từ immutable AW/AR snapshot vào fault path; không đọc lại live AXI bus.

## 10. Quyết định chưa được phép khóa

- Không chọn mask semantics khác canonical để khớp code sinh viên.
- Không dùng first-match priority thay most-restrictive AND.
- Không bỏ profile errors khi `FW_EN=0`.
- Không đánh giá live APB policy sau transaction acceptance.
- Không chuyển read/write owner state vào matcher; top sở hữu owner lifecycle.
- Không đổi tên hoặc gộp sáu Stage 1 flags canonical.
- Không sửa region count xuống ít hơn tám để đơn giản hóa.

## 11. Checklist review gói nộp

### Source

- Combinational và sequential boundaries rõ.
- Không latch do thiếu default.
- Output decision ổn định dưới backpressure.
- AW và AR state độc lập.

### Policy correctness

- Full start/end containment.
- Invalid descriptor không match.
- MID mask đúng convention.
- Secure, privileged, data profile đúng.
- Read/write permission đúng direction.
- Overlap dùng AND mọi match.
- No-match default deny khi enabled.

### Snapshot

- Policy được chốt nguyên tử với transaction.
- Config/context thay đổi sau handshake không đổi decision.
- Một request được phát đúng một decision.

### Fault

- Profile, overflow, 4 KiB đi đến fault.
- Permission và PROT mapping đúng bit.
- Address, ID, LEN/SIZE metadata không lấy từ live bus.

### Evidence

- Directed edge cases PASS.
- Random seeds tái chạy được.
- Mismatch report có input policy đầy đủ.
- Timeout và explicit PASS marker.

## 12. Acceptance tests tối thiểu

| ID | Nội dung |
|---|---|
| ACL-01 | Một region allow read và write theo permission |
| ACL-02 | No match với FW enabled |
| ACL-03 | Start trong, end ngoài region |
| ACL-04 | Start ngoài, end trong region |
| ACL-05 | Base lớn hơn limit |
| ACL-06 | MID exact và masked mismatch |
| ACL-07 | Non-secure, unprivileged và non-data |
| ACL-08 | Two-region overlap cùng allow |
| ACL-09 | Two-region overlap một deny |
| ACL-10 | Profile, overflow và 4 KiB flags |
| ACL-11 | FW disabled nhưng profile invalid |
| ACL-12 | Policy mutation sau acceptance |
| ACL-13 | AW/AR simultaneous và independent stalls |
| ACL-14 | Random eight-region differential testing |

## 13. Rủi ro khi bắt đầu sớm

| Rủi ro | Hậu quả |
|---|---|
| Policy bị phân đôi | Hai matcher cho kết quả khác nhau |
| Nối nhầm sáu cờ Stage 1 | Matcher không phân biệt profile và arithmetic fault |
| Live policy evaluation | TOCTOU trong burst |
| Random model sao chép RTL | Cùng một bug vẫn PASS |
| Overlap semantics sai | Vi phạm most-restrictive policy |

## 14. Mẫu tiếp tục sau bàn giao

```text
Package: student-02 fw_acl_matcher
RTL and TB identifiers:
Reference model identifier:
Directed tests passed:
Random seeds passed:
Stage 1 port contract result:
Canonical policy mismatches:
Required corrections:
Acceptance decision:
```

## 15. Điều kiện chuyển sang `READY_NOW`

- RTL, TB và pure reference model chạy được.
- Most-restrictive overlap và full containment có evidence.
- Mask semantics được xác nhận.
- Sáu Stage 1 flags dùng đúng tên canonical và được giữ ổn định cùng snapshot.
- Denied read/write fault path bảo toàn ID, LEN và SIZE từ immutable snapshot.
- Decision/fault payload ổn định dưới stall.
- Mọi mismatch với architecture đã đóng.

## 16. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.2, 5.2 và 5.3
- `DMA-controller/docs/architecture/signal_list.csv`, Stage 1 và matcher decisions
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/register_map.csv`, region fields và fault code
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/02_fw_acl_matcher_lab_guide.md`
