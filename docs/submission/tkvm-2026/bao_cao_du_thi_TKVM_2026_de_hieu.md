---
title: Tường lửa DMA cho AEGIS SoC
subtitle: Bản giải thích bằng ngôn ngữ đơn giản
version: Bản dễ hiểu 1.0
---

# Tóm tắt dễ hiểu

DMA là cơ chế giúp một thiết bị tự chuyển dữ liệu trong bộ nhớ mà không cần CPU xử lý từng bước. Cách làm này nhanh, nhưng cũng tạo ra một đường truy cập có thể vượt qua các kiểm tra của phần mềm. Đề tài đặt một **tường lửa phần cứng** trên đường đi đó. Mỗi yêu cầu đọc hoặc ghi đều được kiểm tra trước khi tới vùng nhớ cần bảo vệ.

Tường lửa làm hai việc song song. Đường xử lý nhanh kiểm tra ngay địa chỉ, nguồn gửi và quyền truy cập. Đường phân tích theo dõi nhiều giao dịch theo thời gian để tìm hành vi đáng ngờ. Vì đường phân tích nằm bên cạnh đường chính, giao dịch hợp lệ không phải chờ phép phân tích phức tạp.

Gói bằng chứng hiện có **25/25 bài kiểm thử PASS**. Trong số này, 23 bài kiểm tra thiết kế thật hoặc từng khối thật. Hai bài dùng mô hình giả lập chỉ giúp truy tìm lỗi và không được dùng để chứng minh tường lửa production.

Hai layout đã được kiểm tra DRC và có 0 lỗi theo báo cáo. AEGIS SoC chạy đạt timing ở 38 MHz tại điều kiện TT, 25 °C, 1.80 V. Ở điều kiện chậm hơn là SS, 100 °C, 1.60 V, thiết kế không đạt khoảng 38.5 MHz nhưng đạt ở chu kỳ 52 ns, tương đương khoảng 19.23 MHz.

LVS của tường lửa độc lập và AEGIS SoC đều có raw log kết luận hai mạch khớp nhau. Với SoC, hai phía đều có 29.957 devices và 30.422 nets, không có pin, net hoặc device mismatch. Báo cáo parser ghi `PASS/MATCHED`.

> [TRẠNG THÁI BẰNG CHỨNG] Gói hiện có trạng thái `EVIDENCE_COMPLETE_REVIEW_REQUIRED` vì kết quả physical vẫn được trình bày theo phạm vi bằng chứng của dự án. Raw LVS SoC, báo cáo parser, manifest và hash bundle đã được đồng bộ. Báo cáo không tự chạy lại công cụ DRC, LVS hoặc timing.

## Phạm vi của bản báo cáo

- Giải thích ý tưởng, mục tiêu bảo vệ và cách các khối làm việc với nhau.
- Trình bày RTL, kết quả mô phỏng và một số dạng sóng tiêu biểu.
- Trình bày layout, GDS/GDSII, DRC, LVS và timing.
- Giữ các tệp nguồn, log và mã hash cần để kiểm tra lại bằng chứng.

<!-- pagebreak -->

# 1. Ý tưởng và đóng góp

## 1.1. Vấn đề cần giải quyết

DMA có thể đọc hoặc ghi bộ nhớ mà không cần CPU tham gia vào từng nhịp. Nếu DMA bị cấu hình sai hoặc bị chiếm quyền, nó có thể truy cập vùng nhớ nhạy cảm trước khi phần mềm kịp phản ứng.

Thiết kế giải quyết vấn đề này bằng cách kiểm tra giao dịch ngay trong phần cứng. Tường lửa đọc địa chỉ, nguồn gửi và quyền truy cập. Sau đó, nó cho phép giao dịch đi qua hoặc chặn giao dịch theo chính sách đã cấu hình.

## 1.2. Cách hệ thống phản ứng

Khi phát hiện giao dịch không hợp lệ, tường lửa có thể:

1. Từ chối giao dịch.
2. Hoàn tất phần giao tiếp còn lại để bus không bị treo.
3. Giảm tốc độ của nguồn gửi.
4. Chuyển giao dịch sang Honey-Pot, là một đích giả dùng để giữ và quan sát giao dịch đáng ngờ.
5. Phát cảnh báo và ghi lại thông tin sự kiện.

Thiết kế còn thu thập dữ liệu quan sát, gọi là telemetry. Khối HDC dùng dữ liệu này để nhận biết các mẫu truy cập bất thường. Kết quả phân tích được dùng cho các giao dịch tiếp theo, không thay đổi quyết định của giao dịch đang xử lý.

## 1.3. Điểm giới hạn

Thiết kế hiện chưa có ánh xạ vật lý đầy đủ của DRAM vì `DRAM_MAP_VALID=0`. Các bài kiểm thử chứng minh khả năng nhận ra mẫu truy cập lặp giữa các hàng nhớ trong mô hình hiện tại. Kết quả này chưa chứng minh khả năng phát hiện Rowhammer vật lý trên một chip nhớ cụ thể. Bài CPU smoke test cũng không phải kiểm tra đầy đủ tập lệnh của CPU.

<!-- pagebreak -->

# 2. Mục tiêu bảo vệ và mô hình đe dọa

## 2.1. Những gì cần được bảo vệ

- Dữ liệu trong vùng nhớ phía sau tường lửa.
- Hoạt động đúng của bus AXI khi giao dịch bị chặn hoặc bị chậm.
- Giao dịch hợp lệ trong lúc hệ thống đang phân tích hành vi đáng ngờ.
- Chính sách bảo mật và bản ghi sự kiện được điều khiển qua APB4.
- Chuỗi thông tin từ lúc phát hiện vi phạm đến lúc phần cứng phản ứng.

## 2.2. Các nguy cơ chính

| Nguy cơ | Tường lửa quan sát gì | Cách phản ứng | Giới hạn |
|---|---|---|---|
| Truy cập sai vùng nhớ | Địa chỉ đọc hoặc ghi | Chặn và ghi sự kiện | Phụ thuộc chính sách đã cấu hình |
| Sai nguồn gửi hoặc sai quyền | Master ID và thuộc tính truy cập | Chặn và cảnh báo | Không thay thế secure boot |
| Giao dịch vượt qua ranh giới cho phép | Địa chỉ và độ dài giao dịch | Chặn trước khi tới bộ nhớ | Chỉ hỗ trợ AXI profile đã định |
| Gửi yêu cầu quá nhanh | Telemetry và bộ đếm tốc độ | Giảm tốc độ hoặc cách ly | Ngưỡng do chính sách quyết định |
| Truy cập hàng nhớ lặp lại | Chỉ số hàng nhớ trong mô hình | Chuyển hướng hoặc chặn | Chưa phải bằng chứng Rowhammer vật lý |
| Cố tình né kiểm tra | Telemetry và bài stress | Tăng điểm đe dọa | Không bao phủ mọi cách tấn công |

## 2.3. Yêu cầu bắt buộc

Khi bus tạm dừng, tín hiệu đầu ra phải giữ ổn định. Một giao dịch bị chặn vẫn phải được kết thúc đúng quy tắc để thiết bị gửi không bị treo. Khối phân tích không được làm chậm giao dịch hợp lệ. Nếu hàng đợi telemetry đầy, hệ thống phải ghi nhận sự việc thay vì âm thầm bỏ dữ liệu.

## 2.4. Ngoài phạm vi

Hồ sơ không tuyên bố chống mọi kiểu tấn công kênh kề. Thiết kế chưa có chứng nhận sản xuất và chưa thay thế memory controller.

<!-- pagebreak -->

# 3. Kiến trúc thiết kế

