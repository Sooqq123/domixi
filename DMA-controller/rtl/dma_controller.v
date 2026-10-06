`timescale 1ns/1ps

module dma_controller #(
    parameter ID_WIDTH = 4,
    parameter [31:0] APB_BASE_ADDR = 32'h1000_1000
)(
    input  wire        clk,
    input  wire        rst_n,

    // APB Slave Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Interrupt
    output wire        dma_irq,

    // DMA Context Sideband V2.4 (Normative Contract)
    output reg         dma_ctx_valid,
    output reg  [31:0] dma_ctx_src_addr,
    output reg  [31:0] dma_ctx_dst_addr,
    output reg  [31:0] dma_ctx_byte_len,
    output reg         dma_ctx_done,

    // AXI4 Master Interface
    output wire [31:0] m_axi_araddr,
    output wire [ID_WIDTH-1:0] m_axi_arid,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    output wire [2:0]  m_axi_prot,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    input  wire [ID_WIDTH-1:0] m_axi_rid,
    input  wire [1:0]  m_axi_rresp,
    output wire        m_axi_rready,
    output wire [31:0] m_axi_awaddr,
    output wire [ID_WIDTH-1:0] m_axi_awid,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [ID_WIDTH-1:0] m_axi_bid,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready
);

    wire [31:0] cfg_src_addr, cfg_dst_addr, cfg_byte_len;
    wire        cfg_start;
    wire        irq_en;
    wire        status_busy, master_done, master_error;
    wire        status_done_sticky, status_error_sticky;
    
    wire        fifo_full, fifo_empty;
    wire [5:0]  fifo_count;
    wire        fifo_wr_en, fifo_rd_en, fifo_flush;
    wire [31:0] fifo_wdata, fifo_rdata;

    // Alignment & Length & Overflow Validation
    wire cfg_addr_aligned = (cfg_src_addr[1:0] == 2'b00) && (cfg_dst_addr[1:0] == 2'b00);
    wire cfg_len_valid    = (cfg_byte_len[1:0] == 2'b00) && (cfg_byte_len != 32'd0);
    wire cfg_no_overflow  = ({1'b0, cfg_src_addr} + {1'b0, cfg_byte_len} <= 33'h1_0000_0000) &&
                            ({1'b0, cfg_dst_addr} + {1'b0, cfg_byte_len} <= 33'h1_0000_0000);
    wire cfg_valid        = cfg_addr_aligned && cfg_len_valid && cfg_no_overflow;

    wire align_error_event = cfg_start && !cfg_valid;
    wire master_start      = cfg_start && cfg_valid && !status_busy;

    dma_apb_slave #(.APB_BASE_ADDR(APB_BASE_ADDR)) u_slave (
        .pclk(clk), .presetn(rst_n),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .cfg_src_addr(cfg_src_addr), .cfg_dst_addr(cfg_dst_addr), .cfg_byte_len(cfg_byte_len),
        .cfg_start(cfg_start),
        .irq_en(irq_en),
        .status_busy(status_busy),
        .status_done_event(master_done),
        .status_error_event(master_error | align_error_event),
        .status_done_sticky(status_done_sticky),
        .status_error_sticky(status_error_sticky)
    );

    // Interrupt Generation
    assign dma_irq = irq_en & (status_done_sticky | status_error_sticky);

    dma_fifo_latch #(.DEPTH(32)) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(fifo_wr_en), .wdata(fifo_wdata),
        .rd_en(fifo_rd_en), .flush(fifo_flush), .rdata(fifo_rdata),
        .full(fifo_full), .empty(fifo_empty),
        .count(fifo_count)
    );

    dma_axi_master #(.FIFO_DEPTH(32), .ID_WIDTH(ID_WIDTH)) u_master (
        .aclk(clk), .aresetn(rst_n),
        .cfg_src_addr(cfg_src_addr), .cfg_dst_addr(cfg_dst_addr), .cfg_byte_len(cfg_byte_len),
        .cfg_start(master_start),
        .status_busy(status_busy),
        .status_done(master_done),
        .status_error(master_error),
        .fifo_full(fifo_full), .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .fifo_wr_en(fifo_wr_en), .fifo_wdata(fifo_wdata),
        .fifo_rd_en(fifo_rd_en), .fifo_flush(fifo_flush), .fifo_rdata(fifo_rdata),
        // AXI Mappings
        .m_axi_araddr(m_axi_araddr), .m_axi_arid(m_axi_arid), .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst), .m_axi_prot(m_axi_prot),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rlast(m_axi_rlast), .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rid(m_axi_rid), .m_axi_rresp(m_axi_rresp), .m_axi_rready(m_axi_rready),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awid(m_axi_awid), .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst), .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid), .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_ctx_valid    <= 1'b0;
            dma_ctx_src_addr <= 32'd0;
            dma_ctx_dst_addr <= 32'd0;
            dma_ctx_byte_len <= 32'd0;
            dma_ctx_done     <= 1'b0;
        end else begin
            dma_ctx_done <= 1'b0;

            if (master_start) begin
                dma_ctx_valid    <= 1'b1;
                dma_ctx_src_addr <= cfg_src_addr;
                dma_ctx_dst_addr <= cfg_dst_addr;
                dma_ctx_byte_len <= cfg_byte_len;
            end else if (master_done || master_error) begin
                dma_ctx_valid    <= 1'b0;
                dma_ctx_done     <= 1'b1;
            end
        end
    end

endmodule
