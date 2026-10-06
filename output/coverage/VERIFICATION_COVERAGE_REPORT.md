# AEGIS-RISC Sky130 v2.0.0 RTL Frontend Verification Coverage Report

Date: 2026-09-16 (Reconciled & Rebound: 2026-09-19)
Specification Baseline: docs/AEGIS_RISC_ARCHITECTURE_SPECIFICATION.md (v2.0.0, commit 8bedf91, Reconciled to Frozen Release ba7a753)
Status: **100% VERIFIED & FULLY ACCEPTED (ALL 7 BLOCKERS RESOLVED)**

---

## 1. Executive Verification Summary

| Verification Vector | Target Metric | Achieved Result | Verdict |
|---|---|---|:---:|
| **Simulation Testbenches** | 19/19 PASS | **19/19 PASS (0 failures)** | **PASS** |
| **Mutation Testing (Sensitivity)** | 100% Mutants Killed | **4/4 Mutants Killed (0 survived)** | **PASS** |
| **Formal Verification Suites (SBY)** | 9/9 Suites PASS | **9/9 Suites PASS (7 BMC [depth 20–55] + 1 k-induction + 1 COVER)** | **PASS** |
| **Formal Cover Targets** | 100% Reachability | **7/7 Cover points reached (4 traces generated)** | **PASS** |
| **Verilator Lint (Top Firewall)** | 0 Errors, 0 Warnings | **0 Errors, 0 Warnings** | **PASS** |
| **Verilator Lint (Top SoC)** | Zero SYNCASYNCNET | **PASS (SYNCASYNCNET 100% eliminated, DFT test_mode added)** | **PASS** |
| **Yosys Synthesis & Check** | Clean Elaboration | **PASS (19,241 cells, 16,437 wires, 0 latches, 0 conflicts)** | **PASS** |
| **Timing Constraints (SDC)** | 26.315 ns (38.00 MHz, WAV-STA-003) | **SDC updated to 26.315 ns across all tops** | **PASS** |
| **HDC Cognitive Engine Latency** | Max 49 cycles | **Strictly 49 cycles verified (tb_challenger2: 37/37 assertions)** | **PASS** |
| **HDC Avalanche & Toggle** | SAC ~50%, 100% bit toggle | **100% dynamic toggle, mean SAC = 16.06 bits/32 bits** | **PASS** |
| **MTD Scrambler Contract** | Polynomial x^16+x^14+x^13+x^11+1 | **Seed 16'h1ACE, state named scrambler_state, proven by k-induction** | **PASS** |
| **PicoRV32 CPU Integration** | NMI Reflex & APB Access | **PASS (Real RISC-V CPU firmware executing DMA & NMI trap)** | **PASS** |

---

## 2. Comprehensive Functional Coverage Mapping

| Functional Requirement | Architecture Spec Section | Verification Method | Evidence Artifact | Status |
|---|---|---|---|:---:|
| **ACL Enforcement (Allow / Deny)** | Sec 4.1, 5 | Icarus Simulation | tb_fw_acl_matcher.log | **COVERED** |
| **4 KiB Boundary & Overflow Check** | Sec 5 | Icarus Simulation | tb_fw_axi_address_slice.log | **COVERED** |
| **Protocol Drain (Read / Write)** | Sec 4.1, 5 | Icarus Simulation | tb_fw_drain_fsm.log, tb_fw_write_drain.log, tb_fw_read_drain.log | **COVERED** |
| **Honey-Pot AXI Sink Redirection** | Sec 4.1, 7 | Simulation & Formal | tb_fw_honeypot_sink.log, formal/fw_mtd/ | **COVERED** |
| **Per-MID Saturating Score (0-15)** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Automatic Quarantine at Score 10** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Immediate Level 3 Quarantine** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Score Decay Epoch (1024 cycles)** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Score Collision Priority (Inc > Dec)** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **1-Cycle NMI Pulse Guarantee** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Zero NMI Storm Guarantee** | Sec 5 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Software IRQ Acknowledge (0x0BC)** | Sec 9, 10 | Simulation & Formal | tb_fw_apb_regs.log, formal/fw_closed/ | **COVERED** |
| **Forensic FIFO (Depth 4, No Overwrite)** | Sec 10 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Telemetry Overrun Containment & Attribution**| Sec 7, 10 | Simulation & Formal | tb_fw_closed_loop_ctrl.log, formal/fw_closed/ | **COVERED** |
| **Canonical Register Map (0x0A0-0x0BC)** | Sec 9, 10 | Simulation & Formal | tb_fw_apb_regs.log, formal/fw_closed/ | **COVERED** |
| **HDC 1024-D 64-bit Sequential Engine** | Sec 6.1 | Simulation & Formal | tb_fw_hdc_sense_challenger2.log, formal/fw_hdc/ | **COVERED** |
| **HDC Latency Strictly <= 49 Cycles** | Sec 6.1 | Directed Assertions | tb_fw_hdc_sense_challenger2.log (37/37 assertions) | **COVERED** |
| **HDC Formal Reachability Cover** | Sec 6.1 | SBY Cover (Depth 24) | formal/fw_hdc_cover/ (all 7 cover points reached, 4 traces generated) | **COVERED** |
| **Bounded Level 1 Timing Shaping** | Sec 4.2, 7 | Formal k-induction | formal/fw_mtd_prove/ (proven invariant) | **COVERED** |
| **Level 2 Scrambler 16'h1ACE** | Sec 7 | Formal k-induction | formal/fw_mtd_prove/ (proven invariant) | **COVERED** |
| **Fail-Secure Honey-Pot to Drain** | Sec 4.2 | Formal k-induction | formal/fw_mtd_prove/ (proven invariant) | **COVERED** |
| **Real PicoRV32 CPU + DMA Integration** | Sec 1, 4 | End-to-End Sim | tb_aegis_picorv32_soc.log, tb_soc_dma_firewall_contract.log | **COVERED** |
| **Adversarial False-Positive Stress** | Sec 3 | 5,000 Burst Sim | tb_adversarial_m1.log (0 false positives) | **COVERED** |
| **Row-thrashing 5,000 Bursts Stress** | Sec 3, 5 | End-to-End Sim | tb_aegis_soc.log (16/16 assertions passed) | **COVERED** |
| **Abnormal Stress & Reset Invariance** | Sec 4, 5 | Icarus Simulation | tb_fw_abnormal_stress.log (Mid-burst reset, backpressure, DECERR containment) | **COVERED** |
| **Fault-Sensitivity & Non-Vacuity** | Verification Rigor | Mutation Testing | tools/run_mutation_testing.py (4/4 mutants killed, 100%) | **COVERED** |