[[FIGURE:architecture_soc|Sơ đồ tổng thể của tường lửa DMA trong AEGIS SoC]]

## 3.1. Đường đi của một giao dịch

CPU cấu hình DMA Controller qua bus APB. DMA Controller sau đó tạo yêu cầu đọc hoặc ghi trên bus AXI. Khối Address slice giữ lại thông tin địa chỉ tại đúng thời điểm giao dịch bắt đầu. Khối ACL matcher so sánh yêu cầu với danh sách quyền truy cập. Context tracker bổ sung trạng thái của nguồn gửi.

Action selector nhận kết quả kiểm tra và chọn một trong các hành động: cho đi qua, từ chối, giảm tốc độ hoặc chuyển sang Honey-Pot. Giao dịch được phép sẽ đi tới cổng bộ nhớ được bảo vệ.

## 3.2. Hai đường xử lý

Fast path là đường xử lý nhanh. Nó kiểm tra các luật rõ ràng và đưa ra quyết định ngay. Analysis path là đường phân tích. Nó quan sát nhiều giao dịch theo thời gian để tìm mẫu bất thường.

Khối HDC làm việc với vector 1024 bit nhưng xử lý từng phần 64 bit. Cách này giảm lượng phần cứng cần dùng so với xử lý toàn bộ 1024 bit cùng lúc. Kết quả HDC chỉ cập nhật chính sách cho giao dịch sau, nên giao dịch hợp lệ không phải chờ HDC.

## 3.3. Cảnh báo và bản ghi sự kiện

Closed-loop controller giữ điểm đe dọa cho từng nguồn gửi. Khi điểm đủ cao, khối có thể yêu cầu chặn giao dịch, phát IRQ hoặc NMI và ghi một bản chụp sự kiện. CPU đọc trạng thái và bản ghi qua APB4. Cơ chế khóa sticky ngăn việc thay đổi chính sách trái phép sau secure boot.

<!-- pagebreak -->

# 4. Các khối của tường lửa

## 4.1. Bảng chức năng

| Khối RTL | Giải thích ngắn |
|---|---|
| `fw_axi_address_slice` | Giữ địa chỉ đọc hoặc ghi và kiểm tra giao dịch vượt biên 4 KB |
| `fw_acl_matcher` | So sánh yêu cầu với danh sách quyền truy cập |
| `fw_context_tracker` | Ghi trạng thái và số liệu theo từng nguồn gửi |
| `fw_data_path_mux` | Chọn đường đi qua, chặn hoặc chuyển hướng |
| `fw_write_drain`, `fw_read_drain` | Kết thúc giao dịch bị chặn để bus không bị treo |
| `fw_drain_fsm` | Điều khiển thứ tự các bước khi kết thúc giao dịch |
| `fw_hdc_sense` | Phân tích telemetry để tìm mẫu đáng ngờ |
| `fw_closed_loop_ctrl` | Cập nhật mức đe dọa, cảnh báo và bản ghi sự kiện |
| `fw_honeypot_sink` | Nhận giao dịch bị chuyển hướng và trả phản hồi hợp lệ |
| `fw_mtd_engine` | Hỗ trợ thay đổi chính sách phòng vệ theo thời gian |
| `fw_apb_regs` | Cung cấp thanh ghi cấu hình và trạng thái |
| `dma_bus_firewall` | Ghép tất cả các khối thành tường lửa hoàn chỉnh |

## 4.2. Xử lý giao dịch bị chặn

Các kênh đọc và ghi của AXI có thể dừng ở những thời điểm khác nhau. Vì vậy, thiết kế giữ riêng thông tin đọc và ghi. Khi một giao dịch bị chặn, các khối drain vẫn nhận đủ phần còn lại và trả phản hồi đúng quy tắc. Cách này giúp thiết bị gửi không bị treo.

## 4.3. Trạng thái an toàn

