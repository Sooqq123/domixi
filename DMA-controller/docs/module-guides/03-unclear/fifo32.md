# Làm rõ tên `fifo32`

> Phân loại: `UNCLEAR`. Disposition hiện hành: tên artifact mô phỏng, không tạo RTL; FIFO canonical là `dma_fifo_latch`.

## 1. Tên được tìm thấy ở đâu

`fifo32` chỉ xuất hiện như một phần tên executable simulation tạm trong:

- `docs/superpowers/plans/2026-08-19-fifo-depth-32-canonicalization.md`.

Không có declaration `module fifo32` hoặc source `fifo32.v` trong cây hiện hành.

## 2. Vì sao không được coi là module

Architecture V2.4.1 chốt `FIFO_DEPTH=32` cho `dma_fifo_latch.v`. Số 32 là quyết định depth baseline, không tạo một module name mới.

Một tên build như `domixi-fifo32.vvp` chỉ giúp phân biệt artifact mô phỏng. Nó không định nghĩa port, reset, FIFO semantics hoặc ownership.

## 3. Quan hệ có evidence

Module chuẩn là `dma_fifo_latch`:

- data width 32 bit;
- depth 32 words trong baseline;
- synchronous single-clock FIFO;
- có full, empty, count và flush.

Không có compatibility requirement cho tên `fifo32`.

## 4. Thông tin cần có nếu muốn thêm alias

- Consumer cụ thể instantiate `fifo32`.
- Port list consumer mong đợi.
- Alias chỉ khóa depth hay còn đổi behavior.
- Parameter policy và test compatibility.
- Lý do không cập nhật consumer sang `dma_fifo_latch`.

## 5. Hành động bị cấm

- Không tạo FIFO implementation song song.
- Không copy `dma_fifo_latch` sang file mới.
- Không hard-code wrapper depth 32 khi chưa có consumer.
- Không đưa alias vào production manifest để xử lý tên build tạm.

## 6. Điều kiện xem xét lại

Chỉ xem xét compatibility target nếu có consumer thực tế, port contract và compatibility test với `dma_fifo_latch`. Không cần owner quyết định thêm nếu ba artifact này chưa tồn tại.

Nếu không có consumer, kết luận cuối là `fifo32` không phải module RTL.

## 7. Nguồn đối chiếu

- `docs/superpowers/plans/2026-08-19-fifo-depth-32-canonicalization.md`
- `DMA-controller/rtl/dma_fifo_latch.v`
- `DMA-controller/tb/tb_dma_fifo_latch.v`
- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.1
- `DMA-controller/docs/architecture/document_manifest.md`
