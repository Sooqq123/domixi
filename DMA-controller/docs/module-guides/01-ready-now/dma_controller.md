# Thiết kế `dma_controller`

> Phân loại: `READY_NOW`. Source hiện hành nằm tại `DMA-controller/rtl/dma_controller.v`; testbench nằm tại `DMA-controller/tb/tb_dma_controller.v`.

## 1. Mục tiêu và sản phẩm

`dma_controller` là wrapper của DMA core. Module ghép APB register block, descriptor validator, FIFO và AXI master, đồng thời phát sideband context cho Firewall.

Sản phẩm cần chứng minh ba điều:

1. Descriptor lỗi bị chặn trước AXI.
2. Descriptor hợp lệ tạo đúng một lần chạy và đúng một context window.
3. DONE, ERROR và IRQ phản ánh terminal event của engine mà không làm sai APB semantics.

## 2. Vị trí trong hệ thống

```text
CPU/APB
   |
   v
dma_apb_slave
   |
descriptor validator
   |
   +----> dma_ctx_* ----> Firewall context tracker
   |
dma_axi_master <----> dma_fifo_latch
   |
AXI master qua Firewall
```

Module này không chứa ACL, drain hoặc Firewall datapath. Một unit test PASS tại `dma_controller` chỉ chứng minh DMA core; nó không chứng minh giao dịch đã được Firewall cấp quyền.

## 3. Giao diện

| Nhóm | Nội dung |
|---|---|
| Clock/reset | `clk`, `rst_n`, một clock domain |
| APB | APB3 32 bit cho DMA registers |
| IRQ | `dma_irq` |
| Context sideband | `dma_ctx_valid`, source, destination, length, `dma_ctx_done` |
| AXI master | Read và write channels 32 bit, ID width mặc định 4 |

Tham số `APB_BASE_ADDR` mặc định `0x10001000`. `ID_WIDTH` mặc định 4 và phải nhất quán với toàn bộ AXI wiring.

## 4. Descriptor validation

Trước khi phát `master_start`, kiểm:

```text
src[1:0] == 0
dst[1:0] == 0
len != 0
len[1:0] == 0
zero_extend(src, 33) + zero_extend(len, 33) <= 2^32
zero_extend(dst, 33) + zero_extend(len, 33) <= 2^32
```

Phép cộng 33 bit cho phép range kết thúc đúng ở biên `2^32` nhưng không cho phép wrap. Ví dụ `src=0xFFFF_FFFC`, `len=4` hợp lệ vì byte cuối là `0xFFFF_FFFF`. `src=0xFFFF_FFFC`, `len=8` không hợp lệ.

`cfg_start && !cfg_valid` tạo `align_error_event` cho sticky ERROR. Không được phát AXI hoặc context cho descriptor lỗi.

## 5. Command, status và IRQ

`dma_apb_slave` phát `cfg_start` một chu kỳ khi CPU ghi START trong lúc không busy. Wrapper tạo:

```text
master_start = cfg_start AND cfg_valid AND NOT status_busy
dma_irq = irq_en AND (done_sticky OR error_sticky)
```

Nếu descriptor sai, `cfg_start` vẫn là một APB command đã được nhận, nhưng `master_start=0` và ERROR sticky được set. Nếu START đến khi busy, APB block biến nó thành no-op đối với command.

DONE/ERROR từ master là event một chu kỳ. APB block chuyển chúng thành sticky status. IRQ là level, không phải pulse, và chỉ hạ khi phần mềm W1C hết nguồn sticky hoặc tắt IRQ enable.

## 6. Dynamic context sideband

Khi `master_start`:

- `dma_ctx_valid` lên 1;
- source, destination và length được chốt;
- các giá trị giữ ổn định trong cả lần chạy.

Khi `master_done || master_error`:

- `dma_ctx_valid` về 0;
- `dma_ctx_done` phát một xung một chu kỳ.

Context mở cùng start và đóng ở terminal event. Không cập nhật context từ các lần ghi APB mới trong lúc busy. `dma_ctx_done` phải có default 0 mỗi chu kỳ để không trở thành level.

Firewall có quy tắc armed one-shot riêng. Wrapper cần hạ valid sau terminal trước khi mở context mới.

## 7. Cấu trúc triển khai

Nên chia wrapper thành bốn vùng rõ ràng:

1. Internal wires và descriptor validator.
2. Instance `dma_apb_slave` và IRQ equation.
3. Instance FIFO và AXI master.
4. Sequential context sideband register.

Không đưa state AXI vào wrapper. Không sao chép register map từ APB slave. Không đưa ACL policy vào validator.

## 8. Thiết kế từ đầu theo mốc

### Mốc 1: Skeleton và wiring