Nếu chính sách không hợp lệ hoặc giao dịch nằm ngoài profile hỗ trợ, tường lửa không chuyển yêu cầu tới bộ nhớ được bảo vệ. Hệ thống vẫn kết thúc giao dịch có kiểm soát. Reset giữa giao dịch đưa quyền điều khiển về trạng thái an toàn.

## 4.4. Khả năng mở rộng

Thiết kế tách phần chính sách, dữ liệu quan sát và hành động. Nhóm có thể tăng số vùng ACL hoặc thay đổi ngưỡng mà không viết lại toàn bộ đường dữ liệu. Nếu thay đổi HDC hoặc cách tạo đặc trưng, nhóm phải tạo lại bộ dữ liệu chuẩn trước khi dùng làm bằng chứng mới.

<!-- pagebreak -->

# 5. Thiết kế logic và RTL

## 5.1. Mã nguồn trong gói nộp

Gói nộp lấy mã nguồn từ manifest của các bài kiểm thử production. Mã dưới thư mục `mocks/` không được đưa vào phần bằng chứng chính. Hai tệp constraint là `aegis_soc_top.sdc` và `dma_bus_firewall.sdc` được giữ để người đọc biết điều kiện dùng khi kiểm tra timing.

Mã RTL gồm DMA Controller, các khối tường lửa, CPU PicoRV32, APB bridge và top `aegis_soc_top`. Testbench nằm trong thư mục riêng. Mỗi tệp có mã SHA256 để phát hiện thay đổi khi sao chép.

## 5.2. Quy tắc điều khiển

Thiết kế chốt hành động cho từng giao dịch. Khi bus tạm dừng, quyết định không bị tính lại. Các state machine đọc và ghi theo dõi đúng số phần dữ liệu của mỗi giao dịch. Bộ đếm và con trỏ bản ghi chỉ thay đổi khi có điều kiện cho phép rõ ràng.

## 5.3. Tích hợp vào SoC

`aegis_soc_top` ghép CPU PicoRV32, APB bridge, DMA Controller và tường lửa thật. Top đưa các cổng `ext_mem` và `m_axi` ra ngoài, không chứa RAM bên trong. Testbench `soc_real_integration` nối một mô hình bộ nhớ vào các cổng này. Firmware cấu hình hai thiết bị APB, khởi động DMA và theo dõi trap hoặc NMI.

## 5.4. Cách truy tìm bằng chứng

Mỗi kết luận trong báo cáo có thể được kiểm tra bằng mã RTL, log mô phỏng, dạng sóng hoặc báo cáo physical. `MANIFEST.csv` ghi đường dẫn, kích thước và SHA256 của từng tệp. Gói không chứa PDK deck, Liberty, SPEF hoặc SDF.

<!-- pagebreak -->

# 6. Kết quả mô phỏng

## 6.1. Cách kiểm tra

Các bài kiểm thử dùng Icarus Verilog và VVP. Mỗi bài lưu lệnh biên dịch, số cảnh báo, lệnh chạy, điều kiện PASS, log và đường dẫn dạng sóng. Các bài directed test dùng tình huống được định nghĩa trước. Nếu một bài dùng số ngẫu nhiên có seed, seed phải được ghi trong tham số chạy.

Các bài kiểm thử đi từ từng khối DMA và firewall đến tích hợp toàn SoC, sau đó là stress AEGIS. Kết quả trong bundle là 25 PASS và không có bài FAIL.

> [PHÂN ĐỊNH MOCK] `drain_wrapper_mock` và `dma_firewall_boundary_mock` là hai bài dùng mô hình giả lập. Hai bài có trạng thái PASS nhưng không chứng minh tường lửa production. Bằng chứng production dựa trên các bài dùng `dma_bus_firewall` thật và các khối RTL liên quan.

[[TEST_TABLE]]

<!-- pagebreak -->

# 7. Dạng sóng kiểm chứng

## 7.1. Giữ địa chỉ và kiểm tra biên

