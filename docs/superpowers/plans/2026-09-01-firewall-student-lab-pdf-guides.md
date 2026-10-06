# Firewall student lab PDF guides implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo bốn PDF tiếng Việt tự chứa để bốn sinh viên thiết kế và kiểm chứng độc lập `fw_apb_regs`, `fw_acl_matcher`, write drain và read drain.

**Architecture:** Bốn file Markdown giữ nội dung có thể sửa. Một bộ sinh ReportLab dùng chung chuyển Markdown có giới hạn thành PDF A4, đăng ký font tiếng Việt, tạo header/footer và style thống nhất. Một script kiểm tra mở lại PDF, kiểm tra số trang, text, placeholder và kích thước trang; Poppler render toàn bộ trang để kiểm tra trực quan.

**Tech Stack:** Markdown, Python 3, ReportLab, pypdf, pdfplumber và Poppler.

**Spec:** `docs/superpowers/specs/2026-09-01-firewall-student-lab-pdf-guides-design.md`

## Global constraints

- Tạo đúng bốn PDF trong `output/pdf/` với tên đã khóa trong spec.
- Mỗi PDF phải tự chứa kiến thức nền, thiết kế RTL, testbench, debug, rubric và checklist.
- Không in RTL đáp án hoàn chỉnh; dùng skeleton, pseudocode, biểu thức và checker mẫu.
- Hành vi kỹ thuật phải truy được về `DMA-controller/docs/architecture/`.
- PDF dùng A4, font hỗ trợ tiếng Việt, header tên module và footer số trang.
- Toàn bộ trang phải được render và kiểm tra trước khi bàn giao.

---

### Task 1: Bộ sinh và bộ kiểm tra PDF

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/tools/build_student_guides.py`
- Create: `DMA-controller/docs/tutorials/firewall-rtl/tools/verify_student_guides.py`

**Interfaces:**
- Consumes: bốn file Markdown trong `student-guides/`.
- Produces: `build_all(repo_root: Path) -> list[Path]` và báo cáo kiểm tra theo từng PDF.

- [ ] **Step 1: Định nghĩa metadata và parser block**

Tạo `GuideSpec` với `source_name`, `output_name`, `module_name`, `accent_color`. Parser hỗ trợ heading, paragraph, bullet, numbered list, fenced code, bảng Markdown, blockquote và page break `<!-- pagebreak -->`.

- [ ] **Step 2: Tạo style A4 dùng chung**

Đăng ký Arial hoặc font Unicode tương đương, Consolas cho code, lề 18 mm, body 10.2 pt, code 8.2 pt. Header hiển thị module; footer hiển thị `Trang n`.

- [ ] **Step 3: Tạo hàm build**

```python
def build_all(repo_root: Path) -> list[Path]:
    """Build the four declared student guides and return output paths."""
```

Mỗi output dùng `BaseDocTemplate`, `PageTemplate` và Platypus flowables. Build thất bại nếu thiếu source hoặc font.

- [ ] **Step 4: Tạo script kiểm tra cấu trúc**

Script mở từng PDF bằng `pypdf`, kiểm tra A4, số trang lớn hơn 10, text lớn hơn 5.000 ký tự, không có trang rỗng và không có chuỗi đánh dấu nội dung chưa hoàn thiện.

- [ ] **Step 5: Chạy kiểm tra cú pháp**

Run: `python -m py_compile DMA-controller/docs/tutorials/firewall-rtl/tools/build_student_guides.py DMA-controller/docs/tutorials/firewall-rtl/tools/verify_student_guides.py`

Expected: exit code 0.

### Task 2: Hướng dẫn `fw_apb_regs`

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/student-guides/01_fw_apb_regs_lab_guide.md`

**Interfaces:**
- Consumes: register map, pinout, integration contract, architecture overview và verification plan.
- Produces: nguồn cho `01_fw_apb_regs_lab_guide.pdf`.

- [ ] **Step 1: Viết nền tảng APB và register semantics**

Giải thích setup/access, handshake, Secure-Privileged `PPROT`, address decode, RW, RO, RW1S, W1C và reserved bits bằng timing ví dụ.

- [ ] **Step 2: Viết thiết kế control plane**

Mô tả state ownership, next-state priority, lock, static/dynamic region, active-region guard, fault logger, IRQ và reset.

- [ ] **Step 3: Viết quy trình RTL và skeleton**

Chia thiết kế thành decode tổ hợp, next-state, sequential register update và read mux. Skeleton giữ trống biểu thức sinh viên phải hoàn thiện.

- [ ] **Step 4: Viết testbench và rubric**

Cung cấp APB tasks, checker mẫu, ma trận reset/access/lock/W1C/concurrent fault, debug guide, câu hỏi có đáp án và rubric 10 điểm.

