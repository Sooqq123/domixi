from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path


EVIDENCE_BUNDLE = Path("output/evidence/release_signoff_bundle_20260920_soc")
PHYSICAL_ROOTS = (
    Path("output/physical/sky130_aegis_soc_top"),
    Path("output/physical/sky130_dma_bus_firewall"),
)
CONSTRAINTS = (
    Path("constraints/aegis_soc_top.sdc"),
    Path("constraints/dma_bus_firewall.sdc"),
)
SELECTED_WAVEFORM_SCOPES = (
    "address_slice_observation",
    "fw_acl_matcher",
    "fw_closed_loop_ctrl",
    "fw_honeypot_sink",
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
PHYSICAL_OPTIONAL_ALLOWLIST = (
    "netgen_lvs.log",
    "sta_ss_100C_1v60_38p5mhz.rpt",
    "sta_ss_100C_1v60_52ns.rpt",
    "sta_ff_n40C_1v95_40mhz.rpt",
    "power_vcd.rpt",
    "power.rpt",
    "ir_drop.rpt",
    "run_vcd_power.tcl",
    "gate_sdf_sim.log",
    "gate_sdf_soc.vcd",
    "gate_sdf_firewall.vcd",
)
PPA_ARTIFACTS = (
    (Path("output/ppa/PPA_SUMMARY.md"), Path("ppa/PPA_SUMMARY.md"), "ppa-report"),
    (Path("output/ppa/ppa_master_summary.json"), Path("ppa/ppa_master_summary.json"), "ppa-metadata"),
    (Path("output/ppa/power_vcd_summary.json"), Path("ppa/power_vcd_summary.json"), "ppa-power"),
    (Path("output/ppa/release_provenance.json"), Path("ppa/release_provenance.json"), "release-provenance"),
    (Path("output/ppa/dma_bus_firewall/run_manifest.json"), Path("ppa/dma_bus_firewall/run_manifest.json"), "ppa-synthesis"),
    (Path("output/ppa/aegis_soc_top/run_manifest.json"), Path("ppa/aegis_soc_top/run_manifest.json"), "ppa-synthesis"),
)
EXPECTED_PHYSICAL_SIGNOFF = {
    "aegis_soc_top": {
        "setup": (0.89, 0.0),
        "hold": (0.041, 0.0),
    },
    "dma_bus_firewall": {
        "setup": (0.81, 0.0),
        "hold": (-0.02, -0.07),
    },
}


@dataclass(frozen=True, order=True)
class ArtifactSpec:
    destination: Path
    source: Path
    category: str
    scope: str
    required: bool = True


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _safe_source(repo_root: Path, relative: Path) -> Path:
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError(f"Unsafe repository-relative source: {relative}")
    resolved = (repo_root / relative).resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ValueError(f"Source escapes repository: {relative}") from exc
    return resolved


def _normalize_relative(raw: str) -> Path:
    return Path(raw.replace("\\", "/"))


def _source_destination(relative: Path) -> tuple[Path, str]:
    lower_parts = {part.lower() for part in relative.parts}
    filename = relative.name.lower()
    if "tb" in lower_parts or "testbench" in filename or filename.startswith("tb_"):
        return Path("source/testbench") / relative, "testbench"
    return Path("source/rtl") / relative, "rtl"


def _add(
    items: dict[Path, ArtifactSpec],
    *,
    repo_root: Path,
    source_relative: Path,
    destination: Path,
    category: str,
    scope: str,
    required: bool = True,
) -> None:
    if destination.is_absolute() or ".." in destination.parts:
        raise ValueError(f"Unsafe submission destination: {destination}")
    source = _safe_source(repo_root, source_relative)
    if required and not source.is_file():
        raise FileNotFoundError(source)
    if not source.is_file():
        return
    existing = items.get(destination)
    candidate = ArtifactSpec(destination, source, category, scope, required)
    if existing and existing.source != source:
        raise ValueError(f"Destination collision: {destination}")
    items.setdefault(destination, candidate)


def _validate_physical_manifest(manifest: dict, manifest_path: Path, physical_root: Path) -> None:
    top = str(manifest.get("top", ""))
    if top not in EXPECTED_PHYSICAL_SIGNOFF:
        raise ValueError(f"Unexpected physical top in {manifest_path}: {top}")
    if manifest.get("drc", {}).get("violations") != 0:
        raise ValueError(f"DRC result is not zero for {top}")
    if manifest.get("lvs", {}).get("matched") is not True:
        raise ValueError(f"LVS is not matched for {top}")
    timing_by_check = {str(item.get("check")): item for item in manifest.get("timing", [])}
    for check, (expected_wns, expected_tns) in EXPECTED_PHYSICAL_SIGNOFF[top].items():
        record = timing_by_check.get(check)
        if record is None:
            raise ValueError(f"Missing {check} timing record for {top}")
        actual = (float(record.get("wns")), float(record.get("tns")))
        if actual != (expected_wns, expected_tns):
            raise ValueError(
                f"Unexpected {check} timing for {top}: {actual}; "
                f"expected {(expected_wns, expected_tns)}"
            )
    gds_name = manifest.get("artifacts", {}).get("gds")
    expected_hash = manifest.get("gds_sha256")
    if not gds_name or not expected_hash:
        raise ValueError(f"Physical manifest has no GDS identity: {manifest_path}")
    gds_path = physical_root / str(gds_name)
    if not gds_path.is_file() or sha256_file(gds_path) != expected_hash:
        raise ValueError(f"GDS hash differs from physical manifest: {gds_path}")


def build_inventory(
    repo_root: Path,
    *,
    vcd_limit_bytes: int = 25 * 1024 * 1024,
) -> list[ArtifactSpec]:
    """Return a sorted, collision-free allowlist rooted inside repo_root."""

    repo_root = repo_root.resolve()
    summary_relative = EVIDENCE_BUNDLE / "summary.json"
    summary_path = _safe_source(repo_root, summary_relative)
    if not summary_path.is_file():
        raise FileNotFoundError(summary_path)
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    if summary.get("status") != "EVIDENCE_COMPLETE_REVIEW_REQUIRED":
        raise ValueError(f"Unexpected evidence status: {summary.get('status')}")

    items: dict[Path, ArtifactSpec] = {}
    _add(
        items,
        repo_root=repo_root,
        source_relative=summary_relative,
        destination=Path("verification/summary.json"),
        category="verification",
        scope="bundle",
    )
    _add(
        items,
        repo_root=repo_root,
        source_relative=EVIDENCE_BUNDLE / "simulation_results.csv",
        destination=Path("verification/simulation_results.csv"),
        category="verification",
        scope="bundle",
    )

    production_tests: dict[str, dict] = {}
    for test in summary.get("tests", []):
        test_id = str(test.get("id", ""))
        scope = str(test.get("scope", ""))
        if scope == "MOCK_INTEGRATION":
            continue
        production_tests[test_id] = test
        for source_record in test.get("sources", []):
            relative = _normalize_relative(str(source_record["path"]))
            if "mocks" in {part.lower() for part in relative.parts}:
                continue
            destination, category = _source_destination(relative)
            _add(
                items,
                repo_root=repo_root,
                source_relative=relative,
                destination=destination,
                category=category,
                scope=scope,
            )
            expected_hash = source_record.get("sha256")
            selected = items[destination].source
            if expected_hash and sha256_file(selected) != expected_hash:
                raise ValueError(f"Source hash differs from signoff summary: {relative}")

        for log_name in ("compile.log", "simulation.log"):
            _add(
                items,
                repo_root=repo_root,
                source_relative=EVIDENCE_BUNDLE / "simulation" / test_id / log_name,
                destination=Path("verification/logs") / test_id / log_name,
                category="simulation-log",
                scope=scope,
            )

    for test_id in SELECTED_WAVEFORM_SCOPES:
        test = production_tests.get(test_id)
        if test is None:
            raise ValueError(f"Selected production waveform is absent: {test_id}")
        scope = str(test.get("scope", ""))
        simulation_dir = EVIDENCE_BUNDLE / "simulation" / test_id
        for name in ("waveform.svg", "waveform.json", "simulation.log"):
            _add(
                items,
                repo_root=repo_root,
                source_relative=simulation_dir / name,
                destination=Path("verification/waveforms") / test_id / name,
                category="waveform",
                scope=scope,
            )
        waveform_raw = test.get("waveform")
        if waveform_raw:
            waveform_relative = EVIDENCE_BUNDLE / _normalize_relative(str(waveform_raw))
            waveform_path = _safe_source(repo_root, waveform_relative)
            if waveform_path.is_file() and waveform_path.stat().st_size <= vcd_limit_bytes:
                _add(
                    items,
                    repo_root=repo_root,
                    source_relative=waveform_relative,
                    destination=Path("verification/waveforms") / test_id / waveform_path.name,
                    category="waveform-vcd",
                    scope=scope,
                )

    for constraint in CONSTRAINTS:
        _add(
            items,
            repo_root=repo_root,
            source_relative=constraint,
            destination=Path("source/constraints") / constraint.name,
            category="constraint",
            scope="physical",
        )

    for source_relative, destination, category in PPA_ARTIFACTS:
        _add(
            items,
            repo_root=repo_root,
            source_relative=source_relative,
            destination=destination,
            category=category,
            scope="ppa",
        )

    for physical_root in PHYSICAL_ROOTS:
        manifest_path = _safe_source(repo_root, physical_root / "physical_manifest.json")
        if not manifest_path.is_file():
            raise FileNotFoundError(manifest_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        top = str(manifest.get("top", physical_root.name.removeprefix("sky130_")))
        _validate_physical_manifest(manifest, manifest_path, _safe_source(repo_root, physical_root))
        for name in PHYSICAL_ALLOWLIST:
            _add(
                items,
                repo_root=repo_root,
                source_relative=physical_root / name,
                destination=Path("physical") / top / name,
                category="physical",
                scope=top,
            )
        for name in PHYSICAL_OPTIONAL_ALLOWLIST:
            _add(
                items,
                repo_root=repo_root,
                source_relative=physical_root / name,
                destination=Path("physical") / top / name,
                category="physical-review",
                scope=top,
                required=False,
            )
        gds_name = manifest.get("artifacts", {}).get("gds")
        _add(
            items,
            repo_root=repo_root,
            source_relative=physical_root / str(gds_name),
            destination=Path("physical") / top / Path(str(gds_name)).name,
            category="gds",
            scope=top,
        )

    inventory = sorted(items.values())
    destinations = [item.destination for item in inventory]
    if len(destinations) != len(set(destinations)):
        raise ValueError("Submission inventory has duplicate destinations")
    return inventory