[[WAVEFORM:address_slice_observation|Dạng sóng nhận địa chỉ và phát hiện giao dịch vượt biên 4 KB]]

Dạng sóng cho thấy thời điểm hệ thống nhận địa chỉ ghi, giữ địa chỉ vào pipeline và bật cờ lỗi khi giao dịch vượt biên 4 KB. Kiểm tra này xảy ra trước khi tường lửa quyết định cho giao dịch đi qua.

## 7.2. Kiểm tra quyền truy cập

[[WAVEFORM:fw_acl_matcher|Dạng sóng yêu cầu và kết quả của khối kiểm tra quyền truy cập]]

Hai tín hiệu valid và ready cho biết lúc yêu cầu được gửi và lúc kết quả được nhận. Gói nộp giữ bản SVG, JSON và log gốc. Hình trong báo cáo được dựng từ dữ liệu JSON để giữ đúng mốc thời gian.

## 7.3. Kiểm tra toàn hệ thống

Bài `dma_bus_firewall` kiểm tra tường lửa hoàn chỉnh. Bài `soc_dma_firewall_contract` kiểm tra DMA Controller nối với tường lửa thật. Bài `soc_real_integration` kiểm tra CPU, APB bridge, DMA Controller, tường lửa và mô hình bộ nhớ trong cùng một hệ thống. Log và dạng sóng của ba bài được giữ riêng trong gói nộp.

<!-- pagebreak -->

# 8. Kiểm tra phản ứng và stress

## 8.1. Phản ứng khi có cảnh báo

[[WAVEFORM:fw_closed_loop_ctrl|Dạng sóng từ cảnh báo bất thường đến chặn giao dịch và phát NMI]]

Dạng sóng cho thấy cảnh báo làm tăng mức đe dọa. Khi điều kiện phản ứng được thỏa mãn, hệ thống yêu cầu drain giao dịch và phát NMI cho AEGIS SoC.

## 8.2. Bài kiểm thử đối kháng

[[WAVEFORM:adversarial_m1|Dạng sóng stress với giao dịch hợp lệ và các yêu cầu cố né kiểm tra]]

Bài `adversarial_m1` chạy 5.000 burst DMA hợp lệ ngẫu nhiên, giao dịch qua biên 4 KB và các yêu cầu cố né kiểm tra. Log ghi nhận 0% false positive trong tập dữ liệu hợp lệ của bài này. Con số không đại diện cho mọi chương trình hoặc mọi thiết bị.

## 8.3. Mẫu truy cập hàng nhớ

Bài `aegis_rowhammer_5000` chạy 5.000 burst luân phiên, timing probe, DMA bình thường và tình huống CPU nhận NMI. Kết quả PASS cho thấy hệ thống phản ứng đúng với mẫu truy cập lặp trong mô hình đang dùng. Do `DRAM_MAP_VALID=0`, đây chưa phải bằng chứng phát hiện Rowhammer vật lý.

Một số hình dạng sóng chỉ hiển thị một cửa sổ thời gian để giữ báo cáo dễ đọc. Gói nộp chỉ giữ VCD đầy đủ khi tệp không vượt quá 25 MB.

<!-- pagebreak -->

# 9. Layout và GDS/GDSII

## 9.1. Layout của AEGIS SoC

[[IMAGE:layout_soc|Layout của toàn bộ `aegis_soc_top`]]

Layout là hình dạng vật lý của mạch sau khi các cell đã được đặt và nối dây. Tệp GDS/GDSII là dữ liệu hình học dùng để mô tả layout. Tệp `aegis_soc_top.gds` có SHA256 `0644fb1b28193d3065bb5b495e1080d3c2f7624da2d30494490cd0ab8a6e513e`. Thiết kế dùng PDK `sky130A`.

## 9.2. Layout của tường lửa

[[IMAGE:layout_firewall|Layout riêng của khối `dma_bus_firewall`]]

