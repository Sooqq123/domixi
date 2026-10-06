# Đặc tả tối ưu PPA portable cho FPGA đa họ và ASIC mở

> Trạng thái: thiết kế đã được duyệt để bàn giao triển khai
>
> Đối tượng: mô hình hoặc kỹ sư sẽ sửa RTL, chạy flow và nộp báo cáo nghiệm thu
>
> Phạm vi: `dma_bus_firewall` và các khối AEGIS liên quan trong repository này

## Kết luận

Thiết kế bàn giao dùng một RTL chung, sau đó đo bằng các backend độc lập cho từng họ FPGA và một flow ASIC dùng PDK mở. Không có một con số Fmax hoặc một con số area duy nhất đại diện cho mọi FPGA. Mỗi target phải có device, package, speed grade, constraint và baseline riêng.

Mục tiêu triển khai là giữ nguyên hành vi bảo mật và giao tiếp của firewall, đồng thời giảm logic nằm trên đường HDC, closed-loop và MTD. Các phép đo generic bằng `cmos_cells.lib` chỉ là proxy hồi quy. Chúng không được dùng để tuyên bố đã đạt signoff ASIC.

Mô hình nhận đặc tả này phải tự chạy baseline trước khi sửa, giữ lại manifest có hash nguồn và công cụ, sau đó mới tối ưu theo thứ tự trong tài liệu. Bản triển khai chỉ được gọi là đạt khi qua các gate chức năng, portability, timing và PPA của mọi target bắt buộc.

## Phạm vi và mục tiêu

### Trong phạm vi

- RTL của `rtl/dma_bus_firewall.v`, `rtl/fw_hdc_sense.v`, `rtl/fw_closed_loop_ctrl.v`, `rtl/fw_mtd_engine.v`, `rtl/fw_apb_regs.v` và các module mà chúng gọi.
- Script tổng hợp, constraint và adapter backend trong `backend/`, `constraints/` hoặc thư mục con mới có tên rõ ràng.
- Flow FPGA dùng công cụ miễn phí hoặc mã nguồn mở.
- Flow ASIC dùng PDK mở, ưu tiên Sky130HD qua OpenROAD-flow-scripts và OpenSTA.
- Regression, assertion và báo cáo đo PPA có thể tái lập.

### Ngoài phạm vi

- Không thay đổi giao thức AXI, APB, DMA hoặc giao diện top để đổi lấy area.
- Không tắt tính năng phát hiện Rowhammer, Bus Flooding, timing probe, MTD, Honey-pot, NMI hoặc các đường cưỡng chế an toàn trong bản shipping.
- Không dùng primitive độc quyền của một vendor trong RTL chung.
- Không tuyên bố DRC, LVS, parasitic signoff hoặc power signoff khi chưa có netlist, Liberty, SPEF, rule deck và backend tương ứng.
- Không so sánh trực tiếp LUT của FPGA với đơn vị area của ASIC.

## Bối cảnh và baseline phải được khóa

Các số liệu dưới đây là mốc hồi quy đã có trong repository. Nếu một artifact không còn trên máy chạy, mô hình triển khai phải chạy lại baseline và ghi artifact mới; không được tự điền số cũ vào manifest.

| Mốc | Giá trị hoặc trạng thái | Nguồn và cách hiểu |
|---|---:|---|
| Generic baseline của `dma_bus_firewall` | 42,792 đơn vị area, 14,052 cell | `.agents/tb_toolchain_survey/survey_verification_report.md`; chỉ là ước lượng với thư viện cell toy |
| Ngân sách proxy tăng thêm | 2,139.60 đơn vị, tương đương tổng 44,931.60 | Tính từ baseline generic với giới hạn tăng tối đa 5% |
| FPGA reference đã có | ECP5 out-of-context, 46.65 MHz, delay 21.43 ns | Cùng báo cáo survey; đây chỉ là một reference, không phải target duy nhất |
| Constraint tích hợp | clock 10 ns, uncertainty setup 0.1 ns, hold 0.05 ns | `constraints/dma_bus_firewall.sdc`; là giả định tích hợp sớm, chưa phải signoff |
| Regression gần nhất | 18 PASS, physical BLOCKED | `output/verification_readiness_20260915_05/regression/summary.json` |
| Generic synthesis hiện tại | Flow đọc `tools/synth/cmos_cells.lib`, chạy Yosys `dfflibmap`, `abc`, `stat` | `backend/run_synth_ppa.ps1`; manifest phải ghi rõ đây là `generic_cell_mapped_estimate` |

