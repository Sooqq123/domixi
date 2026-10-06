---
title: DMA-Aware Bus Firewall cho AEGIS SoC
subtitle: Hồ sơ thiết kế vi mạch bảo mật TKVM 2026
version: Bản phát hành kỹ thuật 1.1
---

# Tóm tắt hồ sơ

Đề tài xây dựng một khối **DMA-Aware Bus Firewall** đặt trên đường giao dịch AXI, có khả năng phân biệt giao dịch hợp lệ và giao dịch vi phạm chính sách ngay tại phần cứng. Firewall được tích hợp với DMA Controller và nền tảng AEGIS SoC để kiểm chứng từ mức RTL đến physical design. Mục tiêu không phải thay thế toàn bộ cơ chế bảo mật phần mềm, mà tạo một lớp chặn và phản ứng gần tài nguyên được bảo vệ, nơi hành vi DMA có thể vượt qua CPU và hệ điều hành.

Thiết kế dùng hai đường xử lý. Fast path quyết định tất định theo địa chỉ, thuộc tính giao dịch và policy; analysis path thu thập telemetry, phân loại hành vi đáng ngờ bằng HDC và cập nhật policy cho các giao dịch tiếp theo. Cấu trúc này giữ phân tích hành vi ra khỏi critical path của lưu lượng an toàn.

Bộ kiểm thử ghi nhận **25/25 bài kiểm thử PASS**. Trong đó, 23 bài là kiểm thử production hoặc unit có thể dùng làm bằng chứng kỹ thuật. Hai bài `MOCK_INTEGRATION` chỉ được dùng để truy xuất và không chứng minh firewall production.

Bằng chứng physical ghi nhận DRC 0 vi phạm cho `aegis_soc_top` và firewall độc lập. Tại corner TT, 25 °C, 1.80 V, SoC có setup slack `+0.89 ns` và hold slack `+0.041 ns` ở 38 MHz. Đây là TT operating point, không phải MCMM signoff. Firewall độc lập có setup slack `+0.81 ns`, hold WNS `-0.02 ns` và hold TNS `-0.07 ns` theo boundary hold waiver.

LVS của firewall và AEGIS SoC top đều có raw Netgen log kết thúc bằng `Circuits match uniquely`. Với SoC, raw log ghi 29.957 devices và 30.422 nets ở cả layout và schematic, không có pin, net hoặc device mismatch; parser nghiêm ngặt đã sinh `lvs.rpt` với trạng thái `PASS/MATCHED`.

> [TRẠNG THÁI BẰNG CHỨNG] Báo cáo mang trạng thái `EVIDENCE_COMPLETE_REVIEW_REQUIRED` vì physical evidence vẫn là kết quả được báo cáo cần xem xét theo phạm vi hồ sơ. Các kết quả được đối soát với raw LVS SoC, `lvs.rpt`, manifest và hash của dự án. Quá trình biên soạn không chạy lại DRC, LVS hoặc STA; DRC 0 và timing TT được giữ theo đúng corner.

## Phạm vi nộp

Lần nộp này chỉ gồm **một tệp PDF báo cáo**. PDF trình bày ý tưởng, mục tiêu bảo vệ, kiến trúc, thiết kế logic và RTL, kết quả mô phỏng, dạng sóng, layout, GDS/GDSII, DRC, LVS, timing và PPA.

RTL, testbench, waveform gốc, GDS/GDSII, log DRC/LVS/timing và manifest SHA256 là các nguồn đối soát của dự án. Những tệp này không phải tệp nộp kèm trong lần nộp PDF này.

<!-- pagebreak -->

# 1. Ý tưởng và đóng góp

## 1.1. Bài toán

DMA giúp truyền dữ liệu mà không cần CPU tham gia vào từng nhịp. Chính đặc tính này cũng tạo ra một đường truy cập bộ nhớ có thể nằm ngoài các kiểm tra thông thường của phần mềm. Một DMA master cấu hình sai, bị chiếm quyền hoặc phát giao dịch bất thường có thể đọc, ghi hoặc tạo tải lặp trên vùng nhạy cảm trước khi phần mềm phản ứng.

