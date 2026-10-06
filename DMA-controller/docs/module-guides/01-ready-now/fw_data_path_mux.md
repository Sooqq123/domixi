# Thiết kế `fw_data_path_mux`

> Phân loại: `READY_NOW`. Module có thể thiết kế với Stage 1, matcher và drain stubs. Chưa có Firewall RTL hiện hành được công nhận trong source tree.

## 1. Mục tiêu và sản phẩm

`fw_data_path_mux` định tuyến các kênh AXI theo owner đã được chốt cho từng transaction:

- giao dịch allowed đi giữa DMA và Matrix;
- giao dịch denied bị tách khỏi Matrix và nối với drain engine;
- response từ đúng nguồn được trả về DMA.

Module là combinational cut-through cho datapath hợp lệ. Nó không tự đánh giá ACL và không được đổi owner giữa burst.

## 2. Vì sao owner phải được chốt

`acl_w_pass` hoặc `acl_r_pass` là kết quả của một address snapshot. Nếu mux nhìn live matcher output trong toàn burst, một config write, context revoke hoặc request mới có thể đổi đường data giữa chừng.

Mỗi direction cần transaction ownership state rõ ràng:

| Owner | Ý nghĩa |
|---|---|
| `NONE` | Chưa có transaction đã nhận |
| `ALLOW` | Transaction đã được Matrix nhận và data/response thuộc Matrix |
| `DRAIN` | Transaction bị deny và data/response thuộc drain |

Owner được set từ address decision handshake, không từ mức live của ACL. Owner chỉ clear khi response cuối của transaction handshake.

## 3. Write routing contract

### Allowed write

Sau AW được phép đã handshake downstream:

- DMA W channel chuyển đến Matrix;
- Matrix WREADY trả về DMA;
- Matrix B channel trả về DMA;
- DMA BREADY chuyển đến Matrix;
- drain inputs giữ inactive.

### Denied write

Sau denied AW snapshot được drain nhận:

- không phát AW xuống Matrix;
- DMA W channel chuyển vào write drain;
- drain WREADY trả về DMA;
- drain B response trả về DMA;
- Matrix WVALID và BREADY từ transaction này giữ inactive.

### Gate G3 bắt buộc

`WVALID` không được đi đến bất kỳ consumer nào trước khi AW decision đã được nhận và owner được chốt. Với allowed path, còn phải bảo đảm AW đã handshake downstream trước khi forwarding W. Điều này khớp DMA master rule AW-before-W và ngăn orphan W traffic.

## 4. Read routing contract

### Allowed read

Sau AR allowed handshake downstream, Matrix R channel đi về DMA và DMA RREADY đi xuống Matrix. Owner clear khi `RVALID && RREADY && RLAST`.

### Denied read

Không phát AR xuống Matrix. Read drain tạo `ARLEN+1` dummy beats. Drain R channel đi về DMA và DMA RREADY đi vào drain. Owner clear ở dummy RLAST handshake.

Không OR hai response source. Mỗi chu kỳ chỉ nguồn sở hữu transaction được phép điều khiển output về DMA.

## 5. Address path và decision handoff

Address slice tạo snapshot. Matcher quyết định allow hoặc deny. Mux hoặc top-level handshake logic phải:

1. Chỉ consume một decision khi owner tương ứng là `NONE`.
2. Với allow, forward address payload và chờ Matrix READY.
3. Với deny, chuyển request metadata cho drain và không chạm Matrix.
4. Set owner đúng một lần.

Theo integration contract, `dma_bus_firewall` sở hữu lifecycle owner. Mux nhận owner đã chốt và thực hiện routing tổ hợp. Với denied write, top giữ immutable `AWADDR`, `AWID`, `AWLEN` và `AWSIZE` từ khi nhận denied decision đến B handshake.

Write drain chỉ nhận ID, LEN và error mode cần cho exact-beat sink và B response. Không chuyển `AWADDR` hoặc `AWSIZE` vào write drain. Khi drain phát `w_framing_fault_valid` cùng `w_framing_fault_code`, top ghép pulse với write-owner metadata đang giữ để tạo full `w_fault_event_*` trước khi gửi logger.

## 6. Tie-off và inactive outputs

Mọi output không thuộc owner hiện tại cần giá trị vô hại:

- VALID và READY request về inactive;
- data có thể 0 nhưng không được dùng khi VALID=0;
- response ID/data có thể 0 khi no owner;
- `AxCACHE=0`, `AxLOCK=0`, `AxQOS=0` ở ranh giới top nếu mux sở hữu các signal đó.

Không tạo combinational loop READY giữa Stage 1, matcher, mux và Matrix. Vẽ phương trình ready path trước khi code.

## 7. Backpressure và stability

Cut-through không miễn trừ AXI stability:

- Nếu DMA giữ WVALID và consumer WREADY thấp, W payload phải ổn định.
- Nếu Matrix hoặc drain giữ RVALID khi DMA RREADY thấp, output R payload phải ổn định.
- Nếu BVALID bị stall, BID/BRESP từ owner giữ ổn định.

Mux không cần register data nếu các endpoint đã tuân AXI. Tuy nhiên select `owner` phải ổn định suốt stall. Đổi select khi VALID đang cao là lỗi nghiêm trọng.

## 8. Cấu trúc thiết kế đề xuất

Phần tổ hợp nên tách theo channel:

1. AW/AR decision routing.
2. W data routing theo write owner và AW acceptance gate.
3. B response selection theo write owner.
4. R response selection theo read owner.
5. Default tie-offs trước case owner.

