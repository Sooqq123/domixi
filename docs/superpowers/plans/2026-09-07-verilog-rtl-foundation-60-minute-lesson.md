# Verilog RTL foundation 60-minute lesson implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo một giáo trình PDF tiếng Việt giúp sinh viên năm 3 đã biết mạch số nhưng chưa học HDL nắm được tập con Verilog-2001 RTL nền tảng trong 60 phút lý thuyết.

**Architecture:** Một file Markdown giữ toàn bộ nội dung có thể chỉnh sửa, gồm giáo án giảng viên, bài học, ví dụ Verilog, bảng tra cứu một trang và sáu câu hỏi có đáp án. Một script mỏng tái sử dụng bộ dựng ReportLab hiện có để sinh PDF A4. Một script kiểm tra riêng xác nhận thời lượng, cấu trúc, cú pháp Verilog-2001, trang tra cứu, nội dung PDF và kích thước trang trước khi render toàn bộ trang để kiểm tra trực quan.

**Tech Stack:** Markdown, Verilog-2001, Python 3, ReportLab, pypdf, pdfplumber và Poppler.

**Spec:** `docs/superpowers/specs/2026-09-07-verilog-rtl-foundation-60-minute-lesson-design.md`

## Global constraints

- Tiết học kéo dài đúng 60 phút và không có hoạt động viết mã hoặc chạy công cụ.
- Người học đã biết mạch tổ hợp, mạch tuần tự, flip-flop, thanh ghi, bộ đếm, clock, reset và FSM ở mức khái niệm.
- Mọi ví dụ mã dùng Verilog-2001 và tập con RTL có thể tổng hợp.
- Không dùng cú pháp SystemVerilog trong code block.
- Không dạy APB, AXI, DMA, firewall hoặc hành vi của module dự án.
- Mỗi đoạn mã phải được nối với phần cứng suy ra và ít nhất một lỗi thường gặp.
- PDF cuối dùng A4, font tiếng Việt, code monospace, header, footer và số trang.
- Bảng tra cứu Verilog-2001 phải nằm gọn trên đúng một trang riêng.
- Sáu câu hỏi cuối tiết phải có đáp án và giải thích cho giảng viên.

---

### Task 1: Nguồn giáo trình Verilog RTL

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md`

**Interfaces:**
- Consumes: đặc tả đã duyệt và kiến thức đầu vào của sinh viên.
- Produces: nguồn Markdown duy nhất cho PDF và dữ liệu để script kiểm tra thời lượng, heading, code block và số câu hỏi.

- [ ] **Step 1: Viết frontmatter và giáo án giảng viên**

Dùng frontmatter sau:

```markdown
---
title: Verilog RTL nền tảng trong 60 phút
subtitle: Từ sơ đồ mạch số đến mã RTL có thể tổng hợp
version: Giáo trình lý thuyết cho sinh viên năm 3
---
```

Mở đầu bằng mục tiêu, điều kiện đầu vào, bảy kết quả học tập và bảng lịch từ phút 0 đến phút 60. Bảng phải chứa tám khoảng liên tục: `0-5`, `5-13`, `13-22`, `22-33`, `33-41`, `41-50`, `50-56`, `56-60`.

- [ ] **Step 2: Viết phần mô hình tư duy RTL và cấu trúc module**

Giải thích phần cứng hoạt động song song, mọi `always` block cùng tồn tại và thứ tự dòng mã không biến các khối thành chuỗi lệnh phần mềm. Dùng một sơ đồ ASCII nhỏ và module Verilog-2001 sau để giới thiệu cổng, vector, `wire` và `reg`:

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

Giải thích `wire` mang kết quả kết nối hoặc continuous assignment; `reg` là biến được gán trong procedural block và không tự động có nghĩa là flip-flop.

- [ ] **Step 3: Viết phần logic tổ hợp**

Trình bày hai mẫu hợp lệ: `assign` cho biểu thức ngắn và `always @(*)` cho nhiều nhánh. Mẫu procedural phải khai báo output là `reg`, đặt giá trị mặc định trước `case`, dùng blocking `=` và có `default`.

Đưa cặp ví dụ đúng và sai để chỉ ra latch ngoài ý muốn. Giải thích rằng mọi output tổ hợp phải được gán trên mọi đường điều khiển.

- [ ] **Step 4: Viết phần logic tuần tự và assignment**

Dùng mẫu thanh ghi có reset đồng bộ và enable:

```verilog
always @(posedge clk) begin
    if (rst)
        q <= 8'h00;
    else if (en)
        q <= d;
