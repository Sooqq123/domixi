# Firewall interface gap resolution implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phát hành các quyết định giao diện Firewall đã duyệt vào tài liệu kiến trúc và module guides mà không viết hoặc sửa RTL Firewall.

**Architecture:** `signal_list.csv` sở hữu tên, width, producer và consumer của internal contract. Architecture overview cùng integration contract sở hữu semantics. Status và traceability phản ánh source tree. Module guides diễn giải lại contract đã phát hành nhưng không tạo quyết định riêng.

**Tech stack:** Markdown, CSV, PowerShell, Git.

**Spec:** `docs/superpowers/specs/2026-09-02-firewall-interface-gap-resolution-design.md`

## Global constraints

- Không tạo hoặc sửa file RTL, testbench, assertion, script mô phỏng hoặc adapter.
- Không sửa `DMA-controller/docs/tutorials/firewall-rtl/` hoặc PDF hiện có.
- Tên canonical duy nhất của APB Firewall register block là `fw_apb_regs`.
- Stage 1 profile chỉ gồm BURST, SIZE, address alignment và LEN; MID/PROT thuộc matcher policy.
- Read/write fault record có ID, LEN và SIZE; context first-fault dùng ID/LEN/SIZE bằng 0.
- `fw_drain_fsm` là wrapper của `fw_write_drain` và `fw_read_drain`.
- Không tạo module hoặc wrapper cho `dma_top`, `dma32` hoặc `fifo32`.
- Source status chỉ là partial hoặc implemented khi file và evidence truy xuất được tồn tại.
- Dùng `apply_patch` cho mọi chỉnh sửa thủ công.
- Worktree có thay đổi không thuộc nhiệm vụ; chỉ stage và commit đúng file của từng task.
- Không dùng dấu gạch dài Unicode hoặc double-hyphen separator trong văn xuôi mới.

---

### Task 1: Khóa internal signal contract

**Files:**

- Modify: `DMA-controller/docs/architecture/signal_list.csv`

**Interfaces:**

- Consumes: Quyết định 1 và 2 trong spec đã duyệt.
- Produces: Tên signal canonical cho Stage 1 errors, fault LEN/SIZE và write framing pulse.

- [ ] **Step 1: Chạy kiểm tra trước thay đổi**

Run:

```powershell
$p = 'DMA-controller/docs/architecture/signal_list.csv'
$required = @(
  'pipe_s1_aw_profile_err','pipe_s1_aw_overflow_err',
  'pipe_s1_ar_profile_err','pipe_s1_ar_overflow_err',
  'w_fault_event_len','w_fault_event_size',
  'r_fault_event_len','r_fault_event_size',
  'w_framing_fault_valid','w_framing_fault_code'
)
$text = Get-Content -Raw $p
$required | ForEach-Object { "$_=" + $text.Contains($_) }
```

Expected: Cả mười signal báo `False` trước khi cập nhật.

- [ ] **Step 2: Bổ sung Stage 1 error flags**

Chèn các dòng AW ngay sau `pipe_s1_aw_4kb_err` và các dòng AR ngay sau `pipe_s1_ar_4kb_err`:

```csv
pipe_s1_aw_profile_err,STAGE1_TO_STAGE2,Internal,Status,1,clk,rst_n,High,pipe_s1_awvalid,Internal Pipeline,fw_axi_address_slice,fw_acl_matcher,0,Cờ AW vi phạm BURST SIZE address alignment hoặc LEN của constrained profile
pipe_s1_aw_overflow_err,STAGE1_TO_STAGE2,Internal,Status,1,clk,rst_n,High,pipe_s1_awvalid,Internal Pipeline,fw_axi_address_slice,fw_acl_matcher,0,Cờ extended last byte của AW vượt không gian địa chỉ 32 bit
pipe_s1_ar_profile_err,STAGE1_TO_STAGE2,Internal,Status,1,clk,rst_n,High,pipe_s1_arvalid,Internal Pipeline,fw_axi_address_slice,fw_acl_matcher,0,Cờ AR vi phạm BURST SIZE address alignment hoặc LEN của constrained profile
pipe_s1_ar_overflow_err,STAGE1_TO_STAGE2,Internal,Status,1,clk,rst_n,High,pipe_s1_arvalid,Internal Pipeline,fw_axi_address_slice,fw_acl_matcher,0,Cờ extended last byte của AR vượt không gian địa chỉ 32 bit
```

