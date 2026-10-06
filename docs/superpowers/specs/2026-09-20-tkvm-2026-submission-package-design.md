# Thiết kế gói hồ sơ dự thi TKVM 2026

## Kết luận

Gói nộp được tạo mới tại `output/submission/tkvm-2026/`. Repository hiện tại giữ nguyên. Quy trình chỉ sao chép các tài liệu và artifact cần cho báo cáo, sau đó tạo `output/submission/tkvm-2026-submission.zip` với manifest và hash để kiểm tra nguồn gốc.

Sản phẩm chính là `DMA-Aware Bus Firewall IP`. `AEGIS SoC` là nền tảng kiểm chứng tích hợp và là bằng chứng physical chính vì báo cáo hiện có ghi nhận DRC 0, LVS matched, setup slack `+0.89 ns` và hold slack `+0.041 ns` tại 38 MHz. Physical của firewall standalone được giữ làm bằng chứng bổ sung, kèm hold WNS `-0.02 ns`, TNS `-0.07 ns` và phạm vi waiver đã ghi trong manifest nguồn.

## Phạm vi

Gói nộp phải cho phép Ban Giám khảo đánh giá các nội dung sau:

- Ý tưởng và bài toán bảo vệ DMA trên bus AXI.
- Mục tiêu bảo vệ, mô hình đe dọa và giới hạn của thiết kế.
- Kiến trúc Firewall, DMA Controller và nền tảng kiểm chứng AEGIS SoC.
- Thiết kế logic và RTL của các khối thuộc sản phẩm.
- Kết quả mô phỏng, test tự kiểm tra và dạng sóng đại diện.
- Layout, GDS/GDSII, DRC, LVS và timing.

Gói nộp không bổ sung FPGA. Cuộc thi xếp FPGA vào mức khuyến khích, còn đội đã chọn dùng bằng chứng ASIC physical-design và mô phỏng RTL.

## Cấu trúc thư mục

