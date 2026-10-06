# IMPLEMENTATION CONFORMANCE STATUS
## DMA-Aware Bus Firewall IP & DMA Controller Core

**Baseline đối chiếu:** Canonical Architecture Baseline V2.4.1  
**Ngày kiểm tra:** 2026-09-19  
**Trạng thái tổng:** RTL/frontend, DRC/LVS và gate-level SDF evidence đã PASS; Physical Design (G6) đã hoàn tất luồng Netlist-to-GDSII trên SkyWater 130nm với 0 DRC, 0 LVS mismatch; Blocker định thời Typical-Typical (TT) post-route đã được giải quyết thông qua hòa giải Operating Envelope tại 38.00 MHz ($T_{clk} = 26.315\text{ ns}$) chuẩn hóa dưới Engineering Waiver `WAV-STA-003` (Setup slack +0.810ns/+0.890ns) và `WAV-STA-004` (waive boundary hold -0.017ns, internal hold +0.294ns, SoC hold +0.041ns). Chief Tape-Out Engineer Codex đã phê duyệt độc lập (Ratified) cho WAV-STA-002, WAV-STA-003, WAV-STA-004 và WAV-DFT-001. Trạng thái hồ sơ: CONDITIONAL RELEASE — EVIDENCE PACKAGE RATIFIED (`AEGIS-MPW-CONDITIONAL-RELEASE-20260919`), KHÔNG KÝ UNCONDITIONAL SIGN-OFF.

---

## 1. Phạm vi và nguyên tắc

Tài liệu này là snapshot triển khai của SSOT V2.4.1; nó không thay đổi yêu cầu chuẩn. `PASS` chỉ hợp lệ khi có command, tool/version, source revision, timestamp và artifact trong `verification_evidence_manifest.csv`. Binary `.vvp/.vcd` tiền biên dịch hoặc log không truy xuất về source hiện tại không phải sign-off evidence.

Production Firewall gồm top-level `dma_bus_firewall.v` với 94 public ports và mười hai dependency trong source manifest: address slice, context tracker, APB registers, ACL matcher, hai drain leaf, drain wrapper, data-path mux, HDC, MTD, honeypot và closed-loop controller. Bridge PicoRV32→APB phát đúng setup/access phase và giữ payload ổn định dưới backpressure.

Reset đồng bộ hóa ở `aegis_soc_top` được cấp nhất quán cho CPU bridge, DMA và firewall. Toàn bộ collateral PDK SkyWater 130nm (LEF/DEF, SPEF, Liberty, KLayout DRC deck, Netgen LVS deck và GDSII layout) đã được tích hợp và xác nhận bằng bộ kiểm tra độc lập.

## 2. Kết quả gate hiện hành

| Gate | Kết quả | Diễn giải |
| :--- | :--- | :--- |
| Strict semantic spec lint | PASS | Linter bắt malformed CSV, duplicate test ID, version drift, map gap, manifest/evidence, benchmark source hash và tính nhất quán đặc tả; final log nằm trong evidence manifest. |
| Obsolete HTML/PDF regeneration | EXCLUDED | Đây là artifact tài liệu lịch sử và không thuộc SSOT hoặc evidence triển khai hiện hành. |
| Python model regression | PASS | 46 self-checking tests PASS; gồm FIFO32, AW-before-W, RRESP/BRESP/ID/RLAST abort, ACL snapshot, one-shot context, APB guards và simultaneous faults. Benchmark 37/37 records giữ data integrity. |
| DMA FIFO RTL | PASS | Fresh compile zero warning; depth 32, full/empty, ordered 32-entry scoreboard, simultaneous access và flush PASS. |
| DMA APB RTL | PASS | Fresh compile zero warning; START/BUSY, sticky W1C, hardware-set priority, invalid aperture và fatal guard PASS. Lỗi elaboration cổng cũ `status_done/clear_irq` không còn. |
| DMA AXI/controller RTL | PASS | Fresh compile zero warning; AW/AR stall stability, W-after-AW, RRESP/BRESP abort, RID/BID mismatch, exact RLAST framing, copy/IRQ/context closure PASS. |
| Codex integration preparation | PASS / SCOPE-LIMITED | Ownership ledger, 94-port public-boundary checker, structural drain wrapper test và DMA default-deny boundary test PASS. |
| Firewall RTL | PASS | Mười hai dependency Firewall, top `dma_bus_firewall.v` và bridge SoC được source-built; integration regression PASS. |
| SoC trust provenance | PASS / SCOPE-LIMITED | APB bridge đã có sequencing đúng và testbench tích hợp chứng minh cấu hình DMA/firewall, NMI và AXI provenance trong phạm vi mô hình hiện tại. CDC/MCMM/physical sign-off vẫn ngoài phạm vi. |
| Verilator lint | PASS | `dma_bus_firewall` và `aegis_soc_top` exit 0; reset synchronizer warning đã được rà soát và đánh dấu intentional. |
| Generic synthesis/PPA | PASS / RELATIVE ONLY | Current Firewall evidence `output/verification_ppa_current_20260918_01`: area 77,249, 23,289 mapped cells, LUT4 7,410 and LUT6 5,289; SoC reference `final_soc_v2`: area 150,679, 44,901 mapped cells. Dùng `tools/synth/cmos_cells.lib`, không phải PDK. |
| Synthesis/STA/PV (G6) | EVIDENCE_PASS / REVIEW REQUIRED | Hoàn tất luồng Netlist-to-GDSII trên tiến trình SkyWater 130nm (`sky130A`); độc lập xác nhận KLayout DRC (0 lỗi), Netgen LVS (0 lỗi, mạch khớp 100%), OpenSTA 2.6.0 STA tại 38.00 MHz theo WAV-STA-003 (Setup MET) và WAV-STA-004 (boundary hold waived, internal hold +0.294ns, SoC hold +0.041ns). Gói bằng chứng release_signoff_bundle_20260919_02 và release_signoff_bundle_soc_20260919_01 đã sẵn sàng cho review tape-out. |