Khai báo đầy đủ APB, sideband và AXI ports. Dùng stub cho ba submodule. Compile với implicit net bị coi là lỗi.

### Mốc 2: Descriptor validator

Viết combinational equations và unit checker cho mọi biên alignment, zero length và overflow. Chưa cần AXI behavior.

### Mốc 3: START và error routing

Chứng minh descriptor hợp lệ tạo `master_start`, descriptor lỗi chỉ tạo error event. Kiểm START busy không mở context mới.

### Mốc 4: Context lifecycle

Test start, stable payload, done và error. Kiểm `dma_ctx_done` đúng một chu kỳ và valid đã hạ.

### Mốc 5: Ghép submodule thật

Thay stub bằng APB slave, FIFO và AXI master. Dùng memory model để chạy một transfer end-to-end trong phạm vi DMA core.

### Mốc 6: IRQ

Test IRQ disabled, enabled, DONE sticky, ERROR sticky, W1C từng bit và tắt enable.

## 9. Test matrix

| ID cục bộ | Stimulus | Expected |
|---|---|---|
| CTRL-01 | Reset | Context, IRQ và AXI control ở trạng thái vô hại |
| CTRL-02 | Descriptor 4 byte hợp lệ | Một master start, một context open |
| CTRL-03 | Source misaligned | Không AXI, ERROR sticky |
| CTRL-04 | Destination misaligned | Không AXI, ERROR sticky |
| CTRL-05 | Length 0 hoặc không chia hết 4 | Không AXI, ERROR sticky |
| CTRL-06 | Range kết thúc đúng `2^32` | Hợp lệ |
| CTRL-07 | Range vượt `2^32` | Bị chặn |
| CTRL-08 | DONE terminal | Context đóng, done pulse đi vào sticky |
| CTRL-09 | ERROR terminal | Context đóng, error sticky |
| CTRL-10 | START khi busy | Không context hoặc AXI start mới |
| CTRL-11 | IRQ enable/disable và W1C | Level IRQ đúng contract |
| CTRL-12 | Hai lần chạy liên tiếp | Context payload của từng lần độc lập |

## 10. Checker cần có

- `master_start` kéo theo `cfg_valid` và `!status_busy`.
- `align_error_event` không đồng thời với `master_start`.
- Context payload ổn định khi `dma_ctx_valid=1`.
- `dma_ctx_done` chỉ là pulse một chu kỳ.
- Không có AXI address handshake cho descriptor lỗi.
- IRQ bằng đúng phương trình enable và sticky status.
- Mọi AXI signal width nối đúng, không truncate ID hoặc length.

## 11. Điểm cần tránh

- Dùng phép cộng 32 bit để kiểm overflow.
- Tính end address bằng `addr+len-1` trong 32 bit rồi so sau khi đã wrap.
- Mở context từ `cfg_start` trước khi validation.
- Đóng context ngay khi phát hiện lỗi AXI nhưng master chưa quiescent.
- Dùng `dma_ctx_done` dạng level.
- Tuyên bố đã kiểm Firewall chỉ vì DMA transfer PASS.
- Tự thêm đồng bộ CDC trong baseline một clock domain.

## 12. Rủi ro và bằng chứng

| Rủi ro | Bằng chứng |
|---|---|
| Overflow lọt | Directed boundary vectors với arithmetic 33 bit |
| Context stale | Hai transfer khác descriptor liên tiếp |
| IRQ mất hoặc kẹt | Event, W1C và enable transition tests |
| Wiring sai ID/PROT | Interface checker trên AXI outputs |
| False integration claim | Báo cáo ghi rõ Firewall chưa nằm trong unit scope |

## 13. Tiêu chí hoàn thành

- Submodule unit tests PASS độc lập.
- Wrapper test chứng minh mọi validation boundary.
- Transfer end-to-end trong DMA core giữ đúng dữ liệu.
- Context open, stable và close đúng terminal event.
- IRQ semantics đúng với sticky status.
- Compile sạch implicit net, width mismatch và unconnected port quan trọng.

## 14. Lộ trình tự triển khai

Đầu tiên lập bảng truth table cho validator. Tiếp theo ghép APB bằng stub master status và kiểm START/error. Sau đó hiện thực context lifecycle. Chỉ khi các checker này ổn định mới ghép FIFO và AXI master thật. Cuối cùng chạy lại toàn bộ APB, FIFO và AXI unit regression để bắt lỗi wrapper làm thay đổi contract con.

## 15. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 1.2, 5.1 và 5.3
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/signal_list.csv`, DMA control, context và AXI groups
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/architecture/requirements_traceability.csv`
- `DMA-controller/rtl/dma_controller.v`
- `DMA-controller/tb/tb_dma_controller.v`
