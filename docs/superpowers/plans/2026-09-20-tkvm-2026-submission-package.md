# TKVM 2026 submission package implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo hồ sơ dự thi TKVM 2026 dạng PDF và gói ZIP sạch, chỉ chứa các minh chứng cần nộp, đồng thời giữ nguyên mọi giới hạn kỹ thuật đã được ghi nhận.

**Architecture:** Một bộ chọn hiện vật theo allowlist đọc nguồn sự thật từ bundle signoff và hai manifest physical, sau đó sao chép bất biến vào thư mục nộp, tạo manifest SHA256 và ZIP. Báo cáo được biên tập bằng Markdown, dựng thành PDF A4 bằng ReportLab, rồi kiểm tra cấu trúc, số liệu, hình ảnh và hiển thị từng trang trước khi phát hành.

**Tech Stack:** Python 3, `unittest`, ReportLab, pypdf hoặc PyMuPDF, Pillow, Markdown nguồn, JSON, CSV, SHA256, ZIP, CodeGraph và Open Code Review.

**Spec:** `docs/superpowers/specs/2026-09-20-tkvm-2026-submission-package-design.md`

## Global Constraints

- Không sửa, di chuyển hoặc xóa hiện vật nguồn. Việc "dọn file" được thực hiện bằng cách tạo một thư mục nộp mới theo allowlist.
- Không đưa tài liệu giảng dạy, đặc tả lịch sử, kế hoạch nội bộ, bundle cũ, mock integration, tệp tạm, cache, debug, FPGA, PDK deck, Liberty, SPEF, SDF hoặc script vá GDS vào gói nộp.
- Không tự điền tên đội, thành viên, trường, giảng viên hướng dẫn hoặc thông tin liên hệ chưa có nguồn xác nhận.
- Dùng SoC làm bằng chứng physical chính. Dùng firewall độc lập làm bằng chứng bổ sung.
- Giữ nguyên nhãn `REPORTED_PASS` và trạng thái `EVIDENCE_COMPLETE_REVIEW_REQUIRED`. Không mô tả DRC, LVS hoặc timing là đã được chạy lại trong quá trình đóng gói.
- Giữ nguyên số liệu SoC tại 38 MHz: setup slack `+0.89 ns`, hold slack `+0.041 ns`, DRC `0`, LVS matched.
- Giữ nguyên số liệu firewall độc lập: setup slack `+0.81 ns`, hold WNS `-0.02 ns`, hold TNS `-0.07 ns`, có boundary hold waiver. Không gọi đây là timing pass không điều kiện.
- Không dùng hai bài kiểm thử mock integration làm bằng chứng production.
- FPGA không thuộc phạm vi hồ sơ này theo quyết định của đội.
- Chỉ sao chép VCD nếu kích thước không vượt quá 25 MB. Nếu vượt ngưỡng, giữ SVG, `waveform.json` và simulation log tương ứng.
- PDF phải khổ A4, có lớp văn bản tìm kiếm được, không có trang trắng, không có dấu gạch dài, không có nội dung tạm và không có số liệu không truy nguyên được.
- ZIP cuối cùng phải nhỏ hơn 500 MB và không chứa chính nó.
- Mọi tệp trong thư mục nộp phải có SHA256 trong `MANIFEST.csv`, ngoại trừ chính `MANIFEST.csv` để tránh vòng lặp tự tham chiếu.

---

## Task 1: Implement the allowlisted artifact inventory

**Files:**

- Create: `tools/submission/__init__.py`
- Create: `tools/submission/tkvm_manifest.py`
- Create: `tools/submission/test_tkvm_manifest.py`
- Read: `output/evidence/release_signoff_bundle_20260920_soc/summary.json`
- Read: `output/evidence/release_signoff_bundle_20260920_soc/simulation_results.csv`
- Read: `output/physical/sky130_aegis_soc_top/physical_manifest.json`
- Read: `output/physical/sky130_dma_bus_firewall/physical_manifest.json`
- Read: `constraints/aegis_soc_top.sdc`
- Read: `constraints/dma_bus_firewall.sdc`

- [ ] **Step 1: Write failing inventory tests**

Create tests for exact inclusion, mock exclusion, missing required artifacts, source path safety, stable ordering and VCD size policy.

