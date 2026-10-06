# Nguồn học DMA AXI Firewall RTL

## Kiến thức

- [`docs/architecture/firewall_rtl_integration_contract.md`](../../architecture/firewall_rtl_integration_contract.md)
  Contract canonical về module boundary, interface, invariant, reset và trình tự tích hợp. Dùng trước mọi bài RTL.
- [`docs/architecture/pinout.csv`](../../architecture/pinout.csv)
  Danh sách top-level port, width, direction, clock/reset domain và reset value. Dùng khi đóng port list.
- [`docs/architecture/signal_list.csv`](../../architecture/signal_list.csv)
  Hợp đồng internal signal giữa các module. Dùng khi kiểm tra dependency closure.
- [`docs/architecture/fsm_specification.md`](../../architecture/fsm_specification.md)
  Trạng thái, transition, priority, recovery và timeout/framing semantics. Dùng cho drain và top ownership FSM.
- [`docs/architecture/register_map.csv`](../../architecture/register_map.csv)
  APB register/bit-field/reset/access/side-effect canonical. Dùng cho `fw_apb_regs`.
- [`docs/architecture/verification_test_plan.md`](../../architecture/verification_test_plan.md)
  Test IDs, assertion IDs, expected result và sign-off intent. Dùng để viết test trước implementation.
- [`docs/architecture/requirements_traceability.csv`](../../architecture/requirements_traceability.csv)
  Liên kết requirement → module/interface/FSM → test/evidence. Dùng khi review coverage theo yêu cầu.
## Kinh nghiệm thực hành

- Icarus Verilog 12.0 tại workspace cục bộ.
  Dùng cho syntax/elaboration và self-checking unit/integration simulation ngay trong khóa học.
- Antigravity trên máy người dùng.
  Dùng làm giảng viên tương tác theo instructor guide; mọi kết luận kỹ thuật phải truy ngược về SSOT hoặc evidence thực.

## Khoảng trống nguồn lực

- Chưa xác nhận formal engine cho G4.
- Chưa xác nhận simulator có code/functional coverage cho G5.
- Chưa có target library/FPGA part và timing corner cho G6.
- Chưa có SoC-level provenance/synchronization evidence cho G7.
