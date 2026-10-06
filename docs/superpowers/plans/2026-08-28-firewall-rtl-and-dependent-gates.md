# Firewall RTL and Dependent Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the DMA AXI firewall exactly to the V2.4.1 canonical contract and close every dependent verification gate without claiming closure where a required tool, target library, or SoC-level trust source is unavailable.

**Architecture:** Build seven synthesizable Verilog-2001 modules in dependency order. AW and AR each enter a one-entry elastic address slice; a transaction decision is captured once from an effective policy view and remains immutable. Allowed traffic is forwarded through the data-path mux. Denied traffic is terminated locally by exact-length read/write drain logic. APB registers and the DMA context tracker feed the policy view with the documented same-cycle priority.

**Tech Stack:** Verilog-2001 RTL, SystemVerilog assertions where supported, Icarus Verilog 12.0 for immediate simulation, Verilator/Yosys/SymbiYosys/OpenSTA for later lint/formal/synthesis gates when installed, PowerShell regression scripts, CSV/Markdown SSOT under `DMA-controller/docs/architecture`.

**Spec:** `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`

## Global Constraints

- The canonical release is V2.4.1 and the Firewall RTL is currently missing.
- Do not modify or infer the DMA's fixed AXI profile: `AxID=0`, `AxPROT=3'b001`, `AxSIZE=3'b010`, `AxBURST=INCR`, `AxLEN<=15`, and 32-bit alignment.
- Reject profile violations, arithmetic overflow, and 4-KiB boundary crossing even when `FW_EN=0`.
- Use one clock, `clk`, and active-low reset with asynchronous assertion and synchronous deassertion.
- Permit at most one outstanding write transaction and one outstanding read transaction.
- Once an address handshake is accepted, latch the transaction descriptor and decision result; later APB or context updates must not change that transaction.
- Never expose denied addresses or denied write data on the downstream AXI master interface.
- A denied write consumes exactly `AWLEN+1` W beats and then returns one local B response with the accepted AWID.
- A denied read returns exactly `ARLEN+1` local R beats, with RLAST only on the final beat and RID equal to the accepted ARID.
- Preserve payload stability whenever VALID is high and READY is low.
- Apply same-cycle policy priority exactly as `dma_ctx_done > accepted one-shot context > accepted APB write > existing ACL state`.
- Keep matrix-side `AxCACHE`, `AxLOCK`, `AxQOS`, and `AxREGION` tied to zero.
- Do not claim G4, G5, G6, or G7 closed without their named evidence artifacts.

## Current Baseline

- No Firewall `.v` or `.sv` source exists under `DMA-controller/rtl`.
- `spec_lint.py` currently fails only because REQ_FW_01, REQ_FW_02, and REQ_FW_13 still reference the deleted `fw_axi_address_slice.v` draft.
- The traceability and evidence CSV files still describe a partial draft and must be reconciled when the first real RTL source is introduced.
- Icarus Verilog 12.0 is available. Verilator, Yosys, SymbiYosys, and a characterized implementation library are not currently established as available.
- The canonical internal signal list has 4-KiB error flags but lacks explicit profile-error and address-overflow flags. Stage 1 requires those flags, so the SSOT must add them before the module interface is frozen.

## Gate Dependency Model

| Gate | Exit condition | Depends on | Evidence |
|---|---|---|---|
| G0 — SSOT consistency | Spec lint passes and internal interfaces express every required decision input | Canonical docs only | `spec_lint.py` log and reviewed diff |
| G1 — Per-module compile | Every RTL module and unit test elaborates without warnings treated as errors | G0, relevant module source | Icarus/Verilator logs |
| G2 — Unit behavior | Every module's self-checking testbench reports PASS | G1 | Unit simulation logs |
| G3 — Firewall integration | Directed and randomized top-level cases pass with no protocol deadlock | All seven modules, G2 | Top-level regression log and seed list |
| G4 — Security properties | Required SVA/formal properties prove or pass bounded checks | G3, formal tool | `.sby`/assertion reports |
| G5 — Coverage | Requirement, functional, assertion, and code coverage meet approved thresholds | G3/G4, coverage tool | Coverage report and waiver list |
| G6 — Implementation feasibility | Synthesizes cleanly and meets the selected timing/area target | G3, target library/FPGA | Synthesis, STA, and utilization reports |
| G7 — SoC trust closure | DMA provenance and end-to-end integration assumptions are verified at SoC level | G3–G6 plus SoC integration | SoC simulation/formal evidence |

