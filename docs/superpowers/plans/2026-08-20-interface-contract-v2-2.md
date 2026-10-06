# DMA Controller V2.2 Interface Contract Implementation Plan

> **Status: Historical — superseded by Canonical Architecture Baseline V2.4.1 in `DMA-controller/docs/architecture/`.** Retained only as execution history; it is not an implementation contract.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the DMA controller's executable RTL, model, testbenches, and pinout comply with the SSOT V2.2 pinout, sideband, ID-width, and APB-address contracts.

**Architecture:** `dma_controller.v` owns the V2.2 public sideband outputs and derives them from APB configuration and the existing `status_busy/status_done` signals. `dma_apb_slave.v` retains a 32-bit APB system address and decodes the 32-byte window at `APB_BASE_ADDR=32'h1000_1000`, returning `PSLVERR` for other accesses. The Python model mirrors the same five-signal sideband V1 interface.

**Tech Stack:** Verilog-2001 RTL, Icarus Verilog testbenches, Python `unittest`, architecture CSV/Markdown specification.

**Spec:** `DMA-controller/docs/architecture/architecture_overview.md`

## Global Constraints

- Default `ID_WIDTH = 4`; every default-width AXI ID port and test wire is `[3:0]`.
- APB `paddr` is `[31:0]`; valid DMA registers are byte offsets `0x00`, `0x04`, `0x08`, `0x0C`, and `0x10` in `APB_BASE_ADDR=32'h1000_1000` through `32'h1000_101F`.
- Sideband V1 exposes only `dma_ctx_valid`, `dma_ctx_src`, `dma_ctx_dst`, `dma_ctx_len`, and one-cycle `dma_ctx_done`.
- No `dma_ctx_state` exists in an executable interface.
- Preserve FIFO depth 32 and existing DMA data-transfer behavior.

---

### Task 1: RTL and model contract

**Files:**

- Modify: `DMA-controller/rtl/dma_axi_master.v`
- Modify: `DMA-controller/rtl/dma_apb_slave.v`
- Modify: `DMA-controller/rtl/dma_controller.v`
- Modify: `DMA-controller/model/soc_components.py`

**Interfaces:**

- Consumes: APB configuration registers and `status_busy/status_done` from the existing DMA master.
- Produces: 4-bit default AXI IDs, 32-bit APB address validation, and the five V2.2 sideband outputs.

- [x] Set both RTL default `ID_WIDTH` parameters to `4`.
- [x] Gate APB register decode with `paddr[31:5] == APB_BASE_ADDR[31:5]`; assign `pslverr` only during an invalid APB access phase.
- [x] Add the five sideband ports to `dma_controller.v`; latch descriptor fields on `cfg_start`, assert valid while busy, and emit done from `status_done`.
- [x] Delete model-only `dma_ctx_state` assignments while preserving the model's valid/descriptor/done lifecycle.

### Task 2: Directed interface tests

**Files:**

- Modify: `DMA-controller/tb/tb_dma_controller.v`
- Modify: `DMA-controller/tb/tb_dma_apb_slave.v`
- Modify: `DMA-controller/model/test_unit.py`

**Interfaces:**

- Consumes: V2.2 sideband outputs and APB error response from Task 1.
- Produces: self-checking failures for non-4-bit ID wiring, incorrect sideband timing, and nonzero APB address prefixes.

- [x] Change AXI ID testbench wires and zero-ID comparisons to `[3:0]` / `4'b0000`.
- [x] Observe sideband ports in the DMA controller testbench: descriptor latches at start, valid is high during the transfer, done pulses on completion, and valid falls after completion.
- [x] Add APB slave tests for the `0x10001000` base window and an invalid `32'h1000_0004` access; invalid access returns `PREADY=1`, `PSLVERR=1`, `PRDATA=0`, and leaves `cfg_src_addr` unchanged.
- [x] Add Python unit coverage that `DMACore` has all five V2.2 sideband attributes and no `dma_ctx_state` attribute.

### Task 3: Documentation and validation

**Files:**

- Modify: `DMA-controller/docs/architecture/pinout.csv`
- Modify: `DMA-controller/docs/architecture/changelog.md`

**Interfaces:**

- Consumes: Tested V2.2 RTL contract from Tasks 1 and 2.
- Produces: pinout rows that correctly describe sideband direction/timing and the APB system address window.

- [x] Change DMA sideband pinout direction to DMA controller outputs and describe synchronous revoke behavior.
- [x] Record the executable-interface alignment in the V2.2 changelog.
- [x] Run `python DMA-controller/docs/architecture/tools/spec_lint.py`.
- [x] Compile and run `tb_dma_apb_slave.v` and `tb_dma_controller.v` with Icarus Verilog; run Python unit and integration tests.