Đề tài giải quyết bài toán bằng một firewall nhận biết ngữ cảnh DMA. Khối này quan sát các kênh địa chỉ AXI, chụp thuộc tính giao dịch, đối chiếu policy và chọn một hành động rõ ràng trước khi giao dịch đi tới bộ nhớ được bảo vệ. Khi phát hiện vi phạm, thiết kế có thể deny, drain, rate-limit, redirect sang Honey-Pot hoặc phát tín hiệu cảnh báo tùy mức đe dọa.

## 1.2. Đóng góp kỹ thuật

Đóng góp chính là một chuỗi bảo vệ thống nhất từ giao dịch đến bằng chứng:

1. Fast path kiểm tra ACL, master ID, thuộc tính bảo vệ và biên giao dịch theo luật tất định.
2. Analysis path nhận telemetry sideband, dùng HDC 1024 chiều với lane vật lý 64 bit để đánh giá mẫu đáng ngờ mà không buộc safe traffic chờ kết quả.
3. Closed-loop controller duy trì threat score, phản ứng theo mức và ghi forensic record.
4. Honey-Pot AXI sink hấp thụ giao dịch bị chuyển hướng và trả response đúng hợp đồng giao thức.
5. Môi trường kiểm chứng SoC tích hợp PicoRV32, APB bridge, DMA Controller, firewall thật và AXI memory model để kiểm tra đường điều khiển đầu cuối.
6. Hồ sơ kỹ thuật nối kết RTL, testbench, log, waveform, layout, GDS, DRC, LVS và timing bằng manifest SHA256 của dự án.

Hồ sơ kết hợp nhận biết giao dịch DMA, policy theo vùng, phân tích telemetry ngoài critical path và kiểm chứng đối kháng ở cấp SoC trong cùng một kiến trúc có thể tổng hợp.

## 1.3. Giới hạn tuyên bố

Baseline đặt `DRAM_MAP_VALID=0`. Vì vậy, hồ sơ chứng minh khả năng nhận biết **row-thrashing và mẫu truy cập giống Rowhammer**, không tuyên bố phát hiện Rowhammer vật lý khi chưa có ánh xạ channel, bank và row của DRAM được kiểm chứng. CPU smoke test cũng không được diễn giải thành ISA compliance.

<!-- pagebreak -->

# 2. Mục tiêu bảo vệ và mô hình đe dọa

## 2.1. Tài sản cần bảo vệ

- Tính bí mật và toàn vẹn của vùng nhớ phía sau AXI firewall.
- Tính đúng đắn của giao dịch AXI dưới backpressure, deny và drain.
- Tính sẵn sàng của safe traffic khi analysis path đang xử lý telemetry.
- Policy, forensic record và trạng thái quarantine được điều khiển qua APB4.
- Khả năng truy nguyên sự kiện từ tín hiệu vi phạm đến phản ứng phần cứng.

## 2.2. Tác nhân và hành vi

| Nguy cơ | Điểm quan sát | Phản ứng thiết kế | Giới hạn |
|---|---|---|---|
| Truy cập ngoài vùng ACL | AXI AW/AR và region policy | Deny, drain, ghi sự kiện | Phụ thuộc policy đã cấu hình |
| Sai master ID hoặc PROT | Thuộc tính giao dịch | Deny và cảnh báo | Không thay thế secure boot |
| Burst vượt biên hoặc profile | Address slice | Chặn trước khi forward | AXI constrained profile |
| Tần suất truy cập bất thường | Telemetry, HDC và MTD rate logic | Rate-limit hoặc quarantine | Ngưỡng do policy quyết định |
| Row-thrashing luân phiên | Row index logic và telemetry | Redirect hoặc drain | Không phải bằng chứng Rowhammer vật lý |
| Probe né tránh | Telemetry và adversarial tests | Cập nhật threat score | Không tuyên bố bao phủ mọi chiến thuật |