```python
class TkvmManifestTests(unittest.TestCase):
    def test_required_physical_artifacts_are_selected(self):
        inventory = build_inventory(self.repo_root)
        destinations = {item.destination.as_posix() for item in inventory}
        self.assertIn(
            "physical/aegis_soc_top/aegis_soc_top.gds",
            destinations,
        )
        self.assertIn(
            "physical/aegis_soc_top/layout.png",
            destinations,
        )

    def test_mock_integration_is_not_selected(self):
        inventory = build_inventory(self.repo_root)
        for item in inventory:
            self.assertNotIn("/mocks/", item.source.as_posix())
            self.assertNotEqual(item.scope, "MOCK_INTEGRATION")

    def test_large_vcd_is_skipped_but_companions_remain(self):
        inventory = build_inventory(self.repo_root, vcd_limit_bytes=1)
        destinations = {item.destination.as_posix() for item in inventory}
        self.assertFalse(any(path.endswith(".vcd") for path in destinations))
        self.assertTrue(any(path.endswith("waveform.svg") for path in destinations))
        self.assertTrue(any(path.endswith("waveform.json") for path in destinations))
```

- [ ] **Step 2: Run the tests and confirm they fail for the missing module**

Run:

```powershell
$workspacePython = 'C:\Users\Hi Windows 11 Home\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $workspacePython -m unittest tools.submission.test_tkvm_manifest -v
```

Expected: `ModuleNotFoundError` or failing assertions because the inventory implementation does not exist yet.

- [ ] **Step 3: Implement the inventory data model and path validation**

Implement the public interfaces below:

```python
@dataclass(frozen=True, order=True)
class ArtifactSpec:
    destination: Path
    source: Path
    category: str
    scope: str
    required: bool = True


def build_inventory(
    repo_root: Path,
    *,
    vcd_limit_bytes: int = 25 * 1024 * 1024,
) -> list[ArtifactSpec]:
    """Return a sorted, collision-free allowlist rooted inside repo_root."""


def sha256_file(path: Path) -> str:
    """Return the lowercase SHA256 digest for path."""
```

Validate that every source resolves beneath `repo_root`, every destination is relative and unique, and every required source exists. Reject absolute destinations and `..` traversal.

- [ ] **Step 4: Select only approved evidence**

Select these evidence groups:

```python
SELECTED_WAVEFORM_SCOPES = (
    "dma_bus_firewall",
    "soc_dma_firewall_contract",
    "soc_real_integration",
    "aegis_rowhammer_5000",
    "adversarial_m1",
)

PHYSICAL_ALLOWLIST = (
    "physical_manifest.json",
    "layout.png",
    "klayout_drc.rpt",
    "lvs.rpt",
    "sta_tt_025C_1v80_38mhz.rpt",
)
```

For each physical design, add the actual `.gds` or `.gdsii` file discovered from its manifest, but do not select broad directory contents. Read production RTL and testbench paths from the signoff summary, then reject any record with scope `MOCK_INTEGRATION` or a source path containing `/mocks/`.

- [ ] **Step 5: Run inventory tests**

Run:

```powershell
& $workspacePython -m unittest tools.submission.test_tkvm_manifest -v
```

Expected: all inventory tests pass.

- [ ] **Step 6: Commit the inventory implementation**

```powershell
git add tools/submission/__init__.py tools/submission/tkvm_manifest.py tools/submission/test_tkvm_manifest.py
git commit -m "feat: define TKVM submission artifact allowlist"
```

---

## Task 2: Build the clean submission tree and ZIP

**Files:**

- Create: `tools/submission/package_tkvm.py`
- Create: `tools/submission/test_package_tkvm.py`
- Create at runtime: `output/submission/tkvm-2026/README.txt`
- Create at runtime: `output/submission/tkvm-2026/MANIFEST.csv`
- Create at runtime: `output/submission/tkvm-2026-submission.zip`

- [ ] **Step 1: Write failing packaging tests**