```text
output/submission/
|-- tkvm-2026/
|   |-- README.txt
|   |-- MANIFEST.csv
|   |-- bao_cao_du_thi_TKVM_2026.pdf
|   |-- source/
|   |   |-- rtl/
|   |   |-- constraints/
|   |   `-- testbench/
|   |-- verification/
|   |   |-- summary.json
|   |   |-- simulation_results.csv
|   |   |-- logs/
|   |   `-- waveforms/
|   `-- physical/
|       |-- aegis_soc_top/
|       `-- dma_bus_firewall/
`-- tkvm-2026-submission.zip
```

`README.txt` mô tả cách đọc gói, top module, phạm vi của từng bằng chứng và các giới hạn đã biết. `MANIFEST.csv` ghi đường dẫn tương đối, loại artifact, kích thước, SHA-256 và nguồn trong repository.

## Nội dung báo cáo PDF

Báo cáo dùng khổ A4 và dự kiến dài 12 đến 14 trang, chưa tính phụ lục artifact. Trang bìa để trống các trường tên đội, đơn vị, thành viên và giảng viên hướng dẫn để đội điền trước khi nộp. Nguồn chỉnh sửa được đặt tại `docs/submission/tkvm-2026/`; nguồn này không nằm trong ZIP.

1. Tóm tắt sản phẩm và kết quả đã chứng minh.
2. Ý tưởng và bài toán bảo vệ DMA.
3. Mục tiêu bảo vệ, tài sản, tác nhân và phạm vi đe dọa.
4. Kiến trúc hệ thống và luồng quyết định bảo mật.
5. Thiết kế logic và RTL.
6. Chiến lược mô phỏng và kiểm chứng.
7. Dạng sóng đại diện.
8. Physical design, layout và GDS/GDSII.
9. Kết quả DRC, LVS và timing.
10. Giới hạn kỹ thuật và hướng phát triển.
11. Danh mục artifact bàn giao.

Mỗi số liệu chỉ xuất hiện một lần trong phần kết quả. Các phần còn lại dẫn lại bảng kết quả thay vì lặp số. Báo cáo phân biệt ba mức bằng chứng: `Measured` cho kết quả được tái tạo từ repository, `Sourced` cho số liệu đọc từ artifact gốc và `Reported` cho kết quả do manifest hiện có công bố nhưng chưa được chạy lại độc lập trong lần đóng gói.

## Artifact được giữ lại

### Source RTL và constraint

Gói `source/` chứa production RTL của Firewall, DMA Controller và AEGIS SoC cùng constraint tương ứng. Danh sách file được lấy từ source manifest của bài kiểm tra production và physical manifest. Không lấy file chỉ vì nó nằm trong thư mục `rtl/`.

Testbench được giữ khi nó tạo ra kết quả được trích trong báo cáo. Mock có nhãn `SIMULATION-ONLY MOCK` không được dùng làm bằng chứng chính và không nằm trong source list sản phẩm.

### Mô phỏng và dạng sóng

Gói giữ `summary.json`, `simulation_results.csv`, log của 25 bài kiểm tra và các waveform đại diện sau:

- Firewall top-level production.
- DMA và Firewall end-to-end contract.
- PicoRV32 SoC integration với Firewall production.
- AEGIS Rowhammer 5.000 burst.
- Adversarial stress với DMA traffic hợp lệ và probe né tránh.

Mỗi waveform gồm bản SVG để đọc nhanh. VCD được giữ khi file không quá 25 MB và gắn đúng test, source hash cùng log trong manifest. Trường hợp VCD vượt ngưỡng, gói chỉ giữ SVG, `waveform.json` và simulation log của test đó.

### Physical design

`physical/aegis_soc_top/` là bằng chứng chính. Thư mục này chứa:

- `aegis_soc_top.gds`.
- Ảnh layout.
- KLayout DRC report.
- Netgen LVS report.
- OpenSTA setup và hold report tại 38 MHz.
- Physical manifest gốc.

`physical/dma_bus_firewall/` là bằng chứng IP bổ sung. Thư mục giữ cùng loại artifact và manifest gốc. Báo cáo phải ghi rõ hold âm tại biên IP và waiver; kết quả SoC không được dùng để xóa hoặc thay đổi giới hạn này.

## Artifact bị loại khỏi gói nộp

Các nhóm sau không thuộc gói nộp:

- PDF giáo trình, hướng dẫn thực hành và tài liệu đào tạo.
- Đặc tả lịch sử, kế hoạch triển khai, tài liệu phân công và nhật ký nội bộ.
- Bundle evidence cũ hoặc trùng nội dung.
- Mock integration và source có nhãn simulation-only.
- File tạm, log debug, cache, executable mô phỏng và ảnh kiểm tra PDF.
- Liberty, SPEF, SDF, PDK deck và artifact backend dung lượng lớn mà thể lệ không yêu cầu.
- Source của công cụ tạo báo cáo, script vá GDS và script bảo trì evidence.
- Tài liệu FPGA, bitstream hoặc báo cáo FPGA.

Việc loại khỏi gói nộp không xóa file khỏi repository. Script đóng gói chỉ sao chép danh sách cho phép vào thư mục mới.

## Quy tắc bảo toàn và giới hạn

Quy trình đóng gói không sửa RTL, GDS, report hoặc manifest nguồn. Mọi file sao chép phải giữ nguyên SHA-256. PDF được phép rút gọn cách trình bày nhưng không được đổi số đo, trạng thái hoặc phạm vi bằng chứng.

Báo cáo phải giữ các giới hạn sau:

- Physical evidence dùng trạng thái `REPORTED_PASS` hoặc `EVIDENCE_COMPLETE_REVIEW_REQUIRED` đúng như bundle nguồn.
- DRC 0 và LVS matched là kết quả từ report đã đóng gói; lần tạo hồ sơ không chạy lại KLayout, Netgen hoặc Magic.
- SoC timing tại 38 MHz có setup `+0.89 ns` và hold `+0.041 ns` theo physical manifest hiện hành.
- Firewall standalone có setup `+0.81 ns`, hold WNS `-0.02 ns` và hold TNS `-0.07 ns`; boundary hold được quản lý bằng waiver.
- Hai bài mock trong bundle không được dùng để chứng minh production Firewall.
- Không có kết quả FPGA trong phạm vi nộp.

Nếu nguồn và bản sao khác hash, quá trình đóng gói phải dừng. Nếu artifact bắt buộc thiếu, script phải báo lỗi và không tạo ZIP cuối.

## Kiểm tra chất lượng

Gói nộp phải qua các kiểm tra sau:

1. Đúng cấu trúc thư mục và không có file ngoài allowlist.
2. Mọi artifact trong `MANIFEST.csv` tồn tại và khớp SHA-256.
3. ZIP nhỏ hơn giới hạn 500 MB của cổng nộp.
4. PDF mở được, trích xuất được tiếng Việt và không có trang rỗng ngoài chủ ý.
5. Toàn bộ trang PDF được render sang PNG để kiểm tra chữ cắt, bảng tràn lề, glyph lỗi và ảnh mờ.
6. Các số DRC, LVS và timing trong PDF khớp `summary.json` cùng physical manifest.
7. Không còn marker chưa hoàn thiện, nội dung mẫu hoặc thông tin đội được bịa.
8. Không có em dash, en dash hoặc chuỗi ` -- ` trong phần văn xuôi.

## Tiêu chí hoàn thành

Công việc hoàn tất khi có một PDF chính thức, một thư mục artifact tối giản, một manifest có hash và một ZIP dưới 500 MB. Repository gốc không mất hoặc bị đổi artifact. Báo cáo cho phép giám khảo truy từ mỗi tuyên bố kỹ thuật đến RTL, log, waveform hoặc physical report tương ứng.
