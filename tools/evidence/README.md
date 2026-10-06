# Bộ công cụ tổng hợp bằng chứng kiểm chứng

Phạm vi: **CPU PicoRV32, DMA, Firewall và tích hợp SoC**. Bộ công cụ chạy từ dự án gốc hoặc bản sao dự án. Python 3.11+ và Icarus Verilog đủ cho phần mô phỏng/tổng hợp báo cáo; không cần thư viện Python bổ sung.

## Chạy ngay

Tại thư mục gốc dự án:

```powershell
python -B tools/evidence/evidence.py doctor
python -B tools/evidence/evidence.py run --out output/evidence/run_001
python -B tools/evidence/evidence.py verify --bundle output/evidence/run_001
```

Mở `output/evidence/run_001/index.html`. Mỗi lần chạy dùng một thư mục mới; chương trình từ chối ghi đè để tránh trộn bằng chứng của nhiều lần chạy.

Gói kết quả gồm:

| File | Nội dung |
|---|---|
| `index.html` | Báo cáo tổng hợp, mở offline, ảnh dạng sóng và liên kết bằng chứng |
| `summary.json` | Trạng thái, phạm vi, lệnh chạy, phiên bản, thời gian, hash source |
| `simulation_results.csv` | Bảng kết quả từng test, mở bằng Excel |
| `simulation/<test>/compile.log`, `simulation.log` | Toàn bộ stdout/stderr của lần chạy mới |
| `simulation/<test>/*.vcd` | Dạng sóng gốc để đọc bằng GTKWave |
| `simulation/<test>/waveform.svg`, `waveform.json` | Ảnh tín hiệu và dữ liệu của cửa sổ xem trước |
| `physical_results.csv`, `physical/` | Số liệu và bản sao file vật lý khi có đầu vào |
| `artifacts.csv` | Danh sách file, kích thước, SHA-256 để phát hiện mất/sửa file |

Binary mô phỏng và module phụ bật dump được tạo trong thư mục tạm, tự dọn sau chạy. Source RTL của các nhóm không bị chỉnh sửa. Các log/bằng chứng canonical cũ không bị ghi đè. SHA-256 dùng kiểm tra tính toàn vẹn, không phải chữ ký xác thực người bàn giao.

## Test đang có và test đang chờ

`simulations.json` có bốn test DMA, một CPU smoke, hai test tích hợp dùng mock, một test address slice để quan sát và bảy mục chờ source/testbench/tích hợp thật. Đường dẫn được lấy từ cấu trúc hiện tại: DMA ở `DMA-controller/rtl`, phần Firewall đang làm ở `rtl`, CPU ở `picorv32-main/picorv32-main`.

Khi nhận module, sửa đúng entry trong manifest: `sources` là danh sách source và testbench đầy đủ; `top` là top testbench; `pass_pattern` là regex marker thành công của checker. Các entry chờ sinh viên dùng đường dẫn và marker dự kiến, cần xác nhận khi bàn giao. Mục `soc_real_integration` giữ chờ cho đến khi có top CPU–interconnect–DMA–Firewall thật, source list và testbench tự kiểm tra.

`waveform` khai báo tên VCD nếu testbench tự dump. Nếu không có trường này, runner thêm một root mô phỏng chỉ gọi `$dumpvars` để ghi `waves.vcd`. Không thêm wrapper logic vào DUT. `signals` chọn các tín hiệu cho hình xem trước bằng glob. Runner giữ `-g2012` tương thích testbench hiện có dùng `$fatal`; không chuyển RTL hay giáo trình sang SystemVerilog.

```powershell
python -B tools/evidence/evidence.py run --test dma_axi --test dma_controller --out output/evidence/dma_focus_001
```

Các test không được chọn vẫn hiện `NOT_RUN`. `--timeout 60` đặt giới hạn giây cho từng lệnh compile/run. Với test ngẫu nhiên mới, ghi seed và các plusargs mà testbench thực sự sử dụng vào manifest; runner không giả định testbench đã dùng seed chỉ vì nhận được `+SEED`.

| Trạng thái | Ý nghĩa |
|---|---|
| `PASS` | Compile/run trả 0, có marker đúng, không có marker lỗi, có VCD đọc được, không có cảnh báo compile |
| `REVIEW` | Có kết quả chạy nhưng cần xem cảnh báo hoặc lỗi/thiếu waveform |
| `OBSERVED` | Testbench chỉ in kết quả; chưa có marker tự kiểm tra được cấu hình |
| `BLOCKED` / `NOT_RUN` | Thiếu dependency/công cụ hoặc chưa được chọn chạy |
| `FAIL` | Compile/runtime lỗi, timeout, marker lỗi hoặc thiếu marker thành công bắt buộc |