```python
class PackageTkvmTests(unittest.TestCase):
    def test_copy_preserves_sha256(self):
        result = stage_submission(self.repo_root, self.output_root)
        for record in result.records:
            self.assertEqual(record.sha256, sha256_file(record.staged_path))

    def test_unlisted_file_is_not_copied(self):
        stage_submission(self.repo_root, self.output_root)
        self.assertFalse((self.output_root / "debug.tmp").exists())

    def test_manifest_is_relative_and_sorted(self):
        result = stage_submission(self.repo_root, self.output_root)
        paths = [record.relative_path.as_posix() for record in result.records]
        self.assertEqual(paths, sorted(paths))
        self.assertTrue(all(not Path(path).is_absolute() for path in paths))

    def test_zip_does_not_contain_itself(self):
        archive = build_zip(self.output_root, self.archive_path)
        with ZipFile(archive) as zip_file:
            self.assertNotIn(archive.name, zip_file.namelist())
```

- [ ] **Step 2: Run the packaging tests and confirm they fail**

Run:

```powershell
& $workspacePython -m unittest tools.submission.test_package_tkvm -v
```

Expected: import or assertion failures because the packager is not implemented.

- [ ] **Step 3: Implement deterministic staging**

Implement these interfaces:

```python
@dataclass(frozen=True)
class ManifestRecord:
    relative_path: Path
    category: str
    scope: str
    size_bytes: int
    sha256: str
    source_path: Path
    staged_path: Path


@dataclass(frozen=True)
class StageResult:
    output_root: Path
    records: tuple[ManifestRecord, ...]


def stage_submission(repo_root: Path, output_root: Path) -> StageResult:
    """Replace only output_root with a clean tree built from the allowlist."""


def write_manifest(result: StageResult) -> Path:
    """Write a stable UTF-8 CSV without hashing MANIFEST.csv itself."""


def build_zip(output_root: Path, archive_path: Path) -> Path:
    """Create a deterministic archive whose top-level folder is tkvm-2026."""
```

Before replacing an existing staging directory, resolve and verify that the target is exactly `repo_root / "output/submission/tkvm-2026"`. Never delete any source directory.

- [ ] **Step 4: Generate a concise package README**

`README.txt` must state:

```text
HỒ SƠ DỰ THI TKVM 2026

Tệp bắt đầu: bao_cao_du_thi_TKVM_2026.pdf
Bằng chứng physical chính: AEGIS SoC top
Bằng chứng physical bổ sung: DMA bus firewall độc lập
FPGA: không thuộc phạm vi nộp
Lưu ý: kết quả DRC, LVS và timing là kết quả được báo cáo trong bundle signoff; quá trình đóng gói không chạy lại các công cụ EDA.
```

- [ ] **Step 5: Run packaging tests**

Run:

```powershell
& $workspacePython -m unittest tools.submission.test_package_tkvm -v
```

Expected: all packaging tests pass.

- [ ] **Step 6: Commit the packager**

```powershell
git add tools/submission/package_tkvm.py tools/submission/test_package_tkvm.py
git commit -m "feat: build clean TKVM submission package"
```

---

## Task 3: Write the official report source

**Files:**

- Create: `docs/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.md`
- Read: `README.md`
- Read: `docs/AEGIS_RISC_ARCHITECTURE_SPECIFICATION.md`
- Read: `output/evidence/release_signoff_bundle_20260920_soc/summary.json`
- Read: `output/evidence/release_signoff_bundle_20260920_soc/simulation_results.csv`
- Read: `output/physical/sky130_aegis_soc_top/physical_manifest.json`
- Read: `output/physical/sky130_dma_bus_firewall/physical_manifest.json`

- [ ] **Step 1: Establish the report outline and evidence map**

Use this 12 to 14 page target structure:

1. Trang bìa, trạng thái hồ sơ và chỗ trống có nhãn cho thông tin đội.
2. Tóm tắt đề tài và tuyên bố đóng góp.
3. Bài toán bảo vệ và mô hình đe dọa.
4. Mục tiêu bảo vệ và giới hạn phạm vi.
5. Kiến trúc tổng thể AEGIS SoC.
6. Kiến trúc DMA-aware bus firewall.
7. Thiết kế logic và RTL.
8. Chiến lược mô phỏng và kiểm chứng.
9. Kết quả mô phỏng và bảng 25 bài kiểm thử.
10. Dạng sóng kiểm chứng chọn lọc.
11. Physical design và hình ảnh layout.
12. GDS/GDSII, DRC và LVS.
13. Báo cáo timing và diễn giải giới hạn.
14. Kết luận, khả năng phát triển và phụ lục truy xuất hiện vật.

