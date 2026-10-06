import sys
import os

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import csv
import hashlib
import json
import platform
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict, Any
from model.config import SoCConfig, CLOCK_FREQ_ASIC_28NM_HZ, CLOCK_FREQ_FPGA_HZ, CLOCK_FREQ_SKYWATER_HZ
from model.soc_system_sim import SoCSystemSimulator

def run_benchmark_sweep() -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []

    fifo_depths = [4, 8, 16, 32, 64]
    mem_latencies = [0, 1, 2, 3, 5]
    transfer_sizes_bytes = [64, 256, 1024, 4096]
    frequencies = [
        ("ASIC_28nm_800MHz", CLOCK_FREQ_ASIC_28NM_HZ),
        ("FPGA_300MHz", CLOCK_FREQ_FPGA_HZ),
        ("SkyWater_150MHz", CLOCK_FREQ_SKYWATER_HZ)
    ]

    print("================================================================================")
    print("           STARTING SYSTEM-LEVEL ARCHITECTURAL BENCHMARK SWEEP                  ")
    print("================================================================================")

    # 1. Sweep FIFO Depth & Memory Latency @ 800 MHz (Transfer size = 1024 bytes)
    print("\n>>> SWEEP 1: FIFO Depth vs Memory Latency (Size = 1024 Bytes @ 800 MHz)")
    for depth in fifo_depths:
        for lat in mem_latencies:
            cfg = SoCConfig(
                clock_freq_hz=CLOCK_FREQ_ASIC_28NM_HZ,
                fifo_depth=depth,
                mem_read_latency_cycles=lat,
                mem_write_latency_cycles=lat
            )
            sim = SoCSystemSimulator(cfg)
            SRC = 0x0001_0000
            DST = 0x0002_0000
            BYTES = 1024

            payload = bytes([(i * 3 + 7) & 0xFF for i in range(BYTES)])
            sim.main_mem.load_bytes(SRC, payload)
            sim.configure_firewall_static_region(0, SRC, SRC + BYTES - 1, read_en=True, write_en=False)
            sim.configure_firewall_static_region(1, DST, DST + BYTES - 1, read_en=False, write_en=True)

            sim.dma.start_transfer(SRC, DST, BYTES)
            sim_res = sim.run_simulation(max_cycles=50000)

            # Verification check
            dst_data = sim.main_mem.read_bytes(DST, BYTES)
            verified = (dst_data == payload) and sim_res["completed"]

            bus_utilization = (sim_res["total_bytes_transferred"] / 4) / sim_res["total_cycles"] * 100.0 if sim_res["total_cycles"] > 0 else 0.0

            entry = {
                "test_category": "FIFO_Depth_Sweep",
                "target_platform": "ASIC_28nm",
                "clock_freq_mhz": cfg.clock_freq_hz / 1e6,
                "fifo_depth": depth,
                "mem_latency_cycles": lat,
                "transfer_bytes": BYTES,
                "total_cycles": sim_res["total_cycles"],
                "duration_ns": sim_res["duration_ns"],
                "throughput_gb_per_sec": sim_res["throughput_gb_per_sec"],
                "throughput_mb_per_sec": sim_res["throughput_mb_per_sec"],
                "bus_utilization_pct": bus_utilization,
                "peak_fifo_occupancy": sim_res["peak_fifo_occupancy"],
                "avg_fifo_occupancy": sim_res["avg_fifo_occupancy"],
                "fifo_full_stalls": sim_res["fifo_full_stall_cycles"],
                "fifo_empty_stalls": sim_res["fifo_empty_stall_cycles"],
                "data_integrity_pass": verified,
                "security_faults": sim_res["fault_count"]
            }
            results.append(entry)
            print(f"Depth={depth:2d} | Lat={lat} | Cycles={sim_res['total_cycles']:4d} | TP={sim_res['throughput_mb_per_sec']:7.1f} MB/s | BusUtil={bus_utilization:5.1f}% | PeakFIFO={sim_res['peak_fifo_occupancy']:2d} | StallFull={sim_res['fifo_full_stall_cycles']:3d}")

    # 2. Sweep Transfer Sizes (FIFO Depth = 32, Latency = 1)
    print("\n>>> SWEEP 2: Payload Transfer Size Scaling (FIFO=32, Lat=1)")
    for size in transfer_sizes_bytes:
        for plat_name, freq in frequencies:
            cfg = SoCConfig(clock_freq_hz=freq, fifo_depth=32, mem_read_latency_cycles=1, mem_write_latency_cycles=1)
            sim = SoCSystemSimulator(cfg)
            SRC = 0x0001_0000
            DST = 0x0002_0000
            payload = bytes([(i * 5 + 11) & 0xFF for i in range(size)])
            sim.main_mem.load_bytes(SRC, payload)
            sim.configure_firewall_static_region(0, SRC, SRC + size - 1, read_en=True, write_en=False)
            sim.configure_firewall_static_region(1, DST, DST + size - 1, read_en=False, write_en=True)

            sim.dma.start_transfer(SRC, DST, size)
            sim_res = sim.run_simulation(max_cycles=100000)
            dst_data = sim.main_mem.read_bytes(DST, size)
            verified = (dst_data == payload) and sim_res["completed"]
            bus_utilization = (sim_res["total_bytes_transferred"] / 4) / sim_res["total_cycles"] * 100.0

            entry = {
                "test_category": "Payload_Scaling",
                "target_platform": plat_name,
                "clock_freq_mhz": freq / 1e6,
                "fifo_depth": 32,
                "mem_latency_cycles": 1,
                "transfer_bytes": size,
                "total_cycles": sim_res["total_cycles"],
                "duration_ns": sim_res["duration_ns"],
                "throughput_gb_per_sec": sim_res["throughput_gb_per_sec"],
                "throughput_mb_per_sec": sim_res["throughput_mb_per_sec"],
                "bus_utilization_pct": bus_utilization,
                "peak_fifo_occupancy": sim_res["peak_fifo_occupancy"],
                "avg_fifo_occupancy": sim_res["avg_fifo_occupancy"],
                "fifo_full_stalls": sim_res["fifo_full_stall_cycles"],
                "fifo_empty_stalls": sim_res["fifo_empty_stall_cycles"],
                "data_integrity_pass": verified,
                "security_faults": sim_res["fault_count"]
            }
            results.append(entry)

    return results