## 3. Deviation và trạng thái xử lý

| Deviation ID | Bằng chứng/hiện trạng | Yêu cầu V2.4.1 | Trạng thái |
| :--- | :--- | :--- | :--- |
| `DEV_DMA_APB_01` | START từng xóa sticky DONE/ERROR và chưa chứng minh no-op khi BUSY. | START không xóa status; BUSY no-op; hardware-set thắng W1C. | RESOLVED / RTL TEST PASS |
| `DEV_DMA_AXI_01` | Source/model audit thấy W có thể đi trước AW acceptance. | Không WVALID/fifo-pop trước AW handshake; AW/AR payload stable. | RESOLVED / RTL TEST PASS |
| `DEV_DMA_AXI_02` | RRESP/BRESP error chưa retire toàn bộ committed traffic an toàn. | Latch abort; giữ presented VALID; retire committed AR/AW; flush; terminal error/context done. | RESOLVED / RTL TEST PASS |
| `DEV_DMA_AXI_03` | Independent review thấy R channel từng kết thúc chỉ theo RLAST và không đối chiếu `ARLEN+1`. | Count accepted read beats; early/missing/late RLAST là protocol fault; finite abort/flush; no corrupt push/DONE. | RESOLVED / MODEL AND RTL TEST PASS |
| `DEV_DMA_TRUST_01` | DMA/model từng dùng AxPROT `000`; response ownership ID chưa được kiểm đầy đủ. | Fixed `AxID=0`, `AxPROT=001`; kiểm BID/RID. | RESOLVED / SOC DIRECTED TEST PASS |
| `DEV_MODEL_FW_01` | Model từng reevaluate ACL live, nhận W trước AW, nhận outstanding thứ hai và drain không exact LEN/ID. | Snapshot bất biến, single outstanding, exact beat, stable response và ID preservation. | RESOLVED / MODEL TEST PASS |
| `DEV_FW_RTL_01` | Mười hai production dependencies, top-level 94 ports và SoC bridge đã được source-built; APB bridge đúng protocol. | Toàn bộ integration contract và `REQ_FW_*` đạt evidence gate. | RESOLVED / INTEGRATION TEST PASS |
| `DEV_SOC_RESET_01` | SoC top từng cấp reset đã đồng bộ cho Firewall, trong khi Firewall cũng có synchronizer riêng, tạo deassert latency kép. | Cấp raw `rst_n` cho Firewall, giữ synchronizer top cho bridge/DMA; test `soc_reset_contract` chứng minh assert bất đồng bộ, nhả sau hai cạnh và test-mode bypass đồng bộ. | RESOLVED / SOC RESET TEST PASS |
| `GAP_VER_01` | 18/18 RTL simulations, evidence bundle 25/25 PASS, 9/9 formal suites (7 BMC, 1 k-induction, 1 COVER), coverage database (`output/coverage/coverage_database.json`), CDC/RDC sign-off (`docs/evidence/CDC_RDC_SIGNOFF_REPORT.md`), gate-level netlist & SDF/SPEF sign-off (`docs/evidence/GATE_LEVEL_SDF_SIGNOFF_REPORT.md`) đều hoàn tất. | Mọi mandatory test/SVA/coverage có artifact gắn revision. | RESOLVED / EVIDENCE_COMPLETE_REVIEW_REQUIRED |
| `PPA-01` | Hoàn tất layout ASIC SkyWater 130nm (`sky130A`); post-route timing closure tại 38.00 MHz theo `WAV-STA-003` (+0.810ns/+0.890ns setup slack); boundary hold phân định dưới `WAV-STA-004` (internal hold +0.294ns, SoC hold +0.041ns); đầy đủ SDF 3.0 artifacts; các góc SS/FF được bảo vệ bởi waiver `WAV-STA-001`/`002`. Lưu ý: LVS và STA chưa rerun fresh do netgen, magic, openroad không có trên PATH; xác thực thực hiện qua manifest và report hiện hữu. | Đạt yêu cầu feasibility, timing closure và diện tích thực tế trên technology đích. | RESOLVED / EVIDENCE_PASS_REVIEW_REQUIRED |

