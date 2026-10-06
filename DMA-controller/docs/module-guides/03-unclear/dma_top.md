# Làm rõ tên `dma_top`

> Phân loại: `UNCLEAR`. Disposition hiện hành: tên lịch sử, không tạo RTL hoặc compatibility wrapper.

## 1. Tên được tìm thấy ở đâu

`dma_top` xuất hiện trong tài liệu lịch sử:

- `docs/superpowers/specs/2026-08-13-dma-controller-design.md`.

Tài liệu đó ghi rõ việc đổi file/module `dma_top` thành `dma_controller` và không giữ compatibility wrapper.

Không có `DMA-controller/rtl/dma_top.v` trong source hiện hành.

## 2. Vì sao tên thuộc nhóm chưa rõ

Ở baseline hiện tại, `dma_controller` đã là wrapper DMA core có APB, FIFO, AXI master và context sideband. Không có requirement hiện hành nào định nghĩa một tầng `dma_top` khác.

Tên `dma_top` có thể xuất hiện trong script, test cũ hoặc tài liệu ngoài baseline, nhưng không đủ để tạo module mới. Tài liệu lịch sử cũng không có quyền override architecture V2.4.1.

## 3. Quan hệ đã có evidence

Evidence lịch sử duy nhất cho thấy `dma_top` là tên cũ được thay bằng `dma_controller`, không phải một module mới bổ sung. Vì vậy hướng mặc định là không tồn tại `dma_top` trong RTL hiện hành.

Điều này không loại trừ một wrapper SoC tương lai, nhưng wrapper đó phải có requirement mới và boundary cụ thể.

## 4. Thông tin còn thiếu nếu muốn phục hồi tên

- Consumer nào yêu cầu module `dma_top`.
- Port list mà consumer đó mong đợi.
- Wrapper chỉ đổi tên hay còn thêm clock/reset, APB bridge hoặc Firewall.
- Yêu cầu backward compatibility và thời hạn duy trì.
- Test nào chứng minh wrapper cần thiết.

## 5. Khi nào mới xem xét lại

Không cần thêm quyết định trong baseline hiện tại. Chỉ xem xét lại nếu có consumer thực tế bị chặn. Khi đó yêu cầu mới phải chọn rõ một trong các hướng:

- cập nhật consumer sang `dma_controller`; hoặc
- phê duyệt một compatibility wrapper có phạm vi tối thiểu; hoặc
- định nghĩa top SoC mới với tên và trách nhiệm khác.

## 6. Hành động bị cấm

- Không tạo `dma_top.v` chỉ vì tên từng tồn tại.
- Không copy toàn bộ `dma_controller` sang tên mới.
- Không thêm wrapper rỗng vào production manifest mà không có consumer.
- Không sửa port `dma_controller` để giả lập một interface chưa biết.

## 7. Điều kiện xem xét lại

Chỉ phân loại lại khi có một consumer, build target hoặc requirement hiện hành chỉ rõ:

- module name;
- port contract;
- trách nhiệm bổ sung so với `dma_controller`;
- compatibility test.

Nếu không có các mục này, tên nên được giữ ở trạng thái retired historical name.

## 8. Nguồn đối chiếu

- `docs/superpowers/specs/2026-08-13-dma-controller-design.md`, tài liệu lịch sử
- `DMA-controller/rtl/dma_controller.v`
- `DMA-controller/docs/architecture/architecture_overview.md`
- `DMA-controller/docs/architecture/document_manifest.md`
