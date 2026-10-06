# Backend Readiness Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `writing-plans` to implement this plan task-by-task.

**Goal:** Close the remaining RTL, integration, verification, and evidence-consistency issues so the project has a defensible handoff point for generic PPA estimation and subsequent physical-design execution.

**Architecture:** Keep the existing IP-level firewall backend flow, add a synthesizable `aegis_soc_top` that connects the PicoRV32 APB bridge, DMA controller, and firewall, and make the AEGIS interrupt path a true unmaskable NMI at the CPU boundary. Keep generated evidence and document manifests truthful when derived artifacts are unavailable.

**Tech Stack:** SystemVerilog/Verilog RTL, PicoRV32, Verilator/Icarus, SymbiYosys with Z3, Yosys, PowerShell backend wrappers, SDC, repository-local evidence tools.

**Spec:** User-requested verification closure for synthesis/PPA and physical-design preparation. Missing OpenROAD/OpenSTA/PDK/real physical collateral and the parallel `rtl/` vs `DMA-controller/rtl/` source reconciliation are explicitly out of scope for this pass.

## Global Constraints

- Preserve unrelated dirty-worktree changes.
- Do not fabricate missing PDFs, PDK collateral, timing corners, or physical signoff results.
- Use `apply_patch` for repository edits.
- Validate every changed RTL path with lint, simulation, and generic synthesis where supported.

---

## Task 1: Make architecture/evidence manifests truthful

**Files:**
- Modify: `DMA-controller/docs/architecture/document_manifest.csv`
- Modify: `DMA-controller/docs/architecture/evidence/verification_evidence.csv`
- Inspect: `DMA-controller/docs/architecture/tools/spec_lint.py`

**Steps:**
1. Confirm the eight lint failures are only missing derived documents and stale PASS evidence.
2. Mark unavailable generated documents as deferred/planned using the repository’s accepted status vocabulary.
3. Change evidence rows that claim PASS without an artifact to a non-PASS status with an explicit reason.
4. Run the architecture semantic lint and evidence unit tests.

## Task 2: Implement and prove the CPU NMI contract

**Files:**
- Modify: `picorv32-main/picorv32-main/picorv32.v`
- Modify: `rtl/aegis_picorv32_apb_bridge.v`
- Modify: `tb/tb_aegis_picorv32_soc.v`

**Steps:**
1. Add a named `nmi` CPU input with a latched request so pulses are not lost.
2. Service NMI independently of `irq_mask`, expose the NMI cause in `eoi[3]`, and allow a telemetry-triggered NMI to escape the trap state into the configured IRQ vector.
3. Connect `aegis_nmi_irq` to the dedicated NMI input in the production bridge.
4. Add integration assertions that an NMI is serviced while the ordinary IRQ mask remains set.
5. Run the focused SoC test, full regression, lint, and generic synthesis.

## Task 3: Add a synthesizable full-SoC integration boundary

**Files:**
- Add: `rtl/aegis_soc_top.v`
- Add: `backend/sources_aegis_soc.f`
- Add: `constraints/aegis_soc_top.sdc`
- Add: `backend/run_synth_soc.ps1`
- Modify: `backend/README.md`

**Steps:**
1. Instantiate the real bridge, DMA controller, and firewall with explicit APB/AXI/sideband wiring.
2. Expose only integration-facing CPU memory, downstream AXI, interrupt, and AEGIS observability ports; keep the AXI memory model in the testbench.
3. Record the exact source manifest and 93-port firewall boundary in the generic synthesis run.
4. Run Verilator lint and Yosys synthesis for `aegis_soc_top`.

## Task 4: Add bounded-proof and readiness accounting

**Files:**
- Add: `formal/fw_mtd_prove.sby`
- Add: `backend/verification_readiness.md`
- Modify: `backend/README.md`

**Steps:**
1. Add an unbounded/prove-mode MTD formal target in addition to the existing bounded targets.
2. Document which verification gates are executed and which require external physical/DFT infrastructure, without claiming unavailable signoff.
3. Run the prove target and retain its status in the final verification report.

## Task 5: Final gate and handoff report

**Steps:**
1. Re-run model tests, evidence tests, architecture lint, RTL lint, all formal targets, simulations, and generic synthesis.
2. Verify generated evidence-bundle integrity.
3. Check the final diff for accidental scope expansion and report pass/review items with exact artifact paths.

