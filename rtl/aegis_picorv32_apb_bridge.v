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
// The AEGIS NMI is wired to PicoRV32's dedicated unmaskable NMI input.  The
// ordinary irq[3] observation remains available as cpu_irq3 for compatibility,
// but security service no longer depends on the software IRQ mask.  This is a
// single-clock, single-domain bridge; CDC is outside the frontend scope.

module aegis_picorv32_apb_bridge #(
    parameter [31:0] FW_APB_CPU_BASE  = 32'h4000_0000,
    parameter [31:0] DMA_APB_CPU_BASE = 32'h4000_1000,
    parameter [31:0] DMA_APB_TARGET_BASE = 32'h1000_1000,
    parameter [31:0] CPU_PROGADDR_IRQ = 32'h0000_0010
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

    // These optional PicoRV32 observability ports are intentionally unused by
    // this APB bridge. Keep them in one explicit sink so lint can distinguish
    // an intentional integration choice from an accidentally unconnected net.
    wire _unused_cpu_optional = &{
        1'b0,
        cpu_mem_la_read,
        cpu_mem_la_write,
        cpu_mem_la_addr,
        cpu_mem_la_wdata,
        cpu_mem_la_wstrb,
        cpu_pcpi_valid,
        cpu_pcpi_insn,
        cpu_pcpi_rs1,
        cpu_pcpi_rs2,
        cpu_eoi,
        cpu_trace_valid,
        cpu_trace_data
    };

    wire fw_window  = (cpu_mem_addr[31:12] == FW_APB_CPU_BASE[31:12]);
    wire dma_window = (cpu_mem_addr[31:12] == DMA_APB_CPU_BASE[31:12]);

    // APB requires a setup cycle (PSEL=1, PENABLE=0) before the access
    // cycle (PSEL=1, PENABLE=1).  PicoRV32 holds its native request until
    // mem_ready, so the bridge latches the request and explicitly sequences
    // both phases.  The latched payload also remains stable while a target
    // stretches PREADY.
    localparam [2:0] APB_IDLE      = 3'd0;
    localparam [2:0] APB_FW_SETUP  = 3'd1;
    localparam [2:0] APB_FW_ACCESS = 3'd2;
    localparam [2:0] APB_DMA_SETUP = 3'd3;
    localparam [2:0] APB_DMA_ACCESS = 3'd4;

    reg [2:0]  apb_state;
    reg [31:0] apb_addr_q;
    reg [31:0] apb_wdata_q;
    reg [3:0]  apb_wstrb_q;

    // The SoC integration supplies a synchronized reset to this bridge. Keep
    // the APB sequencer reset synchronous so a reset synchronizer output is
    // never consumed as both a synchronous and an asynchronous reset domain.
    always @(posedge clk) begin
        if (!rst_n) begin
            apb_state  <= APB_IDLE;
            apb_addr_q <= 32'b0;
            apb_wdata_q <= 32'b0;
            apb_wstrb_q <= 4'b0;
        end else begin
            case (apb_state)
                APB_IDLE: begin
                    if (cpu_mem_valid && fw_window) begin
                        apb_addr_q  <= cpu_mem_addr;
                        apb_wdata_q <= cpu_mem_wdata;
                        apb_wstrb_q <= cpu_mem_wstrb;
                        apb_state   <= APB_FW_SETUP;
                    end else if (cpu_mem_valid && dma_window) begin
                        apb_addr_q  <= cpu_mem_addr;
                        apb_wdata_q <= cpu_mem_wdata;
                        apb_wstrb_q <= cpu_mem_wstrb;
                        apb_state   <= APB_DMA_SETUP;
                    end
                end

                APB_FW_SETUP:
                    apb_state <= APB_FW_ACCESS;

                APB_FW_ACCESS:
                    if (fw_pready)
                        apb_state <= APB_IDLE;

                APB_DMA_SETUP:
                    apb_state <= APB_DMA_ACCESS;

                APB_DMA_ACCESS:
                    if (dma_pready)
                        apb_state <= APB_IDLE;

                default:
                    apb_state <= APB_IDLE;
            endcase
        end
    end

    wire fw_selected  = (apb_state == APB_FW_SETUP) || (apb_state == APB_FW_ACCESS);
    wire dma_selected = (apb_state == APB_DMA_SETUP) || (apb_state == APB_DMA_ACCESS);
    wire fw_access    = (apb_state == APB_FW_ACCESS);
    wire dma_access   = (apb_state == APB_DMA_ACCESS);

    assign fw_paddr   = apb_addr_q - FW_APB_CPU_BASE;
    assign fw_psel    = fw_selected;
    assign fw_penable = fw_access;
    assign fw_pwrite  = |apb_wstrb_q;
    assign fw_pwdata  = apb_wdata_q;
    assign fw_pprot   = 3'b001; // secure, privileged, data access

    assign dma_paddr   = DMA_APB_TARGET_BASE + (apb_addr_q - DMA_APB_CPU_BASE);
    assign dma_psel    = dma_selected;
    assign dma_penable = dma_access;
    assign dma_pwrite  = |apb_wstrb_q;
    assign dma_pwdata  = apb_wdata_q;

    assign ext_mem_valid = cpu_mem_valid && !fw_window && !dma_window &&
                           (apb_state == APB_IDLE);
    assign ext_mem_instr = cpu_mem_instr;
    assign ext_mem_addr  = cpu_mem_addr;
    assign ext_mem_wdata = cpu_mem_wdata;
    assign ext_mem_wstrb = cpu_mem_wstrb;

    assign cpu_mem_ready = fw_access ? fw_pready :
                           dma_access ? dma_pready :
                           ((apb_state == APB_IDLE) && !fw_window && !dma_window) ?
                           ext_mem_ready : 1'b0;
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
        .ENABLE_IRQ(1'b1),
        .PROGADDR_IRQ(CPU_PROGADDR_IRQ)
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
        .irq       (32'b0),
        .nmi       (aegis_nmi_irq),
        .eoi       (cpu_eoi),
        .trace_valid(cpu_trace_valid),
        .trace_data(cpu_trace_data)
    );

endmodule