---

## 3. Tool Verification Regression Evidence

### 3.1. Formal Verification Regression (tools/verify_formal.ps1)
```
[FORMAL] formal\fw_hdc.sby: PASS (BMC depth 55)
[FORMAL] formal\fw_mtd.sby: PASS (BMC depth 20)
[FORMAL] formal\fw_mtd_prove.sby: PASS (k-induction proven)
[FORMAL] formal\fw_closed.sby: PASS (BMC depth 20)
[FORMAL] formal\fw_hdc_cover.sby: PASS (Depth 24, all 7 cover targets reached, 4 traces generated)
[FORMAL] formal\fw_axi_contract.sby: PASS (BMC depth 20)
[FORMAL] formal\fw_honeypot_contract.sby: PASS (BMC depth 20)
[FORMAL] formal\fw_drain_contract.sby: PASS (BMC depth 20)
[FORMAL] formal\fw_stream_contract.sby: PASS (BMC depth 20)
[FORMAL-PASS] 9/9 suites passed
```

### 3.2. Simulation Regression (tools/run_all_sims.py)
```
[+] PASS: tb_adversarial_m1
[+] PASS: tb_aegis_picorv32_soc
[+] PASS: tb_aegis_soc_reset
[+] PASS: tb_aegis_soc
[+] PASS: tb_dma_bus_firewall
[+] PASS: tb_fw_acl_matcher
[+] PASS: tb_fw_apb_regs
[+] PASS: tb_fw_axi_address_slice
[+] PASS: tb_fw_closed_loop_ctrl
[+] PASS: tb_fw_context_tracker
[+] PASS: tb_fw_data_path_mux
[+] PASS: tb_fw_drain_fsm
[+] PASS: tb_fw_hdc_sense
[+] PASS: tb_fw_hdc_sense_challenger2
[+] PASS: tb_fw_honeypot_sink
[+] PASS: tb_fw_read_drain
[+] PASS: tb_fw_write_drain
[+] PASS: tb_fw_abnormal_stress
[+] PASS: tb_soc_dma_firewall_contract
============================================================
FINAL SIMULATION RESULTS: 19/19 PASSED, 0 FAILED
============================================================
```

### 3.3. Mutation Testing & Assertion Sensitivity (tools/run_mutation_testing.py)
```
[*] Evaluating Mutant: MUT-01-ACL-BYPASS (fw_acl_matcher.v)
    [+] MUTANT KILLED (tb_fw_acl_matcher caught bypass)
[*] Evaluating Mutant: MUT-02-WRITE-DRAIN-RESP (fw_write_drain.v)
    [+] MUTANT KILLED (tb_fw_write_drain caught response corruption)
[*] Evaluating Mutant: MUT-03-READ-DRAIN-RESP (fw_read_drain.v)
    [+] MUTANT KILLED (tb_fw_read_drain caught response corruption)
[*] Evaluating Mutant: MUT-04-NMI-PULSE-SUPPRESS (fw_closed_loop_ctrl.v)
    [+] MUTANT KILLED (tb_fw_closed_loop_ctrl caught NMI pulse suppression)
============================================================
MUTATION TESTING SUMMARY: 4/4 MUTANTS KILLED (100.0%), 0 SURVIVED
============================================================
```
Detailed audit report and individual error logs:
- [MUTATION_AUDIT_REPORT.md](file:///D:/domixi/output/mutation_testing/MUTATION_AUDIT_REPORT.md)
- [mutation_testing.log](file:///D:/domixi/output/mutation_testing/mutation_testing.log)
- [`MUT-01-ACL-BYPASS.log`](file:///D:/domixi/output/mutation_testing/MUT-01-ACL-BYPASS.log)
- [`MUT-02-WRITE-DRAIN-RESP.log`](file:///D:/domixi/output/mutation_testing/MUT-02-WRITE-DRAIN-RESP.log)
- [`MUT-03-READ-DRAIN-RESP.log`](file:///D:/domixi/output/mutation_testing/MUT-03-READ-DRAIN-RESP.log)
- [`MUT-04-NMI-PULSE-SUPPRESS.log`](file:///D:/domixi/output/mutation_testing/MUT-04-NMI-PULSE-SUPPRESS.log)


### 3.4. Synthesis & Elaboration (tools/synth/synth_firewall.ys)
- Return code: 0 (clean execution)
- Cells: 19,241
- Wires: 16,437
- All 10 submodules correctly resolved and elaborated.

---

## 4. Requirements & Boundary Verification Matrix
For complete traceability between architecture requirements, verification methods, coverage metrics, and boundary conditions, see:
- [REQUIREMENTS_VERIFICATION_AND_BOUNDARY_MATRIX.md](file:///D:/domixi/docs/evidence/REQUIREMENTS_VERIFICATION_AND_BOUNDARY_MATRIX.md)

