# Canonical Architecture V2.4.1 Closure Plan

> **Execution status:** Completed in the authorized non-Firewall scope on 2026-08-24. Canonical lint, 46 model tests, 37 benchmark records and four source-built DMA RTL regressions pass; Firewall RTL/full-system gates remain blocked exactly as described below.
>
> **Mandatory exclusion:** Firewall RTL implementation and integration remain user-owned. This plan may inspect that RTL, document its contract and dependencies, and mark blocked evidence, but must not modify it or claim that it is complete.

## Objective

Promote the DMA + memory-firewall specification from V2.4 to a clarification and closure baseline, V2.4.1, by removing every known inconsistency outside the excluded Firewall RTL implementation, strengthening machine-checkable validation, repairing derived documents, and recording reproducible verification evidence.

## Governing decisions

1. `DMA-controller/docs/architecture/` remains the sole canonical specification set.
2. V2.4.1 is a clarification/closure release; it does not silently redefine the approved architecture.
3. FIFO depth remains 32 entries everywhere.
4. DMA AXI is the constrained single-outstanding AXI4 subset: 32-bit address/data, 4-bit ID fixed to zero, INCR only, 1–16 beats, 4-byte beats, no 4 KiB crossing, no WRAP/FIXED, no narrow or unaligned access.
5. The DMA is integrated as a dedicated Secure-Privileged master. Its AXI `AxPROT` value is `3'b001`, and its APB programming aperture must only be reachable from the SoC Secure-Privileged domain.
6. Firewall Stage 1 acceptance captures an immutable transaction descriptor; Stage 2 makes the ACL decision from that snapshot. Upstream acceptance is not permission grant.
7. Firewall enable bypasses only ACL permission matching. AXI-profile checks, 4 KiB checks, containment checks and protocol-fault reporting remain active.
8. Firewall RTL and integration evidence stay explicitly blocked until the user-owned implementation satisfies the published integration contract.

## Issue classes

### Authorized and actionable

- AXI/FSM lifecycle, priority, burst-drain, ID and error-response ambiguities.
- APB/AXI pinout, sideband, width and reset-value inconsistencies.
- malformed CSV rows and insufficient schema/lint checks.
- dynamic-region privilege/security defaults and context-priority semantics.
- obsolete V2.1 HTML/PDF artifacts that still contain approval overclaims.
- stale system-model narrative and model defaults that disagree with FIFO depth 32.
- DMA RTL/testbench/model defects outside Firewall RTL.
- missing evidence manifest, duplicate test identifiers and incomplete traceability states.

### Dependent on Firewall RTL

- firewall synthesis/lint closure, endpoint integration and top-level elaboration;
- firewall protocol assertions, ACL/containment/TOCTOU simulations and coverage;
- PPA/timing and end-to-end DMA-to-firewall performance evidence;
- final sign-off of fail-closed behavior at the implemented mux and response-drain paths.

### Information required from the user

None for V2.4.1 document closure. Technology-node timing/PPA targets remain `TBD` and cannot be fabricated; they are acceptance inputs for a later implementation sign-off.

## Execution steps

### 1. Canonical contract repair

Edit the Markdown and CSV files under `DMA-controller/docs/architecture/` to:

- define transaction snapshot, ACL decision and context-update priority;
- specify exact write/read drain counting, latched IDs and malformed-framing behavior;
- close region activation, full-burst containment, `FW_EN` and `AUTO_CTX_EN` semantics;
- standardize DMA trust attributes and dynamic-region defaults;
- add complete data/control interfaces for address slices, response drains and the event logger;
- assign deterministic handling to simultaneous read/write/context violations;
- repair reset expectations and unique test IDs;
- update traceability with `PARTIAL`, `BLOCKED_FIREWALL_RTL` and evidence states.

### 2. Firewall integration boundary

Add `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md` defining:

- current draft/not-integrated status;
- required modules and connections;
- secure AXI/APB assumptions;
- integration sequence, invariants and acceptance gates;
- exact evidence that remains blocked by the excluded implementation.

No file under `D:/domixi/rtl/` is modified.

### 3. Machine-readable governance

- Repair `register_map.csv` quoting and row shape.
- Add `document_manifest.csv` and `verification_evidence_manifest.csv`.
- Extend `tools/spec_lint.py` to reject malformed row lengths, duplicate IDs, stale versions, forbidden overclaims and missing cross-references.
- Run the linter after each contract-edit batch.

### 4. DMA/model conformance outside the exclusion

Based on source-level audit, apply only evidence-backed changes in `DMA-controller/rtl/`, `DMA-controller/tb/` and `DMA-controller/model/` for defects that are independent of Firewall RTL. Candidate closure items include FIFO default depth, START-while-busy behavior, AXI AW-before-W ordering, fixed Secure-Privileged `AxPROT`, and abort/error coordination. Add focused regression cases for each changed behavior.

### 5. Derived and obsolete artifacts

- Mark both V2.1 HTML/PDF deliverables visibly obsolete and remove approval/“flawless” claims.
- Make the generator scripts repository-relative so regeneration is deterministic.
- Regenerate PDFs and inspect every page visually.
- Keep `docs/system_model_spec.md` clearly historical/non-normative and reconcile any live numerical claims with V2.4.1.

### 6. Verification and final audit

Run, as available:

```text
python DMA-controller/docs/architecture/tools/spec_lint.py
python -m unittest discover -s DMA-controller/model -p "test_*.py" -v
iverilog compile + vvp for each DMA FIFO/APB/AXI/controller testbench
standalone compile-only check of the Firewall draft (evidence only; no edit)
HTML/PDF text, page-count and rendered-page inspection
git diff --check
```

Record command, result, artifact, date and limitation in the evidence manifest. A stale precompiled `.vvp` is never accepted as source-built evidence.

## Completion gate

The authorized scope is complete only when:

- all canonical files identify V2.4.1 consistently;
- strict spec lint passes;
- every changed DMA/model behavior has a passing focused regression;
- all generated obsolete artifacts match their generators and show the obsolete status;
- no known non-Firewall contradiction remains;
- every Firewall-dependent item is labelled `BLOCKED_FIREWALL_RTL`, with a concrete acceptance condition.

Full-system completion remains prohibited until the user-owned Firewall RTL is implemented, integrated and passes every gate in the integration contract.