## 2.3. Mục tiêu bắt buộc

Thiết kế phải giữ output AXI ổn định khi `valid=1` và `ready=0`, hoàn tất hoặc drain giao dịch bị deny, không để analysis path kéo `ready` của safe traffic xuống và không âm thầm bỏ telemetry khi queue đầy. Các thay đổi bảo mật qua APB chỉ hợp lệ với request secure privileged theo hợp đồng kiến trúc.

## 2.4. Ngoài phạm vi

Hồ sơ không tuyên bố chống mọi kênh kề, không cung cấp chứng nhận sản xuất và không thay thế memory controller có ánh xạ DRAM. Những giới hạn này giữ ranh giới giữa kết quả đã kiểm chứng và định hướng phát triển.

<!-- pagebreak -->

# 3. Kiến trúc thiết kế

[[FIGURE:architecture_soc|Sơ đồ kiến trúc logic của DMA-Aware Bus Firewall trong AEGIS SoC]]

## 3.1. Luồng giao dịch

DMA Controller được CPU cấu hình qua APB và phát giao dịch AXI. Address slice chụp riêng AW và AR, kiểm tra kích thước, burst, overflow và biên 4 KB. ACL matcher kết hợp địa chỉ với master ID và thuộc tính bảo vệ. Context tracker bổ sung trạng thái theo nguồn giao dịch. Kết quả policy đi vào action selector để chọn pass, deny, rate-limit hoặc redirect.

Giao dịch hợp lệ đi qua protected AXI egress. Giao dịch bị deny được các drain FSM hoàn tất theo đúng kênh write hoặc read, tránh để bus treo. Giao dịch redirect đi tới Honey-Pot sink. Telemetry chỉ đi trên sideband vào analysis queue, HDC và closed-loop controller.

## 3.2. Tách fast path và analysis path

Fast path chịu trách nhiệm cho các quyết định có luật rõ ràng và cần phản ứng ngay. Analysis path xử lý mẫu hành vi theo thời gian. HDC dùng hypervector logic 1024 bit nhưng tái sử dụng lane vật lý 64 bit qua các chunk và prototype, giảm tài nguyên so với datapath 1024 bit song song.

Kết quả analysis không được thay đổi action của giao dịch đã chốt. Nó cập nhật threat policy cho giao dịch sau, nhờ đó safe traffic không mang thêm độ trễ do HDC. Khi telemetry queue đầy, thiết kế phải ghi nhận overrun và nâng mức kiểm soát thay vì bỏ mẫu không dấu vết.

## 3.3. Phản ứng và forensics

Closed-loop controller nhận sự kiện từ fast path và HDC, cập nhật threat score theo master, phát NMI hoặc IRQ khi cần, đồng thời lưu forensic snapshot. APB4 cung cấp đường đọc trạng thái, pop FIFO và thao tác phục hồi được cho phép. Cơ chế khóa sticky ngăn policy bị thay đổi ngoài hợp đồng sau secure boot.

<!-- pagebreak -->

# 4. Kiến trúc DMA-aware bus firewall

## 4.1. Các khối chức năng

| Khối RTL | Vai trò |
|---|---|
| `fw_axi_address_slice` | Chụp AW/AR, kiểm tra profile, overflow và biên 4 KB |
| `fw_acl_matcher` | Đối chiếu vùng địa chỉ, master ID và thuộc tính truy cập |
| `fw_context_tracker` | Duy trì ngữ cảnh và thống kê theo nguồn giao dịch |
| `fw_data_path_mux` | Chọn đường pass, deny hoặc redirect |
| `fw_write_drain`, `fw_read_drain` | Tiêu thụ giao dịch bị chặn mà vẫn giữ hợp đồng AXI |
| `fw_drain_fsm` | Điều phối vòng đời drain |
| `fw_hdc_sense` | Phân tích telemetry bằng HDC |
| `fw_closed_loop_ctrl` | Cập nhật mức đe dọa, cảnh báo và forensic FIFO |
| `fw_honeypot_sink` | Kết thúc giao dịch redirect bằng response hợp lệ |
| `fw_mtd_engine` | Hỗ trợ policy phản ứng và moving-target defense |
| `fw_apb_regs` | Thanh ghi cấu hình và quan sát |
| `dma_bus_firewall` | Tích hợp các khối thành IP firewall production |