Create an evidence map table in the source with columns `Khẳng định`, `Nguồn`, `Phạm vi`, `Cách trình bày` so every numerical or pass/fail claim has a traceable source.

- [ ] **Step 2: Write concise, persuasive Vietnamese prose**

Lead with the central claim: the project provides a DMA-aware protection path integrated into AEGIS SoC and is supported by production simulation plus reported RTL-to-GDSII evidence. Explain the novelty as the integration of DMA transaction awareness, region policy and SoC-level adversarial verification. Do not claim novelty beyond what the repository supports.

Use natural technical prose, short paragraphs and explicit transitions. Avoid generic promotional language, rhetorical questions, repeated conclusions and long dashes.

- [ ] **Step 3: Insert figure directives with evidence captions**

Use machine-readable directives that the PDF builder can replace:

```text
[[FIGURE:architecture_soc|Kiến trúc AEGIS SoC và đường kiểm soát DMA]]
[[FIGURE:waveform_firewall|Dạng sóng kiểm chứng firewall production]]
[[FIGURE:waveform_soc|Dạng sóng tích hợp PicoRV32 SoC production]]
[[FIGURE:waveform_stress|Dạng sóng kiểm chứng adversarial stress]]
[[FIGURE:layout_soc|Layout AEGIS SoC top]]
[[FIGURE:layout_firewall|Layout DMA bus firewall độc lập]]
```

If no repository image already documents the architecture clearly, generate a deterministic vector block diagram from verified module relationships. Label it as a schematic architectural view, not a physical implementation image.

- [ ] **Step 4: State limitations exactly**

Include this meaning without dilution:

```text
Các kết quả physical được trích từ bundle signoff và giữ trạng thái REPORTED_PASS, EVIDENCE_COMPLETE_REVIEW_REQUIRED. Quá trình biên soạn hồ sơ không chạy lại DRC, LVS hoặc STA.

Ở AEGIS SoC top, báo cáo tại 38 MHz ghi nhận setup slack +0.89 ns và hold slack +0.041 ns, DRC không có vi phạm và LVS matched.

Ở DMA bus firewall độc lập, setup slack là +0.81 ns; hold WNS là -0.02 ns và hold TNS là -0.07 ns. Hồ sơ giữ nguyên boundary hold waiver, vì vậy không diễn giải kết quả này thành timing pass không điều kiện.
```

- [ ] **Step 5: Check the source for unsupported or unfinished content**

Run:

```powershell
rg -n "TBD|TODO|PLACEHOLDER|lorem|sẽ bổ sung|đang cập nhật|—|–| -- " docs/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.md
```

Expected: no matches. Deliberately blank identity fields must be labeled `Đội tự điền trước khi nộp`, not presented as unfinished editorial text.

- [ ] **Step 6: Commit the report source**

```powershell
git add docs/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.md
git commit -m "docs: draft official TKVM competition report"
```

---

## Task 4: Build and structurally verify the PDF

**Files:**

- Create: `tools/submission/build_tkvm_report.py`
- Create: `tools/submission/verify_tkvm_report.py`
- Create: `tools/submission/test_tkvm_report.py`
- Reuse: `DMA-controller/docs/tutorials/firewall-rtl/tools/build_student_guides.py`
- Create at runtime: `output/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.pdf`

- [ ] **Step 1: Write failing PDF verification tests**

