# Three-group module guides implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo 19 file Markdown gồm một README, một ma trận và 17 hướng dẫn module được chia thành `READY_NOW`, `WAIT_FOR_STUDENTS` và `UNCLEAR`.

**Architecture:** Bộ tài liệu mới nằm tại `DMA-controller/docs/module-guides/` và không liên kết ngược vào giáo trình. Ma trận sở hữu trạng thái phân loại. Mỗi file module sở hữu hướng dẫn chi tiết và liên kết trực tiếp tới nguồn chuẩn trong `DMA-controller/docs/architecture/`.

**Tech Stack:** Markdown, PowerShell, `rg`, Git và các tài liệu SSOT V2.4.1.

**Spec:** `docs/superpowers/specs/2026-09-02-module-guides-three-groups-design.md`

## Global constraints

- Tạo đúng 19 file Markdown trong `DMA-controller/docs/module-guides/`.
- Tạo đúng 7 tài liệu `READY_NOW`, 6 tài liệu `WAIT_FOR_STUDENTS` và 4 tài liệu `UNCLEAR`.
- Không sửa file trong `DMA-controller/rtl/`, `DMA-controller/tb/`, `DMA-controller/docs/architecture/` hoặc `DMA-controller/docs/tutorials/firewall-rtl/`.
- Không sửa bốn PDF trong `output/pdf/`.
- Không thay đổi phân loại đã khóa trong spec.
- Mọi width, reset, register offset, fault semantic và test ID phải truy được về nguồn chuẩn.
- Không trình bày module Firewall chưa có source như module đã triển khai.
- Không biến alias hoặc tên lịch sử thành module mới.
- Không ghi prompt, persona, lời thoại hoặc quy tắc điều khiển Antigravity trong bộ tài liệu.
- Viết nội dung kỹ thuật để người dùng tự thiết kế module, có thể dùng trực tiếp hoặc cung cấp cho công cụ hỗ trợ do người dùng chọn.
- Văn bản dùng tiếng Việt. Identifier, tên protocol, signal, requirement và test ID giữ nguyên tiếng Anh.
- Phần văn xuôi không dùng em dash, en dash hoặc chuỗi ` -- `.
- Heading dùng sentence case.

## File map

```text
DMA-controller/docs/module-guides/
|-- README.md
|-- module-classification-matrix.md
|-- 01-ready-now/
|   |-- dma_apb_slave.md
|   |-- dma_axi_master.md
|   |-- dma_fifo_latch.md
|   |-- dma_controller.md
|   |-- fw_axi_address_slice.md
|   |-- fw_context_tracker.md
|   `-- fw_data_path_mux.md
|-- 02-wait-for-students/
|   |-- fw_apb_regs.md
|   |-- fw_acl_matcher.md
|   |-- fw_write_drain.md
|   |-- fw_read_drain.md
|   |-- fw_drain_fsm.md
|   `-- dma_bus_firewall.md
`-- 03-unclear/
    |-- fw_apb_slave.md
    |-- dma_top.md
    |-- dma32.md
    `-- fifo32.md
```

### Task 1: Điểm vào và ma trận phân loại

**Files:**

- Create: `DMA-controller/docs/module-guides/README.md`
- Create: `DMA-controller/docs/module-guides/module-classification-matrix.md`

**Interfaces:**

- Consumes: spec đã duyệt và toàn bộ nguồn chuẩn trong mục Global constraints.
- Produces: điểm vào duy nhất và 17 dòng phân loại liên kết tới 17 file module.

- [ ] **Step 1: Tạo README với quy tắc sử dụng ba nhóm**

README mở đầu bằng kết luận: người đọc chọn module từ ma trận, chỉ triển khai module `READY_NOW`, và không triển khai cuối module `WAIT_FOR_STUDENTS` hoặc `UNCLEAR`.

README định nghĩa:

