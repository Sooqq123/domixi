# Trạng thái khóa Firewall RTL

## Quy ước

- `NOT_STARTED`: chưa có bằng chứng học hoặc lab.
- `IN_PROGRESS`: đang học hoặc implementation chưa qua exit gate.
- `PASSED`: đạt rubric tối thiểu và evidence tồn tại.
- `BLOCKED`: thiếu dependency/tool/input được nêu rõ.

## Tiến độ

Bảng này theo dõi bằng chứng học tập của người học, không phải trạng thái implementation của dự án. Production baseline đã có RTL, regression và formal evidence để đối chiếu; các artifact đó không tự động chứng minh người học đã đạt rubric.

| Bài | Trạng thái | Evidence yêu cầu | Evidence hiện có |
|---:|---|---|---|
| 00 | NOT_STARTED | Baseline report + spec-lint log | Không |
| 01 | NOT_STARTED | Address slice source + unit PASS | Không |
| 02 | NOT_STARTED | Context tracker source + unit PASS | Không |
| 03 | NOT_STARTED | APB regs source + unit PASS | Không |
| 04 | NOT_STARTED | ACL matcher source + unit PASS | Không |
| 05 | NOT_STARTED | Write drain source + unit PASS | Không |
| 06 | NOT_STARTED | Read drain source + unit PASS | Không |
| 07 | NOT_STARTED | Data mux source + unit PASS | Không |
| 08 | NOT_STARTED | Firewall top + directed integration PASS | Không |
| 09 | NOT_STARTED | DMA–Firewall regression PASS | Không |
| 10 | NOT_STARTED | Formal/SVA reports | Project reference: 9/9 formal suite PASS; chưa có learner review |
| 11 | BLOCKED | Coverage, synth/STA và SoC evidence | Thiếu coverage database, technology STA và boundary CDC/RDC/DFT sign-off |

## Quyền cập nhật

Antigravity chỉ đổi trạng thái sau khi:

1. chỉ ra artifact cụ thể;
2. đọc kết quả PASS/FAIL thực;
3. hỏi người học tự giải thích invariant chính;
4. ghi learning record nếu đã có bằng chứng hiểu thật sự.