```python
REQUIRED_TEXT = (
    "Ý tưởng và đóng góp",
    "Mục tiêu bảo vệ",
    "Kiến trúc thiết kế",
    "Thiết kế logic và RTL",
    "Kết quả mô phỏng",
    "Dạng sóng kiểm chứng",
    "Layout và GDS/GDSII",
    "DRC và LVS",
    "Báo cáo timing",
    "+0.89 ns",
    "+0.041 ns",
    "+0.81 ns",
    "-0.02 ns",
    "-0.07 ns",
    "REPORTED_PASS",
    "EVIDENCE_COMPLETE_REVIEW_REQUIRED",
)


class TkvmReportTests(unittest.TestCase):
    def test_required_sections_and_values_exist(self):
        result = verify_pdf(self.pdf_path)
        self.assertEqual(result.missing_text, ())

    def test_every_page_has_content_and_is_a4(self):
        result = verify_pdf(self.pdf_path)
        self.assertEqual(result.blank_pages, ())
        self.assertEqual(result.non_a4_pages, ())

    def test_no_unfinished_markers_or_long_dashes(self):
        result = verify_pdf(self.pdf_path)
        self.assertEqual(result.forbidden_matches, ())
```

- [ ] **Step 2: Run tests and confirm they fail before the builder exists**

Run:

```powershell
& $workspacePython -m unittest tools.submission.test_tkvm_report -v
```

Expected: import or missing PDF failures.

- [ ] **Step 3: Implement the report builder**

Reuse Vietnamese font registration, paragraph styles and Markdown flowable conversion from the existing student guide builder. Add figure directive parsing and keep all figure sources under the allowlisted evidence set.

```python
@dataclass(frozen=True)
class FigureSpec:
    key: str
    source: Path
    caption: str
    kind: str


def build_report(
    repo_root: Path,
    markdown_path: Path,
    output_pdf: Path,
) -> Path:
    """Build the A4 Vietnamese competition report with embedded evidence figures."""
```

Generate the architecture diagram using ReportLab drawing primitives so it remains vector content. Scale raster waveform and layout images without upsampling beyond their native resolution. Add page number, short project title and evidence status footer.

- [ ] **Step 4: Implement structural PDF verification**

```python
@dataclass(frozen=True)
class PdfVerification:
    page_count: int
    missing_text: tuple[str, ...]
    blank_pages: tuple[int, ...]
    non_a4_pages: tuple[int, ...]
    forbidden_matches: tuple[str, ...]


def verify_pdf(pdf_path: Path) -> PdfVerification:
    """Validate required text, searchable content, page size and forbidden markers."""
```

Treat A4 as 595.28 by 841.89 points with a tolerance of 2 points. A page is blank if it has neither extracted text nor an image or drawing object.

- [ ] **Step 5: Run report tests**

Run:

```powershell
& $workspacePython -m unittest tools.submission.test_tkvm_report -v
```

Expected: all report tests pass after a test fixture PDF is generated.

- [ ] **Step 6: Commit the PDF tooling**

```powershell
git add tools/submission/build_tkvm_report.py tools/submission/verify_tkvm_report.py tools/submission/test_tkvm_report.py
git commit -m "feat: build and verify TKVM report PDF"
```

---

## Task 5: Generate and visually inspect the release PDF

**Files:**

- Create at runtime: `output/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.pdf`
- Create temporarily: `output/submission/tkvm-2026/rendered-pages/page-*.png`

- [ ] **Step 1: Mark the PDF creation operation exactly once**

Run this once before the first PDF authoring command in the execution session:

```powershell
node container_tools/mark_artifact_operation_started.mjs --operation-kind create --expected-output-count 1 --output-format pdf
```

Expected: the artifact operation is registered successfully. Do not run this command again for rebuilds of the same deliverable.

- [ ] **Step 2: Build the report and run structural verification**

Run:

```powershell
& $workspacePython tools/submission/build_tkvm_report.py --repo-root . --source docs/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.md --output output/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.pdf
& $workspacePython tools/submission/verify_tkvm_report.py output/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.pdf
```

Expected: exit code 0, all required sections and exact signoff values present, no blank or non-A4 pages, no forbidden markers.

- [ ] **Step 3: Render every PDF page to PNG**

Use the PDF skill's bundled rendering utility or PyMuPDF to render all pages at a legible resolution into `rendered-pages`.

Expected: one PNG per PDF page with continuous numbering and no render errors.

- [ ] **Step 4: Inspect every rendered page**

Check all pages for:

- clipped headings, captions or tables;
- unreadable waveform labels;
- distorted layout images;
- orphan headings or excessive whitespace;
- broken Vietnamese diacritics;
- incorrect page numbering;
- accidental disclosure of local absolute paths;
- inconsistent status language;
- unsupported claims or altered signoff values.