- `READY_NOW`: đủ nguồn để thiết kế, kiểm tra hoặc tái sử dụng ngay mà không chờ bốn gói sinh viên.
- `WAIT_FOR_STUDENTS`: thiếu một đầu ra sinh viên được nêu tên và định dạng.
- `UNCLEAR`: thiếu authority, role hoặc module boundary.
- Trạng thái thay đổi bằng cách sửa ma trận sau khi evidence đáp ứng điều kiện trong file module.
- Thứ tự đọc: README, ma trận, file module, nguồn chuẩn được file module dẫn.

- [ ] **Step 2: Tạo ma trận 17 dòng**

Ma trận dùng chính xác các cột:

```text
Module ID | Tên module | Mô tả ngắn | Phân loại | Lý do phân loại |
Phụ thuộc vào ai/phần nào | File hướng dẫn | Trạng thái tài liệu |
Ghi chú cần kiểm tra thêm
```

Điền 17 dòng theo bảng phân loại trong spec. Cột `File hướng dẫn` dùng link tương đối. Trạng thái tài liệu là `complete` cho file đã viết đủ schema. Ma trận không ghi gate RTL là PASS trừ bốn DMA unit evidence đã được nguồn chuẩn xác nhận.

- [ ] **Step 3: Kiểm tra số dòng và link dự kiến**

Run:

```powershell
rg -n '^\| (DMA|FW|UNC)-[0-9]+' DMA-controller/docs/module-guides/module-classification-matrix.md
```

Expected: 17 dòng dữ liệu, mỗi Module ID xuất hiện một lần.

- [ ] **Step 4: Commit điểm vào và ma trận**

```powershell
git add DMA-controller/docs/module-guides/README.md DMA-controller/docs/module-guides/module-classification-matrix.md
git commit -m "docs: add module guide classification index"
```

### Task 2: Hướng dẫn bốn module DMA sẵn sàng

**Files:**

- Create: `DMA-controller/docs/module-guides/01-ready-now/dma_apb_slave.md`
- Create: `DMA-controller/docs/module-guides/01-ready-now/dma_axi_master.md`
- Create: `DMA-controller/docs/module-guides/01-ready-now/dma_fifo_latch.md`
- Create: `DMA-controller/docs/module-guides/01-ready-now/dma_controller.md`

**Interfaces:**

- Consumes: source và testbench tương ứng trong `DMA-controller/rtl/` và `DMA-controller/tb/`, architecture overview, FSM, pinout, register map, signal list, traceability và evidence manifest.
- Produces: bốn hướng dẫn từ đầu có quy trình đọc source, tái tạo module và chạy unit regression.

- [ ] **Step 1: Viết `dma_apb_slave.md`**

Tài liệu phải có đủ 14 mục `READY_NOW` trong spec. Nội dung bắt buộc gồm APB3 full-word, cửa sổ `0x10001000` đến `0x1000101F`, START WO, BUSY RO, DONE/ERROR W1C, hardware-set priority, descriptor next-run và trust provenance ngoài IP. Test bắt buộc dẫn `TC_DMA_APB_REG_SEMANTICS`, `TC_START_WHILE_BUSY` và `TC_DMA_APB_PROFILE`.

- [ ] **Step 2: Viết `dma_axi_master.md`**

Tài liệu mô tả read FSM, write FSM, AW-before-W, one outstanding, FIFO handshakes, response ID, RLAST framing và terminal abort coordinator. Hướng dẫn phân biệt liveness theo handshake với bounded liveness có fairness. Test bắt buộc dẫn response error, ID mismatch, RLAST và backpressure cases.

- [ ] **Step 3: Viết `dma_fifo_latch.md`**

Tài liệu mô tả FIFO đồng bộ 32 word x 32 bit, pointer/count, full/empty, simultaneous push/pop, flush và guard overflow/underflow. Tài liệu ghi rõ depth 32 là baseline hiện hành và không suy PPA từ model benchmark.

- [ ] **Step 4: Viết `dma_controller.md`**

Tài liệu mô tả top DMA, APB configuration, descriptor snapshot, context emitter, AXI master, FIFO, IRQ và terminal behavior. Phần dependency ghi Firewall integration chưa có và unit PASS của DMA không đóng end-to-end security.