Mốc generic nêu trên là phép kiểm tra hồi quy bắt buộc vì nó đã được dùng để phát hiện phần cứng tăng diện tích. Tuy nhiên, kết luận cuối cùng phải dựa trên flow vật lý theo từng target. Nếu baseline và candidate không dùng cùng source manifest, cùng thư viện, cùng constraint và cùng phiên bản công cụ thì phép so sánh bị coi là không hợp lệ.

## Hợp đồng chức năng không được phá vỡ

### Giao tiếp và độ trễ

- Giữ nguyên port, hướng tín hiệu, độ rộng và reset của `dma_bus_firewall`.
- Giữ các quy tắc ready/valid: khi giao dịch bị stall, địa chỉ, dữ liệu, ID, response và trạng thái liên quan phải ổn định như baseline.
- Không thêm độ trễ quan sát được trên AXI hoặc APB. Nếu cần thêm một thanh ghi nội bộ để cắt đường timing, phải giữ nguyên chu kỳ handshake và chứng minh bằng assertion trước và sau tối ưu.
- `rst_n` vẫn là reset bất đồng bộ active-low ở biên IP; không dùng reset như một đường dữ liệu timing.

### Hành vi bảo mật

- Các mức `threat_level`, cảnh báo anomaly, `aegis_nmi_irq`, `honey_hit`, địa chỉ biến hình và quyết định drain phải giữ nguyên ý nghĩa trong các kịch bản regression.
- Bộ đếm phải giữ độ rộng, điều kiện saturate hoặc wrap và thời điểm cập nhật đã được đặc tả.
- Dấu vân tay đọc qua APB phải vẫn xác định với cùng một chuỗi sự kiện. Nếu thuật toán fingerprint thay đổi, phải tăng version và thêm test tương thích, không được đổi âm thầm.
- “1024-bit HDC” trong tài liệu kiến trúc là không gian logic. Không được suy ra rằng phải tạo một mạng popcount 1024 bit đầy đủ trong một chu kỳ nếu điều đó phá vỡ ngân sách. Bản tối ưu có thể dùng projection hoặc signature có độ rộng hữu hạn, nhưng phải bảo toàn đầu ra và các ngưỡng phát hiện được cam kết.

### Bản đồ thanh ghi

Nguồn đặc tả `docs/AEGIS_SPEC_BASELINE.md` quy định:

- `0x090`: `REG_AEGIS_STATUS`
- `0x094`: `REG_AEGIS_FINGERPRINT`
- `0x098`: `REG_AEGIS_HONEY_COUNT`

Trước khi sửa `rtl/fw_apb_regs.v`, phải kiểm tra bản đồ đang có trong RTL và testbench. Nếu RTL hiện tại dùng offset khác, đó là lỗi hợp đồng cần xử lý bằng cách chuyển sang offset chuẩn hoặc thêm alias có test hồi quy. Không được tự chọn một trong hai bản đồ mà không ghi quyết định và test tương ứng.

## Kiến trúc flow portable

```text
RTL chung, không primitive vendor
        |
        +--> Yosys generic LUT4 và LUT6, kiểm tra logic độc lập backend
        |
        +--> profile FPGA iCE40, ECP5 và profile thứ ba nếu backend ổn định
        |       +--> family synthesis
        |       +--> nextpnr hoặc vendor-free backend tương ứng
        |       +--> timing, resource, route legality
        |
        +--> profile ASIC Sky130HD
                +--> OpenROAD-flow-scripts
                +--> OpenSTA
                +--> area, timing, power từ Liberty và VCD
```

