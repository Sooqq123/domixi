# Thiết kế `dma_fifo_latch`

> Phân loại: `READY_NOW`. Source hiện hành nằm tại `DMA-controller/rtl/dma_fifo_latch.v`; testbench nằm tại `DMA-controller/tb/tb_dma_fifo_latch.v`.

## 1. Mục tiêu và sản phẩm

`dma_fifo_latch` tách nhịp tiến triển của AXI read và AXI write. Read engine push dữ liệu đã kiểm tra vào FIFO. Write engine pop dữ liệu chỉ sau khi AW đã handshake. Khi abort kết thúc, `flush` xóa occupancy còn lại.

Sản phẩm cần có là FIFO đồng bộ 32 word x 32 bit với `full`, `empty`, `count`, simultaneous push/pop, flush và testbench có ordered scoreboard.

## 2. Vấn đề module giải quyết

AXI read và write có backpressure độc lập. Read data có thể đến trước khi matrix đích sẵn sàng nhận write. FIFO giữ dữ liệu theo thứ tự và giới hạn số burst read được phép phát dựa trên dung lượng trống.

Baseline chốt `DEPTH=32`. Kết quả model cho depth 32 là nguồn lựa chọn kiến trúc, không phải area, timing hoặc power evidence của RTL.

## 3. Input, output và tham số

| Tên | Hướng | Ý nghĩa |
|---|---|---|
| `clk`, `rst_n` | Input | Clock chung và reset active-low |
| `wr_en`, `wdata[31:0]` | Input | Push request và dữ liệu |
| `rd_en` | Input | Pop request |
| `flush` | Input | Xóa pointer và occupancy |
| `rdata[31:0]` | Output | Head hiện tại |
| `full`, `empty` | Output | Guard push/pop |
| `count` | Output | Occupancy từ 0 đến DEPTH |
| `DEPTH` | Parameter | Baseline bằng 32 |
| `PTR_WIDTH` | Parameter | Phải phù hợp `log2(DEPTH)` |

Source hiện hành dùng output read tổ hợp từ `mem_array[r_ptr]`. Consumer phải lấy `rdata` trước hoặc tại pop handshake theo timing contract của wrapper.

## 4. State ownership và phương trình

FIFO sở hữu memory array, write pointer và read pointer. Producer sở hữu `wr_en/wdata`. Consumer sở hữu `rd_en`. Abort coordinator sở hữu `flush`.

Với pointer có thêm một wrap bit:

```text
count = write_pointer_binary - read_pointer_binary
empty = write_pointer == read_pointer
full  = cùng low pointer nhưng wrap phase khác
```

Push hợp lệ khi `wr_en && !full`. Pop hợp lệ khi `rd_en && !empty`. Nếu cả hai hợp lệ cùng cạnh, occupancy giữ nguyên và thứ tự phải được bảo toàn.

## 5. Luồng dữ liệu

```text
AXI R handshake hợp lệ
        |
        v
   wr_en + wdata
   [ dma_fifo_latch ]
        |
        v
   rdata + rd_en
AXI W handshake sau AW acceptance
```

Beat có RRESP error, RID mismatch hoặc RLAST framing mismatch không được push. Quy tắc này thuộc `dma_axi_master`; FIFO chỉ thực hiện request hợp lệ được gửi đến.

## 6. Cấu trúc file đề xuất

Một file FIFO gồm:

1. Memory declaration.
2. Binary pointer và optional Gray pointer calculation.
3. Combinational `rdata/full/empty/count`.
4. Sequential write pointer và memory write.
5. Sequential read pointer.
6. Reset và flush priority.

Thiết kế này là single-clock. Gray pointer không cần cho CDC. Nếu giữ Gray pointer để full/empty, tài liệu và test phải ghi rõ nó không chứng minh asynchronous FIFO.

## 7. Thiết kế từ đầu

### Mốc 1: Occupancy model

Viết reference queue trong testbench. Push một item, kiểm `count=1`, `empty=0`, `rdata=item`. Pop và kiểm về empty.

### Mốc 2: Fill và drain

Push đúng 32 item có pattern tăng. Kiểm full chỉ lên sau item thứ 32. Drain và so từng item theo thứ tự.