- [ ] **Step 5: Kiểm tra cấu trúc bốn file**

Run:

```powershell
rg -n '^## ' DMA-controller/docs/module-guides/01-ready-now/dma_*.md
```

Expected: mỗi file có trạng thái, mục tiêu, interface, quy trình thiết kế, test, rủi ro, tiêu chí hoàn thành và nguồn chuẩn.

- [ ] **Step 6: Commit bốn hướng dẫn DMA**

```powershell
git add DMA-controller/docs/module-guides/01-ready-now/dma_apb_slave.md DMA-controller/docs/module-guides/01-ready-now/dma_axi_master.md DMA-controller/docs/module-guides/01-ready-now/dma_fifo_latch.md DMA-controller/docs/module-guides/01-ready-now/dma_controller.md
git commit -m "docs: add ready DMA module guides"
```

### Task 3: Hướng dẫn ba module Firewall sẵn sàng

**Files:**

- Create: `DMA-controller/docs/module-guides/01-ready-now/fw_axi_address_slice.md`
- Create: `DMA-controller/docs/module-guides/01-ready-now/fw_context_tracker.md`
- Create: `DMA-controller/docs/module-guides/01-ready-now/fw_data_path_mux.md`

**Interfaces:**

- Consumes: integration contract, architecture overview, FSM, pinout, signal list, verification plan và kế hoạch Firewall đã được duyệt.
- Produces: ba hướng dẫn thiết kế độc lập bằng stub cho dependency chưa có.

- [ ] **Step 1: Viết `fw_axi_address_slice.md`**

Tài liệu mô tả hai elastic slot AW/AR, extended last-byte arithmetic, profile check, overflow, 4 KiB, backpressure và payload stability. Phần interface gap ghi bốn tín hiệu `pipe_s1_aw_profile_err`, `pipe_s1_aw_overflow_err`, `pipe_s1_ar_profile_err`, `pipe_s1_ar_overflow_err` chưa có trong `signal_list.csv`. Điều kiện đóng port list là owner tài liệu chuẩn xác nhận các tín hiệu hoặc một fault bundle tương đương.

- [ ] **Step 2: Viết `fw_context_tracker.md`**

Tài liệu mô tả năm sideband signal, `CTX_IDLE`, `CTX_ACTIVE`, `CTX_REVOKED`, valid one-shot, Region 4/5, alignment, len zero, overflow, `AUTO_CTX_EN` và priority revoke. Testbench dùng input `auto_ctx_en` độc lập và stub fault sink nên không cần chờ `fw_apb_regs`.

- [ ] **Step 3: Viết `fw_data_path_mux.md`**

Tài liệu mô tả owner inputs, allowed routing, denied isolation, W-before-AW guard, B/R source selection, tie-off và stable response. Testbench dùng stub matcher decision, stub drain và stub matrix. Phần rủi ro ghi exact adapter ports chỉ được đóng khi module sinh viên được nhận, nhưng mux behavior và unit design không phụ thuộc các source đó.

- [ ] **Step 4: Kiểm tra các blocker không bị biến thành quyết định**

Run:

```powershell
rg -n 'signal_list|profile_err|overflow_err|stub|adapter' DMA-controller/docs/module-guides/01-ready-now/fw_*.md
```

Expected: address slice ghi rõ interface gap; context và mux ghi rõ stub boundary.

- [ ] **Step 5: Commit ba hướng dẫn Firewall sẵn sàng**

```powershell
git add DMA-controller/docs/module-guides/01-ready-now/fw_axi_address_slice.md DMA-controller/docs/module-guides/01-ready-now/fw_context_tracker.md DMA-controller/docs/module-guides/01-ready-now/fw_data_path_mux.md
git commit -m "docs: add ready Firewall module guides"
```

### Task 4: Hướng dẫn bốn đầu ra sinh viên

**Files:**