Layout riêng giúp kiểm tra khối bảo mật mà không bị lẫn với diện tích và đường dây của toàn SoC. Gói nộp giữ GDS, ảnh layout, DRC, LVS và báo cáo timing của khối này. Kết quả của tường lửa và kết quả của SoC được trình bày riêng.

## 9.3. Bảo toàn tệp

Script đóng gói sao chép hai tệp GDS mà không chỉnh sửa cell, layer hoặc netlist. `MANIFEST.csv` cho phép kiểm tra SHA256 sau khi giải nén ZIP.

<!-- pagebreak -->

# 10. DRC và LVS

[[PHYSICAL_TABLE]]

## 10.1. Kiểm tra luật layout

DRC kiểm tra xem layout có tuân theo các quy tắc kích thước và khoảng cách của công nghệ sản xuất hay không. Hai báo cáo KLayout đều có 0 marker, nghĩa là công cụ không ghi nhận lỗi DRC theo deck đã dùng. Deck được ghi là `sky130A_mr.drc 2024.2.11_01.09`.

## 10.2. So sánh layout với mạch logic

LVS so sánh mạch rút ra từ layout với netlist logic. Với tường lửa độc lập, raw Netgen log kết thúc bằng `Final result: Circuits match uniquely`. Kết quả này thống nhất với `lvs.rpt` và manifest.

Với AEGIS SoC, raw `netgen_lvs.log` kết thúc bằng `Final result: Circuits match uniquely`. Hai phía đều có 29.957 devices và 30.422 nets, không có sai khác. `lvs.rpt` ghi `PASS/MATCHED`, phù hợp với manifest.

## 10.3. Mức độ xác nhận

Quá trình làm báo cáo không chạy lại KLayout, Netgen hoặc Magic. Kết quả DRC 0 được đọc từ hai báo cáo có 0 marker. Raw LVS SoC đã được parser kiểm tra trước khi đóng gói và bundle đã được kiểm tra hash. Vì vậy, phiên bản này ghi nhận LVS SoC là `PASS/MATCHED`.

<!-- pagebreak -->

# 11. Báo cáo timing

Timing cho biết tín hiệu có đi qua mạch đủ nhanh và ổn định hay không. WNS dương nghĩa là đường xấu nhất vẫn còn thời gian dự phòng. WNS âm nghĩa là có ít nhất một đường chưa đạt yêu cầu.

## 11.1. AEGIS SoC tại TT, 38 MHz

| Kiểm tra | WNS | TNS | Số điểm chưa có ràng buộc | Cách hiểu |
|---|---:|---:|---:|---|
| Setup | `+0.89 ns` | `0.00 ns` | 0 | Đạt, còn 0.89 ns dự phòng |
| Hold | `+0.041 ns` | `0.00 ns` | 0 | Đạt, còn 0.041 ns dự phòng |

Báo cáo `sta_tt_025C_1v80_38mhz.rpt` dùng điều kiện TT, 25 °C, 1.80 V và trạng thái TT post-route. Ở điều kiện này, setup và hold đều đạt tại 38 MHz.

## 11.2. AEGIS SoC tại SS, 100 °C, 1.60 V

| Chu kỳ và tần số | Setup WNS | Hold WNS | Kết quả |
|---|---:|---:|---|
| `25.974 ns`, khoảng `38.5 MHz` | `-25.10 ns` | `+0.09 ns` | Setup FAIL |
| `52 ns`, khoảng `19.23 MHz` | `+0.92 ns` | `+0.09 ns` | PASS trong report |

SS là điều kiện chậm hơn TT. Thiết kế chưa đạt setup ở khoảng 38.5 MHz tại SS. Khi tăng chu kỳ lên 52 ns, tương đương giảm tần số xuống khoảng 19.23 MHz, setup và hold đều dương. Hai điểm đo chưa đủ để khẳng định tần số lớn nhất của chip.

## 11.3. Tường lửa độc lập tại TT

