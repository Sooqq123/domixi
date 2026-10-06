import json
import shutil
import sys
from pathlib import Path

# Add tools/evidence to path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from evidence import inventory, make_report, verify_bundle, write_json
from physical import collect_physical

def refresh(bundle_dir: Path, manifest_path: Path):
    print(f"Refreshing bundle: {bundle_dir} with manifest {manifest_path}")
    # 1. Read existing summary.json
    summary_path = bundle_dir / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    
    # 2. Re-collect physical
    shutil.copy2(manifest_path, bundle_dir / "physical_manifest.json")
    physical_dir = bundle_dir / "physical"
    if physical_dir.exists():
        shutil.rmtree(physical_dir)
    physical_data = collect_physical(manifest_path.resolve(), physical_dir)
    summary["physical"] = physical_data
    
    # 3. Write summary, make_report, and inventory
    write_json(summary_path, summary)
    make_report(bundle_dir, summary)
    inventory(bundle_dir)
    
    # 4. Verify bundle
    errors = verify_bundle(bundle_dir)
    if errors:
        print(f"FAILED to verify {bundle_dir}:\n" + "\n".join(errors))
        sys.exit(1)
    print(f"SUCCESS: {bundle_dir} verified clean with SDF included!")

if __name__ == "__main__":
    root = HERE.parent.parent
    b1 = root / "output" / "evidence" / "release_signoff_bundle_20260919_02"
    m1 = root / "output" / "physical" / "sky130_dma_bus_firewall" / "physical_manifest.json"
    refresh(b1, m1)

    b2 = root / "output" / "evidence" / "release_signoff_bundle_soc_20260919_01"
    m2 = root / "output" / "physical" / "sky130_aegis_soc_top" / "physical_manifest.json"
    refresh(b2, m2)