## Build Order

```text
fw_axi_address_slice ─┐
fw_context_tracker ───┼─> fw_acl_matcher ─┐
fw_apb_regs ──────────┘                   ├─> fw_data_path_mux ─> dma_bus_firewall
fw_drain_fsm ─────────────────────────────┘
```

The matcher consumes a latched address descriptor and the effective policy view. The top level latches `allow`, `fault_code`, `err_mode`, ID, LEN, and direction when a transaction enters the ownership slot; it never re-evaluates an active transaction against live registers.

---

### Task 0: Reconcile the pre-RTL SSOT and freeze internal interfaces

**Files:**
- Modify: `DMA-controller/docs/architecture/signal_list.csv`
- Modify: `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- Modify: `DMA-controller/docs/architecture/requirements_traceability.csv`
- Verify: `DMA-controller/docs/architecture/tools/spec_lint.py`

- [ ] Add `pipe_s1_aw_profile_err`, `pipe_s1_aw_overflow_err`, `pipe_s1_ar_profile_err`, and `pipe_s1_ar_overflow_err` as one-bit Stage-1 outputs in `signal_list.csv`.
- [ ] State in the integration contract that `profile_err` covers ID/PROT/SIZE/BURST/LEN/alignment mismatch, while `overflow_err` denotes the 33rd address bit after last-byte calculation.
- [ ] Change the three stale traceability rows from “partial draft exists” to “RTL missing; implementation planned” without altering requirement text or verification mapping.
- [ ] Run the spec linter and retain the baseline failure only until Task 1 introduces the real address-slice source.

Command:

```powershell
Set-Location D:\domixi
python -B DMA-controller\docs\architecture\tools\spec_lint.py
```

Expected result after Task 0 alone: the only allowed failures are the three missing-source references. Any CSV schema, cross-reference, register-map, pinout, or contradiction error blocks RTL work.

- [ ] Commit the interface decision.

```powershell
git add DMA-controller/docs/architecture/signal_list.csv DMA-controller/docs/architecture/firewall_rtl_integration_contract.md DMA-controller/docs/architecture/requirements_traceability.csv
git commit -m "docs: freeze firewall stage1 error flags"
```

### Task 1: Build `fw_axi_address_slice` test-first

**Files:**
- Create: `DMA-controller/tb/tb_fw_axi_address_slice.v`
- Create: `DMA-controller/rtl/fw_axi_address_slice.v`
- Modify: `DMA-controller/docs/architecture/requirements_traceability.csv`

- [ ] Write a self-checking unit test with independent AW and AR channels.
- [ ] Check reset: both output-valid signals remain zero until synchronous reset release.
- [ ] Check a legal single-beat address and a legal 16-beat address.
- [ ] Check every profile failure independently: ID, PROT, SIZE, BURST, LEN, and alignment.
- [ ] Check the exact last-byte formula using at least these vectors:

```text
addr=0x00000FFC len=0  size=2 -> last=0x00000FFF, no 4K error
addr=0x00000FFC len=1  size=2 -> last=0x00001003, 4K error
addr=0xFFFFFFFC len=0  size=2 -> last=0xFFFFFFFF, no overflow
addr=0xFFFFFFFC len=1  size=2 -> extended overflow set
```

- [ ] Check one-entry backpressure: input READY deasserts while the stored record is valid and not consumed.
- [ ] Check payload stability for every stored field while output VALID is stalled.
- [ ] Check simultaneous AW and AR acceptance to prove channel independence.
- [ ] Run the test before RTL exists and record the expected compile failure.

The implementation must calculate with extended widths:

```verilog
wire [8:0] beats          = {1'b0, s_axlen} + 9'd1;
wire [15:0] span_bytes    = {7'd0, beats} << s_axsize;
wire [32:0] last_byte_ext = {1'b0, s_axaddr} + {17'd0, span_bytes} - 33'd1;

wire profile_err = (s_axid    != 4'd0)     ||
                   (s_axprot  != 3'b001)   ||
                   (s_axsize  != 3'b010)   ||
                   (s_axburst != 2'b01)    ||
                   (s_axlen   >  8'd15)    ||
                   (s_axaddr[1:0] != 2'b00);
wire overflow_err = last_byte_ext[32];
wire boundary_err = overflow_err ||
                    (s_axaddr[31:12] != last_byte_ext[31:12]);
```

- [ ] Implement each channel as a one-entry elastic register: `s_ready = !valid_q || m_ready`; load on `s_valid && s_ready`; clear on `m_valid && m_ready` when no replacement arrives.
- [ ] Latch address, ID, LEN, SIZE, BURST, PROT, last byte, profile error, overflow error, and boundary error on the input handshake.
- [ ] Do not latch or reference live ACL permissions in this module.
- [ ] Compile and run:

```powershell
Set-Location D:\domixi\DMA-controller
iverilog -g2012 -Wall -s tb_fw_axi_address_slice -o build\tb_fw_axi_address_slice.vvp rtl\fw_axi_address_slice.v tb\tb_fw_axi_address_slice.v
vvp build\tb_fw_axi_address_slice.vvp
```

Expected result: `PASS: tb_fw_axi_address_slice`, zero `$error`, and no width-truncation warning.

- [ ] Update REQ_FW_01, REQ_FW_02, and REQ_FW_13 to reference the real source and unit test; rerun `spec_lint.py` until G0 and G1 pass.
- [ ] Commit the module and test.

```powershell
git add DMA-controller/rtl/fw_axi_address_slice.v DMA-controller/tb/tb_fw_axi_address_slice.v DMA-controller/docs/architecture/requirements_traceability.csv
git commit -m "rtl: add firewall AXI address slice"
```

### Task 2: Build `fw_context_tracker`

**Files:**
- Create: `DMA-controller/tb/tb_fw_context_tracker.v`
- Create: `DMA-controller/rtl/fw_context_tracker.v`

- [ ] Test reset values, accepted one-cycle context updates, invalid ranges, regions 4/5 dynamic outputs, and `dma_ctx_done` clearing behavior.
- [ ] Test all same-cycle priority combinations, especially done versus new valid context.
- [ ] Implement the priority synchronously and export a combinational effective view for a transaction accepted on the same edge.
- [ ] Require `start <= end`; invalid context ranges must not activate a region and must create the specified fault event.
- [ ] Run the unit test and require `PASS: tb_fw_context_tracker`.
- [ ] Commit as `rtl: add firewall DMA context tracker`.

### Task 3: Build `fw_apb_regs`

**Files:**
- Create: `DMA-controller/tb/tb_fw_apb_regs.v`
- Create: `DMA-controller/rtl/fw_apb_regs.v`

- [ ] Test the complete register map from `0x000` through region 7, including reset values, read-only fields, W1C, RW1S lock, reserved bits, and invalid addresses.
- [ ] Test the security profile: only privileged secure APB accesses may change protected state; invalid or forbidden accesses assert PSLVERR.
- [ ] Test region activation guard (`START <= END`) and region 4/5 read-only behavior.
- [ ] Test first-fault capture, count saturation/rollover semantics from the SSOT, simultaneous fault priority, and IRQ sticky/W1C behavior.
- [ ] Keep PREADY asserted as required; produce a single accepted-write pulse and decoded write data for the top-level priority network.
- [ ] Run the unit test and require `PASS: tb_fw_apb_regs`.
- [ ] Commit as `rtl: add firewall APB register bank`.

### Task 4: Build `fw_acl_matcher`

**Files:**
- Create: `DMA-controller/tb/tb_fw_acl_matcher.v`
- Create: `DMA-controller/rtl/fw_acl_matcher.v`

- [ ] Test full-burst containment using the latched first and last byte, never only the first address.
- [ ] Test allow, deny, disabled regions, read/write permissions, source ID, context regions 4/5, overlapping regions, and the documented region priority.
- [ ] Test that `FW_EN=0` bypasses only ACL permission and does not bypass profile, overflow, boundary, or framing checks.
- [ ] Test fault-code priority when several violations are true on the same transaction.
- [ ] Implement a pure combinational decision from a latched descriptor plus the effective policy view.
- [ ] Latch the decision in the transaction owner outside this matcher; do not let the matcher observe live state after acceptance.
- [ ] Run the unit test and require `PASS: tb_fw_acl_matcher`.
- [ ] Commit as `rtl: add firewall ACL matcher`.

### Task 5: Build `fw_drain_fsm`

**Files:**
- Create: `DMA-controller/tb/tb_fw_drain_fsm.v`
- Create: `DMA-controller/rtl/fw_drain_fsm.v`

- [ ] Test denied writes for lengths 0 and 15 with random WVALID gaps and BREADY stalls.
- [ ] Detect early, missing, and late WLAST according to the canonical framing policy; never terminate before exactly `AWLEN+1` accepted W beats.
- [ ] Return one B response only after the final required W beat; hold BID/BRESP/BVALID stable under stall.
- [ ] Test denied reads for lengths 0 and 15 with random RREADY stalls; return zero data, the configured error response, stable RID, and exact RLAST position.
- [ ] Test illegal-state recovery to the fail-secure state specified by the FSM document.
- [ ] Run the unit test and require `PASS: tb_fw_drain_fsm`.
- [ ] Commit as `rtl: add firewall denied-transaction drain FSM`.

### Task 6: Build `fw_data_path_mux`

**Files:**
- Create: `DMA-controller/tb/tb_fw_data_path_mux.v`
- Create: `DMA-controller/rtl/fw_data_path_mux.v`

- [ ] Test allowed AW/W/B and AR/R forwarding with independent backpressure.
- [ ] Test denied traffic isolation: downstream AWVALID, ARVALID, and WVALID must remain low for locally terminated transactions.
- [ ] Test response ownership so local and downstream B/R sources can never drive the upstream interface simultaneously.
- [ ] Tie downstream cache/lock/qos/region sidebands to zero and verify the tie-offs in simulation.
- [ ] Run the unit test and require `PASS: tb_fw_data_path_mux`.
- [ ] Commit as `rtl: add firewall AXI data path mux`.

### Task 7: Integrate `dma_bus_firewall`

**Files:**
- Create: `DMA-controller/tb/tb_dma_bus_firewall.v`
- Create: `DMA-controller/rtl/dma_bus_firewall.v`

- [ ] Instantiate all six leaf modules and expose exactly the canonical pinout.
- [ ] Implement one write-owner slot and one read-owner slot; capture descriptor, allow/deny, response mode, ID, LEN, and fault metadata atomically.
- [ ] Implement the effective same-cycle policy view with the required context/APB/ACL priority.
- [ ] Block a second address on a channel until the active transaction reaches its terminal handshake.
- [ ] Generate fault events once per accepted violating transaction, with deterministic simultaneous-fault priority.
- [ ] Verify fail-secure reset: no downstream VALID and no upstream READY/VALID outputs until synchronous reset release.
- [ ] Run directed tests for every requirement-mapped Firewall test ID and require `PASS: tb_dma_bus_firewall`.
- [ ] Commit as `rtl: integrate DMA AXI firewall`.

### Task 8: Close the subsystem integration regression

**Files:**
- Create: `DMA-controller/tb/tb_soc_dma_firewall_top.v`
- Create: `DMA-controller/scripts/run_firewall_regression.ps1`
- Modify: `DMA-controller/docs/architecture/verification_test_plan.md`

- [ ] Connect the existing DMA master to the Firewall upstream port and a protocol-checking memory model to the downstream port.
- [ ] Add directed tests for all listed Firewall cases, including snapshot stall, same-cycle revoke, W-before-AW, response-ID mismatch, mid-burst abort, backpressure, start-while-busy, and deadlock stress.
- [ ] Add reproducible randomized seeds for AW/W skew, B/R stalls, APB writes, context updates, and reset interruption.
- [ ] Make the regression script stop on first compile failure and return nonzero if any test lacks an explicit PASS marker.
- [ ] Require G3 evidence to include the exact source list, simulator version, seed list, and log hash.
- [ ] Commit as `verify: add DMA firewall integration regression`.

### Task 9: Add assertions and formal checks

**Files:**
- Create: `DMA-controller/formal/fw_axi_address_slice_properties.sv`
- Create: `DMA-controller/formal/fw_drain_properties.sv`
- Create: `DMA-controller/formal/fw_security_properties.sv`
- Create: `DMA-controller/formal/firewall.sby`

- [ ] Encode every named property from the verification plan, including stable AXI payload, denied-address isolation, exact drain completion, stable IDs, no early B, APB error response, sticky lock, and synchronous revocation.
- [ ] Bind assertions without changing synthesizable behavior.
- [ ] Run bounded proofs after SymbiYosys/Yosys are installed or through an approved CI environment.
- [ ] Mark G4 `BLOCKED_TOOLING`, not PASS, if no formal engine is available.
- [ ] Commit as `formal: add firewall security properties`.

### Task 10: Close coverage

**Files:**
- Create: `DMA-controller/tb/fw_coverage.sv`
- Modify: `DMA-controller/docs/architecture/verification_evidence_manifest.csv`

- [ ] Cover every requirement-to-test mapping, each ACL region and permission result, every fault code, burst lengths 0/15, 4-KiB edge cases, all context/APB priority combinations, local/forwarded responses, and reset in each active phase.
- [ ] Collect statement, branch, toggle, FSM, functional, and assertion coverage with an approved coverage-capable simulator.
- [ ] Review all holes; add tests or document narrow waivers with requirement impact.
- [ ] Mark G5 `BLOCKED_TOOLING` if the only available simulator cannot produce the required coverage evidence.
- [ ] Commit as `verify: add firewall coverage model`.

### Task 11: Synthesis, timing, CDC, and implementation feasibility

**Files:**
- Create: `DMA-controller/constraints/firewall.sdc`
- Modify: `DMA-controller/docs/architecture/verification_evidence_manifest.csv`

- [ ] Constrain the single clock and reset according to the integration contract.
- [ ] Run lint for width, latch, undriven, multi-driver, unreachable FSM, and reset issues.
- [ ] Run synthesis and STA against the selected target library or FPGA part.
- [ ] Confirm the design has no internal CDC; separately verify that all top-level sources are in `clk` or synchronized before the Firewall boundary.
- [ ] Record area, maximum frequency, critical path, and warnings.
- [ ] Mark G6 `BLOCKED_EXTERNAL_INPUT` until a concrete target library/part and timing corner are supplied; do not extrapolate PPA from generic synthesis.
- [ ] Commit as `impl: add firewall constraints and feasibility evidence`.

### Task 12: Traceability and release closure

**Files:**
- Modify: `DMA-controller/docs/architecture/requirements_traceability.csv`
- Modify: `DMA-controller/docs/architecture/verification_evidence_manifest.csv`
- Modify: `DMA-controller/docs/architecture/verification_test_plan.md`
- Modify: `DMA-controller/docs/architecture/assumptions_and_tbd.md`

- [ ] Map each Firewall requirement to its final module, interface/register/FSM, test case, expected result, and evidence artifact.
- [ ] Supersede the deleted-draft evidence with the final source and regression hashes while retaining audit history.
- [ ] Run the spec linter, all available regressions, assertion checks, and synthesis checks from a clean source list.
- [ ] Confirm there are no stale “partial draft,” obsolete module names, old ports, or unowned requirements.
- [ ] Report each gate as PASS, FAIL, or BLOCKED with a concrete reason; never collapse blocked external gates into “100% complete.”
- [ ] Commit as `docs: close firewall RTL traceability and evidence`.

## Completion Criteria

The Firewall RTL implementation is complete only when G0–G3 pass and all seven canonical modules are present, synthesizable, and requirement-mapped. Security verification is complete only when G4 and G5 pass. Implementation feasibility is complete only when G6 passes against a named target. Full SoC closure is complete only when G7 validates DMA provenance, integration wiring, reset behavior, and end-to-end protected traffic.