| Kiểm tra | WNS | TNS | Cách hiểu |
|---|---:|---:|---|
| Setup | `+0.81 ns` | `0.00 ns` | Setup đạt |
| Hold | `-0.02 ns` | `-0.07 ns` | Hold tại chân vào còn âm và có waiver |

Raw slack tại biên vào khoảng `-0.017 ns`, được làm tròn thành WNS `-0.02 ns`. Hold giữa các flip-flop bên trong khối là `+0.294 ns`; hold ở cấp SoC là `+0.041 ns`. Waiver `WAV-STA-004` ghi nhận giới hạn tại biên. Vì vậy, khối độc lập chưa được xem là timing pass không điều kiện.

## 11.4. Giới hạn của kết quả timing

SoC đạt 38 MHz tại TT nhưng không đạt khoảng 38.5 MHz tại SS. Tường lửa độc lập còn hold âm tại biên. Tập báo cáo hiện có chưa phải kiểm tra MCMM, OCV hoặc tapeout signoff.

<!-- pagebreak -->

# 12. Kết luận và truy xuất hiện vật

Tường lửa kiểm tra giao dịch DMA trước khi yêu cầu tới bộ nhớ được bảo vệ. Hệ thống có đường quyết định nhanh, đường phân tích hành vi và cơ chế chặn giao dịch mà không làm bus bị treo. Gói nộp nối mã RTL với log, dạng sóng, layout, GDS, DRC, LVS và timing bằng SHA256.

Kết quả hiện có cho thấy 25/25 bài kiểm thử PASS và DRC 0 trên hai layout. SoC đạt timing tại TT, 38 MHz. Các giới hạn còn lại là timing SS chưa đạt khoảng 38,5 MHz, tường lửa còn boundary hold waiver và mô hình chưa có ánh xạ DRAM thật.

## 12.1. Bảng truy xuất

| Kết luận | Tệp dùng để kiểm tra | Vị trí trong gói |
|---|---|---|
| 25/25 bài kiểm thử PASS | `summary.json`, `simulation_results.csv` | `verification/` |
| Kiểm tra tường lửa thật | Test `dma_bus_firewall` và mã nguồn | `source/`, `verification/logs/` |
| Kiểm tra tích hợp SoC | Test `soc_real_integration` | Log và dạng sóng chọn lọc |
| Kiểm tra stress | `aegis_rowhammer_5000`, `adversarial_m1` | Log, SVG, JSON |
| DRC 0 | Hai báo cáo KLayout có 0 marker | `physical/*/klayout_drc.rpt` |
| LVS tường lửa khớp | `lvs.rpt` và raw Netgen log | `physical/dma_bus_firewall/` |
| LVS SoC khớp | `lvs.rpt`, manifest và raw Netgen log; 29.957 devices, 30.422 nets, 0 mismatch | `physical/aegis_soc_top/` |
| SoC TT setup `+0.89 ns`, hold `+0.041 ns` | Báo cáo timing TT | `physical/aegis_soc_top/` |
| SoC SS setup `-25.10 ns` tại khoảng 38.5 MHz, `+0.92 ns` tại 52 ns | Hai báo cáo timing SS | `physical/aegis_soc_top/` |
| Tường lửa setup `+0.81 ns`, hold `-0.02 ns`, TNS `-0.07 ns` | Báo cáo timing và waiver | `physical/dma_bus_firewall/` |

## 12.2. Việc cần hoàn thiện

Timing tại SS cần được cải thiện nếu mục tiêu vẫn là khoảng 38 MHz. Boundary hold của tường lửa và ánh xạ DRAM cho phần cứng cụ thể cũng cần được hoàn thiện trước khi nâng mức kết luận.

> [GHI CHÚ] Đây là bản giải thích dễ hiểu. Mọi con số và giới hạn kỹ thuật được giữ theo hồ sơ kỹ thuật gốc.