`MOCK_INTEGRATION` không thay kết quả integration thật. `CPU_SMOKE` dùng chương trình vòng lặp tăng số của upstream, quan sát CPU ghi giá trị 5 vào địa chỉ `0x3fc`; không phải bộ kiểm tra đầy đủ tập lệnh RISC-V. Test address slice hiện chỉ in giá trị kỳ vọng nên được ghi `OBSERVED`.

Exit code: `1` khi có lỗi/thất bại; mặc định `0` khi đã tổng hợp xong dù còn mục chờ. Thêm `--strict` để trả `2` khi hồ sơ chưa đủ. Trạng thái tổng hợp luôn thể hiện `INCOMPLETE` nếu chưa có kết quả thật cho phạm vi bắt buộc. Công cụ không chứng nhận tapeout.

## Chọn cửa sổ dạng sóng

```powershell
python -B tools/evidence/evidence.py wave --input output/evidence/run_001/simulation/dma_axi/waves.vcd --output output/evidence/dma_axi_detail.svg --signals "*awvalid" "*awready" "*wvalid" "*wready" "*wlast" --start 0 --end 1000000
gtkwave output/evidence/run_001/simulation/dma_axi/waves.vcd
```

`start/end` là tick theo `$timescale` của VCD; ví dụ tick 1 ps thì 1.000.000 tick = 1 µs. Hình giới hạn 12 tín hiệu và 2.000 sự kiện/tín hiệu. Nếu vượt giới hạn, cửa sổ bị cắt và có nhãn rõ ràng; dùng VCD gốc hoặc chọn khoảng ngắn hơn để xem đầy đủ. X/Z giữ màu riêng; không suy ra functional coverage từ số lần đổi tín hiệu. Preview hỗ trợ các tín hiệu scalar/vector nhị phân trong VCD do Icarus tạo; FSDB/FST cần xuất sang VCD trước khi dựng ảnh bằng công cụ này.

## Tiếp nhận thiết kế vật lý bằng công cụ miễn phí