- Create: `DMA-controller/docs/module-guides/02-wait-for-students/fw_apb_regs.md`
- Create: `DMA-controller/docs/module-guides/02-wait-for-students/fw_acl_matcher.md`
- Create: `DMA-controller/docs/module-guides/02-wait-for-students/fw_write_drain.md`
- Create: `DMA-controller/docs/module-guides/02-wait-for-students/fw_read_drain.md`

**Interfaces:**

- Consumes: bốn student guides hiện có, source architecture và thứ tự gói 01 đến 04.
- Produces: bốn hợp đồng tiếp nhận và template tiếp tục thiết kế sau khi sinh viên bàn giao.

- [ ] **Step 1: Viết `fw_apb_regs.md` cho gói 01**

Yêu cầu đầu ra gồm RTL, self-checking testbench, port list, register decode table, log PASS, waveform concurrent set/W1C, waveform simultaneous fault và state ownership note. Checklist bắt buộc kiểm APB4 `PPROT`, full-word, lock, active guard, dynamic readback, first-fault, count saturation, IRQ và `LEN/SIZE` fault metadata.

- [ ] **Step 2: Viết `fw_acl_matcher.md` cho gói 02**

Yêu cầu đầu ra gồm RTL, reference model, directed matrix, random seed log, snapshot ownership diagram và port-gap note. Checklist kiểm full containment, overlap AND, MID mask, PROT, `FW_EN`, profile/overflow/4 KiB, backpressure và immutable decision.

- [ ] **Step 3: Viết `fw_write_drain.md` cho gói 03**

Yêu cầu đầu ra gồm write RTL unit hoặc block, unit testbench, exact-beat scoreboard, framing event contract, log và waveform LEN 0/15 với BREADY stall. Tài liệu cấm quyết định file wrapper cuối trước khi so sánh với gói 04.

- [ ] **Step 4: Viết `fw_read_drain.md` cho gói 04**

Yêu cầu đầu ra gồm read RTL unit hoặc block, unit testbench, exact-beat scoreboard, log và waveform final-beat stall. Checklist kiểm RID, zero RDATA, RRESP, RLAST, ERR_MODE và no downstream AR.

- [ ] **Step 5: Kiểm tra đủ điều kiện chuyển nhóm**

Run:

```powershell
rg -n 'Điều kiện chuyển|Đầu ra cần nhận|Chưa được quyết định|Rủi ro khi thiết kế sớm' DMA-controller/docs/module-guides/02-wait-for-students/fw_apb_regs.md DMA-controller/docs/module-guides/02-wait-for-students/fw_acl_matcher.md DMA-controller/docs/module-guides/02-wait-for-students/fw_write_drain.md DMA-controller/docs/module-guides/02-wait-for-students/fw_read_drain.md
```

Expected: bốn file đều có bốn mục kiểm soát chờ.

- [ ] **Step 6: Commit bốn hợp đồng đầu ra sinh viên**

```powershell
git add DMA-controller/docs/module-guides/02-wait-for-students/fw_apb_regs.md DMA-controller/docs/module-guides/02-wait-for-students/fw_acl_matcher.md DMA-controller/docs/module-guides/02-wait-for-students/fw_write_drain.md DMA-controller/docs/module-guides/02-wait-for-students/fw_read_drain.md
git commit -m "docs: add student-dependent module guides"
```

### Task 5: Hướng dẫn tích hợp drain và Firewall top

**Files:**

- Create: `DMA-controller/docs/module-guides/02-wait-for-students/fw_drain_fsm.md`
- Create: `DMA-controller/docs/module-guides/02-wait-for-students/dma_bus_firewall.md`

**Interfaces:**

- Consumes: kết quả bốn gói sinh viên, ba module Firewall `READY_NOW`, pinout, signal list, FSM và integration contract.
- Produces: hai runbook tiếp nhận, hợp nhất và tích hợp có gate rõ ràng.

- [ ] **Step 1: Viết `fw_drain_fsm.md`**

Tài liệu định nghĩa bảng đối chiếu port write/read, ownership chung, reset, simultaneous activity, fault event merge và hai phương án tích hợp được phép đánh giá: một file chứa hai FSM hoặc wrapper chứa hai submodule. Tài liệu không chọn phương án trước khi đọc source gói 03 và 04. Điều kiện bắt đầu gồm cả hai unit PASS và interface review không còn collision.