### Luật RTL chung

1. Chỉ dùng SystemVerilog synthesizable được Yosys và simulator hiện có chấp nhận.
2. Ghi rõ độ rộng mọi hằng số và biểu thức số học. Tránh phép chia, modulo biến thiên, multiplier lớn, mảng unpacked có kích thước động và cấu trúc chỉ được một vendor suy luận.
3. Không dùng `initial`, delay, `real`, DPI, `$display` trong datapath shipping hoặc primitive như `SB_*`, `TRELLIS_*`, `XPM_*`, `AL_*` trong RTL chung.
4. Chỉ dùng một clock và clock enable. Không tạo gated clock bằng logic RTL.
5. Bất kỳ attribute phục vụ BRAM, DSP hoặc packing phải nằm trong adapter của target, không nằm trong module bảo mật chung.
6. Giữ kết quả tổng hợp xác định: không phụ thuộc seed ngẫu nhiên để đạt gate. Nếu backend có seed, ghi seed và chạy ít nhất ba seed khi chênh lệch gần ngưỡng.
7. Dùng tham số compile-time cho thí nghiệm A/B, nhưng flow shipping chỉ elaborate đúng một nhánh để tránh giữ cả baseline lẫn candidate trong mạch.

### Target FPGA tối thiểu

Phải có ít nhất hai profile backend ổn định, trong đó một profile không phải ECP5. Mốc tối thiểu đề xuất là:

| Profile | Vai trò | Ghi chú |
|---|---|---|
| iCE40 HX8K hoặc thiết bị tương đương được nextpnr hỗ trợ ổn định | Reference ngoài ECP5 | Ghi device, package và speed grade thực tế |
| ECP5 của baseline hiện có | Reference tương thích lịch sử | Không được coi là đại diện cho mọi FPGA |
| Gowin, Nexus hoặc họ khác có backend hoạt động | Khuyến nghị | Chỉ đưa vào gate khi toolchain và constraint được kiểm chứng |

Không được nói “đạt cho mọi FPGA” chỉ vì hai profile trên cùng pass. Kết luận đúng là “RTL portable trên các profile đã đo”; target mới phải chạy đầy đủ flow riêng.

## Thay đổi RTL được phép và thứ tự ưu tiên

### Bước 0: tạo baseline bất biến

- Chạy regression chức năng và formal hiện có.
- Chạy generic Yosys với đúng `tools/synth/cmos_cells.lib` và source manifest hiện hành.
- Với mỗi profile FPGA, chạy synthesis và PnR candidate baseline ở cùng constraint.
- Nếu có PDK, chạy ASIC baseline ở cùng Liberty, SDC và corner.
- Lưu `run_manifest.json` gồm commit hoặc tree hash, SHA-256 source, SHA-256 constraint và library, lệnh đầy đủ, phiên bản tool, device, seed, warning count và trạng thái.
- Chụp thống kê theo module để biết thay đổi nào thật sự làm PPA tốt hơn.

### Bước 1: thu gọn HDC mà không đổi hợp đồng quan sát

`rtl/fw_hdc_sense.v` là điểm ưu tiên cao vì có nhiều phép toán rộng và các matcher song song.

