# Thiết kế `dma_axi_master`

> Phân loại: `READY_NOW`. Source hiện hành nằm tại `DMA-controller/rtl/dma_axi_master.v`; testbench nằm tại `DMA-controller/tb/tb_dma_axi_master.v`.

## 1. Mục tiêu và sản phẩm

`dma_axi_master` thực hiện một phép sao chép tuyến tính từ vùng nguồn sang vùng đích bằng AXI4. Read engine đọc dữ liệu vào FIFO, write engine lấy dữ liệu từ FIFO để ghi ra đích. Hai engine tiến triển độc lập nhưng cùng chịu một cơ chế abort để mọi lỗi đều kết thúc bằng đúng một terminal event.

Sản phẩm hoàn chỉnh phải có:

- hai FSM AXI độc lập cho read và write;
- bộ chia burst tối đa 16 beat và không vượt ranh giới 4 KiB;
- giao tiếp FIFO có backpressure đúng;
- kiểm `RID`, `BID`, `RRESP`, `BRESP` và framing `RLAST`;
- cơ chế abort đưa cả hai kênh về quiescent rồi flush FIFO;
- đúng một xung `status_done` hoặc `status_error` cho mỗi lần chạy;
- testbench có slave model, scoreboard dữ liệu, stall ngẫu nhiên và timeout.

## 2. Profile giao dịch được phép

Baseline cố định các thuộc tính sau:

| Thuộc tính | Giá trị | Ý nghĩa |
|---|---:|---|
| Data width | 32 bit | Mỗi beat bằng 4 byte |
| `AxSIZE` | `3'b010` | 4 byte mỗi beat |
| `AxBURST` | `2'b01` | INCR |
| `AxLEN` | 0 đến 15 | 1 đến 16 beat |
| `AWID`, `ARID` | 0 | Dedicated DMA master |
| `AxPROT` | `3'b001` | Secure, Privileged, Data |
| `WSTRB` | `4'b1111` | Full-word write |

Descriptor đầu vào phải được `dma_controller` kiểm địa chỉ word-aligned, length khác 0, length chia hết cho 4 và không overflow không gian 32 bit. Module này vẫn không được tạo burst vượt 4 KiB, kể cả descriptor tổng thể hợp lệ.

## 3. Giao diện và quyền sở hữu state

| Nhóm | Tín hiệu chính | Chủ sở hữu |
|---|---|---|
| Command | `cfg_src_addr`, `cfg_dst_addr`, `cfg_byte_len`, `cfg_start` | `dma_controller` |
| Status | `status_busy`, `status_done`, `status_error` | `dma_axi_master` |
| FIFO | `fifo_*` | Master phát push/pop/flush; FIFO giữ dữ liệu |
| AXI read address | `m_axi_ar*` | Read FSM |
| AXI read data | `m_axi_r*` | Read FSM và slave |
| AXI write address | `m_axi_aw*` | Write FSM |
| AXI write data | `m_axi_w*` | Write FSM và slave |
| AXI response | `m_axi_b*` | Write FSM và slave |

Reset active-low phải đưa VALID, READY do master điều khiển, status, pointer và state về giá trị vô hại. Không được phát terminal event trong reset hoặc chỉ do nhả reset.

## 4. Chia burst đúng

Với địa chỉ hiện tại `addr` và `bytes_left`:

```text
beats_left   = ceil(bytes_left / 4)
bytes_to_4kb = 4096 - addr[11:0]
beats_to_4kb = bytes_to_4kb / 4
burst_beats  = min(beats_left, 16, beats_to_4kb)
AxLEN        = burst_beats - 1
burst_bytes  = burst_beats * 4
```

Vì descriptor word-aligned và length là bội số 4, phép chia không cần xử lý partial beat. Phải dùng biến đủ rộng để không mất carry. Một địa chỉ ở `0x...0FFC` chỉ được phát burst một beat, sau đó pointer chuyển sang page kế tiếp.

Địa chỉ và `AxLEN` phải được chốt trước khi đưa `AxVALID` lên. Khi `AxVALID=1` và `AxREADY=0`, payload phải ổn định cho đến handshake.

## 5. Read FSM

### `R_IDLE`

Chờ `cfg_start`. Khi nhận command hợp lệ, chốt source pointer và byte count, đánh dấu read active rồi chuyển sang `R_ADDR`.

### `R_ADDR`

Chỉ phát AR khi:

- còn byte phải đọc;
- không có abort;
- FIFO còn đủ chỗ cho toàn bộ burst dự kiến.

