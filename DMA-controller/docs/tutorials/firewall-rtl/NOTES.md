# Ghi chú vận hành khóa Firewall RTL

## Trạng thái ban đầu — 2026-08-28

- Canonical release: V2.4.1.
- Firewall RTL: chưa có source `.v`/`.sv`.
- Simulator khả dụng: Icarus Verilog 12.0.
- Spec-lint đang bị chặn bởi ba traceability row còn trỏ đến draft `fw_axi_address_slice.v` đã bị xóa.
- `signal_list.csv` hiện chỉ có cờ `*_4kb_err`; interface Stage 1 cần được chốt thêm profile/overflow flags trước khi viết RTL.
- Đồng bộ hồ sơ người học đã bỏ qua vì skill `learner-profile-teach` không có trong phiên này.

## Quy ước giảng dạy

- Một lần chỉ học một khái niệm hoặc một module có gate độc lập.
- Antigravity hỏi người học tự giải thích trước khi đưa lời giải.
- Không ghi learning record chỉ vì đã trình bày nội dung; chỉ ghi khi người học chứng minh hiểu qua câu trả lời hoặc bài lab.
- Mọi lệnh test phải được chạy từ `D:\domixi\DMA-controller` và log phải có PASS/FAIL rõ ràng.
- Không dùng kết quả `.vvp` cũ làm evidence cho source hiện tại.

## Ngôn ngữ

Toàn bộ phần giải thích, bài tập và rubric dùng tiếng Việt. Identifier RTL, tên chuẩn AXI/APB, tên requirement/test case và câu lệnh công cụ giữ nguyên để tránh sai nghĩa.