- Thay chuỗi cộng ARX 32 bit bằng XOR, rotate cố định, fold theo word và một tầng trộn nhỏ hơn. Không dùng carry chain rộng nếu không cần cho hành vi công khai.
- Chỉ cập nhật signature khi có `valid`, anomaly hoặc sự kiện bus cần ghi nhận. Khi không có sự kiện, giữ thanh ghi bằng clock enable.
- Dùng một đường so sánh hoặc một bộ đếm popcount được chia sẻ cho các prototype nếu vẫn giữ được độ trễ quan sát và ngưỡng phát hiện.
- Nếu giảm từ không gian logic 1024 bit xuống signature 32 hoặc 64 bit, phải ghi rõ hàm ánh xạ, version fingerprint và chứng minh trên toàn bộ trace regression. Không được chỉ so sánh một vài vector ngẫu nhiên.
- Các matcher không tham gia trực tiếp vào quyết định `threat_level` phải được loại bỏ hoặc gate trong bản shipping sau khi đã chứng minh chúng không tạo tác dụng phụ. Nếu chúng là một phần của fingerprint công khai, giữ một bản triển khai tương thích có tài liệu.

### Bước 2: chia sẻ trạng thái closed-loop

`rtl/fw_closed_loop_ctrl.v` phải ưu tiên giảm số thanh ghi và mux, không giảm khả năng phản ứng.

- Tái sử dụng vùng lưu trữ APB hiện có cho status, fingerprint, honey count và thông tin forensic thay vì tạo bản sao ở nhiều module.
- Gom các trường có cùng thời điểm cập nhật vào một thanh ghi có clock enable chung; loại bỏ reset riêng nếu giá trị reset có thể tạo bằng logic hằng an toàn.
- Giữ nguyên độ rộng và semantics của `quarantine_mask`, bộ đếm attack, threat tối đa, MID cuối và xung NMI trong profile shipping.
- Có thể tạo một profile ablation `AEGIS_QUARANTINE_ENABLE=0` để đo phần đóng góp area, nhưng profile này chỉ dùng phân tích, không được dùng làm kết quả nghiệm thu bảo mật.

### Bước 3: làm gọn MTD và Honey-pot

`rtl/fw_mtd_engine.v` có thể tối ưu mà ít rủi ro hơn nếu giữ nguyên chuỗi địa chỉ và trạng thái.

- Chia sẻ một LFSR và một bộ cộng cho các lần cập nhật không đồng thời.
- Chỉ chạy LFSR, jitter counter và honey counter khi có transaction hoặc event tương ứng.
- Giữ nguyên seed reset, đa thức LFSR, điều kiện morph, điều kiện force drain và xung `honey_hit`.
- Tránh multiplier hoặc phép toán modulo tổng quát; dùng mask, truncate và hằng số đã kiểm chứng.

### Bước 4: cắt đường timing tại điểm đã latch

Đường `AXI input -> detector -> MTD -> output` phải được phân tích sau synthesis và sau PnR.

- Tận dụng địa chỉ và metadata đã latch trong `fw_axi_address_slice` để tính decision.
- Có thể register `morph_select`, `threat_action` hoặc tín hiệu tương tự tại biên transaction để giảm logic trên một chu kỳ, miễn là ready/valid và địa chỉ output không đổi về mặt quan sát.
- Không đẩy logic bảo mật sang một chu kỳ mới nếu làm thay đổi thời điểm NMI, drain hoặc response mà testbench đang cam kết.
- Kiểm tra path logic và routing riêng; không kết luận timing chỉ từ số LUT.

### Bước 5: giảm switching

- Dùng clock enable cho fingerprint, counters, LFSR, matcher và quarantine state.
- Không đổi clock frequency hoặc duty cycle để làm đẹp power.
- Tạo ba workload cố định: normal DMA, rowhammer 5,000 burst và timing/probe. Dùng cùng trace cho baseline và candidate.

## Quy trình đo bằng tools miễn phí

### Generic Yosys

Flow hiện hành trong `backend/run_synth_ppa.ps1` là phép hồi quy cell-mapped. Mô hình triển khai phải giữ flow này để so sánh lịch sử, đồng thời thêm hai run generic:

- `abc -lut 4` để đại diện kiến trúc LUT4.
- `abc -lut 6` để đại diện kiến trúc LUT6.

Mỗi run phải xuất netlist, statistics, log, manifest và warning summary. `cmos_cells.lib` không có thông tin parasitic, delay hoặc power đầy đủ; vì vậy chỉ được ghi là proxy.

