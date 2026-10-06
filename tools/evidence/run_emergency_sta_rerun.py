"""Run candidate-only STA reruns for the emergency two-track release path.

The script never overwrites an authoritative STA report.  Each case writes its
Tcl and stdout log under output/verification/timing_rerun_20260920 and is
promotable only after manual review of a complete, successful report.
"""

import json
import os
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple


REPO_ROOT = Path("/mnt/d/domixi")
OPENROAD_BIN = os.environ.get("OPENROAD_BIN", "/build/bin/openroad")
CANDIDATE_ROOT = Path(
    os.environ.get(
        "AEGIS_RERUN_ROOT",
        "/mnt/d/domixi/output/verification/timing_rerun_20260920",
    )
)
CANDIDATE_ROOT.mkdir(parents=True, exist_ok=True)


def run_case(top: str, corner: str, liberty: Path, sdc: Path) -> Dict[str, object]:
    out_dir = REPO_ROOT / "output" / "physical" / f"sky130_{top}"
    odb = out_dir / f"{top}.odb"
    spef = out_dir / f"{top}.spef"
    tcl_path = CANDIDATE_ROOT / f"{top}_{corner}.tcl"
    report_path = CANDIDATE_ROOT / f"{top}_{corner}.rpt"

    if not liberty.exists():
        message = f"MISSING_INPUT: liberty not found: {liberty}"
        report_path.write_text(message + "\n", encoding="utf-8")
        return {
            "status": "RERUN_BLOCKED",
            "reason": "MISSING_INPUT",
            "missing": str(liberty),
            "candidate_report": str(report_path.relative_to(REPO_ROOT)),
        }
    if not sdc.exists() or not odb.exists() or not spef.exists():
        missing = [str(path) for path in (sdc, odb, spef) if not path.exists()]
        message = "MISSING_INPUT: " + ", ".join(missing)
        report_path.write_text(message + "\n", encoding="utf-8")
        return {
            "status": "RERUN_BLOCKED",
            "reason": "MISSING_INPUT",
            "missing": missing,
            "candidate_report": str(report_path.relative_to(REPO_ROOT)),
        }

    tcl_path.write_text(
        f"""read_liberty {liberty}
read_db {odb}
read_spef {spef}
read_sdc {sdc}
set_propagated_clock [all_clocks]
puts \"=== CANDIDATE STA {top} {corner} ===\"
report_checks -path_delay max -fields {{slew cap input fanout}} -digits 3
report_checks -path_delay min -fields {{slew cap input fanout}} -digits 3
puts \"=== SUMMARY ===\"
report_worst_slack -max
report_tns -max
report_worst_slack -min
report_tns -min
exit
""",
        encoding="utf-8",
    )
    result = subprocess.run(
        [OPENROAD_BIN, "-exit", str(tcl_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
        check=False,
    )
    report_path.write_text(result.stdout, encoding="utf-8")
    return {
        "status": "PASS_CANDIDATE" if result.returncode == 0 else "RERUN_BLOCKED",
        "return_code": result.returncode,
        "candidate_report": str(report_path.relative_to(REPO_ROOT)),
        "promotion": "NOT_PROMOTED_PENDING_REVIEW",
    }


def main() -> int:
    cases = []
    for top in ("dma_bus_firewall", "aegis_soc_top"):
        out_dir = REPO_ROOT / "output" / "physical" / f"sky130_{top}"
        cases.extend(
            [
                (
                    top,
                    "tt_38mhz",
                    out_dir / "sky130_fd_sc_hd__tt_025C_1v80.lib",
                    out_dir / f"{top}.sdc",
                ),
                (
                    top,
                    "ss_100C_1v60",
                    out_dir / "sky130_fd_sc_hd__ss_100C_1v60.lib",
                    out_dir / f"{top}.sdc",
                ),
                (
                    top,
                    "ff_n40C_1v95",
                    out_dir / "sky130_fd_sc_hd__ff_n40C_1v95.lib",
                    out_dir / f"{top}.sdc",
                ),
            ]
        )

    results = {}
    for top, corner, liberty, sdc in cases:
        print(f"Running candidate STA for {top} {corner}...")
        results[f"{top}:{corner}"] = run_case(top, corner, liberty, sdc)

    summary = CANDIDATE_ROOT / "sta_rerun_summary.json"
    summary.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
