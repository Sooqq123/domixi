`timescale 1ns/1ps

// AEGIS frontend integration wrapper.
//
// The firewall and DMA controller deliberately expose APB/AXI boundaries
// rather than a CPU-specific bus.  This wrapper is the small, explicit SoC
// adapter that was missing from the end-to-end verification path:
//   PicoRV32 native memory bus
//          |-- 0x4000_0000 + offset -> firewall APB
//          `-- 0x4000_1000 + offset -> DMA APB (translated to 0x1000_1000)
//          `-- everything else     -> external CPU memory port
//
// The AEGIS NMI is wired to PicoRV32 irq[3], as specified by the project
// contract.  This is a single-clock, single-domain bridge; CDC is outside the
// frontend scope.

module aegis_picorv32_apb_bridge #(
    parameter [31:0] FW_APB_CPU_BASE  = 32'h4000_0000,
    parameter [31:0] DMA_APB_CPU_BASE = 32'h4000_1000,
    parameter [31:0] DMA_APB_TARGET_BASE = 32'h1000_1000
)(
    input  wire        clk,
    input  wire        rst_n,

    // External CPU memory port for instruction/data RAM not mapped to APB.
    output wire        ext_mem_valid,
    output wire        ext_mem_instr,
    output wire [31:0] ext_mem_addr,
    output wire [31:0] ext_mem_wdata,
    output wire [3:0]  ext_mem_wstrb,
    input  wire        ext_mem_ready,
    input  wire [31:0] ext_mem_rdata,

    // Firewall APB target.
    output wire [31:0] fw_paddr,
    output wire        fw_psel,
    output wire        fw_penable,
    output wire        fw_pwrite,
    output wire [31:0] fw_pwdata,
    output wire [2:0]  fw_pprot,
    input  wire [31:0] fw_prdata,
    input  wire        fw_pready,
    input  wire        fw_pslverr,

    // DMA APB target.
    output wire [31:0] dma_paddr,
    output wire        dma_psel,
    output wire        dma_penable,
    output wire        dma_pwrite,
    output wire [31:0] dma_pwdata,
    input  wire [31:0] dma_prdata,
    input  wire        dma_pready,
    input  wire        dma_pslverr,

    // CPU/AEGIS observability.
    input  wire        aegis_nmi_irq,
    output wire        cpu_irq3,
    output wire        cpu_trap,
    output wire        cpu_stall
);

    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    wire        cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [3:0]  cpu_mem_wstrb;
    wire [31:0] cpu_mem_rdata;
    wire        cpu_mem_la_read;
    wire        cpu_mem_la_write;
    wire [31:0] cpu_mem_la_addr;
    wire [31:0] cpu_mem_la_wdata;
    wire [3:0]  cpu_mem_la_wstrb;
    wire        cpu_pcpi_valid;
    wire [31:0] cpu_pcpi_insn;
    wire [31:0] cpu_pcpi_rs1;
    wire [31:0] cpu_pcpi_rs2;
    wire [31:0] cpu_eoi;
    wire        cpu_trace_valid;
    wire [35:0] cpu_trace_data;

    wire fw_window  = (cpu_mem_addr[31:12] == FW_APB_CPU_BASE[31:12]);
    wire dma_window = (cpu_mem_addr[31:12] == DMA_APB_CPU_BASE[31:12]);
    wire fw_access  = cpu_mem_valid && fw_window;
    wire dma_access = cpu_mem_valid && dma_window;

    // Native CPU requests are presented as a one-cycle APB access because
    // both project APB slaves have PREADY asserted for their access phase.
    assign fw_paddr   = cpu_mem_addr - FW_APB_CPU_BASE;
    assign fw_psel    = fw_access;
    assign fw_penable = fw_access;
    assign fw_pwrite  = |cpu_mem_wstrb;
    assign fw_pwdata  = cpu_mem_wdata;
    assign fw_pprot   = 3'b001; // secure, privileged, data access

    assign dma_paddr   = DMA_APB_TARGET_BASE + (cpu_mem_addr - DMA_APB_CPU_BASE);
    assign dma_psel    = dma_access;
    assign dma_penable = dma_access;
    assign dma_pwrite  = |cpu_mem_wstrb;
    assign dma_pwdata  = cpu_mem_wdata;

    assign ext_mem_valid = cpu_mem_valid && !fw_window && !dma_window;
    assign ext_mem_instr = cpu_mem_instr;
    assign ext_mem_addr  = cpu_mem_addr;
    assign ext_mem_wdata = cpu_mem_wdata;
    assign ext_mem_wstrb = cpu_mem_wstrb;

    assign cpu_mem_ready = fw_access ? fw_pready :
                           dma_access ? dma_pready : ext_mem_ready;
    assign cpu_mem_rdata = fw_access ? fw_prdata :
                           dma_access ? dma_prdata : ext_mem_rdata;

    assign cpu_stall = cpu_mem_valid && !cpu_mem_ready;
    assign cpu_irq3  = aegis_nmi_irq;

    // fw_pslverr/dma_pslverr are intentionally not translated into a CPU
    // trap here: the APB contract exposes PREADY/PSLVERR to the integration
    // boundary, while PicoRV32 has no native APB error input.  Software reads
    // back status/error registers after a transaction as the project does in
    // its APB verification suite.
    wire unused_apb_error = fw_pslverr | dma_pslverr;

    picorv32 #(
        .ENABLE_IRQ(1'b1)
    ) u_picorv32 (
        .clk       (clk),
        .resetn    (rst_n),
        .trap      (cpu_trap),
        .mem_valid (cpu_mem_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (cpu_mem_ready),
        .mem_addr  (cpu_mem_addr),
        .mem_wdata (cpu_mem_wdata),
        .mem_wstrb (cpu_mem_wstrb),
        .mem_rdata (cpu_mem_rdata),
        .mem_la_read(cpu_mem_la_read),
        .mem_la_write(cpu_mem_la_write),
        .mem_la_addr(cpu_mem_la_addr),
        .mem_la_wdata(cpu_mem_la_wdata),
        .mem_la_wstrb(cpu_mem_la_wstrb),
        .pcpi_valid(cpu_pcpi_valid),
        .pcpi_insn(cpu_pcpi_insn),
        .pcpi_rs1 (cpu_pcpi_rs1),
        .pcpi_rs2 (cpu_pcpi_rs2),
        .pcpi_wr   (1'b0),
        .pcpi_rd   (32'b0),
        .pcpi_wait (1'b0),
        .pcpi_ready(1'b0),
        .irq       ({28'b0, aegis_nmi_irq, 3'b0}),
        .eoi       (cpu_eoi),
        .trace_valid(cpu_trace_valid),
        .trace_data(cpu_trace_data)
    );

endmodule