### Task 3: Hướng dẫn `fw_acl_matcher`

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/student-guides/02_fw_acl_matcher_lab_guide.md`

**Interfaces:**
- Consumes: architecture overview, register attributes, integration contract, signal list và verification plan.
- Produces: nguồn cho `02_fw_acl_matcher_lab_guide.pdf`.

- [ ] **Step 1: Viết nền tảng address arithmetic và policy**

Giải thích `last_byte`, overflow, 4 KiB, full containment, MID/mask, PROT, permission và default deny.

- [ ] **Step 2: Viết thuật toán matcher**

Trình bày đánh giá tám region, valid match vector, most-restrictive AND, fault priority, `FW_EN` bypass và snapshot invariance.

- [ ] **Step 3: Viết skeleton và reference model**

Cung cấp port contract, pseudocode vòng lặp region, pure testbench function và các ví dụ tính tay.

- [ ] **Step 4: Viết ma trận test và rubric**

Bao phủ boundary, overflow, overlap, masked MID, PROT, policy mutation, bypass, debug guide, câu hỏi có đáp án và rubric 10 điểm.

### Task 4: Hướng dẫn write drain

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/student-guides/03_fw_write_drain_lab_guide.md`

**Interfaces:**
- Consumes: write drain FSM, signal list, integration contract và verification plan.
- Produces: nguồn cho `03_fw_write_drain_lab_guide.pdf`.

- [ ] **Step 1: Viết nền tảng AW/W/B và ready/valid**

Giải thích owner, `AWLEN+1`, handshake, WLAST framing, B response và stability under stall.

- [ ] **Step 2: Viết FSM và counter design**

Trình bày IDLE, SINK, RESP, snapshot, exact-beat counter, error mode và isolation invariant.

- [ ] **Step 3: Viết skeleton và testbench driver**

Cung cấp state skeleton, W beat task, B monitor, scoreboard và timeout.

- [ ] **Step 4: Viết corner cases và rubric**

Bao phủ LEN 0/15, WVALID gaps, WLAST sớm/thiếu, BREADY stall, DECERR/honeypot, reset, debug guide và rubric 10 điểm.

### Task 5: Hướng dẫn read drain

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/student-guides/04_fw_read_drain_lab_guide.md`

**Interfaces:**
- Consumes: read drain FSM, signal list, integration contract và verification plan.
- Produces: nguồn cho `04_fw_read_drain_lab_guide.pdf`.

- [ ] **Step 1: Viết nền tảng AR/R và ready/valid**

Giải thích owner, `ARLEN+1`, handshake, RLAST, local response và stability under stall.

- [ ] **Step 2: Viết FSM và response generator**

Trình bày IDLE, GEN, snapshot, exact-beat counter, final index, error mode và isolation invariant.

- [ ] **Step 3: Viết skeleton và testbench monitor**

Cung cấp state skeleton, AR fault task, randomized RREADY, scoreboard và timeout.

- [ ] **Step 4: Viết corner cases và rubric**

Bao phủ LEN 0/15, stall đầu/final beat, DECERR/honeypot, reset, downstream isolation, debug guide và rubric 10 điểm.

### Task 6: Build, kiểm tra và render

**Files:**
- Create: `output/pdf/01_fw_apb_regs_lab_guide.pdf`
- Create: `output/pdf/02_fw_acl_matcher_lab_guide.pdf`
- Create: `output/pdf/03_fw_write_drain_lab_guide.pdf`
- Create: `output/pdf/04_fw_read_drain_lab_guide.pdf`
- Create: `tmp/pdfs/student-guides/` render PNG và báo cáo kiểm tra.

**Interfaces:**
- Consumes: Tasks 1 đến 5.
- Produces: bốn PDF cuối và evidence kiểm tra.

- [ ] **Step 1: Build bốn PDF**

Run: `python DMA-controller/docs/tutorials/firewall-rtl/tools/build_student_guides.py`

Expected: bốn đường dẫn output được in và command exit code 0.

- [ ] **Step 2: Chạy kiểm tra cấu trúc**

Run: `python DMA-controller/docs/tutorials/firewall-rtl/tools/verify_student_guides.py`

Expected: bốn dòng PASS, không có lỗi.

- [ ] **Step 3: Render toàn bộ trang**

Run `pdftoppm -png -r 120` cho từng PDF vào thư mục riêng dưới `tmp/pdfs/student-guides/`.

Expected: số PNG bằng số trang PDF.

- [ ] **Step 4: Kiểm tra trực quan**

Xem contact sheet của mỗi PDF và trang đại diện có cover, bảng, code, FSM, waveform, rubric và trang cuối. Sửa source hoặc style nếu có clipping, overlap, glyph lỗi hoặc khoảng trắng bất thường; build và render lại sau mỗi sửa đổi.

- [ ] **Step 5: Kiểm tra bàn giao**

Run: `Get-Item output/pdf/*.pdf | Select-Object Name,Length`

Expected: đúng bốn file, mỗi file có kích thước lớn hơn 50 KiB.
