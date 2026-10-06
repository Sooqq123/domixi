# FIFO Depth 32 Canonicalization Implementation Plan

> **Status: Historical — completed decision absorbed into Canonical Architecture Baseline V2.4.1.** Retained for traceability only; checked-in benchmark artifacts must follow the V2.4.1 evidence manifest.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the DMA RTL and system-model defaults with the architecture SSOT's 32-word FIFO configuration.

**Architecture:** Keep FIFO capacity fixed at 32 words in the canonical runtime paths. Represent FIFO occupancy and free space with six bits so the valid count range `0..32` is preserved. Leave the benchmark sweep and checked-in historical results unchanged; only its payload-scaling baseline changes to 32.

**Tech Stack:** Verilog, Python standard library `unittest`, Icarus Verilog.

**Spec:** `docs/superpowers/specs/2026-08-19-fifo-depth-32-canonicalization-design.md`

## Global Constraints

- Canonical FIFO depth is exactly 32 words (128 bytes).
- FIFO count and free-space signals must represent every integer from 0 through 32.
- Do not alter AXI behavior, burst sizing, firewall behavior, FIFO sweep points, or historical benchmark artifacts.
- Keep edits limited to the default/runtime configuration and its existing tests.

---

### Task 1: Make the model default testable and set it to 32

**Files:**
- Modify: `DMA-controller/model/config.py:45`
- Modify: `DMA-controller/model/test_unit.py:15`

**Interfaces:**
- Consumes: `SoCConfig` from `model.config`.
- Produces: `SoCConfig().fifo_depth == 32` for all model callers that do not override the field.

- [ ] **Step 1: Add a failing model-default test**

Add this test to `TestUnitComponents`:

```python
def test_default_fifo_depth_matches_architecture(self):
    self.assertEqual(SoCConfig().fifo_depth, 32)
```

- [ ] **Step 2: Run the new test and verify the current failure**

Run:

```powershell
python -m unittest model.test_unit.TestUnitComponents.test_default_fifo_depth_matches_architecture
```

Expected: failure because the current default is `16`.

- [ ] **Step 3: Change the model default**

Change the dataclass field to:

```python
fifo_depth: int = 32
```

- [ ] **Step 4: Run the model unit suite**

Run:

```powershell
python -m unittest model.test_unit
```

Expected: all unit tests pass, including the default-depth assertion.

- [ ] **Step 5: Commit the model-default change**

```powershell
git add -- DMA-controller/model/config.py DMA-controller/model/test_unit.py
git commit -m "fix: default model FIFO depth to 32"
```

### Task 2: Align FIFO RTL capacity and count widths

**Files:**
- Modify: `DMA-controller/rtl/dma_fifo_latch.v:2-3`
- Modify: `DMA-controller/rtl/dma_axi_master.v:2,20,93`
- Modify: `DMA-controller/rtl/dma_controller.v:59,68,76`
- Modify: `DMA-controller/tb/tb_dma_fifo_latch.v:6,21-23`

**Interfaces:**
- Consumes: a 32-word FIFO whose occupancy is a six-bit unsigned count.
- Produces: a six-bit `fifo_count` connection and six-bit `fifo_free` calculation that preserve 32 instead of truncating it to zero.

- [ ] **Step 1: Make the FIFO testbench exercise the module default**

Replace the testbench parameter with a fixed localparam and instantiate the FIFO without a depth override:

```verilog
localparam DEPTH = 32;

dma_fifo_latch u_fifo (
```

This makes the existing fill-to-full and drain-to-empty loops verify the 32-word module default.

- [ ] **Step 2: Compile and run the unchanged RTL implementation to establish the pre-change failure**

Run from `DMA-controller`:

```powershell
$out = Join-Path $env:TEMP 'domixi-fifo32-prechange.vvp'
iverilog -g2012 -o $out rtl/dma_fifo_latch.v tb/tb_dma_fifo_latch.v
vvp $out
```

Expected: the test reports that FIFO does not become full after 32 writes because the current module default remains 16.

- [ ] **Step 3: Apply the minimal RTL width and depth changes**

Make these changes:

```verilog
// dma_fifo_latch.v
parameter DEPTH     = 32,
parameter PTR_WIDTH = 5

// dma_axi_master.v
parameter FIFO_DEPTH = 32,
input  wire [5:0] fifo_count,
wire   [5:0] fifo_free = FIFO_DEPTH - fifo_count;

// dma_controller.v
wire [5:0] fifo_count;
dma_fifo_latch #(.DEPTH(32)) u_fifo (...);
dma_axi_master #(.FIFO_DEPTH(32), .ID_WIDTH(ID_WIDTH)) u_master (...);
```