### Mốc 3: Guard lỗi

Giữ `wr_en=1` khi full và chứng minh pointer/count không đổi. Giữ `rd_en=1` khi empty và chứng minh pointer/count không đổi.

### Mốc 4: Simultaneous push/pop

Khởi tạo một item A. Cùng cạnh pop A và push B. Sau cạnh, `count=1` và head là B.

### Mốc 5: Flush

Nạp nhiều item, assert `flush`, kiểm `count=0`, `empty=1`, `full=0`. Memory content không cần xóa vì pointer làm dữ liệu cũ không còn hợp lệ.

## 8. Source hiện hành

Source hiện hành dùng binary và Gray pointers. `count` là hiệu binary pointers. Full detection dùng wrap bits. `flush` có priority sau reset và trước push/pop. Read data là combinational.

Hai parameter `DEPTH` và `PTR_WIDTH` không được kiểm tự động. Cấu hình không phải power-of-two hoặc `PTR_WIDTH` sai có thể làm pointer index và full detection không đúng. Baseline chỉ dùng `DEPTH=32`, `PTR_WIDTH=5`.

## 9. Test case bắt buộc

| ID cục bộ | Stimulus | Expected |
|---|---|---|
| FIFO-01 | Reset | Empty, count 0, not full |
| FIFO-02 | Push một item | Count 1, head đúng |
| FIFO-03 | Fill 32 item | Full tại depth 32 |
| FIFO-04 | Push khi full | State giữ nguyên |
| FIFO-05 | Drain 32 item | Ordered data, empty cuối |
| FIFO-06 | Pop khi empty | State giữ nguyên |
| FIFO-07 | Push và pop cùng cạnh | Occupancy giữ, old head được tiêu thụ |
| FIFO-08 | Flush khi có bốn item | Empty trong một clock update |
| FIFO-09 | Reset giữa trạng thái non-empty | Pointer và count về 0 |

Đối chiếu `TC_FIFO_RTL_UNIT` và `REQ_DMA_00`.

## 10. Điểm cần tránh

- Tăng pointer khi full hoặc empty guard không thỏa.
- Xóa từng memory word khi flush và tạo path reset lớn không cần thiết.
- Gọi thiết kế single-clock là asynchronous FIFO vì có Gray pointer.
- Cho `count` có width không biểu diễn được DEPTH.
- Dùng cấu hình parameter ngoài baseline mà không thêm elaboration guard và test.
- Pop FIFO trước W handshake.

## 11. Rủi ro và cách kiểm tra

| Rủi ro | Kiểm tra |
|---|---|
| Off-by-one full | Fill đúng 31, 32 và thử item 33 |
| Pointer wrap | Push/pop hơn hai lần DEPTH với scoreboard |
| Simultaneous ordering | Case A pop và B push cùng cạnh |
| Stale data sau flush | Flush, push C, kiểm head là C |
| Parameter mismatch | Khóa baseline hoặc thêm fatal elaboration check |

## 12. Tiêu chí hoàn thành

- Count luôn trong miền 0 đến 32 ở baseline.
- Không overflow hoặc underflow pointer từ request không hợp lệ.
- Ordered scoreboard PASS qua wrap-around.
- Simultaneous push/pop và flush có directed test.
- Testbench có timeout và explicit PASS marker.

## 13. Lộ trình tự triển khai

Bắt đầu bằng queue model trong testbench, sau đó hiện thực binary pointers. Chỉ thêm Gray pointers nếu giữ cấu trúc source hiện hành hoặc có lý do rõ. Chạy fill/drain trước simultaneous case. Thêm flush cuối cùng và rerun toàn suite sau mọi thay đổi pointer.

## 14. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.1
- `DMA-controller/docs/architecture/fsm_specification.md`, DMA read/write FSM
- `DMA-controller/docs/architecture/signal_list.csv`, nhóm `DMA_FIFO_IF`
- `DMA-controller/docs/architecture/verification_test_plan.md`, `TC_FIFO_RTL_UNIT`
- `DMA-controller/docs/architecture/requirements_traceability.csv`, `REQ_DMA_00`
- `DMA-controller/rtl/dma_fifo_latch.v`
- `DMA-controller/tb/tb_dma_fifo_latch.v`
