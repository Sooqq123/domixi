# Thiết kế `dma_apb_slave`

> Phân loại: `READY_NOW`. Source hiện hành nằm tại `DMA-controller/rtl/dma_apb_slave.v`; testbench nằm tại `DMA-controller/tb/tb_dma_apb_slave.v`.

## 1. Mục tiêu và sản phẩm

`dma_apb_slave` là control plane của DMA Controller. CPU dùng APB3 để ghi địa chỉ nguồn, địa chỉ đích, số byte, bật ngắt và phát lệnh START. Module lưu trạng thái DONE và ERROR dạng sticky để phần mềm không bỏ lỡ một sự kiện ngắn.

Sau khi hoàn thành, người dùng phải tạo hoặc hiểu được:

- một APB slave 32 bit, không wait state;
- một xung `cfg_start` đúng một chu kỳ khi START được chấp nhận;
- ba thanh ghi descriptor;
- hai cờ sticky W1C với hardware-set ưu tiên;
- một testbench tự kiểm tra mọi access hợp lệ và không hợp lệ.

## 2. Vấn đề module giải quyết

DMA engine hoạt động theo sự kiện clock, còn CPU thao tác bằng thanh ghi. Module chuyển APB transfer thành state và command nội bộ. Nếu module phát START nhiều chu kỳ, engine có thể khởi động lặp. Nếu W1C thắng hardware event cùng cạnh, phần mềm có thể làm mất lỗi vừa xảy ra. Nếu address decode chỉ nhìn offset thấp, một địa chỉ ngoài aperture có thể alias thanh ghi hợp lệ.

Đây là APB3 profile cục bộ. Module không có `PPROT` hoặc `PSTRB`. Secure-Privileged provenance phải được APB bridge hoặc Firewall phía trước thực thi. Unit test của module không thể chứng minh trust boundary đó.

## 3. Input, output và reset

| Nhóm | Signal | Ý nghĩa |
|---|---|---|
| Clock/reset | `pclk`, `presetn` | Clock và reset active-low |
| APB request | `psel`, `penable`, `pwrite`, `paddr`, `pwdata` | Request APB3 32 bit |
| APB response | `prdata`, `pready`, `pslverr` | Dữ liệu, ready và lỗi |
| Descriptor | `cfg_src_addr`, `cfg_dst_addr`, `cfg_byte_len` | Cấu hình cho lần chạy kế tiếp |
| Command | `cfg_start` | Xung một chu kỳ khi ghi START=1 và `status_busy=0` |
| IRQ control | `irq_en` | Bit enable ngắt DMA |
| Hardware status | `status_busy`, `status_done_event`, `status_error_event` | Trạng thái và event từ DMA engine |
| Sticky status | `status_done_sticky`, `status_error_sticky` | Cờ phần mềm đọc và W1C |

Reset phải xóa descriptor, START, IRQ enable và hai sticky bit. `pready` bằng 1. `prdata` mặc định 0. `pslverr` chỉ lên trong access phase không hợp lệ.

## 4. Luồng xử lý chính

Một APB transfer có hai phase:

```text
setup:  PSEL=1, PENABLE=0, address và payload hợp lệ
access: PSEL=1, PENABLE=1, slave trả PREADY/PSLVERR/PRDATA
```

Với `PREADY=1`, transfer hoàn tất ở cạnh clock trong access phase. Write state chỉ thay đổi khi `psel && penable && pwrite && apb_addr_valid`.

Address classifier cần kiểm ba điều kiện:

```text
đúng cửa sổ 32 byte
AND PADDR[1:0] == 0
AND offset thuộc 0x00, 0x04, 0x08, 0x0C hoặc 0x10
```

## 5. Register contract

| Offset | Register | Quy tắc |
|---:|---|---|
| `0x00` | `DMA_CTRL` | Bit 0 START là WO command; bit 1 IRQ_EN là RW |
| `0x04` | `DMA_SRC` | RW 32 bit; cấu hình cho lần kế tiếp |
| `0x08` | `DMA_DST` | RW 32 bit; cấu hình cho lần kế tiếp |
| `0x0C` | `DMA_LEN` | RW 32 bit; cấu hình cho lần kế tiếp |
| `0x10` | `DMA_STATUS` | BUSY RO; DONE và ERROR W1C |

START khi BUSY là no-op đối với command. Cùng access đó, IRQ_EN vẫn cập nhật từ bit 1. Đọc START luôn trả 0. START không xóa DONE hoặc ERROR.

Hardware-set thắng W1C:

```text
done_next  = (done_current  AND NOT sw_clear_done)  OR done_event
error_next = (error_current AND NOT sw_clear_error) OR error_event
```

## 6. Cấu trúc file đề xuất

Giữ module trong một file `dma_apb_slave.v` với bốn phần:

1. Aperture, alignment và offset decode.
2. Sequential register update.
3. Hardware event priority.
4. Combinational read mux.

Không trộn logic kiểm descriptor alignment hoặc overflow vào module này. `dma_controller` sở hữu quyết định descriptor có hợp lệ để start engine hay không.