## 4.2. Quyết định ở biên giao dịch

AW và AR được xử lý độc lập vì hai kênh có thể bị backpressure khác nhau. Thông tin địa chỉ phải được chụp tại handshake và giữ ổn định cho đến khi action được chốt. Với write, thiết kế quản lý đồng thời địa chỉ, dữ liệu và response. Với read, drain phải trả đủ beat theo chiều dài burst đã nhận hoặc phát response lỗi theo profile đã định.

## 4.3. Fail-safe và protocol safety

Khi policy không hợp lệ hoặc phát hiện profile ngoài phạm vi, thiết kế ưu tiên không forward giao dịch tới protected memory. Tuy vậy, chặn không đồng nghĩa bỏ transaction. Các drain path tạo điểm kết thúc có kiểm soát, nhờ đó master không bị treo và các kênh AXI không mất ownership.

## 4.4. Khả năng phát triển

Kiến trúc tách policy, telemetry và action nên có thể mở rộng số vùng ACL, thay đổi ngưỡng hoặc ánh xạ DRAM mà không viết lại toàn bộ datapath. Mọi thay đổi prototype HDC, feature encoding hoặc fingerprint phải tăng version và tạo lại golden vectors trước khi trở thành bằng chứng kỹ thuật mới.

<!-- pagebreak -->

# 5. Thiết kế logic và RTL

## 5.1. Nguồn dữ liệu lập báo cáo

Các số liệu RTL và kiểm thử được lấy trực tiếp từ manifest của các bài kiểm thử production. Cách đối soát này tránh dùng nhầm source mock chỉ vì tên hoặc vị trí của tệp. Các source dưới `mocks/` bị loại khỏi cơ sở bằng chứng. Hai constraint `aegis_soc_top.sdc` và `dma_bus_firewall.sdc` được dùng để xác định điều kiện timing. Các source và constraint là dữ liệu nền của dự án, không phải tệp nộp kèm PDF.

Production RTL bao gồm DMA APB slave, AXI master, FIFO và controller; các khối firewall; PicoRV32; APB bridge; cùng `aegis_soc_top`. Testbench đi kèm được tách sang thư mục riêng. Mỗi tệp sao chép giữ nguyên SHA256 so với nguồn.

## 5.2. Nguyên tắc thiết kế tuần tự

Các quyết định action được chốt theo transaction, không tính lại tùy tiện khi bus stall. State machine của drain tách read và write để xử lý đúng số beat. Threat state, counter và forensic pointer chỉ cập nhật tại điều kiện enable rõ ràng. Reset giữa transaction phải trả ownership về trạng thái an toàn và không forward request chưa hoàn tất.

## 5.3. Tích hợp SoC

`aegis_soc_top` ghép PicoRV32, APB bridge, DMA Controller và firewall production. Top RTL đưa nhóm cổng `ext_mem` và `m_axi` ra biên tích hợp; nó không chứa RAM. Testbench `soc_real_integration` nối memory model vào các cổng này, chạy firmware cấu hình hai APB target, khởi động transfer và quan sát trap hoặc NMI. Bài kiểm thử dùng firewall production, không dùng firewall stub.

## 5.4. Quy tắc truy xuất

Mỗi khẳng định trong báo cáo phải trỏ được về ít nhất một trong bốn lớp: source RTL, log mô phỏng, waveform hoặc physical report. Manifest của dự án ghi đường dẫn tương đối, kích thước và SHA256. PDK deck, Liberty, SPEF, SDF và script vá GDS không được đưa vào PDF vì chúng không cần cho phần trình bày kết quả.

<!-- pagebreak -->

# 6. Kết quả mô phỏng

## 6.1. Phương pháp kiểm chứng