### FPGA synthesis và PnR

Mỗi profile phải có một file cấu hình mô tả:

- top module và source manifest;
- device, package, speed grade;
- clock pin hoặc clock constraint, I/O constraint và false path;
- lệnh Yosys family synthesis;
- lệnh nextpnr hoặc backend tương ứng;
- seed, effort, version tool và thư mục artifact.

Đo tối thiểu: LUT hoặc ALM, FF, carry, BRAM, DSP, IO, tổng resource, critical path, logic delay, routing delay, Fmax, route legality và timing violations. Nếu backend không cung cấp một chỉ số, ghi `unknown`, không thay bằng zero.

### ASIC Sky130HD

Flow tham chiếu là OpenROAD-flow-scripts với OpenROAD và OpenSTA. Dùng cùng RTL, cùng SDC 10 ns ở giai đoạn sớm và cùng VCD cho baseline và candidate. Khi có corner thực tế, báo cáo setup, hold, cell area, core area, wirelength, congestion, dynamic power và leakage riêng.

Nếu máy chạy không có OpenROAD, OpenSTA hoặc PDK, trạng thái ASIC phải là `BLOCKED` hoặc `NOT_RUN`. Không được suy ra timing ASIC từ `cmos_cells.lib` hoặc từ Fmax FPGA.

### Power

- ASIC: tạo VCD từ đúng ba workload, dùng activity trong OpenSTA hoặc flow power tương ứng, ghi corner và thời gian cửa sổ.
- FPGA: với tools miễn phí, resource và toggle proxy là thông tin tham khảo. Không gọi đó là power signoff. Nếu có board đo được dòng, ghi board, voltage, clock, firmware, nhiệt độ và cách lấy mẫu.
- Không dùng workload khác nhau cho baseline và candidate.

## Gate nghiệm thu

Tất cả gate bắt buộc phải pass. Một kết quả chỉ pass generic hoặc chỉ pass một FPGA là `PARTIAL`, không phải nghiệm thu cuối.

| Gate | Điều kiện bắt buộc | Bằng chứng phải nộp |
|---|---|---|
| Chức năng | Regression hiện hành không có FAIL mới; giữ các kiểm tra APB, AXI, drain, MTD, HDC, closed-loop, SoC và NMI | log, summary, waveform khi test yêu cầu |
| Formal và lint | Không có assertion mới bị bỏ qua; lint không có lỗi chưa phân loại | log tool và danh sách waiver |
| Register contract | Ba offset AEGIS chuẩn và alias tương thích, nếu có, đều được test | testbench và map report |
| Generic proxy | Area không vượt 44,931.60 đơn vị trên cùng baseline 42,792; báo cell count và warning | `run_manifest.json`, statistics, log |
| FPGA profile 1 | Resource tổng không vượt 105% baseline profile; Fmax không thấp hơn 97% baseline; route hợp lệ | synthesis report, PnR report, timing report |
| FPGA profile 2 | Cùng điều kiện như profile 1 trên một họ khác | artifact riêng theo target |
| ASIC | Có PDK và backend thật; area không vượt 105% baseline ASIC; setup và hold pass ở clock yêu cầu; power dynamic không vượt 105% baseline khi đã có flow power | OpenROAD/OpenSTA report, Liberty, SPEF, VCD |
| Portability | Cùng RTL chung compile trên mọi profile bắt buộc; không có primitive vendor trong source chung | source scan và manifest |
| Reproducibility | Lặp lại cùng command và source hash cho kết quả tương đương; seed phải được ghi | manifest và diff report |

Ngưỡng 5% cho ASIC và FPGA là ngưỡng tương đối so với baseline cùng target. Ngưỡng 5% generic là giới hạn hồi quy lịch sử, không phải diện tích silicon thật. Khi chưa có baseline power ASIC, power chỉ ở trạng thái `PROVISIONAL` và chưa đủ để tuyên bố signoff.

## Checklist cho mô hình triển khai