Do not modify read/write burst length or AXI signaling.

- [ ] **Step 4: Compile and run both RTL testbenches**

Run from `DMA-controller`:

```powershell
$fifoOut = Join-Path $env:TEMP 'domixi-fifo32.vvp'
iverilog -g2012 -o $fifoOut rtl/dma_fifo_latch.v tb/tb_dma_fifo_latch.v
vvp $fifoOut

$dmaOut = Join-Path $env:TEMP 'domixi-dma32.vvp'
iverilog -g2012 -o $dmaOut rtl/dma_apb_slave.v rtl/dma_fifo_latch.v rtl/dma_axi_master.v rtl/dma_controller.v tb/tb_dma_controller.v
vvp $dmaOut
```

Expected: FIFO reports full after 32 writes and empty after 32 reads; DMA controller copies the 64-byte test payload and asserts its IRQ.

- [ ] **Step 5: Commit the RTL change**

```powershell
git add -- DMA-controller/rtl/dma_fifo_latch.v DMA-controller/rtl/dma_axi_master.v DMA-controller/rtl/dma_controller.v DMA-controller/tb/tb_dma_fifo_latch.v
git commit -m "fix: use canonical 32-word DMA FIFO"
```

### Task 3: Align the payload-scaling benchmark baseline

**Files:**
- Modify: `DMA-controller/model/run_benchmark.py:82-105`

**Interfaces:**
- Consumes: `SoCConfig(fifo_depth=32, ...)` for payload scaling.
- Produces: `Payload_Scaling` records labelled with `fifo_depth: 32` when the benchmark is run in the future.

- [ ] **Step 1: Run the benchmark sweep without saving artifacts and verify the current payload baseline**

Run:

```powershell
python -c "from model.run_benchmark import run_benchmark_sweep; rows = run_benchmark_sweep(); assert {row['fifo_depth'] for row in rows if row['test_category'] == 'Payload_Scaling'} == {16}"
```

Expected: the assertion passes because the current payload-scaling records are labelled with `fifo_depth` equal to `16`. This calls `run_benchmark_sweep()` directly and does not overwrite `benchmark_data/`.

- [ ] **Step 2: Use the canonical baseline**

Replace both payload-scaling occurrences of `16` with `32`, including the printed label and emitted `fifo_depth` field:

```python
print("\n>>> SWEEP 2: Payload Transfer Size Scaling (FIFO=32, Lat=1)")
cfg = SoCConfig(clock_freq_hz=freq, fifo_depth=32, mem_read_latency_cycles=1, mem_write_latency_cycles=1)
"fifo_depth": 32,
```

- [ ] **Step 3: Run model verification without modifying historical artifacts**

Run:

```powershell
python -m unittest model.test_unit model.test_integration
python -c "from model.run_benchmark import run_benchmark_sweep; rows = run_benchmark_sweep(); assert {row['fifo_depth'] for row in rows if row['test_category'] == 'Payload_Scaling'} == {32}"
rg -n "fifo_depth\s*=\s*16|FIFO_DEPTH\(16\)|\.DEPTH\(16\)" rtl model tb --glob '!*.vvp' --glob '!*.vcd'
```

Expected: all 10 model tests pass; the search finds no remaining canonical runtime default or instantiation set to 16. Values of 16 retained exclusively in FIFO sweep lists or explanatory comments are acceptable.

- [ ] **Step 4: Commit the benchmark-baseline change**

```powershell
git add -- DMA-controller/model/run_benchmark.py
git commit -m "fix: benchmark canonical FIFO depth"
```

### Task 4: Verify the complete change set

**Files:**
- Verify: `DMA-controller/rtl/dma_fifo_latch.v`
- Verify: `DMA-controller/rtl/dma_axi_master.v`
- Verify: `DMA-controller/rtl/dma_controller.v`
- Verify: `DMA-controller/model/config.py`
- Verify: `DMA-controller/model/run_benchmark.py`

**Interfaces:**
- Consumes: the model and RTL changes from Tasks 1–3.
- Produces: one verified canonical 32-word FIFO baseline.

- [ ] **Step 1: Check the diff contains only the planned files**

Run:

```powershell
git diff --check HEAD~3..HEAD
git show --stat --oneline HEAD~3..HEAD
```

Expected: no whitespace errors and only the model, RTL, testbench, and benchmark files named by this plan.

- [ ] **Step 2: Rerun the full prescribed test set**

Run:

```powershell
python -m unittest model.test_unit model.test_integration
```

Expected: all 10 tests pass.

- [ ] **Step 3: Record completion**

Report the FIFO configuration, test outcomes, and any test limitation without changing architecture documents or benchmark history.
