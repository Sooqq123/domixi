# Sứ mệnh: Tự thiết kế và kiểm chứng DMA AXI Firewall

## Vì sao

Mục tiêu thực tế là tự viết được Firewall RTL có thể tổng hợp, tuân thủ SSOT V2.4.1 và chứng minh được các thuộc tính an toàn thay vì chỉ tạo mã “chạy được”. Sau khóa học, người học có thể tự giải thích mọi quyết định kiến trúc, phát hiện sai lệch AXI/FSM và bảo vệ kết quả bằng test/evidence.

## Thành công được xác định bằng

- Tự xây dựng top Firewall và đúng 12 dependency RTL trong closure đã duyệt.
- Tự viết testbench self-checking trước RTL và debug từ lỗi quan sát được.
- Giải thích chính xác handshake, transaction ownership, immutable snapshot, full-burst containment và exact-beat drain.
- Đóng G0–G4 bằng evidence thực; phân biệt rõ PASS, FAIL và BLOCKED ở G5–G7.
- Tích hợp Firewall với DMA mà không làm yếu profile, reset, logging hoặc trust boundary.

## Ràng buộc

- Ngôn ngữ giảng dạy là tiếng Việt; tên module, signal, protocol và code giữ nguyên tiếng Anh chuẩn.
- SSOT V2.4.1 trong `docs/architecture` là căn cứ kỹ thuật duy nhất.
- Baseline đã xác nhận Icarus/vvp, SymbiYosys với Z3/Yices và generic Yosys synthesis; không giả định coverage-capable simulator, PDK hay sign-off deck đã có.
- Học theo test-first, mỗi bài phải có sản phẩm và gate kiểm tra độc lập.
- Antigravity hướng dẫn tương tác; không được làm thay toàn bộ bài tập trước khi người học tự giải thích hướng giải.

## Ngoài phạm vi

- Không thay đổi kiến trúc V2.4.1 nếu chưa phát hành baseline mới.
- Không dạy UVM đầy đủ, physical design chuyên sâu hoặc tối ưu PPA trước khi RTL/integration đúng chức năng.
- Không tuyên bố SoC security closure nếu thiếu formal, coverage, target implementation hoặc provenance evidence.
