# DMA Controller IP Design

> **Status: Obsolete — superseded by Canonical Architecture Baseline V2.4.1 in `DMA-controller/docs/architecture/`.**
>
> This historical proposal is retained for traceability only and must not be used as an implementation contract. Its conventional-DMA-only scope, security-behavior removal, `ID_WIDTH=1` default and `AxPROT=000` conflict with the V2.4.1 canonical baseline in `DMA-controller/docs/architecture/`.

## Scope

Replace the security-oriented `dma_top` wrapper with a conventional DMA peripheral
named `dma_controller`. The controller transfers a configured byte range from a
source address to a destination address through its AXI4 master interface.

## Interface and architecture

- Rename `DMA-controller/rtl/dma_top.v` to `DMA-controller/rtl/dma_controller.v`
  and rename its top-level module from `dma_top` to `dma_controller`.
- Retain the APB slave register interface, FIFO, and `dma_axi_master` datapath.
- Retain the AXI4 master interface, including `m_axi_awid`, `m_axi_arid`, and
  `m_axi_prot`. IDs remain parameterized by `ID_WIDTH` (default 1) and are driven
  low by the AXI master; `m_axi_prot` remains `3'b000`.
- The APB `cfg_start` signal directly starts `dma_axi_master`. The data path is
  AXI read -> FIFO -> AXI write.

## Removed security behavior

- Remove `SAFE_BASE_ADDR` and `SAFE_BOUND_ADDR` parameters.
- Remove address range checks, `secure_cfg_start`, and the
  `security_violation` output.
- `dma_irq` asserts only when the DMA master reports `status_done`; APB
  `clear_irq` clears it.

## Compatibility and verification

- This is an intentional top-level rename: users must instantiate
  `dma_controller`, not `dma_top`; no compatibility wrapper is retained.
- Rename and update the top-level testbench accordingly, remove the obsolete
  security scenario, and verify compilation plus the normal DMA transfer path.
