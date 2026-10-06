# Codex Firewall Integration Readiness Implementation Plan

> **For agentic workers:** Execute this plan task by task. Each task keeps `READY_NOW` and student-owned RTL read-only and ends with a reproducible check.

**Goal:** Prepare the Codex-owned Firewall wrapper, integration test infrastructure, interface validation, traceability, and handoff documentation so the real owner modules can be accepted and integrated without rewriting the test environment.

**Architecture:** The canonical V2.4.1 documents remain the source of truth. The wrapper `fw_drain_fsm` is structural and instantiates the two student-owned drain leaves. Test-only mocks implement the same leaf ports outside production RTL. A public-boundary Firewall stub supports a DMA-to-Firewall default-deny test while the production top remains blocked by unaccepted leaf port lists.

**Tech Stack:** Verilog-2001/SystemVerilog, Icarus Verilog, Python 3 standard library, PowerShell, Markdown and CSV.

**Spec:** `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`

## Global Constraints

- Do not edit the seven `READY_NOW` module implementations or their module-owned testbenches.
- Do not edit the four student-owned leaf module implementations or lab-guide deliverables.
- Preserve every pre-existing working-tree change.
- Test-only mocks must be visibly labelled and excluded from production source lists.
- No mock-backed result may be reported as Firewall RTL integration completion.
- `dma_bus_firewall.v` remains blocked until all dependency ports are accepted and reviewed.
- All generated tests need a timeout, explicit PASS marker, and nonzero exit on failure.

---

### Task 1: Ownership and dependency ledger

**Files:**
- Create: `DMA-controller/docs/integration/codex_scope_and_readiness.md`
- Create: `DMA-controller/docs/integration/integration_traceability.csv`

**Interfaces:**
- Consumes: module classification matrix, student assignment specification, integration contract, pinout, signal list, traceability and evidence manifests.
- Produces: one reviewable A/B/C ownership table and one requirement-to-preparation mapping.

- [x] Record all 17 named module targets and all non-module work categories.
- [x] Mark historical/non-target names `UNASSIGNED` and leave them unchanged.
- [x] Distinguish accepted RTL evidence from mock-backed readiness evidence.
- [x] Validate CSV shape and ownership uniqueness with `check_firewall_contract.py`.

### Task 2: Structural drain wrapper

**Files:**
- Create: `DMA-controller/rtl/fw_drain_fsm.v`
- Create: `DMA-controller/tb/integration/mocks/fw_write_drain_mock.v`
- Create: `DMA-controller/tb/integration/mocks/fw_read_drain_mock.v`
- Create: `DMA-controller/tb/integration/tb_fw_drain_fsm.v`

**Interfaces:**
- Consumes: the canonical write/read drain ports from the student guides and `signal_list.csv`.
- Produces: a synthesizable wrapper with no transaction state and a mock-backed test proving exact port mapping and simultaneous read/write independence.

- [x] Write the wrapper with one `fw_write_drain` and one `fw_read_drain` instance.
- [x] Write clearly labelled simulation-only mocks outside production RTL.
- [x] Test reset, concurrent denied read/write, response stalls, response ID/mode, and framing-event propagation.
- [x] Compile with `iverilog -g2012 -Wall -Wimplicit` and require `PASS: tb_fw_drain_fsm`.

### Task 3: Public-boundary integration harness

**Files:**
- Create: `DMA-controller/tb/integration/mocks/dma_bus_firewall_stub.v`
- Create: `DMA-controller/tb/integration/tb_soc_dma_firewall_contract.v`

**Interfaces:**
- Consumes: the canonical Firewall public pinout and the existing user-owned `dma_controller` interface.
- Produces: a test that connects the real DMA to a fail-secure test-only Firewall boundary, verifies default-deny termination, context release, and zero downstream Matrix traffic.

- [x] Give the stub the exact canonical `dma_bus_firewall` public ports.
- [x] Make the stub terminate denied reads with exact `ARLEN+1` DECERR beats and never assert downstream request VALID.
- [x] Connect the existing DMA RTL without editing it.
- [x] Check DMA terminal ERROR, one-cycle context done, and Matrix isolation.
- [x] Compile with warnings enabled and require `PASS: tb_soc_dma_firewall_contract`.

### Task 4: Contract checker and regression entry point

**Files:**
- Create: `DMA-controller/scripts/check_firewall_contract.py`
- Create: `DMA-controller/scripts/run_codex_integration_prep.ps1`

**Interfaces:**
- Consumes: canonical CSV files, ownership ledger, wrapper source, optional real leaf sources.
- Produces: machine-readable PASS/BLOCKED checks and one command that runs all currently valid preparation gates.

- [x] Validate canonical public port names, directions and widths, module ownership uniqueness, required wrapper instances, mock labels, and source placement.
- [x] Report missing real A/B dependencies as `BLOCKED_DEPENDENCY`, without treating them as test success.
- [x] Run tests from a temporary directory so VCD/VVP files do not pollute the workspace.
- [x] Save a reproducible evidence log under `docs/integration/evidence/`.

### Task 5: Handoff and canonical evidence status

**Files:**
- Create: `DMA-controller/docs/integration/firewall_handoff_runbook.md`
- Modify: `DMA-controller/docs/architecture/requirements_traceability.csv`
- Modify: `DMA-controller/docs/architecture/verification_evidence_manifest.csv`
- Modify: `DMA-controller/docs/architecture/implementation_conformance_status.md`

**Interfaces:**
- Consumes: fresh regression output and source hashes.
- Produces: accurate readiness evidence, dependency blockers, and exact rerun instructions for accepted modules.

- [x] Record wrapper readiness as mock-backed structural evidence only.
- [x] Keep G3, formal, coverage, synthesis/STA, PPA and SoC trust gates blocked.
- [x] Document how to replace mocks with accepted sources and rerun unit/integration tests.
- [x] Run spec lint, full Python model tests, four existing DMA RTL tests, both new integration tests, and `git diff --check`.