Giữ `ARVALID`, `ARADDR` và `ARLEN` ổn định khi bị stall. Sau AR handshake, chốt số beat cần nhận, bật `RREADY` và chuyển sang `R_DATA`.

### `R_DATA`

Mỗi `RVALID && RREADY` là một beat đã nhận. Beat chỉ được push vào FIFO khi:

- `RRESP=OKAY`;
- `RID` đúng ID đã phát;
- `RLAST` xuất hiện đúng beat cuối dự kiến;
- chưa có abort từ kênh kia trong cùng chu kỳ.

Nếu `RLAST` sớm hoặc thiếu ở beat cuối, giao thức đã bị vi phạm. Module phải ghi lỗi và đóng kênh vi phạm hữu hạn, không chờ vô hạn một slave đã phá framing. Nếu burst hoàn tất bình thường, cập nhật source pointer, giảm `read_bytes_left` rồi quay lại `R_ADDR`.

## 6. Write FSM

### `W_IDLE`

Chờ command, chốt destination pointer và byte count rồi chuyển `W_ADDR`.

### `W_ADDR`

Chỉ phát AW khi FIFO đang có đủ dữ liệu cho toàn bộ burst. Điều này tránh nhận AW rồi bị đói dữ liệu do read side chưa tiến triển.

Một AW đã đưa lên bus không được rút lại khi abort đến. Phải giữ payload đến handshake. Sau handshake mới chuyển sang `W_DATA`.

### `W_DATA`

Chỉ được đưa `WVALID` lên sau AW handshake. Lấy head FIFO vào register dữ liệu, giữ `WDATA`, `WSTRB` và `WLAST` ổn định dưới backpressure. Chỉ pop FIFO khi `WVALID && WREADY`.

Không pop FIFO lúc nạp `WDATA` nếu chưa handshake. Nếu FIFO cung cấp head tổ hợp, phải dành một chu kỳ hoặc logic điều phối rõ ràng để không lấy nhầm item kế tiếp.

### `W_RESP`

Sau W beat cuối, bật `BREADY` và chờ response. Kiểm cả `BRESP` và `BID`. Chỉ cập nhật destination pointer sau response OKAY. Lỗi chuyển flow sang abort cleanup.

### `W_FLUSH`

Ngừng phát request mới. Khi không còn transaction write đã nhận, flush FIFO. Chỉ báo write side idle sau khi FIFO rỗng.

## 7. Abort và terminal event

Nguồn abort gồm:

- `RRESP` khác OKAY;
- `RID` mismatch;
- `RLAST` framing mismatch;
- `BRESP` khác OKAY;
- `BID` mismatch.

Abort phải được latch để kênh còn lại thấy lỗi ở các chu kỳ sau. Lỗi cùng chu kỳ phải chặn việc phát địa chỉ mới ở peer channel.

Quy tắc kết thúc:

```text
error terminal = abort_latched AND read_idle AND write_idle AND fifo_empty
done terminal  = NOT abort_latched AND read_idle AND write_idle AND fifo_empty
```

`status_done` và `status_error` là pulse một chu kỳ, loại trừ nhau. `status_busy` giữ 1 từ lúc start được chấp nhận đến terminal event. Một lỗi không được vừa báo ERROR vừa báo DONE.

## 8. Thiết kế từ đầu theo mốc

### Mốc 1: Burst calculator

Viết function và test độc lập cho length 4, 64, 68 byte; địa chỉ đầu page; địa chỉ gần cuối page; descriptor qua nhiều page. Kiểm mọi burst có 1 đến 16 beat và không crossing 4 KiB.

### Mốc 2: Read engine

Dùng FIFO stub luôn có chỗ. Test AR stall, R stall, nhiều burst và pointer. Sau đó thêm kiểm response, ID và RLAST.

### Mốc 3: Write engine

Dùng FIFO model đã có dữ liệu. Test AW stall, W stall, B stall, WLAST và pop count. Chứng minh không có WVALID trước AW handshake.

### Mốc 4: Ghép hai engine

Dùng ordered memory model. Sao chép qua nhiều burst, qua ranh giới page và so vùng đích với vùng nguồn.

### Mốc 5: Abort

Tiêm từng loại lỗi ở đầu, giữa và cuối transfer. Kiểm không còn VALID bị treo, FIFO được dọn và chỉ có ERROR pulse.

### Mốc 6: Random backpressure

Randomize READY/VALID hợp lệ với seed được ghi lại. Thêm progress monitor dựa trên handshake, không dựa trên số chu kỳ cố định của AXI peer.

## 9. Test case bắt buộc

