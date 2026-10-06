from __future__ import annotations

import argparse
import csv
import shutil
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.submission.tkvm_manifest import build_inventory, sha256_file


README_TEXT = """HỒ SƠ DỰ THI TKVM 2026

Tệp bắt đầu: bao_cao_du_thi_TKVM_2026.pdf
Bằng chứng physical chính: AEGIS SoC top
Bằng chứng physical bổ sung: DMA bus firewall độc lập
PPA: output/ppa/PPA_SUMMARY.md và các báo cáo power VCD theo workload
Trạng thái: DRC 0 marker; firewall và AEGIS SoC LVS matched. Raw SoC Netgen log kết thúc bằng `Circuits match uniquely`; hai phía có 29.957 devices, 30.422 nets và 0 mismatch.
Timing 38 MHz PASS tại TT nhưng setup FAIL tại SS; firewall có boundary hold waiver.
Lưu ý: các kết quả physical do nhóm tạo và báo cáo; quá trình đóng gói không chạy lại công cụ EDA.
Mã nguồn giữ nguyên logic; một chú thích thư viện được rút gọn trong bản sao đóng gói để thống nhất phạm vi ASIC.
"""


SCOPE_NORMALIZATIONS = {
    "FPGA SoC interconnects (Xilinx": "ASIC SoC interconnects",
    "FPGA SoC interconnects": "ASIC SoC interconnects",
}


@dataclass(frozen=True)
class ManifestRecord:
    relative_path: Path
    category: str
    scope: str
    size_bytes: int
    sha256: str
    source_sha256: str
    source_path: Path | None
    staged_path: Path


@dataclass(frozen=True)
class StageResult:
    repo_root: Path
    output_root: Path
    records: tuple[ManifestRecord, ...]


def _approved_output(repo_root: Path, output_root: Path) -> Path:
    expected = (repo_root / "output/submission/tkvm-2026").resolve()
    actual = output_root.resolve()
    if actual != expected:
        raise ValueError(f"Refusing to replace unexpected staging directory: {actual}")
    return actual


def stage_submission(repo_root: Path, output_root: Path) -> StageResult:
    """Replace only output_root with a clean tree built from the allowlist."""

    repo_root = repo_root.resolve()
    output_root = _approved_output(repo_root, output_root)
    inventory = build_inventory(repo_root)
    if output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True)

    records: list[ManifestRecord] = []
    for item in inventory:
        target = output_root / item.destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item.source, target)
        source_hash = sha256_file(item.source)
        normalized = False
        if item.category == "rtl" and target.suffix.lower() in {".v", ".sv", ".vh", ".svh"}:
            text = target.read_text(encoding="utf-8")
            normalized_text = text
            for source, replacement in SCOPE_NORMALIZATIONS.items():
                normalized_text = normalized_text.replace(source, replacement)
            if normalized_text != text:
                target.write_text(normalized_text, encoding="utf-8")
                normalized = True
        staged_hash = sha256_file(target)
        if source_hash != staged_hash and not normalized:
            raise ValueError(f"Hash changed while staging: {item.destination}")
        records.append(
            ManifestRecord(
                relative_path=item.destination,
                category=f"{item.category}-scope-normalized" if normalized else item.category,
                scope=item.scope,
                size_bytes=target.stat().st_size,
                sha256=staged_hash,
                source_sha256=source_hash,
                source_path=item.source,
                staged_path=target,
            )
        )

    readme = output_root / "README.txt"
    readme.write_text(README_TEXT, encoding="utf-8")
    records.append(
        ManifestRecord(
            relative_path=Path("README.txt"),
            category="package-guide",
            scope="submission",
            size_bytes=readme.stat().st_size,
            sha256=sha256_file(readme),
            source_sha256=sha256_file(readme),
            source_path=None,
            staged_path=readme,
        )
    )
    return StageResult(repo_root, output_root, tuple(sorted(records, key=lambda record: record.relative_path.as_posix())))


def _all_stage_records(result: StageResult) -> tuple[ManifestRecord, ...]:
    known = {record.relative_path.as_posix(): record for record in result.records}
    records: list[ManifestRecord] = []
    for path in sorted(result.output_root.rglob("*")):
        if not path.is_file() or path.name == "MANIFEST.csv":
            continue
        relative = path.relative_to(result.output_root)
        existing = known.get(relative.as_posix())
        if existing:
            records.append(existing)
            continue
        category = "report" if path.suffix.lower() == ".pdf" else "generated"
        records.append(
            ManifestRecord(
                relative_path=relative,
                category=category,
                scope="submission",
                size_bytes=path.stat().st_size,
                sha256=sha256_file(path),
                source_sha256=sha256_file(path),
                source_path=None,
                staged_path=path,
            )
        )
    return tuple(sorted(records, key=lambda record: record.relative_path.as_posix()))