end
```

Giải thích state chỉ đổi ở cạnh clock, nhánh không gán giữ giá trị cũ và nonblocking `<=` mô tả cập nhật đồng thời của các thanh ghi. So sánh một ví dụ pipeline hai thanh ghi viết đúng bằng `<=` với phiên bản sai dùng `=` để làm rõ phụ thuộc thứ tự mô phỏng.

- [ ] **Step 5: Viết phần bộ đếm và FSM**

Dùng một bộ đếm có reset, enable và hằng số đúng độ rộng. FSM minh họa phải dùng Verilog-2001 với `localparam`, state register và next-state logic, có hai trạng thái `IDLE` và `RUN`. Mỗi state phải có giá trị mặc định, transition rõ và output không phụ thuộc nội dung dự án.

Giải thích ba câu hỏi khi đọc FSM: state được lưu ở đâu, state đổi khi nào và điều kiện nào tạo transition.

- [ ] **Step 6: Viết phần synthesizable RTL và lỗi phổ biến**

Tạo bảng gồm tối thiểu các lỗi sau: latch ngoài ý muốn, blocking trong sequential block, nonblocking trong combinational block, multiple drivers, literal sai độ rộng, signed/unsigned không chủ ý, thiếu `default`, dùng delay `#` trong RTL và dùng `initial` cho logic sản phẩm.

Phân biệt rõ `#`, `$display`, `$finish` là cú pháp phục vụ mô phỏng trong phạm vi nhập môn và không xuất hiện trong RTL sản phẩm của bài học.

- [ ] **Step 7: Viết bảng tra cứu và sáu câu hỏi**

Chèn `<!-- pagebreak -->` trước heading `## Bảng tra cứu Verilog-2001 một trang`. Trang này phải tóm tắt module, kiểu tín hiệu, literal, toán tử, combinational template, sequential template, `if`, `case`, counter, FSM và bảng quy tắc `=` so với `<=`.

Chèn `<!-- pagebreak -->` trước `## Câu hỏi kiểm tra cuối tiết`. Tạo đúng sáu heading `### Câu 1` đến `### Câu 6`. Mỗi câu có câu hỏi, đáp án và giải thích ngắn; nội dung lần lượt kiểm tra hardware parallelism, `wire` với `reg`, combinational completeness, clocked state, blocking với nonblocking và đọc FSM.

Kết thúc bằng `## Kiến thức cần tự ôn trước bài thực hành`, gồm checklist về cấu trúc module, logic tổ hợp, logic tuần tự, assignment, counter, FSM và các lỗi RTL. Checklist chỉ dẫn phần cần ôn, không nhắc tên hoặc hành vi module dự án.

- [ ] **Step 8: Kiểm tra nguồn Markdown**

Run:

```powershell
rg -n "always_comb|always_ff|typedef|enum|interface|fw_|acl_|APB|AXI|DMA" DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md
```

Expected: không có kết quả.

Run:

```powershell
rg -n "CHƯA HOÀN THIỆN|LOREM IPSUM" DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md
```

Expected: không có kết quả.

Run:

```powershell
$lessonText = Get-Content -Raw -LiteralPath 'DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md'
if ($lessonText.Contains([char]0x2014) -or $lessonText.Contains([char]0x2013)) { throw 'Có ký tự gạch dài không hợp lệ' }
```

Expected: exit code 0.

- [ ] **Step 9: Commit nguồn giáo trình**

```powershell
git add DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md
git commit -m "docs: add 60-minute Verilog RTL foundation lesson"
```

