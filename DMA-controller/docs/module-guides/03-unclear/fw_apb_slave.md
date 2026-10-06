# Làm rõ tên `fw_apb_slave`

> Phân loại: `UNCLEAR`. Không tạo RTL từ tài liệu này.

## 1. Tên được tìm thấy ở đâu

`fw_apb_slave` xuất hiện trong:

- `DMA-controller/docs/architecture/architecture_overview.md`, phần mô tả APB protection profile;
- `DMA-controller/docs/architecture/changelog.md`, phần phân tầng bảo mật APB.

Hai vị trí mô tả một Firewall APB4 slave có `s_apb_pprot[2:0]`, không expose `PSTRB` và chỉ nhận full-word access.

## 2. Disposition hiện hành

Tên module canonical duy nhất là `fw_apb_regs`. `fw_apb_slave` là name drift trong prose, không phải alias, wrapper hoặc module RTL cần tạo. Source tree hiện chưa có `fw_apb_regs.v` được công nhận vì vẫn chờ Gói sinh viên 01.

Hành động trực tiếp là không tạo `fw_apb_slave.v`, không thêm alias và không thêm compatibility wrapper. Mọi thiết kế APB Firewall theo hướng dẫn `fw_apb_regs`.

## 3. Quan hệ với `fw_apb_regs`

Nội dung APB4 từng gắn với tên `fw_apb_slave` chính là vai trò bên ngoài của `fw_apb_regs`: decode cửa sổ, kiểm protection, trả read/write response và bảo vệ register state.

Không tạo hai module cùng sở hữu register và không đổi tên bài nộp sinh viên khỏi tên canonical.

## 4. Điều cần kiểm khi nhận Gói 01

- Declaration dùng `module fw_apb_regs`.
- Module này sở hữu `PREADY`, `PSLVERR`, `PRDATA` và register side effects.
- Không có instance hoặc file `fw_apb_slave` trong source/manifest.
- Testbench instantiate tên canonical.

## 5. Khi nào mới xem xét lại

Không cần thêm quyết định owner trong baseline hiện tại. Chỉ mở lại disposition nếu một consumer hoặc build target hiện hành bắt buộc tên `fw_apb_slave`, đồng thời cung cấp port contract và compatibility test. Khi đó thay đổi phải được review như một yêu cầu tích hợp mới.

## 6. Hành động bị cấm

- Không tạo `fw_apb_slave.v`.
- Không duplicate APB decode hoặc register state.
- Không tự rename RTL sinh viên.
- Không thêm compatibility wrapper chỉ để một test compile.
- Không coi hai tên là alias trong baseline hiện tại.

## 7. Điều kiện xem xét lại

Chỉ xem xét tạo compatibility target khi có đủ consumer thật, port contract và compatibility test. Nếu thiếu một trong ba, file này tiếp tục là no-RTL action gate và `fw_apb_regs` vẫn là target duy nhất.

## 8. Nguồn đối chiếu

- `DMA-controller/docs/architecture/architecture_overview.md`
- `DMA-controller/docs/architecture/changelog.md`
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/document_manifest.md`
- `DMA-controller/docs/tutorials/firewall-rtl/student-guides/01_fw_apb_regs_lab_guide.md`