def save_benchmark_results(results: List[Dict[str, Any]], out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, "benchmark_results.json")
    csv_path = os.path.join(out_dir, "benchmark_results.csv")
    metadata_path = os.path.join(out_dir, "benchmark_metadata.json")

    with open(json_path, "w", encoding="utf-8") as jf:
        json.dump(results, jf, indent=2, ensure_ascii=False)

    if results:
        headers = list(results[0].keys())
        with open(csv_path, "w", newline="", encoding="utf-8") as cf:
            writer = csv.DictWriter(cf, fieldnames=headers)
            writer.writeheader()
            writer.writerows(results)

    model_dir = Path(__file__).resolve().parent
    source_hashes = {
        path.name: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(model_dir.glob("*.py"))
    }
    output_hashes = {
        Path(path).name: hashlib.sha256(Path(path).read_bytes()).hexdigest()
        for path in (json_path, csv_path)
        if Path(path).exists()
    }
    metadata = {
        "schema_version": 1,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "generator": "model/run_benchmark.py",
        "reproduction_command": "python -B model/run_benchmark.py",
        "python_version": platform.python_version(),
        "python_implementation": platform.python_implementation(),
        "platform": platform.platform(),
        "record_count": len(results),
        "all_data_integrity_pass": all(
            bool(row.get("data_integrity_pass")) for row in results
        ),
        "source_sha256": source_hashes,
        "output_sha256": output_hashes,
    }
    with open(metadata_path, "w", encoding="utf-8") as mf:
        json.dump(metadata, mf, indent=2, ensure_ascii=False, sort_keys=True)
        mf.write("\n")

    print(f"\n[OK] Benchmark Results saved successfully:")
    print(f"  - JSON: {json_path}")
    print(f"  - CSV:  {csv_path}")
    print(f"  - Metadata: {metadata_path}")

if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(__file__), "..", "benchmark_data")
    res = run_benchmark_sweep()
    save_benchmark_results(res, out_dir)