If a page fails, patch the Markdown or builder, rebuild, rerun structural verification and rerender all pages.

- [ ] **Step 5: Remove temporary rendered pages after approval**

Keep the final PDF but remove `rendered-pages` from the submission staging tree after confirming the target path resolves exactly beneath `output/submission/tkvm-2026/`.

- [ ] **Step 6: Record the approved PDF hash**

Run:

```powershell
Get-FileHash output/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.pdf -Algorithm SHA256
```

Expected: a stable SHA256 value that will appear in `MANIFEST.csv`.

---

## Task 6: Assemble, audit and release the final package

**Files:**

- Modify at runtime: `output/submission/tkvm-2026/`
- Modify at runtime: `output/submission/tkvm-2026/MANIFEST.csv`
- Create at runtime: `output/submission/tkvm-2026-submission.zip`
- Modify: `.codegraph/` index through CodeGraph sync

- [ ] **Step 1: Stage the allowlisted package around the approved PDF**

Run the packager so that it rebuilds the clean tree, then copies the approved PDF into the root before writing `MANIFEST.csv`.

```powershell
& $workspacePython tools/submission/package_tkvm.py --repo-root . --output output/submission/tkvm-2026 --report output/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.pdf --archive output/submission/tkvm-2026-submission.zip
```

Implementation note: to avoid deleting the report while replacing the staging tree, the CLI must first copy the approved PDF to a temporary file created with `tempfile`, rebuild the exact staging target, then restore the PDF and verify its SHA256 before writing the manifest.

- [ ] **Step 2: Verify every manifest record and package boundary**

Run:

```powershell
& $workspacePython tools/submission/package_tkvm.py --repo-root . --output output/submission/tkvm-2026 --archive output/submission/tkvm-2026-submission.zip --verify-only
```

Expected:

- every staged file except `MANIFEST.csv` has one matching record;
- every size and SHA256 matches;
- no unlisted file is present;
- no source path escapes the repository;
- no mock integration or FPGA file is present;
- ZIP contains the same relative file set as the staging tree;
- ZIP is smaller than 500 MB.

- [ ] **Step 3: Run the complete submission test suite**

Run:

```powershell
& $workspacePython -m unittest discover -s tools/submission -p "test_*.py" -v
```

Expected: all tests pass.

- [ ] **Step 4: Sync CodeGraph after source changes**

Run:

```powershell
codegraph sync "D:\domixi"
```

Expected: the project index updates successfully.

- [ ] **Step 5: Review the complete current change set**

Load and follow the Open Code Review skill, then run `ocr review` from the repository root across staged, unstaged and untracked source changes. Fix only high-confidence findings within the submission-package scope and rerun affected tests.

Expected: no unresolved high-confidence finding in `tools/submission/` or the report source. Preserve unrelated pre-existing user changes.

- [ ] **Step 6: Perform final release checks**

Run:

```powershell
git status --short
Get-Item output/submission/tkvm-2026-submission.zip | Select-Object FullName, Length
Get-FileHash output/submission/tkvm-2026-submission.zip -Algorithm SHA256
```

Confirm manually that the package contains exactly:

```text
tkvm-2026/
  README.txt
  MANIFEST.csv
  bao_cao_du_thi_TKVM_2026.pdf
  source/
    rtl/
    constraints/
    testbench/
  verification/
    summary.json
    simulation_results.csv
    logs/
    waveforms/
  physical/
    aegis_soc_top/
    dma_bus_firewall/
```

- [ ] **Step 7: Commit implementation sources without committing generated evidence**

Commit only the authored source, tests and report Markdown unless the repository policy explicitly tracks generated submission outputs.

```powershell
git add tools/submission docs/submission/tkvm-2026/bao_cao_du_thi_TKVM_2026.md
git commit -m "feat: finalize TKVM submission workflow"
```

Do not stage unrelated pre-existing changes. If all implementation files were already committed task by task, skip this commit rather than creating an empty commit.

- [ ] **Step 8: Hand off the deliverables**

Provide the absolute paths, file sizes and SHA256 values for the final PDF and ZIP. State that FPGA is intentionally omitted, physical results were packaged rather than rerun, and the standalone firewall hold result remains waived and review-required.