## 7. Thiết kế từ đầu

### Mốc 1: APB shell

Tạo port list, `pready=1`, `prdata=0` và `pslverr`. Viết test cho đúng base, sai base, misaligned và unmapped offset. Chưa tạo register state.

### Mốc 2: Descriptor registers

Thêm SRC, DST và LEN. Ghi chỉ ở access phase. Đọc trả state. Gửi hai transfer liên tiếp với `PSEL` giữ cao để chứng minh không ghi ở setup phase.

### Mốc 3: START và IRQ_EN

Mỗi chu kỳ mặc định `cfg_start<=0`. Chỉ set 1 khi accepted CTRL write có `PWDATA[0]=1` và `status_busy=0`. Test START idle, START busy, ghi IRQ_EN độc lập và đọc CTRL.

### Mốc 4: Sticky status

Thêm DONE, ERROR và W1C. Tạo task phát hardware event. Test software clear từng bit và hardware-set cùng cạnh clear.

### Mốc 5: Negative regression

Chứng minh write sai aperture không đổi descriptor. Thêm timeout để APB lỗi không treo simulation.

## 8. Source hiện hành

Source hiện hành dùng `paddr[31:5] == APB_BASE_ADDR[31:5]`, alignment 4 byte và offset tối đa `0x10`. `cfg_start` được hạ mỗi chu kỳ. Hardware events được xử lý sau software write trong sequential block, nên nonblocking assignments cuối tạo hardware-set priority.

Khi sửa source, ưu tiên giữ phương trình next-state nhìn thấy được. Không dựa vào thứ tự dòng nếu logic trở nên phức tạp hơn hai cờ hiện tại.

## 9. Test case bắt buộc

| ID cục bộ | Stimulus | Expected |
|---|---|---|
| APB-DMA-01 | Reset | Descriptor, IRQ_EN và sticky bits bằng 0 |
| APB-DMA-02 | Ghi và đọc SRC/DST/LEN | Readback đúng 32 bit |
| APB-DMA-03 | START khi idle | `cfg_start` đúng một chu kỳ |
| APB-DMA-04 | START khi busy | Không có `cfg_start`; IRQ_EN vẫn cập nhật |
| APB-DMA-05 | Đọc CTRL | START đọc 0 |
| APB-DMA-06 | DONE và ERROR events | Sticky bits giữ đến W1C |
| APB-DMA-07 | W1C cùng hardware-set | Bit sau cạnh bằng 1 |
| APB-DMA-08 | Sai base, misaligned, unmapped | `PREADY=1`, `PSLVERR=1`, `PRDATA=0`, không side effect |
| APB-DMA-09 | Timeout | Test fail hữu hạn khi handshake flow sai |

Đối chiếu với `TC_DMA_APB_REG_SEMANTICS`, `TC_START_WHILE_BUSY` và `TC_DMA_APB_PROFILE` trong verification plan.

## 10. Điểm cần tránh

- Phát `cfg_start` theo mức của START register.
- Xóa sticky status khi START.
- Cho W1C thắng event mới cùng cạnh.
- Decode riêng `paddr[4:0]` mà không kiểm full aperture.
- Báo `PSLVERR` trong setup phase.
- Giả định module tự kiểm Secure-Privileged access dù interface không có `PPROT`.

## 11. Rủi ro và cách kiểm tra

| Rủi ro | Kiểm tra |
|---|---|
| START lặp | Đếm số chu kỳ `cfg_start` cho một write |
| Lost event | W1C và event cùng cạnh |
| Address alias | Dùng hai địa chỉ cùng low bits nhưng khác base |
| Side effect từ access lỗi | Snapshot toàn state trước và sau write lỗi |
| Trust claim vượt evidence | Giữ `TC_DMA_TRUST_UPSTREAM` ở SoC integration gate |

## 12. Tiêu chí hoàn thành

- Compile với `iverilog -g2012 -Wall` không có lỗi width hoặc implicit net.
- Testbench tự báo PASS và có timeout.
- Mọi register và negative access có checker.
- START pulse, busy no-op và sticky W1C có directed evidence.
- Báo cáo ghi rõ unit scope không chứng minh upstream trust.

## 13. Lộ trình tự triển khai

Đầu tiên hãy tự vẽ timing setup/access. Tiếp theo viết APB tasks và negative access tests. Sau khi RED do DUT chưa có, hiện thực APB shell rồi thêm từng nhóm state. Mỗi mốc chỉ chuyển tiếp khi test hiện tại PASS. Cuối cùng giải thích bằng lời vì sao START là command còn DONE/ERROR là state.

## 14. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 5.1
- `DMA-controller/docs/architecture/register_map.csv`, các dòng `DMA_*`
- `DMA-controller/docs/architecture/memory_map.csv`, cửa sổ DMA Controller
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/architecture/requirements_traceability.csv`, `REQ_DMA_01` và `REQ_DMA_06`
- `DMA-controller/rtl/dma_apb_slave.v`
- `DMA-controller/tb/tb_dma_apb_slave.v`
