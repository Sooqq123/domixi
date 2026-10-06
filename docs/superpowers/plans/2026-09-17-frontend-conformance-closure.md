# AEGIS-RISC Frontend Conformance Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining RTL frontend verification gaps in Section 12.2 of the Sky130 architecture specification before starting backend implementation.

**Architecture:** Add small formal harnesses at the protocol boundaries instead of changing product RTL solely to make proofs easier. The harnesses will verify address-slice snapshot stability, data-path isolation and output stability, drain/Honey-Pot response stability, MTD bounds, closed-loop ownership, and the HDC 49-cycle latency contract.

**Tech Stack:** Verilog-2001 RTL, Yosys, SymbiYosys, Z3, Verilator, Icarus Verilog, Python regression scripts.

**Spec:** `docs/AEGIS_RISC_ARCHITECTURE_SPECIFICATION.md`

## Global Constraints

- Target technology is Sky130A with `sky130_fd_sc_hd`; FPGA primitives and FPGA PPA evidence are out of scope.
- Functional clock is 40 MHz with a 25 ns period.
- Safe AXI traffic must not depend on HDC completion or analysis-queue state.
- Honeypot and drain paths must never forward a transaction to protected memory.
- AXI valid payloads must remain stable while valid is asserted and ready is low.
- Formal reports must state the bound and the assumptions used by each harness.
- No product RTL behavior may be changed merely to silence a formal warning.

---

### Task 1: Prove address-slice and data-path protocol contracts

**Files:**
- Create: `formal/fw_axi_contract_formal.v`
- Create: `formal/fw_axi_contract.sby`
- Modify: `tools/verify_formal.ps1`

**Interfaces:**
- Consumes: `rtl/fw_axi_address_slice.v` and `rtl/fw_data_path_mux.v`.
- Produces: bounded formal proof of snapshot stability, owner isolation, read/write independence, and output stability under backpressure.

- [ ] **Step 1: Instantiate the address slice and data-path mux with unconstrained legal channel inputs.**

- [ ] **Step 2: Assume reset is asserted for the first two cycles and then remains deasserted.**

- [ ] **Step 3: Assert that every AW and AR snapshot field is stable while its valid is high and downstream ready is low.**

- [ ] **Step 4: Assert that DRAIN and HONEYPOT owners never drive the protected-memory write/read channels, and that each owner selects only its own response source.**

- [ ] **Step 5: Assert that valid response payloads remain stable while the upstream ready is low, using source-hold assumptions required by AXI.**

- [ ] **Step 6: Add the suite to `verify_formal.ps1` and run it with `sby -f formal/fw_axi_contract.sby`.**

Expected result: the suite passes with no counterexample at BMC depth 20 and its log records reset and backpressure assumptions.

### Task 2: Prove Honey-Pot and drain stream contracts

**Files:**
- Create: `formal/fw_stream_contract_formal.v`
- Create: `formal/fw_stream_contract.sby`
- Modify: `tools/verify_formal.ps1`

**Interfaces:**
- Consumes: `rtl/fw_honeypot_sink.v`, `rtl/fw_write_drain.v`, and `rtl/fw_read_drain.v`.
- Produces: bounded formal proof of beat counts, response stability, WLAST/RLAST behavior, and no protected-memory output path.

- [ ] **Step 1: Instantiate the three stream blocks with independent write and read stimuli.**

- [ ] **Step 2: Assume reset shape and hold `ready` low for arbitrary legal backpressure windows.**

- [ ] **Step 3: Assert B-channel ID/response stability while BVALID is high and BREADY is low.**

- [ ] **Step 4: Assert R-channel ID/data/response/LAST stability while RVALID is high and RREADY is low.**

- [ ] **Step 5: Assert that a burst with length N emits exactly N+1 accepted beats and terminates on the final beat.**

- [ ] **Step 6: Assert that Honey-Pot and drain blocks expose no memory-master interface and therefore cannot forward payloads to protected memory.**

- [ ] **Step 7: Add the suite to `verify_formal.ps1` and run it with `sby -f formal/fw_stream_contract.sby`.**

Expected result: the suite passes at BMC depth 20 with all backpressure assumptions listed in the formal report.

### Task 3: Close MTD, HDC, score, quarantine, and FIFO properties

**Files:**
- Modify: `formal/fw_mtd_formal.v`
- Modify: `formal/fw_hdc_formal.v`
- Modify: `formal/fw_closed_formal.v`
- Modify: `formal/fw_hdc.sby`

**Interfaces:**
- Consumes: existing MTD, HDC, and closed-loop formal harnesses.
- Produces: proofs for token/shape bounds, HDC completion within 49 cycles, score saturation, quarantine ownership, and FIFO no-overwrite/order invariants.

- [ ] **Step 1: Add hierarchical assertions for MTD `token_count`, `shape_timer`, and `jitter_run` bounds.**

- [ ] **Step 2: Add a 6-bit HDC age tracker that starts at snapshot dequeue and asserts decision state is reached by cycle 49.**

- [ ] **Step 3: Assert every per-MID score is at most 15 and that an event for MID A does not set quarantine for MID B.**

- [ ] **Step 4: Assert FIFO count remains in 0..4, a full FIFO does not overwrite an existing head record, and FIFO pop advances only the read pointer.**

- [ ] **Step 5: Preserve all existing reset and environment assumptions and document their exact scope.**

- [ ] **Step 6: Run the updated suites and investigate any counterexample before changing RTL.**

Expected result: existing suites remain passing and the new properties appear as named assertions in the generated formal logs.

### Task 4: Publish frontend conformance evidence and rerun all gates

**Files:**
- Create: `output/rtl_acceptance_20260917_01/FORMAL_CONFORMANCE.md`
- Modify: `output/rtl_acceptance_20260917_01/RTL_ACCEPTANCE_REPORT.md`

**Interfaces:**
- Consumes: all formal, simulation, lint, and synthesis logs from the current source manifest.
- Produces: a traceable frontend conformance matrix with explicit PASS, limitation, bound, and assumption fields.

- [ ] **Step 1: Run both Verilator lint tops and record error/warning counts.**

- [ ] **Step 2: Run the complete Icarus regression and record the exact pass/fail total.**

- [ ] **Step 3: Run all SymbiYosys suites and record every suite, mode, bound, and assumption.**

- [ ] **Step 4: Run the Yosys frontend script and record errors separately from informational warnings.**

- [ ] **Step 5: Update the acceptance report so no old warning count or unresolved frontend gap remains.**

- [ ] **Step 6: Run `codegraph sync D:\domixi` after all source and evidence edits.**

Expected result: frontend status is `RTL_CONFORMANT`; backend remains a separate next phase and no PPA or physical signoff claim is made.
