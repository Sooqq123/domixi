# Giáo trình DMA AXI Firewall RTL

Đây là điểm vào duy nhất cho khóa học thực hành thiết kế, kiểm chứng và tích hợp Firewall RTL theo SSOT V2.4.1.

## Bắt đầu nhanh

1. Đọc [MISSION.md](MISSION.md) để hiểu mục tiêu và ranh giới khóa học.
2. Đọc [SYLLABUS.md](SYLLABUS.md) để biết thứ tự 12 bài và dependency gate.
3. Mở [COURSE_STATUS.md](COURSE_STATUS.md); bắt đầu từ bài đầu tiên có trạng thái `NOT_STARTED` mà prerequisite đã đạt.
4. Học đúng file trong `lessons/`; không nhảy sang module phụ thuộc khi exit gate chưa PASS.
5. Antigravity phải tuân thủ [ANTIGRAVITY_INSTRUCTOR_GUIDE.md](ANTIGRAVITY_INSTRUCTOR_GUIDE.md).

## Cấu trúc

```text
firewall-rtl/
├── README.md
├── MISSION.md
├── SYLLABUS.md
├── COURSE_STATUS.md
├── RESOURCES.md
├── course_manifest.csv
├── ANTIGRAVITY_INSTRUCTOR_GUIDE.md
├── lessons/          # 12 bài học tự chứa
├── reference/        # cheat sheet dùng lại nhiều bài
└── learning-records/ # chỉ tạo record khi có bằng chứng đã hiểu
```

## Quy tắc nguồn sự thật

Giáo trình giải thích và tổ chức lộ trình; nó không thay thế đặc tả. Khi có khác biệt, thứ tự ưu tiên là:

```text
SSOT V2.4.1 trong docs/architecture
    > quyết định kỹ thuật đã được phê duyệt
    > giáo trình này
    > ghi chú hoặc output công cụ cũ
```

## Điều kiện hoàn thành

- Hoàn thành bài học không đồng nghĩa đóng toàn bộ Firewall.
- Khóa học phần RTL hoàn thành khi G0–G3 có evidence hợp lệ.
- G4 formal, G5 coverage, G6 implementation và G7 SoC trust chỉ PASS khi có đúng artifact được yêu cầu.
- Gate bị thiếu tool hoặc target phải ghi `BLOCKED`, không được đổi thành PASS.