Bộ kiểm thử được tạo bằng Icarus Verilog và VVP. Mỗi test ghi nguồn cùng hash, lệnh compile, warning count, lệnh simulation, pass pattern, log và đường dẫn waveform. Các test directed hiện có không tự suy diễn seed ngẫu nhiên; nếu một bài dùng seed do chủ sở hữu cung cấp thì seed phải được ghi trong plusargs.

Kiểm chứng bao phủ bốn tầng: DMA unit, firewall unit và top, tích hợp SoC, sau đó là AEGIS end-to-end và adversarial stress. Kết quả tổng hợp là 25 PASS, không có test FAIL trong bộ kiểm thử.

> [PHÂN ĐỊNH MOCK] `drain_wrapper_mock` và `dma_firewall_boundary_mock` có trạng thái PASS nhưng thuộc `MOCK_INTEGRATION`. Hai test này không được dùng để chứng minh production Firewall. Bằng chứng production dựa trên `dma_bus_firewall`, `soc_dma_firewall_contract` và `soc_real_integration` cùng các unit test liên quan.

[[TEST_TABLE]]

<!-- pagebreak -->

# 7. Dạng sóng kiểm chứng

## 7.1. Address slice và kiểm tra biên

[[WAVEFORM:address_slice_observation|Dạng sóng AW handshake, address snapshot và lỗi biên 4 KB]]

Dạng sóng address slice cho phép đối chiếu reset, AW handshake, địa chỉ được chụp vào pipeline và cờ lỗi biên 4 KB. Đây là lớp đầu tiên trước khi ACL và action selector quyết định có forward giao dịch hay không.

## 7.2. ACL handshake

[[WAVEFORM:fw_acl_matcher|Dạng sóng request và decision handshake của ACL matcher]]

Capture cho thấy nhịp nhận request và trả decision của ACL matcher dưới cơ chế valid/ready. Hình trong báo cáo được dựng từ `waveform.json` để bảo toàn mốc thời gian và tránh phụ thuộc vào ảnh chụp màn hình thủ công. Bản SVG, JSON và simulation log gốc thuộc nguồn đối soát của dự án, không nằm trong tệp PDF nộp lần này.

## 7.3. Bằng chứng production và SoC

`dma_bus_firewall` kiểm tra top firewall production. `soc_dma_firewall_contract` kiểm tra DMA Controller cùng production firewall. `soc_real_integration` dùng PicoRV32, APB bridge, DMA Controller, firewall thật và AXI memory model; firmware cấu hình hai APB target, khởi động DMA và tạo trap thật cho đường AEGIS NMI. Log và capture gốc của ba bài được dùng để đối soát các kết luận trong PDF.

<!-- pagebreak -->

# 8. Kiểm chứng AEGIS và adversarial stress

## 8.1. Closed-loop threat response

[[WAVEFORM:fw_closed_loop_ctrl|Dạng sóng anomaly alert, threat level, force drain và AEGIS NMI]]

Waveform closed-loop nối anomaly alert với threat level, yêu cầu force drain và AEGIS NMI. Đây là bằng chứng tín hiệu cho đường phản ứng sau khi fast path hoặc HDC tạo sự kiện.

## 8.2. Adversarial M1

[[WAVEFORM:adversarial_m1|Dạng sóng adversarial stress với lưu lượng DMA hợp lệ và probe né tránh]]

Bài stress gồm 5.000 burst DMA benign ngẫu nhiên, traversal qua biên row 4 KB và các probe né tránh. Log ghi nhận 0% false positive trong tập benign của bài kiểm thử này. Con số chỉ áp dụng cho stimulus đã chạy, không phải tỷ lệ false positive trong mọi workload.

## 8.3. Row-thrashing 5.000 burst và ý nghĩa kiểm chứng

Bài `aegis_rowhammer_5000` tạo 5.000 burst luân phiên, timing probe, DMA bình thường và kịch bản CPU NMI. Kết quả PASS chứng minh phản ứng của baseline với mẫu row-thrashing trong mô hình địa chỉ đang dùng. Do `DRAM_MAP_VALID=0`, kết quả không được nâng thành tuyên bố phát hiện Rowhammer vật lý.