### Task 2: Bộ kiểm tra giáo trình và PDF

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py`

**Interfaces:**
- Consumes: `00_verilog_rtl_foundation_60min.md` và `output/pdf/00_verilog_rtl_foundation_60min.pdf`.
- Produces: exit code 0 cùng một dòng `PASS` có số trang, số ký tự, số câu hỏi và tổng thời lượng; ném `AssertionError` khi vi phạm bất kỳ global constraint nào.

- [ ] **Step 1: Viết kiểm tra lịch 60 phút**

Tạo hàm:

```python
def verify_schedule(source_text: str) -> int:
    slots = [
        (int(start), int(end))
        for start, end in re.findall(
            r"^\|\s*(\d+)-(\d+)\s*phút\s*\|", source_text, re.MULTILINE
        )
    ]
    assert slots[0][0] == 0
    assert slots[-1][1] == 60
    assert all(left[1] == right[0] for left, right in zip(slots, slots[1:]))
    total = sum(end - start for start, end in slots)
    assert total == 60
    return total
```

Yêu cầu đúng tám slot để tránh một bảng phụ bị tính nhầm vào lịch.

- [ ] **Step 2: Viết kiểm tra nội dung và code block**

Tách fenced code block có nhãn `verilog`. Yêu cầu tối thiểu năm block và các token bắt buộc: `module`, `wire`, `reg`, `assign`, `always @(*)`, `always @(posedge clk)`, `localparam`, `case`.

Không cho phép các token SystemVerilog `logic`, `always_comb`, `always_ff`, `typedef`, `enum`, `interface` trong code block. Không cho phép `fw_`, `acl_`, `APB`, `AXI`, `DMA` trong toàn bộ source. Đếm chính xác sáu heading câu hỏi bằng regex `^### Câu [1-6]$`.

- [ ] **Step 3: Viết kiểm tra PDF**

Mở PDF bằng `pypdf` và `pdfplumber`. Yêu cầu file lớn hơn 50 KiB, ít nhất 10 trang, mọi trang là A4 trong sai số 2 point, không có trang rỗng và text extract lớn hơn 8.000 ký tự.

Xác định trang chứa `Bảng tra cứu Verilog-2001 một trang` và trang chứa `Câu hỏi kiểm tra cuối tiết`. Yêu cầu hai heading nằm ở hai trang kế tiếp để chứng minh bảng tra cứu không tràn sang trang thứ hai.

- [ ] **Step 4: Viết CLI và kiểm tra lỗi mong đợi**

CLI nhận `--repo-root`, mặc định bằng `Path(__file__).resolve().parents[5]`. Trước khi PDF tồn tại, chạy:

```powershell
python DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py
```

Expected: FAIL với thông báo `Thiếu PDF` sau khi các kiểm tra source đã vượt qua.

- [ ] **Step 5: Kiểm tra cú pháp và commit**

```powershell
python -m py_compile DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py
git add DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py
git commit -m "test: verify Verilog foundation lesson"
```

### Task 3: Bộ dựng PDF

**Files:**
- Create: `DMA-controller/docs/tutorials/firewall-rtl/tools/build_verilog_foundation.py`
- Reuse: `DMA-controller/docs/tutorials/firewall-rtl/tools/build_student_guides.py`

**Interfaces:**
- Consumes: nguồn Markdown từ Task 1 và các hàm `GuideSpec`, `register_fonts`, `build_guide` từ bộ dựng PDF hiện có.
- Produces: `build(repo_root: Path) -> Path` và `output/pdf/00_verilog_rtl_foundation_60min.pdf`.

- [ ] **Step 1: Viết wrapper build tối thiểu**

Tạo hằng số và hàm sau:

```python
SOURCE = Path("DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md")
OUTPUT = Path("output/pdf/00_verilog_rtl_foundation_60min.pdf")
SPEC = GuideSpec(SOURCE.name, OUTPUT.name, "Verilog RTL nền tảng", "#2F6B4F")


def build(repo_root: Path) -> Path:
    source_path = repo_root / SOURCE
    output_path = repo_root / OUTPUT
    if not source_path.exists():
        raise FileNotFoundError(f"Thiếu source: {source_path}")
    register_fonts()
    build_guide(source_path, output_path, SPEC)
    return output_path
```