Ownership sequential logic nằm ở top và có set/clear events tường minh. `fw_data_path_mux` không sao chép owner register riêng.

## 9. Thiết kế từ đầu theo mốc

### Mốc 1: Interface truth table

Lập bảng cho `NONE`, `ALLOW`, `DRAIN` của read và write. Mỗi input/output phải có đúng một nguồn trong mỗi trạng thái.

### Mốc 2: Allowed write/read

Dùng Matrix stub. Test stall trên W, B và R. So payload từng beat.

### Mốc 3: Denied write/read

Dùng drain stubs có response biết trước. Chứng minh Matrix không thấy VALID của denied traffic.

### Mốc 4: Owner transitions

Set owner từ decision acceptance, clear ở B handshake hoặc RLAST handshake. Thử back-to-back transactions và simultaneous read/write.

### Mốc 5: G3

Đưa WVALID sớm trước AW decision, trong lúc allow AW bị stall và trong deny path. Không consumer nào được nhận W trước thời điểm hợp lệ.

### Mốc 6: Random backpressure

Random stall từng endpoint độc lập. Scoreboard theo owner và transaction ID.

## 10. Test matrix

| ID cục bộ | Tình huống | Expected |
|---|---|---|
| MUX-01 | Reset hoặc owner NONE | Không Matrix/drain VALID giả |
| MUX-02 | Allowed write | AW/W/B chỉ qua Matrix |
| MUX-03 | Denied write | W/B chỉ qua drain, Matrix không thấy traffic |
| MUX-04 | Allowed read | AR/R chỉ qua Matrix |
| MUX-05 | Denied read | R chỉ từ drain, Matrix không thấy AR |
| MUX-06 | WVALID trước AW | Bị chặn |
| MUX-07 | AW allow bị Matrix stall | W vẫn bị chặn đến AW handshake |
| MUX-08 | B hoặc R stall | Payload từ owner ổn định |
| MUX-09 | Config/context thay đổi giữa burst | Owner không đổi |
| MUX-10 | Read allowed và write denied đồng thời | Hai direction độc lập |
| MUX-11 | Back-to-back transactions | Owner clear/set không mất chu kỳ sai |
| MUX-12 | Write framing pulse sau AW bus đã đổi | Fault record vẫn dùng AWADDR/AWID/AWLEN/AWSIZE của owner hiện tại |

## 11. Assertion bắt buộc

- Không có nhiều hơn một B response source active về DMA.
- Không có nhiều hơn một R response source active về DMA.
- Denied owner kéo theo Matrix request/data VALID của transaction bằng 0.
- `matrix_wvalid` kéo theo write owner ALLOW và allowed AW đã handshake.
- `drain_wvalid` kéo theo write owner DRAIN.
- Owner không đổi từ set đến terminal handshake.
- Read owner clear chỉ ở RLAST handshake.
- Write owner clear chỉ ở B handshake.
- Write-owner AWADDR/AWID/AWLEN/AWSIZE ổn định từ denied decision acceptance đến B handshake.
- Write drain không nhận AWADDR hoặc AWSIZE.

## 12. Điểm cần tránh

- Dùng live `acl_*_pass` làm mux select trong toàn burst.
- Forward W cùng lúc AW mới chỉ được matcher allow nhưng Matrix chưa nhận.
- OR response từ Matrix và drain.
- Clear owner theo VALID thay vì handshake.
- Để denied traffic làm Matrix READY hoặc VALID nhấp nháy.
- Tạo combinational ready loop.
- Thêm datapath register rồi vẫn tuyên bố cut-through không latency.
- Lấy metadata framing fault từ live AW bus hoặc đẩy AWADDR/AWSIZE vào write drain.

## 13. Rủi ro và cách đóng

| Rủi ro | Bằng chứng |
|---|---|
| Owner đổi giữa burst | Same-transaction stability assertion |
| Data leak xuống Matrix | Negative monitor cho denied traffic |
| Orphan W | G3 directed tests |
| Hai response nguồn tranh chấp | One-hot source assertions |
| Timing path dài | Synthesis/STA sau functional closure, không suy đoán từ RTL |

## 14. Tiêu chí hoàn thành

- Truth table phủ mọi owner state và channel.
- Allowed traffic bảo toàn payload và handshake.
- Denied traffic hoàn toàn tách khỏi Matrix.
- G3 được chứng minh bằng assertion và directed tests.
- Read/write hoạt động đồng thời độc lập.
- Không có combinational loop trong lint hoặc structural review.
- Mọi tuyên bố latency và timing được giới hạn đúng mức evidence.
- Framing pulse được top làm giàu bằng immutable write-owner metadata trước fault logger.

## 15. Lộ trình tự triển khai

Vẽ owner truth table và ready graph trước. Viết default tie-off rồi thêm từng owner case. Test allowed path bằng stub trước, sau đó denied path. Giữ mux thuần tổ hợp theo owner từ top. Đặt owner lifecycle cùng immutable write metadata ở top testbench, rồi chạy simultaneous/random traffic và bài kiểm tra framing sau khi live AW bus đã thay đổi.

## 16. Nguồn chuẩn

- `DMA-controller/docs/architecture/architecture_overview.md`, mục 2.3 và 5.3
- `DMA-controller/docs/architecture/firewall_rtl_integration_contract.md`
- `DMA-controller/docs/architecture/fsm_specification.md`, owner lifecycle và G3
- `DMA-controller/docs/architecture/signal_list.csv`, matcher decision và drain interface
- `DMA-controller/docs/architecture/verification_test_plan.md`
- `DMA-controller/docs/architecture/detailed_architecture_diagram.md`
