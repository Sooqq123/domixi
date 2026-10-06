#!/usr/bin/env python3
"""Build and refresh complete release evidence bundles with physical manifests."""

import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from evidence import inventory, make_report, verify_bundle, write_json
from physical import collect_physical


def assemble_bundle(source_sim_bundle: Path, manifest_path: Path, target_bundle: Path):
    print(f"\n=======================================================")
    print(f"Assembling complete bundle: {target_bundle.name}")
    print(f"  Simulation source: {source_sim_bundle}")
    print(f"  Physical manifest: {manifest_path}")
    print(f"=======================================================")
    
    if target_bundle.exists():
        shutil.rmtree(target_bundle)
    target_bundle.mkdir(parents=True, exist_ok=False)
    
    # 1. Copy simulations directory and simulation config
    if (source_sim_bundle / "simulation").exists():
        shutil.copytree(source_sim_bundle / "simulation", target_bundle / "simulation")
    if (source_sim_bundle / "simulation_config.json").exists():
        shutil.copy2(source_sim_bundle / "simulation_config.json", target_bundle / "simulation_config.json")
        
    # 2. Copy and collect physical collateral
    shutil.copy2(manifest_path, target_bundle / "physical_manifest.json")
    physical_dir = target_bundle / "physical"
    physical_data = collect_physical(manifest_path.resolve(), physical_dir)
    
    # 3. Read original summary and attach physical
    orig_summary = json.loads((source_sim_bundle / "summary.json").read_text(encoding="utf-8"))
    summary = dict(orig_summary)
    summary["physical"] = physical_data
    
    tests = summary.get("tests", [])
    complete_sim = tests and all(t["status"] == "PASS" for t in tests) and any(t["scope"] not in ("MOCK_INTEGRATION", "CPU_SMOKE") for t in tests)
    failed = any(t["status"] == "FAIL" for t in tests) or physical_data["status"] == "FAIL"
    summary["status"] = "FAIL" if failed else "EVIDENCE_COMPLETE_REVIEW_REQUIRED" if complete_sim and physical_data["status"] == "REPORTED_PASS" else "INCOMPLETE"
    
    # 4. Write summary, make_report, inventory
    write_json(target_bundle / "summary.json", summary)
    make_report(target_bundle, summary)
    inventory(target_bundle)
    
    # 5. Verify bundle
    errors = verify_bundle(target_bundle)
    if errors:
        print(f"FAILED to verify {target_bundle}:\n" + "\n".join(errors))
        sys.exit(1)
    print(f"SUCCESS: {target_bundle.name} verified cleanly with status: {summary['status']}!")
    return target_bundle


def refresh_bundle(bundle_dir: Path, manifest_path: Path):
    print(f"\n=======================================================")
    print(f"Refreshing existing bundle: {bundle_dir.name}")
    print(f"  Physical manifest: {manifest_path}")
    print(f"=======================================================")
    summary_path = bundle_dir / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    
    shutil.copy2(manifest_path, bundle_dir / "physical_manifest.json")
    physical_dir = bundle_dir / "physical"
    if physical_dir.exists():
        shutil.rmtree(physical_dir)
    physical_data = collect_physical(manifest_path.resolve(), physical_dir)
    summary["physical"] = physical_data
    
    tests = summary.get("tests", [])
    complete_sim = tests and all(t["status"] == "PASS" for t in tests) and any(t["scope"] not in ("MOCK_INTEGRATION", "CPU_SMOKE") for t in tests)
    failed = any(t["status"] == "FAIL" for t in tests) or physical_data["status"] == "FAIL"
    summary["status"] = "FAIL" if failed else "EVIDENCE_COMPLETE_REVIEW_REQUIRED" if complete_sim and physical_data["status"] == "REPORTED_PASS" else "INCOMPLETE"
    
    write_json(summary_path, summary)
    make_report(bundle_dir, summary)
    inventory(bundle_dir)
    
    errors = verify_bundle(bundle_dir)
    if errors:
        print(f"FAILED to verify {bundle_dir}:\n" + "\n".join(errors))
        sys.exit(1)
    print(f"SUCCESS: {bundle_dir.name} verified cleanly with status: {summary['status']}!")


def main():
    root = HERE.parent.parent
    fresh_sim = root / "output" / "evidence" / "verification_20260920_01"
    fw_manifest = root / "output" / "physical" / "sky130_dma_bus_firewall" / "physical_manifest.json"
    soc_manifest = root / "output" / "physical" / "sky130_aegis_soc_top" / "physical_manifest.json"
    
    # 1. Build complete fresh bundles from verification_20260920_01
    b_fw_fresh = root / "output" / "evidence" / "release_signoff_bundle_20260920_firewall"
    assemble_bundle(fresh_sim, fw_manifest, b_fw_fresh)
    
    b_soc_fresh = root / "output" / "evidence" / "release_signoff_bundle_20260920_soc"
    assemble_bundle(fresh_sim, soc_manifest, b_soc_fresh)
    
    # 2. Also refresh the existing release bundles so all manifests & hashes stay perfectly in sync
    b1_existing = root / "output" / "evidence" / "release_signoff_bundle_20260919_02"
    refresh_bundle(b1_existing, fw_manifest)
    
    b2_existing = root / "output" / "evidence" / "release_signoff_bundle_soc_20260919_01"
    refresh_bundle(b2_existing, soc_manifest)
    
    print("\nAll evidence bundles assembled, refreshed, and verified successfully!")


if __name__ == "__main__":
    main()
