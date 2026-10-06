`timescale 1ns/1ps

module dma_apb_slave #(
    parameter [31:0] APB_BASE_ADDR = 32'h1000_1000
)(
    input  wire        pclk,
    input  wire        presetn,
    
    // APB Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
  
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Interface to DMA Core & Controller
    output reg  [31:0] cfg_src_addr,
    output reg  [31:0] cfg_dst_addr,
    output reg  [31:0] cfg_byte_len,
    output reg         cfg_start,
    output reg         irq_en,
    
    input  wire        status_busy,
    input  wire        status_done_event,
    input  wire        status_error_event,
    
    output reg         status_done_sticky,
    output reg         status_error_sticky
);

    // APB Window & Alignment Check
    wire apb_window_valid = (paddr[31:5] == APB_BASE_ADDR[31:5]);
    wire addr_aligned      = (paddr[1:0] == 2'b00);
    wire offset_mapped     = (paddr[4:0] <= 5'h10);
    wire apb_addr_valid    = apb_window_valid && addr_aligned && offset_mapped;

    assign pready  = 1'b1;
    assign pslverr = psel && penable && !apb_addr_valid;

    // Write Logic
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            cfg_src_addr        <= 32'd0;
            cfg_dst_addr        <= 32'd0;
            cfg_byte_len        <= 32'd0;
            cfg_start           <= 1'b0;
            irq_en              <= 1'b0;
            status_done_sticky  <= 1'b0;
            status_error_sticky <= 1'b0;
        end else begin
            cfg_start <= 1'b0;

            if (psel && penable && pwrite && apb_addr_valid) begin
                case (paddr[4:0])
                    5'h00: begin // DMA_CTRL
                        // START while BUSY is ignored. IRQ_EN remains an
                        // independently writable control bit.
                        if (pwdata[0] && !status_busy)
                            cfg_start <= 1'b1;
                        irq_en <= pwdata[1];
                    end
                    5'h04: cfg_src_addr <= pwdata; // DMA_SRC
                    5'h08: cfg_dst_addr <= pwdata; // DMA_DST
                    5'h0C: cfg_byte_len <= pwdata; // DMA_LEN
                    5'h10: begin // DMA_STATUS (W1C: Write 1 to clear)
                        if (pwdata[1])
                            status_done_sticky <= 1'b0;
                        if (pwdata[2])
                            status_error_sticky <= 1'b0;
                    end
                    default: begin
                        // apb_addr_valid filters the legal window; keep the
                        // write decode total for lint and formal tools.
                    end
                endcase
            end

            // Hardware-set events have final priority over software W1C when
            // both occur on the same clock edge.
            if (status_done_event)
                status_done_sticky <= 1'b1;
            if (status_error_event)
                status_error_sticky <= 1'b1;
        end
    end

    // Read Logic
    always @(*) begin
        prdata = 32'b0;
        if (psel && penable && !pwrite && apb_addr_valid) begin
            case (paddr[4:0])
                5'h00: prdata = {30'b0, irq_en, 1'b0}; // START is self-clearing command
                5'h04: prdata = cfg_src_addr;
                5'h08: prdata = cfg_dst_addr;
                5'h0C: prdata = cfg_byte_len;
                5'h10: prdata = {29'b0, status_error_sticky, status_done_sticky, status_busy};
                default: prdata = 32'b0;
            endcase
        end
    end

endmodule