Luồng dự kiến: Yosys → OpenROAD/OpenSTA → GDS/layout → KLayout hoặc Magic DRC → Netgen LVS. Có thể dùng OpenLane để điều phối các bước. Bộ thu nhận hoạt động độc lập với công cụ sinh kết quả; khi trường cấp Cadence/Synopsys/Siemens, xuất cùng cấu trúc manifest để giữ nguyên báo cáo. OpenLane có hướng dẫn cài đặt Nix hoặc Docker; trên Windows dùng môi trường WSL/container theo tài liệu chính thức. Xem [OpenLane installation](https://openlane2.readthedocs.io/en/latest/getting_started/installation_overview.html).

**Hiện chưa chốt PDK, top vật lý, thư viện/corner hay clock constraints.** Các công cụ vật lý không được cài bởi collector. Không tạo GDS minh họa hoặc ảnh layout giả cho thiết kế; mục vật lý giữ `BLOCKED/INCOMPLETE` đến khi có kết quả thực tế. Các SDC có sẵn trong ví dụ PicoRV32 là constraint của các ví dụ đó, không tự dùng làm constraint của SoC.

Sao chép `physical_template.json` ra vị trí nhận kết quả, ví dụ `pd_results/physical.json`. Điền các trường từ flow thực tế:

- `top`, `source_revision`, `pdk`, `pdk_version`: cùng thiết kế và lần chạy.
- `artifacts`: GDS/GDSII, ảnh PNG/JPEG, netlist, SDC, SPEF, Liberty, rule deck DRC và setup/deck LVS. Đường dẫn tính từ nơi đặt manifest; chấp nhận đường dẫn tuyệt đối. `sdc`, `spef`, `liberty` nhận một đường dẫn hoặc danh sách đường dẫn cho nhiều mode/corner. File bị include hoặc tài liệu khác cần giao bổ sung trong gói đầu vào của flow.
- `gds_sha256`: hash của đúng GDS dùng tạo ảnh, DRC và extraction/LVS. Không trộn các revision; rule deck/top/corner phải được người phụ trách kiểm tra.
- `drc`, `lvs`: phiên bản công cụ, lệnh đã chạy, exit code, báo cáo gốc và số liệu. DRC dùng `violations` nguyên không âm; LVS dùng `matched` boolean từ kết luận của lần LVS toàn top đã hoàn tất, không lấy dòng match của một subcell.
- `required_timing_views`: danh sách view bắt buộc dạng `corner/mode/setup` hoặc `corner/mode/hold`, theo matrix đã được duyệt; phải có cả setup và hold. Ví dụ về cú pháp: `slow/functional/setup`, `fast/functional/hold`; đây không phải các corner đã lựa chọn cho dự án.
- `timing`: mỗi view có báo cáo gốc, `stage=post_route`, corner/mode/check, đơn vị, WNS, TNS có dấu, số endpoint chưa constraint và tool/version/command/exit code. Số liệu thiếu để `null`, không dùng 0 thay cho chưa đo. SPEF/SDC/Liberty phải khớp từng view.

```powershell
(Get-FileHash -Algorithm SHA256 pd_results/chip.gds).Hash.ToLower()
python -B tools/evidence/evidence.py collect --physical pd_results/physical.json --out output/evidence/physical_001
python -B tools/evidence/evidence.py run --physical pd_results/physical.json --out output/evidence/combined_001
```

GDS/GDSII được sao chép nguyên byte và hash. Collector kiểm tra signature cơ bản của GDS và PNG/JPEG; kiểm tra này không thay cho mở/kiểm tra đầy đủ geometry hoặc nội dung ảnh.

Với KLayout DRC, đặt `drc.format="klayout-rdb"` và trỏ `drc.report` tới `.lyrdb`. Collector đọc XML, kiểm tra top-cell, cộng multiplicity của tất cả marker, kể cả marker được gắn nhãn waived; không âm thầm bỏ violation. Cấu trúc theo [KLayout RDB format](https://www.klayout.de/staging/rdb_format.html). Các báo cáo Magic, Netgen, OpenSTA và công cụ thương mại dùng số liệu chuẩn hóa trong manifest cùng báo cáo gốc; **chưa có parser tự động cho các log vendor này**. Người xuất kết quả hoặc adapter của flow chịu trách nhiệm điền số liệu; collector không chạy lại DRC/LVS/STA.

Gói vật lý đủ file, provenance và số liệu đạt yêu cầu chỉ được ghi `REPORTED_PASS` (theo bên tạo báo cáo). Negative slack, endpoint chưa constraint, violation DRC, LVS không match hoặc exit code lỗi đều chặn kết quả đạt. Gói chỉ có TT, chỉ có setup, thiếu corner bắt buộc, metric NaN/Infinity hoặc thiếu báo cáo không được coi là hồ sơ hoàn chỉnh.

## Xuất ảnh từ GDS thực bằng KLayout

Sau khi cài KLayout đầy đủ và có GDS:

```powershell
klayout -z -r tools/evidence/export_layout.py -rd gds_path=pd_results/chip.gds -rd png_path=pd_results/layout.png -rd top_cell=soc_top
```

`top_cell` phải là tên cell thật; nếu GDS chỉ có một top cell thì có thể bỏ tham số này. Thêm `-rd layer_props=pd_results/layers.lyp` nếu có cấu hình màu/lớp từ PDK. Script từ chối ghi đè ảnh cũ. Dùng `-z` để có giao diện ẩn phục vụ rendering; không thay bằng batch `-b`. Tham khảo [KLayout MainWindow](https://www.klayout.de/doc-qt5/code/class_MainWindow.html) và [LayoutView](https://www.klayout.de/doc-qt5/code/class_LayoutView.html).

Script đã chuẩn bị theo API KLayout; chưa chạy end-to-end với GDS của dự án do hiện chưa có GDS/PDK và KLayout trong môi trường. Toàn bộ kiểm thử collector dùng fixture tổng hợp riêng trong thư mục tạm, không đưa fixture vào báo cáo dự án.

## Kiểm thử bộ công cụ

```powershell
python -B -m unittest discover -s tools/evidence -p test_evidence.py -v
```

Các test kiểm tra false PASS, lỗi/timeout, dependency thiếu, waveform X/Z/alias/cắt cửa sổ, DRC/LVS/timing thiếu hoặc lỗi, hash GDS, matrix corner và thay đổi file trong gói bàn giao.