- [ ] **Step 2: Viết `dma_bus_firewall.md`**

Tài liệu định nghĩa đầu vào bắt buộc từ gói 01 đến 04, input từ address slice, context tracker và mux, top pinout, owner slots, effective policy priority, reset, fault routing và G3 regression. Phần chuẩn bị trước gồm port shell trên giấy, connection matrix, stubs và compile source list. Phần bị cấm gồm final adapter, owner timing và tuyên bố G3 PASS.

- [ ] **Step 3: Kiểm tra dependency bốn gói**

Run:

```powershell
rg -n 'gói 01|gói 02|gói 03|gói 04' DMA-controller/docs/module-guides/02-wait-for-students/dma_bus_firewall.md
```

Expected: top guide nêu đủ bốn gói và đầu ra tương ứng.

- [ ] **Step 4: Commit hai hướng dẫn tích hợp**

```powershell
git add DMA-controller/docs/module-guides/02-wait-for-students/fw_drain_fsm.md DMA-controller/docs/module-guides/02-wait-for-students/dma_bus_firewall.md
git commit -m "docs: add dependent Firewall integration guides"
```

### Task 6: Hướng dẫn bốn tên module chưa rõ

**Files:**

- Create: `DMA-controller/docs/module-guides/03-unclear/fw_apb_slave.md`
- Create: `DMA-controller/docs/module-guides/03-unclear/dma_top.md`
- Create: `DMA-controller/docs/module-guides/03-unclear/dma32.md`
- Create: `DMA-controller/docs/module-guides/03-unclear/fifo32.md`

**Interfaces:**

- Consumes: exact search hits trong architecture docs, tutorial docs và historical plans.
- Produces: bốn blocker records không chứa implementation guidance chưa có authority.

- [ ] **Step 1: Viết `fw_apb_slave.md`**

Ghi vị trí tên xuất hiện, đối chiếu module chuẩn `fw_apb_regs`, thiếu file/module boundary và quyết định cần từ architecture owner. Cấm tạo file `fw_apb_slave.v` trước khi owner xác nhận đây là alias, wrapper hoặc module riêng.

- [ ] **Step 2: Viết `dma_top.md`**

Ghi mọi nguồn hiện tìm thấy, xác nhận không có source chuẩn và đối chiếu với `dma_controller`. Nêu tiêu chí authority cần có trước khi phân loại lại.

- [ ] **Step 3: Viết `dma32.md`**

Ghi đây là tên lịch sử hoặc hỗ trợ, không có source trong baseline V2.4.1. Không suy ra width hoặc behavior từ tên.

- [ ] **Step 4: Viết `fifo32.md`**

Ghi module chuẩn là `dma_fifo_latch` với depth 32. Tên `fifo32` không được dùng để tạo module song song nếu chưa có quyết định đổi tên hoặc compatibility wrapper.

- [ ] **Step 5: Kiểm tra không có hướng dẫn triển khai cuối**

Run:

```powershell
rg -n 'module[[:space:]]+[A-Za-z_]|always|assign|wire[[:space:]]' DMA-controller/docs/module-guides/03-unclear
```

Expected: không có skeleton RTL hoặc port contract được bịa cho bốn tên chưa rõ.

- [ ] **Step 6: Commit bốn blocker records**

```powershell
git add DMA-controller/docs/module-guides/03-unclear/fw_apb_slave.md DMA-controller/docs/module-guides/03-unclear/dma_top.md DMA-controller/docs/module-guides/03-unclear/dma32.md DMA-controller/docs/module-guides/03-unclear/fifo32.md
git commit -m "docs: record unclear module names"
```

### Task 7: Kiểm tra toàn bộ bộ tài liệu

**Files:**