CLI nhận `--repo-root`, gọi `build` và in đường dẫn output. Không sửa `GUIDES` hoặc hành vi build bốn student guide hiện có.

- [ ] **Step 2: Kiểm tra cú pháp**

```powershell
python -m py_compile DMA-controller/docs/tutorials/firewall-rtl/tools/build_verilog_foundation.py
```

Expected: exit code 0.

- [ ] **Step 3: Đánh dấu và tạo PDF lần đầu**

Ngay trước lệnh build đầu tiên, chạy đúng một lần:

```powershell
node container_tools/mark_artifact_operation_started.mjs --operation-kind create --expected-output-count 1 --output-format pdf
```

Sau đó chạy:

```powershell
python DMA-controller/docs/tutorials/firewall-rtl/tools/build_verilog_foundation.py
```

Expected: in `output/pdf/00_verilog_rtl_foundation_60min.pdf` và exit code 0.

- [ ] **Step 4: Chạy verifier đến PASS**

```powershell
python DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py
```

Expected: một dòng PASS với `duration=60`, `questions=6`, ít nhất 10 trang và hơn 8.000 ký tự.

- [ ] **Step 5: Commit bộ dựng và PDF**

```powershell
git add DMA-controller/docs/tutorials/firewall-rtl/tools/build_verilog_foundation.py output/pdf/00_verilog_rtl_foundation_60min.pdf
git commit -m "build: generate Verilog foundation lesson PDF"
```

### Task 4: Render và kiểm tra trực quan

**Files:**
- Create: `tmp/pdfs/verilog-foundation/` chứa PNG kiểm tra, không commit.
- Inspect: `output/pdf/00_verilog_rtl_foundation_60min.pdf`.
- Modify when needed: nguồn Markdown hoặc `build_verilog_foundation.py`.

**Interfaces:**
- Consumes: PDF đã vượt qua structural verifier.
- Produces: PDF cuối không có lỗi bố cục và bằng chứng kiểm tra trực quan tạm thời.

- [ ] **Step 1: Render toàn bộ trang**

```powershell
pdftoppm -png -r 120 output/pdf/00_verilog_rtl_foundation_60min.pdf tmp/pdfs/verilog-foundation/page
```

Expected: số PNG bằng số trang PDF.

- [ ] **Step 2: Tạo contact sheet**

Dùng Pillow ghép thumbnail theo thứ tự trang, bốn cột, nền trắng, giữ tỷ lệ trang. Lưu `tmp/pdfs/verilog-foundation/contact-sheet.png`.

- [ ] **Step 3: Kiểm tra các trang đại diện**

Xem contact sheet và từng trang chứa: bảng lịch 60 phút, sơ đồ ASCII, code block dài nhất, bảng lỗi phổ biến, bảng tra cứu một trang, câu hỏi và trang cuối. Không chấp nhận chữ chồng, code vượt lề, bảng quá nhỏ, glyph tiếng Việt lỗi, heading đơn độc cuối trang hoặc trang rỗng.

- [ ] **Step 4: Sửa và kiểm tra lại nếu cần**

Sau mỗi sửa đổi nội dung hoặc style, build lại PDF, chạy verifier, render lại toàn bộ trang và kiểm tra lại trang bị ảnh hưởng. Giữ nguyên các global constraints.

- [ ] **Step 5: Kiểm tra bàn giao cuối**

```powershell
git diff --check DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md DMA-controller/docs/tutorials/firewall-rtl/tools/build_verilog_foundation.py DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py
python DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py
```

Expected: `git diff --check` không có output và verifier PASS.

- [ ] **Step 6: Commit các sửa đổi QA**

Chỉ tạo commit nếu Task 4 làm thay đổi source hoặc script:

```powershell
git add DMA-controller/docs/tutorials/firewall-rtl/foundation/00_verilog_rtl_foundation_60min.md DMA-controller/docs/tutorials/firewall-rtl/tools/build_verilog_foundation.py DMA-controller/docs/tutorials/firewall-rtl/tools/verify_verilog_foundation.py output/pdf/00_verilog_rtl_foundation_60min.pdf
git commit -m "docs: polish Verilog foundation lesson"
```