Hai nhóm test cho thấy kiến trúc không chỉ xử lý vi phạm ACL đơn giản. Nó còn giữ safe traffic ở mức threat bình thường trong stress đã định nghĩa, đồng thời duy trì đường phản ứng khi xuất hiện mẫu đáng ngờ. Các capture được đánh dấu truncated khi bộ tạo preview chỉ lấy một cửa sổ giới hạn. PDF chỉ trình bày các cửa sổ waveform cần thiết để đọc kết quả.

<!-- pagebreak -->

# 9. Layout và GDS/GDSII

## 9.1. AEGIS SoC top

[[IMAGE:layout_soc|Layout `aegis_soc_top`, bằng chứng physical chính]]

GDS `aegis_soc_top.gds` có SHA256 `0644fb1b28193d3065bb5b495e1080d3c2f7624da2d30490cd0ab8a6e513e` theo hồ sơ physical của dự án. Source revision physical được ghi là `36c4281bb87e67ee18d2462c784bc5d4a3e63a98`, PDK `sky130A`, PDK revision `0fe599b2afb6708d281543108caf8310912f54af`.

## 9.2. DMA bus firewall độc lập

[[IMAGE:layout_firewall|Layout `dma_bus_firewall`, bằng chứng IP bổ sung]]

Block độc lập giúp tách kết quả của security IP khỏi diện tích và routing toàn SoC. Báo cáo giữ ảnh layout và nêu rõ hash GDS cùng các kết quả DRC, LVS và timing tương ứng. Kết quả block không thay thế kết quả SoC, và kết quả SoC không được dùng để xóa hold limitation ở biên block.

## 9.3. Quy tắc bảo toàn

Hai GDS được đối soát nguyên trạng trong dự án và hash được ghi trong báo cáo. Tệp PDF không chứa GDS nhị phân. Các công cụ tạo báo cáo không chỉnh sửa cell, layer, netlist hoặc report nguồn.

<!-- pagebreak -->

# 10. DRC và LVS

[[PHYSICAL_TABLE]]

## 10.1. Design rule check

Manifest ghi KLayout v0.28.16 và deck `sky130A_mr.drc 2024.2.11_01.09`. Hai tệp `klayout_drc.rpt` đều là KLayout RDB hợp lệ và có 0 marker. Vì vậy, AEGIS SoC top và firewall độc lập đều có kết quả DRC 0 theo deck đã ghi.

## 10.2. Layout versus schematic

Manifest ghi Netgen 1.5.255 và Magic 8.3. Với firewall độc lập, raw Netgen log có kết luận `Final result: Circuits match uniquely`. Kết quả này phù hợp với `lvs.rpt` và manifest.

Với AEGIS SoC top, raw `netgen_lvs.log` kết thúc bằng `Final result: Circuits match uniquely`. Hai phía đều có 29.957 devices và 30.422 nets; log cũng xác nhận cell pin lists và device classes tương đương. `lvs.rpt` ghi `Status: PASS`, `Netlist Match: MATCHED` và `0 pin / 0 net / 0 device`, phù hợp với manifest `matched=true`.

## 10.3. Phạm vi xác nhận

KLayout, Netgen và Magic không được chạy lại khi biên soạn hồ sơ. DRC 0 được đọc trực tiếp từ hai RDB có 0 marker. Raw LVS SoC đã được cập nhật trước khi tổng hợp báo cáo, parser đã chạy và dữ liệu đã được kiểm tra lại bằng SHA256. Kết luận LVS SoC trong phiên bản này là `PASS/MATCHED` theo raw log và report tương ứng.

<!-- pagebreak -->

# 11. Báo cáo timing

## 11.1. AEGIS SoC top tại TT, 38 MHz

