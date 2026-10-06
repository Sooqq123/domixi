# AEGIS-RISC: Cryptographic Verification & Provenance Manifest

> **Document ID:** MANIFEST-CRYPTO-PROVENANCE-001<br>
> **Release Baseline Commit:** [`ba7a75343457deaa7d1a86310bb1be81a4a4420f`](file:///D:/domixi) (`ba7a753`)<br>
> **Current Git HEAD:** [`19301bc2c7c2994dc65b67c1e2d61ddf77a60734`](file:///D:/domixi)<br>
> **Verification Verdict:** **21/21 tệp khớp sau chuẩn hóa CRLF/LF với ba7a753**<br>
> **Status:** PENDING FORMAL SIGNOFF — SUBMITTED FOR CODEX ACCEPTANCE REVIEW<br>
> **Timestamp (UTC):** `2026-10-06T15:59:41.875450+00:00`

---

## 1. Mục Đích & Nguyên Tắc Đối Chiếu (Reconciliation Statement)

Manifest này đối chiếu toàn bộ các tệp RTL được kiểm thử trong cây làm việc hiện tại với commit đóng băng release `ba7a753`. Kết quả khẳng định **21/21 tệp khớp sau chuẩn hóa CRLF/LF với ba7a753**.

Sự khác biệt giữa HEAD (`19301bc`) và `ba7a753` chỉ gồm:
1. Bổ sung testbench kịch bản bất thường: [`tb/tb_fw_abnormal_stress.v`](file:///D:/domixi/tb/tb_fw_abnormal_stress.v).
2. Bổ sung kịch bản kiểm thử đột biến: [`tools/run_mutation_testing.py`](file:///D:/domixi/tools/run_mutation_testing.py).
3. Bổ sung adapter FPGA iCE40 độc lập: [`rtl/adapters/dma_bus_firewall_ice40_adapter.v`](file:///D:/domixi/rtl/adapters/dma_bus_firewall_ice40_adapter.v) (không tham gia netlist ASIC SoC).
4. Bổ sung các báo cáo nghiệm thu, nhật ký kiểm thử và ma trận truy vết trong thư mục `docs/` và `output/`.

---

## 2. Bảng Đối Chiếu Băm Mã Nguồn RTL (Production RTL Reconciliation)

| Tệp RTL | Kích Thước (Bytes) | SHA-256 Chuẩn Hóa (Working Tree) | SHA-256 Commit `ba7a753` | Trạng Thái Đối Chiếu |
| :--- | :---: | :--- | :--- | :---: |
| [`rtl/dma_bus_firewall.v`](file:///D:/domixi/rtl/dma_bus_firewall.v) | 45948 | `eae23ddde9353b3d...` | `eae23ddde9353b3d...` | **MATCH (CRLF/LF)** |
| [`rtl/aegis_soc_top.v`](file:///D:/domixi/rtl/aegis_soc_top.v) | 12720 | `f9f95a3fbc073a3b...` | `f9f95a3fbc073a3b...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_hdc_sense.v`](file:///D:/domixi/rtl/fw_hdc_sense.v) | 23059 | `e552591765519049...` | `e552591765519049...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_mtd_engine.v`](file:///D:/domixi/rtl/fw_mtd_engine.v) | 8339 | `1b533b4902a690df...` | `1b533b4902a690df...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_closed_loop_ctrl.v`](file:///D:/domixi/rtl/fw_closed_loop_ctrl.v) | 16172 | `5115d8d3456883d0...` | `5115d8d3456883d0...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_acl_matcher.v`](file:///D:/domixi/rtl/fw_acl_matcher.v) | 6430 | `2eaae86da67f5f6a...` | `2eaae86da67f5f6a...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_apb_regs.v`](file:///D:/domixi/rtl/fw_apb_regs.v) | 26976 | `dca1baff424d32a4...` | `dca1baff424d32a4...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_axi_address_slice.v`](file:///D:/domixi/rtl/fw_axi_address_slice.v) | 9002 | `cd54b8e5af4ad693...` | `cd54b8e5af4ad693...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_context_tracker.v`](file:///D:/domixi/rtl/fw_context_tracker.v) | 9198 | `bf1f4752021ac767...` | `bf1f4752021ac767...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_data_path_mux.v`](file:///D:/domixi/rtl/fw_data_path_mux.v) | 8936 | `ac96871bcc6521b0...` | `ac96871bcc6521b0...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_drain_fsm.v`](file:///D:/domixi/rtl/fw_drain_fsm.v) | 2166 | `584abf87edf141c8...` | `584abf87edf141c8...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_honeypot_sink.v`](file:///D:/domixi/rtl/fw_honeypot_sink.v) | 10460 | `2b5afc7976cfa0f0...` | `2b5afc7976cfa0f0...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_read_drain.v`](file:///D:/domixi/rtl/fw_read_drain.v) | 3864 | `50031b31ce0e695b...` | `50031b31ce0e695b...` | **MATCH (CRLF/LF)** |
| [`rtl/fw_write_drain.v`](file:///D:/domixi/rtl/fw_write_drain.v) | 6190 | `afd1d57f308a633b...` | `afd1d57f308a633b...` | **MATCH (CRLF/LF)** |
| [`rtl/aegis_picorv32_apb_bridge.v`](file:///D:/domixi/rtl/aegis_picorv32_apb_bridge.v) | 8874 | `b5d14ecea311ddec...` | `b5d14ecea311ddec...` | **MATCH (CRLF/LF)** |
| [`rtl/generated/aegis_hdc_params.vh`](file:///D:/domixi/rtl/generated/aegis_hdc_params.vh) | 10608 | `a2068bf248e981da...` | `a2068bf248e981da...` | **MATCH (CRLF/LF)** |
| [`picorv32-main/picorv32-main/picorv32.v`](file:///D:/domixi/picorv32-main/picorv32-main/picorv32.v) | 105630 | `6871796338e9efd1...` | `6871796338e9efd1...` | **MATCH (CRLF/LF)** |
| [`DMA-controller/rtl/dma_apb_slave.v`](file:///D:/domixi/DMA-controller/rtl/dma_apb_slave.v) | 3748 | `a814bf2b99c10420...` | `a814bf2b99c10420...` | **MATCH (CRLF/LF)** |
| [`DMA-controller/rtl/dma_axi_master.v`](file:///D:/domixi/DMA-controller/rtl/dma_axi_master.v) | 16971 | `a41eff2338e467c9...` | `a41eff2338e467c9...` | **MATCH (CRLF/LF)** |
| [`DMA-controller/rtl/dma_fifo_latch.v`](file:///D:/domixi/DMA-controller/rtl/dma_fifo_latch.v) | 2298 | `dc345abbc7d7382c...` | `dc345abbc7d7382c...` | **MATCH (CRLF/LF)** |
| [`DMA-controller/rtl/dma_controller.v`](file:///D:/domixi/DMA-controller/rtl/dma_controller.v) | 6236 | `cff5b90c61b23e47...` | `cff5b90c61b23e47...` | **MATCH (CRLF/LF)** |

---

## 3. Phiên Bản Công Cụ EDA & Môi Trường Kiểm Chứng (Tool Environment)

- **Icarus Verilog:** `Icarus Verilog version 14.0 (devel) (s20260301-434-g79c42a156-dirty)`
- **Yosys Synthesis:** `Yosys 0.69+24 (git sha1 d0e71cfb7-dirty, Release, GNU /usr/bin/x86_64-w64-mingw32-g++ 15.2.1)`
- **SymbiYosys (SBY):** `SBY v0.69`
- **Verilator:** `Verilator 5.053 devel rev v5.052-61-g4aeb3dbc5 (mod)`
- **Python Runtime:** `3.14.4 (tags/v3.14.4:23116f9, Apr  7 2026, 14:10:54) [MSC v.1944 64 bit (AMD64)]`

---

## 4. Bảng Băm Testbench & Kịch Bản Kiểm Thử (Verification Harnesses)

| Tệp Testbench / Kịch Bản | SHA-256 Digest | Vai Trò & Phân Loại |
| :--- | :--- | :--- |
| [`tb/tb_adversarial_m1.v`](file:///D:/domixi/tb/tb_adversarial_m1.v) | `d87664de684a1552acc353a18164965b36ce4b3eb0586f181d4118a993b71ae2` | FROZEN_BASELINE |
| [`tb/tb_aegis_picorv32_soc.v`](file:///D:/domixi/tb/tb_aegis_picorv32_soc.v) | `abc973b364e4277164226d6e043785f6273a28d5853505f576bef649614bf205` | FROZEN_BASELINE |
| [`tb/tb_aegis_soc_reset.v`](file:///D:/domixi/tb/tb_aegis_soc_reset.v) | `fccc9b1ac8b2afb7cb3ace1dde9d30aef9cee183daf5069b0637e8cdfddffa97` | FROZEN_BASELINE |
| [`tb/tb_aegis_soc.v`](file:///D:/domixi/tb/tb_aegis_soc.v) | `b653e29dcf5d0687f778bd7bd5ae0edb4e9a3e01bc5b7f1c5c99231fae504f52` | FROZEN_BASELINE |
| [`tb/tb_dma_bus_firewall.v`](file:///D:/domixi/tb/tb_dma_bus_firewall.v) | `81ec62248cd9fcd35409af51765ed7d58f59530787acb9a41ccecbc25cfb7406` | FROZEN_BASELINE |
| [`tb/tb_fw_acl_matcher.v`](file:///D:/domixi/tb/tb_fw_acl_matcher.v) | `694c700b53765671a78d8e4550d40e3ab4e84c343989722892bb5196adb8ec7d` | FROZEN_BASELINE |
| [`tb/tb_fw_apb_regs.v`](file:///D:/domixi/tb/tb_fw_apb_regs.v) | `65bdd71301d391f73d033b5c4d607a759f1ae0314b2afd936e9db9ae999157b2` | FROZEN_BASELINE |
| [`tb/tb_fw_axi_address_slice.v`](file:///D:/domixi/tb/tb_fw_axi_address_slice.v) | `8be86e0c3dd6ba9633e2bd9d12d3bdc7c14a4b227770b143103e46a157096918` | FROZEN_BASELINE |
| [`tb/tb_fw_closed_loop_ctrl.v`](file:///D:/domixi/tb/tb_fw_closed_loop_ctrl.v) | `d53b46c83851248f3acb936e4a2733ba38453f52fdf85e87f38989d81c33165a` | FROZEN_BASELINE |
| [`tb/tb_fw_context_tracker.v`](file:///D:/domixi/tb/tb_fw_context_tracker.v) | `e0b95bd4fd9111c8830874d794893eb439d22e36a7043371a930f6335b05a5d0` | FROZEN_BASELINE |
| [`tb/tb_fw_data_path_mux.v`](file:///D:/domixi/tb/tb_fw_data_path_mux.v) | `d72018884e34489ebee0cbf1b129e969ab45e7e6a9d17d36bd42d68532826100` | FROZEN_BASELINE |
| [`tb/tb_fw_drain_fsm.v`](file:///D:/domixi/tb/tb_fw_drain_fsm.v) | `122d9271bb7c015523703dbb7004643a5e3749a0ab903e86b98b5f4ea35f9985` | FROZEN_BASELINE |
| [`tb/tb_fw_hdc_sense.v`](file:///D:/domixi/tb/tb_fw_hdc_sense.v) | `3d4070bb87b3e3eebd9479b59e2c5d1404011c45c9b1e9b87d7934beaa09e5a5` | FROZEN_BASELINE |
| [`tb/tb_fw_hdc_sense_challenger2.v`](file:///D:/domixi/tb/tb_fw_hdc_sense_challenger2.v) | `abc2811fedfc196ae88acd5b35f6b8121976e281a474db61aa1913a0667634f4` | FROZEN_BASELINE |
| [`tb/tb_fw_honeypot_sink.v`](file:///D:/domixi/tb/tb_fw_honeypot_sink.v) | `db89bdd2fa999d779db6962ffe08f0bfb4046c91e00dc8973f282fd8a175e160` | FROZEN_BASELINE |
| [`tb/tb_fw_read_drain.v`](file:///D:/domixi/tb/tb_fw_read_drain.v) | `add1564b3cff9513e2284d354cdbb6696ed575be4ac87a49a8beba55264a9e8e` | FROZEN_BASELINE |
| [`tb/tb_fw_write_drain.v`](file:///D:/domixi/tb/tb_fw_write_drain.v) | `1a7925cae750acc3f9cfedbb6e97bf7776410cea286b34bc291a13142061a893` | FROZEN_BASELINE |
| [`tb/tb_fw_abnormal_stress.v`](file:///D:/domixi/tb/tb_fw_abnormal_stress.v) | `a401f2ffbeba9be1594eac122dde81164b3068932b5faef2bd87809b37a455d0` | HEAD_EXTENSION |
| [`tb/tb_soc_dma_firewall_contract.v`](file:///D:/domixi/tb/tb_soc_dma_firewall_contract.v) | `2e2c71021e8de265ddb599f40a642ab356b9f550b050cc1b69f0d2562444d6f2` | FROZEN_BASELINE |
| [`tools/run_all_sims.py`](file:///D:/domixi/tools/run_all_sims.py) | `2f2358e1f422a8a6b474936109b56726ba070bd4e8b85187b566f3aef121e5c5` | VERIFICATION_HARNESS_TOOL |
| [`tools/run_mutation_testing.py`](file:///D:/domixi/tools/run_mutation_testing.py) | `034ec3ee3d965e6e193d26603fcca4b149a61c382ac6bfe7c0bce14b41ae09b4` | VERIFICATION_HARNESS_TOOL |
| [`tools/verify_formal.ps1`](file:///D:/domixi/tools/verify_formal.ps1) | `2acbd5154b39843f8dc6af657e121b5a8eb7901a18f740ffa36a451e9e21ed9f` | VERIFICATION_HARNESS_TOOL |
| [`tools/verify_verilator_lint.ps1`](file:///D:/domixi/tools/verify_verilator_lint.ps1) | `106169683100dd9d6bda01ed81aa18bebd0cd2cfbf65d8db7764732c40b03ced` | VERIFICATION_HARNESS_TOOL |

---

## 5. Bảng Băm Bằng Chứng Thực Nghiệm & Nhật Ký Kiểm Thử (Logs & Evidence Artifacts)

### 5.1. Nhật Ký 19 Mô Phỏng (`output/sim_regression/`)

| Tệp Nhật Ký | Kích Thước | SHA-256 Hash |
| :--- | :---: | :--- |
| [`output/sim_regression/tb_adversarial_m1.log`](file:///D:/domixi/output/sim_regression/tb_adversarial_m1.log) | 660 B | `ceb04f8e74b5fa6e9ecdbf8868e26e5e4a724a436d6b7460455ed41a8810ba34` |
| [`output/sim_regression/tb_aegis_picorv32_soc.log`](file:///D:/domixi/output/sim_regression/tb_aegis_picorv32_soc.log) | 2116 B | `4a696ba22a624c193506b4b869a3ecc31bc4a4268c28d763c9014698e39fc769` |
| [`output/sim_regression/tb_aegis_soc.log`](file:///D:/domixi/output/sim_regression/tb_aegis_soc.log) | 1891 B | `872cdc46a79bd82505daee2433f99821c43ec58d7ad4b5806e1475492e731177` |
| [`output/sim_regression/tb_aegis_soc_reset.log`](file:///D:/domixi/output/sim_regression/tb_aegis_soc_reset.log) | 112 B | `9b757c1d293184c463467f54369d0b88e2a4e20927ccb0e9171edbca141d5aa1` |
| [`output/sim_regression/tb_dma_bus_firewall.log`](file:///D:/domixi/output/sim_regression/tb_dma_bus_firewall.log) | 120742 B | `e68b8280e46402bd8e3a33c07a047345d5550a086dfa0f70212972c96ceb853e` |
| [`output/sim_regression/tb_fw_abnormal_stress.log`](file:///D:/domixi/output/sim_regression/tb_fw_abnormal_stress.log) | 953 B | `c78d50847dd766f1b5ca98d70d2843c0a831170074ea30c878f5f68818087d37` |
| [`output/sim_regression/tb_fw_acl_matcher.log`](file:///D:/domixi/output/sim_regression/tb_fw_acl_matcher.log) | 470 B | `b712b615a8a9442105e3b74d83085e5e76b89a994dc25915908ea2ff2f7780fa` |
| [`output/sim_regression/tb_fw_apb_regs.log`](file:///D:/domixi/output/sim_regression/tb_fw_apb_regs.log) | 89 B | `f8e2d7caf84637e074f8fc6d2becad35bc27bc0199c56397296b3157527db325` |
| [`output/sim_regression/tb_fw_axi_address_slice.log`](file:///D:/domixi/output/sim_regression/tb_fw_axi_address_slice.log) | 875 B | `9f79d99baff5855368ef3b82f9d49d2242d2db34155c0fd013a7964ee017198e` |
| [`output/sim_regression/tb_fw_closed_loop_ctrl.log`](file:///D:/domixi/output/sim_regression/tb_fw_closed_loop_ctrl.log) | 626 B | `5bf7e23e7cc490c364cb57faf626fce23c63599af1648b7425f53e5283d840ca` |
| [`output/sim_regression/tb_fw_context_tracker.log`](file:///D:/domixi/output/sim_regression/tb_fw_context_tracker.log) | 438 B | `fc789f49d4442432b3811504379eea9c2c13e5282a10eb908a781b3ffcec19b1` |
| [`output/sim_regression/tb_fw_data_path_mux.log`](file:///D:/domixi/output/sim_regression/tb_fw_data_path_mux.log) | 966 B | `d53911402b803e87b0bfa33b49c8e33cd52618981faff28011d305151a819741` |
| [`output/sim_regression/tb_fw_drain_fsm.log`](file:///D:/domixi/output/sim_regression/tb_fw_drain_fsm.log) | 90 B | `c79724f347f8d5fafb998c65a103e42a18fc1f0dae32868f14ca38854d87b0ef` |
| [`output/sim_regression/tb_fw_hdc_sense.log`](file:///D:/domixi/output/sim_regression/tb_fw_hdc_sense.log) | 2994 B | `699cb13df47b13c3a2f2fb8e0fae205bd1ca558d1ccf749fd8e5da7394c2b3ce` |
| [`output/sim_regression/tb_fw_hdc_sense_challenger2.log`](file:///D:/domixi/output/sim_regression/tb_fw_hdc_sense_challenger2.log) | 6246 B | `079f1f879cc65504a275c286b393e9f4c519b3e9d9e04452098697624a720114` |
| [`output/sim_regression/tb_fw_honeypot_sink.log`](file:///D:/domixi/output/sim_regression/tb_fw_honeypot_sink.log) | 305 B | `ac51707b21c29434d274d3d7b4d8f804e939c6ba023eeda4076301eb10fc6912` |
| [`output/sim_regression/tb_fw_read_drain.log`](file:///D:/domixi/output/sim_regression/tb_fw_read_drain.log) | 517 B | `5bb321b3eb25a0cb1b9ddb0819d376c2dc1ec6633e74c98e844037a7f32f10d4` |
| [`output/sim_regression/tb_fw_write_drain.log`](file:///D:/domixi/output/sim_regression/tb_fw_write_drain.log) | 426 B | `c7d8b740a70438fbd68d491df0927283d1e5a0f4f7276f969c65e0ef71619d02` |
| [`output/sim_regression/tb_soc_dma_firewall_contract.log`](file:///D:/domixi/output/sim_regression/tb_soc_dma_firewall_contract.log) | 142 B | `4702de6468110ac53d2d000a210b82a7b0e46bcea73fcc921695aeeebc2c7978` |

### 5.2. Nhật Ký Kiểm Thử Đột Biến (`output/mutation_testing/`)

| Tệp Nhật Ký / Báo Cáo | Kích Thước | SHA-256 Hash |
| :--- | :---: | :--- |
| [`output/mutation_testing/MUT-01-ACL-BYPASS.log`](file:///D:/domixi/output/mutation_testing/MUT-01-ACL-BYPASS.log) | 10779 B | `a59a76133bafd73c24cf6d02345c96d50d7d27d9ff93350fc028ed7b21d94994` |
| [`output/mutation_testing/MUT-02-WRITE-DRAIN-RESP.log`](file:///D:/domixi/output/mutation_testing/MUT-02-WRITE-DRAIN-RESP.log) | 20331 B | `0c6546c9f63a6ac5988a4fed8ccc75364560c6a41cca8f87737a1f3d50920f42` |
| [`output/mutation_testing/MUT-03-READ-DRAIN-RESP.log`](file:///D:/domixi/output/mutation_testing/MUT-03-READ-DRAIN-RESP.log) | 535 B | `ec15a4a6a87226d963d23692a57970b3090e125c053c073a1c4ad543a08dfa41` |
| [`output/mutation_testing/MUT-04-NMI-PULSE-SUPPRESS.log`](file:///D:/domixi/output/mutation_testing/MUT-04-NMI-PULSE-SUPPRESS.log) | 701 B | `473becfbf2316c3568f54b04af729b13b60ed039b34c8d14b2244bf076cb5544` |
| [`output/mutation_testing/MUTATION_AUDIT_REPORT.md`](file:///D:/domixi/output/mutation_testing/MUTATION_AUDIT_REPORT.md) | 1712 B | `54bb0686bd2ac67bac560d096b8d8ffbd2c07a2e35df72d58f10a99e3db51b8a` |
| [`output/mutation_testing/mutation_testing.log`](file:///D:/domixi/output/mutation_testing/mutation_testing.log) | 1296 B | `e0bb95cd2dc76bb9ab7ebde45d232cdbb3be4438efc910900271400f2ea9b94e` |

### 5.3. Bằng Chứng Báo Cáo Nghiệm Thu & Ma Trận

| Tài Liệu Bằng Chứng | Kích Thước | SHA-256 Hash |
| :--- | :---: | :--- |
| [`output/formal/verify_formal.log`](file:///D:/domixi/output/formal/verify_formal.log) | 72222 B | `503d8419d14b876d0b79afe1d3e06ba0333f502d5d6752706a13337ff6c32741` |
| [`output/coverage/coverage_database.json`](file:///D:/domixi/output/coverage/coverage_database.json) | 5879 B | `88b435869f1df61d00436d254cfd0a825760767767c0d048c48d08c20e3679f3` |
| [`output/coverage/VERIFICATION_COVERAGE_REPORT.md`](file:///D:/domixi/output/coverage/VERIFICATION_COVERAGE_REPORT.md) | 9229 B | `e6ea987ac82c8f6f76d72d766bfbc99f9df6638d4297c15c00325e5893472c43` |
| [`docs/evidence/REQUIREMENTS_VERIFICATION_AND_BOUNDARY_MATRIX.md`](file:///D:/domixi/docs/evidence/REQUIREMENTS_VERIFICATION_AND_BOUNDARY_MATRIX.md) | 13034 B | `9d47031b46c983e684d21654d61435fe325956e1ed13f96c14c21c6d1a07661f` |

---

## 6. Kết Luận Xác Minh Liên Kết Phiên Bản

1. **RTL Integrity:** Tất cả 21/21 tệp khớp sau chuẩn hóa CRLF/LF với release freeze commit `ba7a753`.
2. **Evidence Cryptographic Binding:** Toàn bộ 19 nhật ký mô phỏng, 9 bộ formal, 4 nhật ký đột biến và ma trận yêu cầu được gắn với mã băm SHA-256 cụ thể.
3. **Sign-off Readiness:** Toàn bộ hồ sơ truy vết đã hoàn tất và sẵn sàng để Kỹ sư trưởng Codex tiến hành thẩm định và ký duyệt nghiệm thu chính thức.
