# FIFO Depth 32 Canonicalization Design

> **Status: Supporting decision record — superseded by Canonical Architecture Baseline V2.4.1.** The normative FIFO value remains 32 words; this file has no independent authority.

## Goal

Make the implementation and system model use the architecture SSOT's canonical DMA FIFO depth of 32 words (128 bytes).

## Decision

The default DMA FIFO configuration is fixed to 32 words. The RTL count and free-space paths must represent the inclusive range `0..32`, so they use six bits. This avoids truncating the value 32 to zero during free-space calculation.

## Scope

- Set the default FIFO depth to 32 in `dma_fifo_latch.v`, `dma_axi_master.v`, and `SoCConfig`.
- Set the `dma_controller.v` instantiations to 32 and widen its FIFO count connection to six bits.
- Widen `dma_axi_master.v`'s FIFO count/free-space path to six bits.
- Set the FIFO testbench default to 32.
- Make the payload-scaling benchmark use 32 words, matching the canonical configuration.

## Non-Goals

- Do not alter the FIFO sweep, which intentionally retains 4, 8, 16, 32, and 64-word comparison points.
- Do not regenerate or edit existing benchmark result files; they remain historical measurement artifacts.
- Do not change the DMA burst length, AXI protocol behavior, or firewall design.

## Verification

- Compile and run the FIFO and DMA-controller RTL testbenches.
- Run the existing Python unit and integration tests.
- Search the standard runtime configuration paths to confirm no canonical FIFO default remains 16.