- [ ] **Step 3: Bổ sung fault LEN/SIZE và framing pulse**

Chèn LEN/SIZE ngay sau ID của record cùng direction:

```csv
w_fault_event_len,FAULT_LOGGING,Internal,Input,8,clk,rst_n,High,w_fault_event_valid,Independent Event,dma_bus_firewall,fw_apb_regs,8'h00,AWLEN từ immutable write owner metadata
w_fault_event_size,FAULT_LOGGING,Internal,Input,3,clk,rst_n,High,w_fault_event_valid,Independent Event,dma_bus_firewall,fw_apb_regs,3'b000,AWSIZE từ immutable write owner metadata
r_fault_event_len,FAULT_LOGGING,Internal,Input,8,clk,rst_n,High,r_fault_event_valid,Independent Event,fw_acl_matcher,fw_apb_regs,8'h00,ARLEN từ denied AR snapshot
r_fault_event_size,FAULT_LOGGING,Internal,Input,3,clk,rst_n,High,r_fault_event_valid,Independent Event,fw_acl_matcher,fw_apb_regs,3'b000,ARSIZE từ denied AR snapshot
w_framing_fault_valid,DRAIN_INTERFACE,Internal,Status,1,clk,rst_n,High,WLAST mismatch handshake,1-Cycle Request,fw_drain_fsm,dma_bus_firewall,0,Xung báo early hoặc missing final WLAST
w_framing_fault_code,DRAIN_INTERFACE,Internal,Input,4,clk,rst_n,High,w_framing_fault_valid,Stable Event Payload,fw_drain_fsm,dma_bus_firewall,4'b0110,Bitmask WRITE_ERR cộng PROT_ERR
```

Sửa producer của bốn dòng hiện có `w_fault_event_valid/code/addr/id` thành `dma_bus_firewall`. Giữ producer của read fault record là `fw_acl_matcher` và context fault record là `fw_context_tracker`.

- [ ] **Step 4: Kiểm cấu trúc CSV và signal uniqueness**

Run:

```powershell
$p = 'DMA-controller/docs/architecture/signal_list.csv'
$rows = Import-Csv $p
$names = $rows.'Signal Name'
$dupes = $names | Group-Object | Where-Object Count -gt 1
if ($dupes) { $dupes | Format-Table; exit 1 }
$required = @(
  'pipe_s1_aw_profile_err','pipe_s1_aw_overflow_err',
  'pipe_s1_ar_profile_err','pipe_s1_ar_overflow_err',
  'w_fault_event_len','w_fault_event_size',
  'r_fault_event_len','r_fault_event_size',
  'w_framing_fault_valid','w_framing_fault_code'
)
$missing = $required | Where-Object { $_ -notin $names }
if ($missing) { $missing; exit 1 }
Write-Output 'PASS signal contract'
```

Expected: `PASS signal contract`, không có signal trùng.

- [ ] **Step 5: Review và commit Task 1**

Run:

```powershell
git diff --check DMA-controller/docs/architecture/signal_list.csv
git diff DMA-controller/docs/architecture/signal_list.csv
git add DMA-controller/docs/architecture/signal_list.csv
git commit -m "docs: freeze firewall internal signal contract"
```

Expected: Diff chỉ chứa các signal đã nêu và producer correction của write fault record.

---

### Task 2: Đồng bộ semantics trong architecture contract

**Files:**