| ID cục bộ | Tình huống | Kết quả |
|---|---|---|
| AXIM-01 | Reset | Tất cả output control vô hại |
| AXIM-02 | Transfer 4 byte | Một AR, một R, một AW, một W, một B |
| AXIM-03 | Transfer 64 byte | Burst 16 beat |
| AXIM-04 | Transfer lớn hơn 64 byte | Nhiều burst, pointer đúng |
| AXIM-05 | Bắt đầu tại offset `0xFFC` | Burst đầu một beat, không crossing 4 KiB |
| AXIM-06 | Stall AR/AW/W/R/B | Payload ổn định, không mất beat |
| AXIM-07 | FIFO near-full | Không phát AR nếu thiếu chỗ cho cả burst |
| AXIM-08 | FIFO thiếu dữ liệu | Không phát AW nếu thiếu cả burst |
| AXIM-09 | `RRESP` hoặc `BRESP` lỗi | Abort, ERROR duy nhất |
| AXIM-10 | `RID` hoặc `BID` mismatch | Abort, không ghi nhận thành công |
| AXIM-11 | `RLAST` sớm hoặc muộn | Framing error, kết thúc hữu hạn |
| AXIM-12 | Abort khi peer channel có request outstanding | Hoàn tất nghĩa vụ đã nhận rồi quiescent |
| AXIM-13 | Nhiều lần chạy liên tiếp | State không rò từ lần trước |

## 10. Assertion và checker hữu ích

- Khi `ARVALID && !ARREADY`, toàn bộ AR payload ổn định.
- Khi `AWVALID && !AWREADY`, toàn bộ AW payload ổn định.
- Khi `WVALID && !WREADY`, `WDATA`, `WSTRB`, `WLAST` ổn định.
- `WVALID` chỉ được xuất hiện sau một AW handshake chưa hoàn tất.
- `fifo_rd_en` chỉ có khi W handshake.
- `fifo_wr_en` chỉ có khi R handshake hợp lệ và không lỗi.
- Mỗi burst có đúng `AxLEN+1` beat.
- `status_done` và `status_error` không đồng thời.
- Không phát AR hoặc AW mới sau abort.

## 11. Điểm cần tránh

- Tính burst chỉ theo `bytes_left` mà quên khoảng cách đến 4 KiB.
- Thay đổi address khi VALID đang bị stall.
- Pop FIFO khi đưa WVALID lên thay vì khi W handshake.
- Tiếp tục push beat có RRESP hoặc framing lỗi.
- Rút một AW đã presented khi abort đến.
- Báo ERROR ngay khi phát hiện lỗi dù channel còn outstanding.
- Dùng timeout RTL để tự bịa response AXI chưa hoàn chỉnh.

## 12. Rủi ro và cách kiểm tra

| Rủi ro | Bằng chứng cần có |
|---|---|
| Deadlock giữa FIFO và hai engine | Random backpressure với progress scoreboard |
| Off-by-one ở `AxLEN` | Sweep 1 đến 33 beat tương đương |
| Crossing 4 KiB | Sweep offset cuối page |
| Lost beat khi stall | Payload stability assertion và memory compare |
| Abort không sạch | Sau terminal, mọi VALID thấp và FIFO empty |
| False DONE | Tiêm mọi lỗi và đếm terminal pulse |

## 13. Tiêu chí hoàn thành

- Directed suite và random suite đều PASS với seed lưu trong log.
- Không có burst vượt 16 beat hoặc crossing 4 KiB.
- Data scoreboard khớp toàn bộ transfer thành công.
- Mọi lỗi response, ID và RLAST đi đến terminal hữu hạn.
- Không có W trước AW acceptance.
- Sau terminal event, module ở trạng thái có thể nhận một start mới.

## 14. Lộ trình tự triển khai

Hãy bắt đầu từ burst calculator và slave model, không bắt đầu bằng FSM hoàn chỉnh. Hoàn thiện read engine và write engine bằng stub riêng, sau đó mới ghép qua FIFO thật. Chỉ thêm abort sau khi đường thành công đã ổn định. Cuối cùng chạy stall ngẫu nhiên và dùng assertion để chứng minh payload stability.

## 15. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.1, 5.1 và 5.2
- `DMA-controller/docs/architecture/fsm_specification.md`, DMA read/write FSM
- `DMA-controller/docs/architecture/assumptions_and_tbd.md`, AXI progress assumptions
- `DMA-controller/docs/architecture/signal_list.csv`, DMA AXI và abort signals
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/architecture/requirements_traceability.csv`, `REQ_DMA_00` đến `REQ_DMA_06`
- `DMA-controller/rtl/dma_axi_master.v`
- `DMA-controller/tb/tb_dma_axi_master.v`
