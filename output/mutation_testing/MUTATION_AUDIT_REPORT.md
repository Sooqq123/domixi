# AEGIS-RISC Mutation Testing & Assertion Sensitivity Audit Report

- **Total Injected Mutants:** 4
- **Killed:** 4 (100.0%)
- **Survived:** 0 (0.0%)
- **Verdict:** ALL INJECTED MUTANTS DETECTED AND KILLED

## Detailed Audit Table

| Mutant ID | Target RTL File | Injected Fault Description | Detection Status | First Flagged Error / Assertion |
| :--- | :--- | :--- | :---: | :--- |
| `MUT-01-ACL-BYPASS` | `fw_acl_matcher.v` | Bypass ACL: force acl_allowed always true | **KILLED** | `[ERROR] Test 2 at 65000: Allow mismatch! DUT=1010, Exp=0101` |
| `MUT-02-WRITE-DRAIN-RESP` | `fw_write_drain.v` | Corrupt Write Drain: return OKAY instead of DECERR on write violation | **KILLED** | `[ERROR] Step 2 at 50000 ps: TC02: bresp must be 2'b11 (DECERR)` |
| `MUT-03-READ-DRAIN-RESP` | `fw_read_drain.v` | Corrupt Read Drain: return OKAY instead of DECERR on read violation | **KILLED** | `FATAL: D:\domixi\tb\tb_fw_read_drain.v:86: SAI RESP: 0 != 11` |
| `MUT-04-NMI-PULSE-SUPPRESS` | `fw_closed_loop_ctrl.v` | Suppress NMI: disable NMI alert pulse generation | **KILLED** | `[FAIL] aegis_nmi_irq failed to pulse high on first cycle` |

## Cross-Reference Artifacts

- [`MUT-01-ACL-BYPASS.log`](file:///D:/domixi/output/mutation_testing/MUT-01-ACL-BYPASS.log): Full simulation failure log
- [`MUT-02-WRITE-DRAIN-RESP.log`](file:///D:/domixi/output/mutation_testing/MUT-02-WRITE-DRAIN-RESP.log): Full simulation failure log
- [`MUT-03-READ-DRAIN-RESP.log`](file:///D:/domixi/output/mutation_testing/MUT-03-READ-DRAIN-RESP.log): Full simulation failure log
- [`MUT-04-NMI-PULSE-SUPPRESS.log`](file:///D:/domixi/output/mutation_testing/MUT-04-NMI-PULSE-SUPPRESS.log): Full simulation failure log
