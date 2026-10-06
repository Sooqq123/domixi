# Runbook tiếp nhận và tích hợp Firewall RTL

Runbook này lưu quy trình tiếp nhận source và cách tái kiểm tra production RTL. Các package Firewall đã được tích hợp; mock chỉ còn dùng cho bài test boundary lịch sử và không thuộc source list production.

## 1. Hồ sơ phải nhận

Mỗi package cần có source RTL dạng text, unit testbench tự kiểm tra, port list có width/reset/producer/consumer, lệnh compile, phiên bản simulator, log có PASS marker, waveform đại diện và báo cáo mismatch với V2.4.1. Gói matcher cần thêm pure reference model và random seeds. Gói APB cần register conformance report. Hai gói drain cần exact-beat evidence và owner handoff note.

## 2. Kiểm tra không sửa source bàn giao

1. Ghi commit/archive ID và SHA256 của từng file.
2. Chạy unit command do owner cung cấp trong thư mục tạm.
3. Đối chiếu module name và port list với student guide cùng `signal_list.csv`.
4. Ghi từng mismatch; trả package về owner nếu mismatch nằm trong module Nhóm A/B.
5. Chỉ đánh dấu accepted khi unit test chạy từ source PASS và contract report không còn blocker.

Lệnh kiểm tra dependency:

```powershell
python -B DMA-controller/scripts/check_firewall_contract.py --require-real
```

Lệnh trên hiện phải PASS với top 94 cổng, mười hai production dependency và hai SDC boundary không có phantom hoặc missing port.

## 3. Thay mock drain bằng source thật

Production wrapper nằm tại `rtl/fw_drain_fsm.v`. Compile wrapper bằng hai leaf production và loại hoàn toàn thư mục mock khỏi source list:

```powershell
iverilog -g2012 -Wall -Wimplicit -s tb_fw_drain_fsm `
  -o "$env:TEMP/tb_fw_drain_fsm_real.vvp" `
  rtl/fw_drain_fsm.v `
  rtl/fw_write_drain.v `
  rtl/fw_read_drain.v `
  tb/tb_fw_drain_fsm.v
vvp "$env:TEMP/tb_fw_drain_fsm_real.vvp"
```

Nếu port khác, không sửa leaf source. Ghi mismatch và cập nhật wrapper mapping sau khi owner phê duyệt port contract. Combined PASS không thay thế unit PASS của từng leaf.

## 4. Điều kiện production `dma_bus_firewall`

Phải có đồng thời:

- version và unit PASS của `fw_axi_address_slice`, `fw_context_tracker`, `fw_data_path_mux`;
- acceptance decision cho bốn gói sinh viên;
- wrapper drain chạy với source thật;
- port matrix cho policy arrays, effective context view, matcher decision, owner set/clear và fault records;
- quyết định rõ cách matcher phục vụ AW và AR độc lập;
- APB event/effective-next-value cho cạnh `AUTO_CTX_EN:1->0`.

Các điều kiện trên đã được đáp ứng trong source hiện hành. `rtl/dma_bus_firewall.v` có đúng 94 public ports theo source manifest. Chạy checker trước mỗi regression:

```powershell
python -B DMA-controller/scripts/check_firewall_contract.py --require-real
```

## 5. Chuyển boundary test sang top thật

Test chuẩn bị tích hợp vẫn có thể chọn stub bằng macro `FIREWALL_DUT`. Regression production dùng top thật cùng toàn bộ dependency:

```powershell
iverilog -g2012 -Wall -Wimplicit `
  -DFIREWALL_DUT=dma_bus_firewall `
  -s tb_soc_dma_firewall_contract `
  -o "$env:TEMP/tb_soc_dma_firewall_real.vvp" `
  <production-source-list> `
  DMA-controller/tb/integration/tb_soc_dma_firewall_contract.v
vvp "$env:TEMP/tb_soc_dma_firewall_real.vvp"
```

Default-deny test phải tiếp tục PASS. Sau đó thêm các test allowed path, static/dynamic region, mixed owner, fault collision và same-cycle priority trong top regression; không sửa expected result để hợp thức hóa source.

## 6. Lệnh regression hiện hành

```powershell
powershell -ExecutionPolicy Bypass -File DMA-controller/scripts/run_codex_integration_prep.ps1
python -B tools/run_all_sims.py
python -B tools/evidence/evidence.py run --out output/audit_20260917/evidence_frontend_v7
```

Script chuẩn bị tích hợp giữ lại kiểm tra mock lịch sử. `tools/run_all_sims.py` chạy production RTL regression; evidence mới nhất nằm tại `output/audit_20260917/evidence_frontend_v7` với 19 PASS và không có REVIEW hoặc FAIL. Regression chính có 18/18 testbench PASS, gồm cả reset contract của `aegis_soc_top`.

## 7. Giả định còn hiệu lực

- Dữ liệu/địa chỉ/ID lần lượt rộng 32/32/4 bit; burst tối đa 16 beat theo baseline.
- Reset là active-low, asynchronous assert và synchronous deassert.
- Hai drain leaf dùng port contract đã in trong student guides 03/04.
- Wrapper không sở hữu state, không serialize read/write và không làm giàu fault metadata.
- Public stub chỉ chứng minh boundary wiring và default-deny isolation; nó không triển khai APB policy, ACL, context tracker, logger hay allowed path.
- Formal/coverage cần hierarchy thật và công cụ phù hợp. Synthesis/STA/PPA cần production RTL cùng target library/part và timing corner.