- Verify: `DMA-controller/docs/module-guides/**/*.md`
- Verify unchanged: `DMA-controller/rtl/`
- Verify unchanged: `DMA-controller/tb/`
- Verify unchanged: `DMA-controller/docs/architecture/`
- Verify unchanged: `DMA-controller/docs/tutorials/firewall-rtl/`
- Verify unchanged: `output/pdf/`

**Interfaces:**

- Consumes: 19 file Markdown đã tạo.
- Produces: báo cáo kiểm tra dùng trong bàn giao cuối.

- [ ] **Step 1: Kiểm tra số file theo nhóm**

Run:

```powershell
$guideRoot = 'DMA-controller/docs/module-guides'
(Get-ChildItem -LiteralPath $guideRoot -Recurse -Filter '*.md').Count
(Get-ChildItem -LiteralPath "$guideRoot/01-ready-now" -Filter '*.md').Count
(Get-ChildItem -LiteralPath "$guideRoot/02-wait-for-students" -Filter '*.md').Count
(Get-ChildItem -LiteralPath "$guideRoot/03-unclear" -Filter '*.md').Count
```

Expected: `19`, `7`, `6`, `4`.

- [ ] **Step 2: Kiểm tra link Markdown nội bộ**

Run:

```powershell
$matrixPath = 'DMA-controller/docs/module-guides/module-classification-matrix.md'
$matrixDir = Split-Path -Parent $matrixPath
$text = Get-Content -LiteralPath $matrixPath -Raw -Encoding UTF8
$matches = [regex]::Matches($text, '\[[^\]]+\]\(([^)]+\.md)\)')
foreach ($match in $matches) {
    $target = Join-Path $matrixDir $match.Groups[1].Value
    if (-not (Test-Path -LiteralPath $target)) { throw "Broken link: $target" }
}
```

Expected: command kết thúc không có exception.

- [ ] **Step 3: Kiểm tra placeholder, style và đường dẫn máy**

Run:

```powershell
rg -n -i '\b(TODO|TBD|PLACEHOLDER)\b' DMA-controller/docs/module-guides
rg -n '[–—]| -- ' DMA-controller/docs/module-guides
rg -n 'D:\\|C:\\|file://' DMA-controller/docs/module-guides
```

Expected: cả ba lệnh không có match. Tên file chuẩn `assumptions_and_tbd.md` được phép xuất hiện vì `tbd` là một phần của đường dẫn nguồn, nên review riêng nếu lệnh đầu tìm thấy dòng này.

- [ ] **Step 4: Kiểm tra module không trùng nhóm**

Run:

```powershell
$matrix = Get-Content -LiteralPath 'DMA-controller/docs/module-guides/module-classification-matrix.md' -Encoding UTF8
$rows = $matrix | Where-Object { $_ -match '^\| (DMA|FW|UNC)-[0-9]+' }
if ($rows.Count -ne 17) { throw "Expected 17 module rows, got $($rows.Count)" }
$ids = $rows | ForEach-Object { ($_ -split '\|')[1].Trim() }
if (($ids | Sort-Object -Unique).Count -ne 17) { throw 'Duplicate module ID' }
```

Expected: command kết thúc không có exception.

- [ ] **Step 5: Kiểm tra phạm vi file thay đổi**

Run:

```powershell
git diff --name-only -- DMA-controller/rtl DMA-controller/tb DMA-controller/docs/architecture DMA-controller/docs/tutorials/firewall-rtl output/pdf
```

Expected: không có output do bộ tài liệu mới không sửa các path bị bảo vệ.

- [ ] **Step 6: Kiểm tra whitespace và nội dung index**

Run:

```powershell
git diff --check -- DMA-controller/docs/module-guides
rg -n '^# ' DMA-controller/docs/module-guides -g '*.md'
```

Expected: `git diff --check` không có lỗi; mỗi file có đúng một heading cấp 1.

- [ ] **Step 7: Commit lượt kiểm tra hoặc sửa cuối**

```powershell
git add DMA-controller/docs/module-guides
git commit -m "docs: complete three-group module guide set"
```

Nếu không có sửa sau các commit trước, bỏ qua commit rỗng.