- Modify: `DMA-controller/docs/architecture/architecture_overview.md`
- Modify: `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- Modify: `DMA-controller/docs/architecture/fsm_specification.md`

**Interfaces:**

- Consumes: Signal names từ Task 1.
- Produces: Semantics canonical cho profile, metadata, APB module name và drain wrapper.

- [ ] **Step 1: Chạy contract scan trước thay đổi**

Run:

```powershell
rg -n 'fw_apb_slave|profile_err|overflow_err|FAULT_LEN|FAULT_SIZE|fw_write_drain|fw_read_drain|w_framing_fault' DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
```

Expected: Có `fw_apb_slave` trong architecture overview; chưa có contract đầy đủ cho bốn Stage 1 flags và LEN/SIZE event fields.

- [ ] **Step 2: Sửa architecture overview**

Áp dụng các thay đổi nội dung sau:

1. Thay tên APB Firewall trong phần profile từ `fw_apb_slave` thành `fw_apb_regs`.
2. Ghi constrained Stage 1 profile chính xác là `AxBURST=INCR`, `AxSIZE=4 bytes`, word alignment và `AxLEN<=15`.
3. Ghi MID và PROT được matcher xử lý riêng, không thuộc `profile_err`.
4. Ghi Stage 1 chốt `profile_err`, `overflow_err` và `4kb_err` cùng AW/AR snapshot.
5. Ghi read/write fault records mang ID/LEN/SIZE; context record dùng ba field bằng 0.
6. Ghi write framing pulse dùng immutable write-owner metadata tại top để tạo full fault record.
7. Ghi `fw_drain_fsm` là wrapper của hai FSM direction độc lập.

- [ ] **Step 3: Sửa integration contract**

Trong bảng module, định nghĩa:

```text
fw_drain_fsm.v: wrapper canonical, instantiate fw_write_drain và fw_read_drain; không serialize hai direction
fw_apb_regs.v: tên duy nhất của APB4 register block
```

Trong phần interface/invariants, thêm các ràng buộc:

```text
Stage 1 snapshot carries profile_err, overflow_err and 4kb_err per AW/AR channel.
Write/read fault records carry ID, LEN and SIZE.
Context first-fault encodes ID=0, LEN=0 and SIZE=0.
Write framing pulse is enriched with retained write-owner metadata before fw_apb_regs.
```

Không thêm module `fw_apb_slave` hoặc fault-arbiter module mới.

- [ ] **Step 4: Sửa FSM specification**

Giữ nguyên write/read drain state transitions. Bổ sung vào write drain section:

```text
w_framing_fault_valid is a one-cycle pulse.
w_framing_fault_code is WRITE_ERR | PROT_ERR.
dma_bus_firewall combines the pulse with retained AWADDR/AWID/AWLEN/AWSIZE metadata.
```

Ghi rõ wrapper không dùng chung state giữa read và write drain.

- [ ] **Step 5: Kiểm semantics**

Run:

```powershell
rg -n 'fw_apb_slave' DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
rg -n 'profile_err|overflow_err|FAULT_LEN|FAULT_SIZE|w_framing_fault|fw_write_drain|fw_read_drain' DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
```

Expected: Lệnh đầu không có kết quả. Lệnh sau tìm được đầy đủ các semantics mới.

- [ ] **Step 6: Review và commit Task 2**

Run:

```powershell
git diff --check DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
git diff DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
git add DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
git commit -m "docs: publish firewall interface semantics"
```

Expected: Chỉ thay đổi prose contract, không có RTL hoặc tutorial file.

---

### Task 3: Hiệu chỉnh implementation status và traceability

**Files:**

- Modify: `DMA-controller/docs/architecture/implementation_conformance_status.md`
- Modify: `DMA-controller/docs/architecture/requirements_traceability.csv`

**Interfaces:**

- Consumes: Source tree hiện hành và status policy từ spec.
- Produces: Trạng thái `MISSING / BLOCKED_FIREWALL_RTL` truy xuất đúng thực tế.

- [ ] **Step 1: Chứng minh source hiện không tồn tại**

Run:

```powershell
$paths = @(
  'DMA-controller/rtl/fw_axi_address_slice.v',
  'rtl/fw_axi_address_slice.v'
)
$paths | ForEach-Object { "$_=" + (Test-Path $_) }
```

Expected: Cả hai đường dẫn báo `False`.

- [ ] **Step 2: Sửa implementation conformance status**

Đổi Firewall RTL gate thành:

```text
MISSING / BLOCKED_FIREWALL_RTL
```

Xóa claim có partial draft hiện hành. Giữ nguyên kết luận không có source-built Firewall regression và không phê duyệt full-system/PPA.

Đổi deviation `DEV_FW_RTL_01` để ghi source Firewall chưa tồn tại trong cây hiện hành, không ghi partial address-slice draft.

- [ ] **Step 3: Sửa requirements traceability**

Trong mọi dòng `REQ_FW_*` còn dẫn `PARTIAL DRAFT ../../../rtl/fw_axi_address_slice.v NOT INTEGRATED`:

- đổi implementation artifact thành `MISSING planned fw_axi_address_slice.v` cho `REQ_FW_01`, `REQ_FW_02` và `REQ_FW_13`;
- đổi status phrase `RTL Partial` thành `RTL Missing`;
- giữ model verification, planned test và blocker hiện hành.

- [ ] **Step 4: Parse CSV và kiểm stale claims**

Run:

```powershell
Import-Csv 'DMA-controller/docs/architecture/requirements_traceability.csv' | Out-Null
rg -n 'PARTIAL DRAFT.*fw_axi_address_slice|RTL Partial' DMA-controller/docs/architecture/implementation_conformance_status.md DMA-controller/docs/architecture/requirements_traceability.csv
```

Expected: CSV parse không lỗi; `rg` không có kết quả.

- [ ] **Step 5: Review và commit Task 3**

Run:

```powershell
git diff --check DMA-controller/docs/architecture/implementation_conformance_status.md DMA-controller/docs/architecture/requirements_traceability.csv
git diff DMA-controller/docs/architecture/implementation_conformance_status.md DMA-controller/docs/architecture/requirements_traceability.csv
git add DMA-controller/docs/architecture/implementation_conformance_status.md DMA-controller/docs/architecture/requirements_traceability.csv
git commit -m "docs: correct firewall source status"
```

Expected: Chỉ status và traceability claims thay đổi; DMA PASS evidence giữ nguyên.

---

### Task 4: Đồng bộ bộ module guides

**Files:**

- Modify: `DMA-controller/docs/module-guides/README.md`
- Modify: `DMA-controller/docs/module-guides/module-classification-matrix.md`
- Modify: `DMA-controller/docs/module-guides/01-ready-now/fw_axi_address_slice.md`
- Modify: `DMA-controller/docs/module-guides/01-ready-now/fw_data_path_mux.md`
- Modify: `DMA-controller/docs/module-guides/02-wait-for-students/fw_apb_regs.md`
- Modify: `DMA-controller/docs/module-guides/02-wait-for-students/fw_acl_matcher.md`
- Modify: `DMA-controller/docs/module-guides/02-wait-for-students/fw_write_drain.md`
- Modify: `DMA-controller/docs/module-guides/02-wait-for-students/fw_read_drain.md`
- Modify: `DMA-controller/docs/module-guides/02-wait-for-students/fw_drain_fsm.md`
- Modify: `DMA-controller/docs/module-guides/02-wait-for-students/dma_bus_firewall.md`
- Modify: `DMA-controller/docs/module-guides/03-unclear/fw_apb_slave.md`
- Modify: `DMA-controller/docs/module-guides/03-unclear/dma_top.md`
- Modify: `DMA-controller/docs/module-guides/03-unclear/dma32.md`
- Modify: `DMA-controller/docs/module-guides/03-unclear/fifo32.md`

**Interfaces:**

- Consumes: Canonical contract sau Tasks 1 đến 3.
- Produces: Hướng dẫn tự thiết kế không còn blocker đã đóng hoặc profile membership sai.

- [ ] **Step 1: Chạy consistency scan trước thay đổi**

Run:

```powershell
rg -n 'thiếu.*profile|thiếu.*LEN|chưa.*SIZE|fw_apb_slave|partial draft|ID.*profile|PROT.*profile|standalone hay|một file hai FSM' DMA-controller/docs/module-guides
```

Expected: Có các blocker cũ và profile list cần sửa.

- [ ] **Step 2: Đồng bộ READY_NOW guides**

Trong `fw_axi_address_slice.md`:

- thay gap bốn cờ bằng contract names đã freeze;
- định nghĩa profile chỉ có BURST, SIZE, alignment và LEN;
- chuyển MID/PROT sang matcher checks;
- thêm rule overflow và 4 KiB có thể cùng bằng 1;
- giữ yêu cầu snapshot stability.

Trong `fw_data_path_mux.md`:

- ghi top giữ immutable write-owner address, ID, LEN và SIZE đến B handshake;
- ghi framing pulse được top làm giàu trước khi gửi logger;
- không chuyển AWADDR/AWSIZE vào write drain.

- [ ] **Step 3: Đồng bộ WAIT_FOR_STUDENTS guides**

Trong `fw_apb_regs.md` và `fw_acl_matcher.md`:

- thay các interface gaps bằng signal names canonical;
- giữ trạng thái `WAIT_FOR_STUDENTS` vì source sinh viên vẫn chưa được nhận;
- yêu cầu Gói 01 dùng ID/LEN/SIZE ports;
- yêu cầu Gói 02 chuyển LEN/SIZE từ immutable snapshot.

Trong ba drain guides:

- chốt `fw_drain_fsm` wrapper hai module con;
- bỏ nội dung yêu cầu chọn standalone hay merge;
- giữ unit ownership riêng;
- ghi `w_framing_fault_valid/code` đúng contract;
- ghi top, không phải drain, giữ AWADDR/AWSIZE.

Trong `dma_bus_firewall.md`:

- bỏ blocker tên module và interface fields đã đóng;
- thêm write-owner metadata retention;
- giữ blocker nhận bốn gói sinh viên và unit evidence.

- [ ] **Step 4: Đồng bộ index và non-module notes**

Trong README và matrix:

- giữ ba nhóm và 17 dòng module hoặc tên được khảo sát;
- mô tả `UNCLEAR` là no-RTL action gate cho tên không có target, kể cả tên đã được kết luận là non-module;
- ghi `fw_apb_slave` không phải alias hoặc wrapper cần tạo;
- ghi Stage 1 và LEN/SIZE gaps đã đóng trong contract;
- không chuyển module WAIT sang READY chỉ vì tài liệu đã rõ.

Trong bốn file `03-unclear/`:

- ghi disposition trực tiếp: không tạo RTL;
- bỏ yêu cầu architecture owner quyết định lại khi không có consumer;
- giữ tiêu chí xem xét lại chỉ khi xuất hiện consumer, port contract và compatibility test.

- [ ] **Step 5: Kiểm guide structure và links**

Run:

```powershell
$root = Resolve-Path 'DMA-controller/docs/module-guides'
$files = Get-ChildItem $root -Recurse -File -Filter '*.md'
if ($files.Count -ne 19) { throw "Expected 19 Markdown files, got $($files.Count)" }
$matrix = Get-Content "$root/module-classification-matrix.md"
$rows = $matrix | Where-Object { $_ -match '^\| (DMA|FW|UNC)-\d+' }
if ($rows.Count -ne 17) { throw "Expected 17 matrix rows, got $($rows.Count)" }
$broken = @()
Get-ChildItem $root -Recurse -File -Filter '*.md' | ForEach-Object {
  $content = Get-Content -Raw $_.FullName
  foreach ($m in [regex]::Matches($content, '\[[^\]]+\]\(([^)#]+\.md)(?:#[^)]+)?\)')) {
    $target = Join-Path $_.DirectoryName $m.Groups[1].Value
    if (-not (Test-Path $target)) { $broken += "$($_.Name) -> $($m.Groups[1].Value)" }
  }
}
if ($broken) { $broken; exit 1 }
Write-Output 'PASS module guides structure'
```

Expected: `PASS module guides structure`.

- [ ] **Step 6: Kiểm nội dung cấm và stale gaps**

Run:

```powershell
$dashPatterns = @([string][char]0x2014, [string][char]0x2013, '\s-{2}\s')
Get-ChildItem 'DMA-controller/docs/module-guides' -Recurse -File | Select-String -Pattern $dashPatterns
rg -n -i 'TODO|PLACEHOLDER|\bTBD\b' DMA-controller/docs/module-guides | Where-Object { $_ -notmatch 'assumptions_and_tbd\.md' }
rg -n -i 'antigravity|prompt:|system prompt|hãy đóng vai' DMA-controller/docs/module-guides
rg -n 'thiếu.*profile|thiếu.*LEN|chưa.*SIZE|standalone hay|một file hai FSM' DMA-controller/docs/module-guides
```

Expected: Không có kết quả ngoài câu README khẳng định bộ tài liệu không chứa prompt, nếu câu đó vẫn được giữ.

- [ ] **Step 7: Review và commit Task 4**

Run:

```powershell
git add DMA-controller/docs/module-guides
git diff --cached --check
git diff --cached DMA-controller/docs/module-guides
git commit -m "docs: align module guides with firewall contract"
```

Expected: Commit chỉ chứa 19 module-guide Markdown files.

---

### Task 5: Chạy cross-document QA và bảo vệ phạm vi

**Files:**

- Verify only: `DMA-controller/docs/architecture/`
- Verify only: `DMA-controller/docs/module-guides/`
- Protected: `DMA-controller/rtl/`
- Protected: `DMA-controller/tb/`
- Protected: `DMA-controller/docs/tutorials/firewall-rtl/`
- Protected: `output/pdf/`

**Interfaces:**

- Consumes: Tất cả tài liệu đã cập nhật ở Tasks 1 đến 4.
- Produces: Evidence rằng contract nhất quán và không có thay đổi ngoài phạm vi.

- [ ] **Step 1: Chạy exact-decision scan**

Run:

```powershell
rg -n 'pipe_s1_aw_profile_err|pipe_s1_aw_overflow_err|pipe_s1_ar_profile_err|pipe_s1_ar_overflow_err' DMA-controller/docs/architecture DMA-controller/docs/module-guides
rg -n 'w_fault_event_len|w_fault_event_size|r_fault_event_len|r_fault_event_size' DMA-controller/docs/architecture DMA-controller/docs/module-guides
rg -n 'w_framing_fault_valid|w_framing_fault_code' DMA-controller/docs/architecture DMA-controller/docs/module-guides
```

Expected: Mỗi decision xuất hiện trong signal list, contract prose và guides liên quan.

- [ ] **Step 2: Chạy naming và status scan**

Run:

```powershell
rg -n 'fw_apb_slave' DMA-controller/docs/architecture/architecture_overview.md DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/fsm_specification.md
rg -n 'PARTIAL DRAFT.*fw_axi_address_slice|RTL Partial' DMA-controller/docs/architecture/implementation_conformance_status.md DMA-controller/docs/architecture/requirements_traceability.csv
```

Expected: Không có kết quả.

- [ ] **Step 3: Parse canonical CSV files**

Run:

```powershell
Import-Csv 'DMA-controller/docs/architecture/signal_list.csv' | Out-Null
Import-Csv 'DMA-controller/docs/architecture/register_map.csv' | Out-Null
Import-Csv 'DMA-controller/docs/architecture/requirements_traceability.csv' | Out-Null
Import-Csv 'DMA-controller/docs/architecture/document_manifest.csv' | Out-Null
Write-Output 'PASS canonical CSV parse'
```

Expected: `PASS canonical CSV parse`.

- [ ] **Step 4: Kiểm tra không sửa protected files**

Run:

```powershell
git diff --name-only DMA-controller/rtl DMA-controller/tb DMA-controller/docs/tutorials/firewall-rtl output/pdf
```

Expected: Không có output từ các commit của kế hoạch này.

- [ ] **Step 5: Chạy final whitespace và status review**

Run:

```powershell
git diff --check HEAD~4..HEAD
git status --short
git log -4 --oneline
```

Expected:

- `git diff --check` không báo lỗi.
- Bốn commit gần nhất tương ứng Tasks 1 đến 4.
- Mọi thay đổi không thuộc nhiệm vụ vẫn được giữ nguyên và không bị stage nhầm.

- [ ] **Step 6: Ghi báo cáo bàn giao trong cuộc trò chuyện**

Báo cáo phải nêu:

- các file architecture và module guides đã sửa;
- exact signal decisions đã phát hành;
- Firewall RTL vẫn do người dùng và nhóm sinh viên tự thiết kế;
- Firewall verification và integration gates vẫn chưa PASS nếu chưa có source/evidence;
- protected files không thay đổi;
- commit IDs của Tasks 1 đến 4.

Không tạo thêm báo cáo repository nếu người dùng không yêu cầu.
