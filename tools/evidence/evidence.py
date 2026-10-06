#!/usr/bin/env python3
"""Run Verilog tests and package simulation/physical evidence using Python stdlib."""

import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
from html import escape
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import quote

from physical import collect_physical, sha256
from waveform import read_vcd, render_svg

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FAIL_PATTERN = r"(?im)^\s*(?:\[FAIL\]|\[TIMEOUT\]|FATAL:|ERROR:|FAIL:|TIMEOUT:)"


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")


def local_path(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Path escapes root: {relative}")
    return path


def execute(argv, cwd, log, timeout=60):
    started = time.monotonic()
    timed_out = False
    with log.open("w", encoding="utf-8") as stream:
        try:
            result = subprocess.run(argv, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=timeout, check=False,
                                    creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
            code = result.returncode
        except subprocess.TimeoutExpired:
            timed_out, code = True, None
            stream.write("\nTIMEOUT: evidence runner wall-clock limit\n")
    return {"argv": [str(a) for a in argv], "exit_code": code, "timeout": timed_out,
            "seconds": round(time.monotonic() - started, 3)}


def classify_run(compile_result, simulation_result, text, pass_pattern, warnings=0):
    if any(r["timeout"] or r["exit_code"] != 0 for r in (compile_result, simulation_result)):
        return "FAIL"
    if re.search(FAIL_PATTERN, text):
        return "FAIL"
    if not pass_pattern:
        return "OBSERVED"
    if not re.search(pass_pattern, text):
        return "FAIL"
    return "REVIEW" if warnings else "PASS"


def run_test(test, root, bundle, timeout):
    root, bundle = root.resolve(), bundle.resolve()
    name = test["id"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
        raise ValueError(f"Invalid test id: {name}")
    case = bundle / "simulation" / name
    case.mkdir(parents=True)
    row = {"id": name, "scope": test["scope"], "status": "BLOCKED", "note": test.get("note", "")}
    if test.get("blocked_reason"):
        return dict(row, reason=test["blocked_reason"])
    sources = [local_path(root, p) for p in test["sources"]]
    missing = [str(p.relative_to(root)) for p in sources if not p.is_file()]
    if missing:
        return dict(row, reason="Await source/testbench: " + ", ".join(missing))
    if not sources:
        raise ValueError(f"Empty source list: {name}")
    row["sources"] = [{"path": str(p.relative_to(root)), "sha256": sha256(p)} for p in sources]
    if any("SIMULATION-ONLY MOCK" in p.read_text(encoding="utf-8", errors="replace") for p in sources):
        row["scope"] = "MOCK_INTEGRATION"
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        return dict(row, reason="Install Icarus Verilog (iverilog and vvp) on PATH")
    top = test["top"]
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_$]*", top):
        raise ValueError(f"Invalid Verilog top: {top}")
    wave = local_path(case, test.get("waveform", "waves.vcd"))
    wave.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="domixi-evidence-") as temporary:
        temporary = Path(temporary)
        binary = temporary / "simulation.vvp"
        # Every Verilog source and the generated observer declares a timescale.
        # Icarus still warns that the command-line compilation unit itself has
        # none, so suppress that tool-level diagnostic while keeping all RTL
        # warnings enabled.
        argv = [
            "iverilog", "-g2012", "-Wall", "-Wimplicit", "-Wno-timescale",
            "-s", top, "-o", str(binary),
        ]
        # Tests execute from their per-case bundle directory, so repository
        # relative Verilog include paths must be anchored to the project root.
        argv += ["-I", str(root / "rtl")]
        argv += test.get("iverilog_flags", [])
        dump_sources = []
        if "waveform" not in test:
            dumper = temporary / "evidence_dump.v"
            dumper.write_text('`timescale 1ns/1ps\nmodule evidence_dump;\ninitial begin\n'
                              f'$dumpfile("waves.vcd");\n$dumpvars(0, {top});\nend\nendmodule\n', encoding="ascii")
            argv += ["-s", "evidence_dump"]
            dump_sources = [str(dumper)]
            row["dump_injection"] = "Observation-only extra simulation root; no RTL edits"
        # Put observer last: its timescale must not change the source files' context.
        argv += [str(p) for p in sources] + dump_sources
        compile_result = execute(argv, case, case / "compile.log", timeout)
        row["compile"] = compile_result
        compile_text = (case / "compile.log").read_text(encoding="utf-8", errors="replace")
        warnings = len(re.findall(r"(?im)warning:", compile_text))
        row["compile_warnings"] = warnings
        if compile_result["exit_code"] != 0 or compile_result["timeout"]:
            return dict(row, status="FAIL", reason="Compile failed; see compile.log")
        simulation = execute(["vvp", str(binary)] + test.get("plusargs", []), case, case / "simulation.log", timeout)
        row["simulation"] = simulation
        text = (case / "simulation.log").read_text(encoding="utf-8", errors="replace")
        row["status"] = classify_run(compile_result, simulation, text, test.get("pass_pattern"), warnings)
        row["pass_pattern"] = test.get("pass_pattern")
        row["plusargs"] = test.get("plusargs", [])
        row["seed_note"] = "No seed inferred. Existing default tests are directed; record owner-supplied random seed in plusargs when supported."
        if row["status"] == "FAIL":
            row["reason"] = "Runtime error, failure marker, timeout or missing required success marker"
        elif row["status"] == "REVIEW":
            row["reason"] = "Success marker present, but compiler warnings require review"
        elif row["status"] == "OBSERVED":
            row["reason"] = "No self-checking success marker configured"
    if wave.is_file() and wave.stat().st_size:
        try:
            trace = read_vcd(wave, test.get("signals", []))
            render_svg(trace, case / "waveform.svg")
            write_json(case / "waveform.json", trace)
            row["waveform"] = str(wave.relative_to(bundle)).replace("\\", "/")
            row["preview"] = f"simulation/{name}/waveform.svg"
            row["preview_truncated"] = trace["truncated"]
        except ValueError as error:
            row["waveform_issue"] = str(error)
    else:
        row["waveform_issue"] = "No nonempty VCD generated"
    if "waveform_issue" in row and row["status"] == "PASS":
        row["status"] = "REVIEW"
    return row


def doctor():
    found = {name: shutil.which(name) for name in
             ("iverilog", "vvp", "gtkwave", "yosys", "openroad", "sta", "klayout", "magic", "netgen", "openlane", "docker", "wsl")}
    versions = {"python": sys.version.split()[0]}
    for tool in ("iverilog", "vvp"):
        if found[tool]:
            try:
                result = subprocess.run([found[tool], "-V"], capture_output=True, text=True, timeout=10,
                                        errors="replace", creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                versions[tool] = (result.stdout or result.stderr).splitlines()[0]
            except (OSError, subprocess.TimeoutExpired, IndexError) as error:
                versions[tool] = str(error)
    return {"executables_on_current_path": found, "versions": versions,
            "note": "PATH presence is not a working installation check. Tools inside WSL/containers may be installed separately. PDK/toolchain installation is not performed by this collector."}


def make_report(bundle, summary):
    rows = summary["tests"]
    with (bundle / "simulation_results.csv").open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=["id", "scope", "status", "compile_warnings", "reason", "note", "waveform"], extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    physical = summary["physical"]
    with (bundle / "physical_results.csv").open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=["id", "status", "value", "corner", "mode", "check", "stage", "unit", "wns", "tns", "unconstrained_endpoints", "tool", "version"], extrasaction="ignore")
        writer.writeheader()
        writer.writerows(physical.get("checks", []))
    esc = lambda value: escape(str(value))
    html = ['<!doctype html><html lang="vi"><meta charset="utf-8"><title>Hồ sơ kiểm chứng dự án</title>',
            '<style>body{font:16px system-ui;margin:32px auto;max-width:1320px;padding:0 20px;color:#172033;background:#f5f7fb}table{border-collapse:collapse;width:100%;background:white}td,th{padding:10px;border:1px solid #d6dce6;text-align:left;vertical-align:top}th{background:#e8edf5}img{max-width:100%;margin:12px 0}code{overflow-wrap:anywhere}a{color:#145cb7}.note{padding:16px;background:#fff3cc}details{margin:14px 0}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style>',
            '<h1>Hồ sơ kiểm chứng — CPU PicoRV32 · DMA · Firewall</h1>',
            f'<p>Lần chạy: {esc(summary["created_utc"])} · <b>{esc(summary["status"])}</b></p>',
            '<p class="note">PASS chỉ áp dụng cho testcase và phạm vi được ghi. MOCK_INTEGRATION dùng mock; CPU_SMOKE chỉ là smoke test. Ảnh dạng sóng giúp đọc VCD, không thay thế checker/coverage. Kết quả vật lý nhập vào mang nhãn REPORTED_PASS, chưa phải signoff độc lập.</p>',
            '<p><a href="simulation_results.csv">CSV mô phỏng</a> · <a href="physical_results.csv">CSV vật lý</a> · <a href="summary.json">JSON đầy đủ</a> · <a href="artifacts.csv">Danh mục SHA-256</a></p>',
            '<h2>Mô phỏng</h2><table><tr><th>Test</th><th>Phạm vi</th><th>Kết quả</th><th>Ghi chú / bằng chứng</th></tr>']
    for row in rows:
        links = []
        for filename in ("compile.log", "simulation.log"):
            relative = f'simulation/{row["id"]}/{filename}'
            if (bundle / relative).exists():
                links.append(f'<a href="{quote(relative)}">{filename}</a>')
        if row.get("waveform"):
            links.append(f'<a href="{quote(row["waveform"])}">VCD</a>')
        notes = " ".join(str(row.get(k, "")) for k in ("reason", "note", "waveform_issue"))
        html.append(f'<tr><td>{esc(row["id"])}</td><td>{esc(row["scope"])}</td><td><b>{esc(row["status"])}</b></td><td>{esc(notes)}<br>{" · ".join(links)}</td></tr>')
    html.append('</table><h2>Dạng sóng từ lần chạy này</h2>')
    for row in rows:
        if row.get("preview"):
            html.append(f'<details><summary>{esc(row["id"])} — {esc(row["scope"])} — {esc(row["status"])}</summary><img src="{quote(row["preview"])}" alt="VCD waveform"><p>Mở VCD bằng GTKWave để xem toàn bộ tín hiệu và khoảng thời gian.</p></details>')
    html += ['<h2>Thiết kế vật lý</h2>', f'<p>Trạng thái: <b>{esc(physical["status"])}</b></p>',
             '<pre>' + esc(json.dumps(physical.get("metadata", {}), ensure_ascii=False, indent=2)) + '</pre>',
             '<ul>' + ''.join(f'<li>{esc(issue)}</li>' for issue in physical.get("issues", [])) + '</ul>',
             '<table><tr><th>Kiểm tra</th><th>Kết quả</th><th>Số liệu</th></tr>']
    for check in physical.get("checks", []):
        html.append(f'<tr><td>{esc(check["id"])}</td><td>{esc(check["status"])}</td><td><code>{esc(json.dumps(check, ensure_ascii=False))}</code></td></tr>')
    html.append('</table><h3>Layout / GDS / báo cáo gốc</h3>')
    for artifact in physical.get("artifacts", []):
        html.append(f'<p><a href="{quote(artifact["path"])}">{esc(artifact["kind"])}</a> · SHA256 <code>{esc(artifact["sha256"])}</code></p>')
        if artifact["kind"] == "layout_image" and Path(artifact["path"]).suffix in (".png", ".jpg", ".jpeg"):
            html.append(f'<img src="{quote(artifact["path"])}" alt="Layout image supplied with physical evidence">')
    html.append('</html>')
    (bundle / "index.html").write_text("\n".join(html), encoding="utf-8")


def inventory(bundle):
    with (bundle / "artifacts.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=["path", "bytes", "sha256"])
        writer.writeheader()
        for path in sorted(bundle.rglob("*")):
            if path.is_file() and path != bundle / "artifacts.csv":
                writer.writerow({"path": path.relative_to(bundle).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)})


def verify_bundle(bundle):
    with (bundle / "artifacts.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    expected = {row["path"] for row in rows}
    actual = {p.relative_to(bundle).as_posix() for p in bundle.rglob("*") if p.is_file() and p != bundle / "artifacts.csv"}
    errors = [f"File set mismatch: {sorted(expected ^ actual)}"] if expected != actual else []
    if len(expected) != len(rows):
        errors.append("Duplicate inventory entries")
    for row in rows:
        path = local_path(bundle, row["path"])
        if not path.is_file() or path.stat().st_size != int(row["bytes"]) or sha256(path) != row["sha256"]:
            errors.append(f'Missing/modified artifact: {row["path"]}')
    return errors


def create_bundle(args):
    bundle = args.out.resolve()
    bundle.mkdir(parents=True, exist_ok=False)
    physical = {"status": "BLOCKED", "checks": [], "artifacts": [], "issues": [
        "Await real GDS/GDSII and layout image", "Await DRC/LVS reports and rule decks",
        "Await post-route setup/hold timing, PDK/corners, netlist, SDC, SPEF and Liberty"]}
    tests = []
    if args.command == "run":
        root = args.root.resolve()
        config = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
        if config.get("schema_version") != 1:
            raise ValueError("Unsupported simulation manifest schema")
        ids = [t["id"] for t in config["tests"]]
        if len(set(ids)) != len(ids) or set(args.test or []) - set(ids):
            raise ValueError("Duplicate or unknown test IDs")
        shutil.copy2(args.manifest, bundle / "simulation_config.json")
        for test in config["tests"]:
            if args.test and test["id"] not in args.test:
                row = {"id": test["id"], "scope": test["scope"], "status": "NOT_RUN", "reason": "Excluded by --test selection"}
            else:
                row = run_test(test, root, bundle, args.timeout)
            tests.append(row)
            print(f'{row["status"]:10s} {row["id"]} ({row["scope"]})', flush=True)
    if args.physical:
        shutil.copy2(args.physical, bundle / "physical_manifest.json")
        physical = collect_physical(args.physical.resolve(), bundle / "physical")
    complete_sim = tests and all(t["status"] == "PASS" for t in tests) and any(t["scope"] not in ("MOCK_INTEGRATION", "CPU_SMOKE") for t in tests)
    failed = any(t["status"] == "FAIL" for t in tests) or physical["status"] == "FAIL"
    status = "FAIL" if failed else "EVIDENCE_COMPLETE_REVIEW_REQUIRED" if complete_sim and physical["status"] == "REPORTED_PASS" else "INCOMPLETE"
    summary = {"schema_version": 1, "created_utc": datetime.now(timezone.utc).isoformat(),
               "status": status, "tests": tests, "counts": dict(Counter(t["status"] for t in tests)),
               "physical": physical, "environment": doctor(),
               "collector_sha256": {p.name: sha256(p) for p in (HERE / "evidence.py", HERE / "waveform.py", HERE / "physical.py")}}
    write_json(bundle / "summary.json", summary)
    make_report(bundle, summary)
    inventory(bundle)
    print(f'Report: {bundle / "index.html"}\nStatus: {status}', flush=True)
    return 1 if failed else 2 if args.strict and status != "EVIDENCE_COMPLETE_REVIEW_REQUIRED" else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor", help="Inspect free EDA tools on the current PATH")
    for name in ("run", "collect"):
        sub = commands.add_parser(name, help="Run simulations / import physical results into a new bundle")
        sub.add_argument("--out", type=Path, required=True, help="New output directory; never overwritten")
        sub.add_argument("--physical", type=Path, required=name == "collect")
        sub.add_argument("--strict", action="store_true", help="Exit 2 while evidence is incomplete")
        if name == "run":
            sub.add_argument("--root", type=Path, default=ROOT)
            sub.add_argument("--manifest", type=Path, default=HERE / "simulations.json")
            sub.add_argument("--test", action="append", help="Test id; repeat to select multiple tests")
            sub.add_argument("--timeout", type=int, default=60)
    wave = commands.add_parser("wave", help="Create SVG from a chosen VCD time window")
    wave.add_argument("--input", type=Path, required=True)
    wave.add_argument("--output", type=Path, required=True)
    wave.add_argument("--signals", nargs="*", default=[])
    wave.add_argument("--start", type=int, default=0)
    wave.add_argument("--end", type=int)
    verify = commands.add_parser("verify", help="Check bundle file set, sizes and SHA256")
    verify.add_argument("--bundle", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "doctor":
            print(json.dumps(doctor(), indent=2))
            return 0
        if args.command == "wave":
            if args.output.exists():
                raise ValueError("Refusing to overwrite existing SVG")
            trace = read_vcd(args.input, args.signals, args.start, args.end)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            render_svg(trace, args.output)
            print(f'Preview: {args.output}; clipped={trace["truncated"]}; ticks={trace["start"]}..{trace["end"]}')
            return 0
        if args.command == "verify":
            errors = verify_bundle(args.bundle.resolve())
            print("\n".join(errors) if errors else "PASS: bundle integrity (not design signoff)")
            return 1 if errors else 0
        return create_bundle(args)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
