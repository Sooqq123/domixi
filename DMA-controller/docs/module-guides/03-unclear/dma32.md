# Làm rõ tên `dma32`

> Phân loại: `UNCLEAR`. Disposition hiện hành: artifact naming, không tạo RTL.

## 1. Tên được tìm thấy ở đâu

`dma32` chỉ được tìm thấy như một phần tên file output mô phỏng tạm trong:

- `docs/superpowers/plans/2026-08-19-fifo-depth-32-canonicalization.md`.

Ví dụ lịch sử dùng chuỗi `domixi-dma32.vvp` cho executable simulation. Đây không phải declaration `module dma32` và không phải file source.

## 2. Vì sao chưa có authority

Không có:

- `dma32.v`;
- declaration `module dma32`;
- port list;
- requirement hoặc manifest entry;
- testbench instantiate `dma32`.

Hậu tố 32 có thể chỉ data width, FIFO depth hoặc nhãn build. Không thể suy ra chức năng từ tên.

## 3. Module chuẩn gần nhất

Baseline hiện hành có:

- `dma_controller` làm wrapper DMA core;
- `dma_axi_master` dùng data width 32 bit;
- `dma_fifo_latch` có depth 32 words.

Không có bằng chứng `dma32` là alias của bất kỳ module nào trong ba module trên.

## 4. Thông tin cần có nếu tên này là yêu cầu thật

- Vị trí consumer instantiate `dma32`.
- Ý nghĩa số 32.
- Port và parameter contract.
- Quan hệ với `dma_controller`.
- Lý do không dùng module canonical hiện hành.
- Compatibility hoặc migration test.

## 5. Hành động bị cấm

- Không tạo `dma32.v` từ tên executable tạm.
- Không hard-code data width hoặc FIFO depth chỉ vì hậu tố.
- Không alias `dma_controller` bằng macro hoặc wrapper chưa được yêu cầu.
- Không đưa tên vào RTL manifest.

## 6. Điều kiện xem xét lại

Chỉ xem xét lại khi có consumer thực tế, port contract và compatibility test. Không cần architecture owner quyết định thêm nếu ba artifact này chưa tồn tại; `dma32` tiếp tục là tên artifact mô phỏng, không phải module.

## 7. Nguồn đối chiếu

- `docs/superpowers/plans/2026-08-19-fifo-depth-32-canonicalization.md`
- `DMA-controller/rtl/dma_controller.v`
- `DMA-controller/rtl/dma_axi_master.v`
- `DMA-controller/docs/architecture/document_manifest.md`