1. Đọc đặc tả này, `docs/AEGIS_SPEC_BASELINE.md`, `backend/verification_readiness.md` và source manifest trước khi sửa.
2. Xác nhận `.codegraph/` tồn tại và tạo snapshot source hash.
3. Chạy toàn bộ baseline chức năng, formal, generic Yosys và các profile FPGA khả dụng. Ghi mọi tool thiếu thành `BLOCKED`.
4. Tạo ablation riêng cho HDC, closed-loop, MTD và timing cut để biết lợi ích của từng thay đổi.
5. Triển khai tối ưu theo thứ tự Bước 1 đến Bước 5, giữ mỗi thay đổi nhỏ và có commit hoặc artifact nhận diện được.
6. Sau mỗi bước, chạy lint, module test liên quan và generic synthesis. Nếu chức năng hỏng hoặc area tăng ngoài dự kiến, quay lại candidate trước đó.
7. Chạy regression SoC và các trace normal, rowhammer 5,000 burst, timing probe; so sánh output theo cycle với baseline.
8. Chạy đủ hai FPGA profile tối thiểu, sau đó chạy Sky130 nếu môi trường có PDK và backend.
9. Xuất báo cáo dạng máy đọc được với các trường `target`, `device`, `tool_versions`, `source_hashes`, `constraints_hash`, `area`, `resources`, `timing`, `power`, `warnings`, `status` và `limitations`.
10. Nộp bảng PASS, PARTIAL, BLOCKED cho từng gate. Không gộp `unknown` vào PASS.

## Quy tắc lỗi và rollback

- Bất kỳ thay đổi nào làm sai giao thức, bản đồ thanh ghi, thời điểm NMI, Honey-pot hoặc drain đều bị loại dù PPA tốt hơn.
- Nếu generic pass nhưng một FPGA profile fail, candidate chưa portable và không được phát hành.
- Nếu FPGA pass nhưng ASIC thiếu PDK hoặc fail timing, chỉ ghi `FPGA_PPA_PASS` và `ASIC_BLOCKED` hoặc `ASIC_FAIL`.
- Nếu warning synthesis che giấu cell blackbox, undriven signal hoặc fallback mapping, run bị `REVIEW` cho đến khi phân loại.
- Không nới constraint, đổi clock, đổi workload hoặc đổi device để biến một kết quả fail thành pass mà không tạo một baseline mới và ghi rõ lý do.

## Tiêu chí kết thúc bàn giao

Mô hình triển khai hoàn tất khi đã có:

- RTL tối ưu và testbench hoặc assertion cập nhật;
- generic LUT4, LUT6 và cell-mapped report;
- ít nhất hai FPGA report theo target riêng;
- ASIC report hoặc bằng chứng `BLOCKED` nêu rõ thiếu PDK/backend;
- manifest có hash, command, version và limitation;
- bảng gate cuối cùng không có trạng thái bị che giấu.

Đây là tiêu chí để tôi nghiệm thu bản triển khai sau đó. Việc có một netlist hoặc một báo cáo area đơn lẻ không đủ để nghiệm thu.

## Tài liệu tham chiếu

- [AEGIS baseline specification](../../../docs/AEGIS_SPEC_BASELINE.md)
- [Verification readiness](../../../backend/verification_readiness.md)
- [Generic synthesis runner](../../../backend/run_synth_ppa.ps1)
- [Yosys `synth_ecp5` documentation](https://yosyshq.readthedocs.io/projects/yosys/en/0.31/cmd/synth_ecp5.html)
- [nextpnr project and supported backends](https://github.com/YosysHQ/nextpnr)
- [nextpnr constraints](https://github.com/YosysHQ/nextpnr/blob/main/docs/constraints.md)
- [OpenROAD-flow-scripts documentation](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/blob/master/docs/index.md)
- [OpenSTA documentation and changelog](https://openroad.readthedocs.io/en/latest/main/src/sta/doc/ChangeLog.html)