| Kiểm tra | WNS | TNS | Unconstrained endpoints | Diễn giải |
|---|---:|---:|---:|---|
| Setup | `+0.89 ns` | `0.00 ns` | 0 | Positive margin |
| Hold | `+0.041 ns` | `0.00 ns` | 0 | Positive margin |

Kết quả dùng report `sta_tt_025C_1v80_38mhz.rpt`, corner TT, 25 °C, 1.80 V, mode functional và stage post-route. OpenSTA 2.6.0 báo setup và hold đều dương tại operating point này.

## 11.2. AEGIS SoC top tại SS, 100 °C, 1.60 V

| Chu kỳ và tần số | Setup WNS | Hold WNS | Kết quả |
|---|---:|---:|---|
| `25.974 ns`, khoảng `38.5 MHz` | `-25.10 ns` | `+0.09 ns` | Setup FAIL |
| `52 ns`, khoảng `19.23 MHz` | `+0.92 ns` | `+0.09 ns` | PASS trong report |

Hai report SS cho thấy thiết kế chưa đóng setup tại khoảng 38.5 MHz ở slow corner. Report 52 ns có setup và hold dương. Hồ sơ không nội suy Fmax từ hai điểm này và không dùng kết quả TT để tuyên bố MCMM closure.

## 11.3. DMA bus firewall độc lập tại TT

| Kiểm tra | WNS | TNS | Diễn giải |
|---|---:|---:|---|
| Setup | `+0.81 ns` | `0.00 ns` | Positive setup margin |
| Hold | `-0.02 ns` | `-0.07 ns` | Boundary hold limitation, có waiver |

Manifest nguồn ghi raw boundary hold slack khoảng `-0.017 ns`, được làm tròn thành WNS `-0.02 ns`, TNS `-0.07 ns` trên tám boundary input bit. Internal flop-to-flop hold là `+0.294 ns`; SoC-level hold là `+0.041 ns`. Boundary hold được quản lý theo `WAV-STA-004` và không được diễn giải thành timing pass không điều kiện ở block độc lập.

## 11.4. Phạm vi timing

SoC top có setup và hold dương tại TT, 38 MHz. Slow-corner report chỉ chứng minh PASS tại chu kỳ 52 ns; điểm khoảng 38.5 MHz bị setup FAIL. Firewall block có setup dương tại TT nhưng còn hold âm ở biên theo waiver. Tập report hiện có không phải MCMM, OCV hoặc tapeout signoff.

<!-- pagebreak -->

# 12. Kết quả PPA

Các số liệu PPA được lấy từ báo cáo tổng hợp của dự án và được trình bày lại trong PDF. Công suất được đo từ hoạt động của mô phỏng gate-level SDF ở 38 MHz:

| Khối | Công suất theo workload VCD | Ghi chú |
|---|---:|---|
| `aegis_soc_top` | `42.60 mW` | Kết quả của trace chức năng đã ghi |
| `dma_bus_firewall` | `49.80 mW` | Kết quả của trace chức năng đã ghi |

Giá trị `79.70 mW` trong `ir_drop.rpt` được giữ thành một kịch bản static power-grid IR-drop ở 40 MHz. Raw report không đủ thông tin để gộp giá trị này vào công suất của workload VCD. Vì vậy, báo cáo không dùng một con số duy nhất cho hai kịch bản.

Hồ sơ PPA vẫn ghi trạng thái `CONDITIONAL / REVIEW REQUIRED`. Các điểm cần đọc cùng PPA gồm boundary hold waiver của Firewall, raw FF hold âm tại corner lạnh và các cảnh báo tổng hợp đã được thống kê trong manifest.

<!-- pagebreak -->

# 13. Kết luận và truy xuất nguồn đối soát

DMA-Aware Bus Firewall có chuỗi bằng chứng từ ý tưởng bảo vệ DMA đến RTL, mô phỏng production, dạng sóng, tích hợp AEGIS SoC và physical design. Hồ sơ cho thấy fast path và analysis path tách biệt, phản ứng phần cứng có kiểm soát và nguồn đối soát có thể truy xuất bằng hash.