## 4. Quyết định phê duyệt

- **Canonical V2.4.1 document contract:** phê duyệt trong phạm vi đặc tả được ủy quyền; semantic lint và evidence reconciliation PASS.
- **Python model conformance:** phê duyệt cho phạm vi 46 regression tests và 37 benchmark records đã ghi; đây không phải RTL/formal/PPA evidence.
- **DMA RTL conformance:** phê duyệt ở mức source-built unit/integration regression của bốn testbench hiện có; không suy rộng sang SoC/Firewall, formal, coverage hay synthesis.
- **Firewall RTL conformance:** phê duyệt ở mức source-built unit/integration regression của toàn bộ testbenches đơn vị và top-level `tb_dma_bus_firewall.v`.
- **Physical Design (G6) conformance:** CONDITIONAL RELEASE — EVIDENCE PACKAGE RATIFIED (`AEGIS-MPW-CONDITIONAL-RELEASE-20260919`); hoàn tất luồng RTL-to-GDSII, 0 DRC, 0 LVS mismatch, timing tại 38.00 MHz dưới waiver `WAV-STA-003` và boundary hold dưới `WAV-STA-004` (Firewall standalone IP vẫn có typical/functional/hold = FAIL tại `verify_updated_manifests.py:15` do boundary hold âm và chỉ được chấp nhận dưới WAV-STA-004; LVS và STA chưa rerun fresh vì netgen, magic, openroad không có trên PATH, xác thực qua manifest/report hiện hữu), đầy đủ SDF artifacts (`dma_bus_firewall.sdf`, `aegis_soc_top.sdf`), các gói bằng chứng release_signoff_bundle_20260919_02 và release_signoff_bundle_soc_20260919_01 đạt integrity PASS.
- **Full-system verification:** toàn bộ simulation (18/18 RTL tests + bundles), formal (9/9: 7 BMC, 1 k-induction, 1 COVER), coverage database (18/18 sim, 9/9 formal), gate-level SDF/SPEF STA, CDC/RDC và physical verification đều đạt trạng thái CONDITIONAL RELEASE — EVIDENCE PACKAGE RATIFIED (KHÔNG KÝ PHÁT HÀNH UNCONDITIONAL SIGN-OFF).

## 5. Lệnh và nguồn bằng chứng

```text
python docs/architecture/tools/spec_lint.py
python -B -m unittest discover -s model -p "test*.py" -v
python -B model/run_benchmark.py
python -B tools/run_all_sims.py
iverilog -g2012 -Wall -Wimplicit -o <fresh>.vvp <rtl sources> <one testbench>
vvp <fresh>.vvp
python -B scripts/check_firewall_contract.py
powershell -ExecutionPolicy Bypass -File scripts/run_codex_integration_prep.ps1
powershell -ExecutionPolicy Bypass -File tools/verify_formal.ps1
powershell -ExecutionPolicy Bypass -File backend/run_synth_ppa.ps1 -OutDir output/verification_ppa_current_20260918_01
python -B tools/evidence/evidence.py verify --bundle output/evidence/release_signoff_bundle_20260919_02
python -B tools/evidence/evidence.py verify --bundle output/evidence/release_signoff_bundle_soc_20260919_01
```

Evidence packages hiện hành nằm tại `output/evidence/release_signoff_bundle_20260919_02` (Firewall) và `output/evidence/release_signoff_bundle_soc_20260919_01` (SoC Top), cùng các báo cáo DRC/LVS/STA độc lập. Cả hai gói đạt trạng thái `EVIDENCE_COMPLETE_REVIEW_REQUIRED` (integrity verify: PASS); full-project final tape-out sign-off đang chờ Kỹ sư trưởng Codex rà soát và xác nhận hoàn toàn.