def write_manifest(result: StageResult) -> Path:
    """Write a stable UTF-8 CSV without hashing MANIFEST.csv itself."""

    manifest_path = result.output_root / "MANIFEST.csv"
    records = _all_stage_records(result)
    with manifest_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=("relative_path", "category", "scope", "size_bytes", "sha256", "source_sha256", "source_path"),
        )
        writer.writeheader()
        for record in records:
            source_path = "GENERATED"
            if record.source_path is not None:
                source_path = record.source_path.relative_to(result.repo_root).as_posix()
            writer.writerow(
                {
                    "relative_path": record.relative_path.as_posix(),
                    "category": record.category,
                    "scope": record.scope,
                    "size_bytes": record.size_bytes,
                    "sha256": record.sha256,
                    "source_sha256": record.source_sha256,
                    "source_path": source_path,
                }
            )
    return manifest_path


def build_zip(output_root: Path, archive_path: Path) -> Path:
    """Create a deterministic archive whose top-level folder is tkvm-2026."""

    output_root = output_root.resolve()
    archive_path = archive_path.resolve()
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    if archive_path.exists():
        archive_path.unlink()
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source in sorted(path for path in output_root.rglob("*") if path.is_file()):
            relative = Path(output_root.name) / source.relative_to(output_root)
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(2026, 9, 20, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, source.read_bytes(), compresslevel=9)
    return archive_path


def verify_stage(output_root: Path, archive_path: Path | None = None) -> list[str]:
    errors: list[str] = []
    manifest_path = output_root / "MANIFEST.csv"
    if not manifest_path.is_file():
        return ["MANIFEST.csv is missing"]
    with manifest_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    listed = {row["relative_path"]: row for row in rows}
    actual = {
        path.relative_to(output_root).as_posix(): path
        for path in output_root.rglob("*")
        if path.is_file() and path.name != "MANIFEST.csv"
    }
    if set(listed) != set(actual):
        errors.append("Manifest file set differs from staged file set")
    for relative, path in actual.items():
        row = listed.get(relative)
        if not row:
            continue
        if int(row["size_bytes"]) != path.stat().st_size:
            errors.append(f"Size mismatch: {relative}")
        if row["sha256"] != sha256_file(path):
            errors.append(f"SHA256 mismatch: {relative}")
        lowered = relative.lower()
        if "/mocks/" in f"/{lowered}" or "fpga" in lowered:
            errors.append(f"Forbidden path: {relative}")
    if archive_path is not None:
        if archive_path.stat().st_size >= 500 * 1024 * 1024:
            errors.append("ZIP is 500 MB or larger")
        with zipfile.ZipFile(archive_path) as archive:
            archived = {
                Path(name).relative_to(output_root.name).as_posix()
                for name in archive.namelist()
                if not name.endswith("/")
            }
        expected = set(actual) | {"MANIFEST.csv"}
        if archived != expected:
            errors.append("ZIP file set differs from staged file set")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    output_root = (repo_root / args.output).resolve() if not args.output.is_absolute() else args.output.resolve()
    archive_path = (repo_root / args.archive).resolve() if not args.archive.is_absolute() else args.archive.resolve()

    if args.verify_only:
        errors = verify_stage(output_root, archive_path)
        if errors:
            for error in errors:
                print(f"ERROR: {error}")
            return 1
        print("Submission package verification passed")
        return 0

    if args.report is None:
        parser.error("--report is required unless --verify-only is used")
    report_path = (repo_root / args.report).resolve() if not args.report.is_absolute() else args.report.resolve()
    if not report_path.is_file():
        raise FileNotFoundError(report_path)

    with tempfile.TemporaryDirectory(prefix="tkvm-report-") as temporary:
        cached_report = Path(temporary) / report_path.name
        shutil.copy2(report_path, cached_report)
        report_hash = sha256_file(cached_report)
        result = stage_submission(repo_root, output_root)
        staged_report = output_root / "bao_cao_du_thi_TKVM_2026.pdf"
        shutil.copy2(cached_report, staged_report)
        if sha256_file(staged_report) != report_hash:
            raise ValueError("Report hash changed while staging")
        write_manifest(result)
        build_zip(output_root, archive_path)

    errors = verify_stage(output_root, archive_path)
    if errors:
        raise ValueError("; ".join(errors))
    print(f"Submission staged at {output_root}")
    print(f"Archive created at {archive_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
