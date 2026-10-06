`timescale 1ns/1ps

module dma_fifo_latch #(
    parameter DEPTH     = 32,
    parameter PTR_WIDTH = 5
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               wr_en,
    input  wire [31:0]        wdata,
    input  wire               rd_en,
    input  wire               flush,
    output wire [31:0]        rdata,
    output wire               full,
    output wire               empty,
    output wire [PTR_WIDTH:0] count
);

    reg [PTR_WIDTH:0] w_ptr_bin, w_ptr_gray;
    reg [PTR_WIDTH:0] r_ptr_bin, r_ptr_gray;

    (* ram_style = "block" *) reg [31:0] mem_array [0:DEPTH-1];

    wire [PTR_WIDTH:0] w_ptr_bin_next = w_ptr_bin + 1'b1;
    wire [PTR_WIDTH:0] w_ptr_gray_next = (w_ptr_bin_next >> 1) ^ w_ptr_bin_next;

    wire [PTR_WIDTH:0] r_ptr_bin_next = r_ptr_bin + 1'b1;
    wire [PTR_WIDTH:0] r_ptr_gray_next = (r_ptr_bin_next >> 1) ^ r_ptr_bin_next;

    assign count = w_ptr_bin - r_ptr_bin;
    assign empty = (w_ptr_gray == r_ptr_gray);
    assign full  = (w_ptr_gray[PTR_WIDTH]     != r_ptr_gray[PTR_WIDTH]) &&
                   (w_ptr_gray[PTR_WIDTH-1]   != r_ptr_gray[PTR_WIDTH-1]) &&
                   (w_ptr_gray[PTR_WIDTH-2:0] == r_ptr_gray[PTR_WIDTH-2:0]);

    assign rdata = mem_array[r_ptr_bin[PTR_WIDTH-1:0]];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_ptr_bin  <= {PTR_WIDTH+1{1'b0}};
            w_ptr_gray <= {PTR_WIDTH+1{1'b0}};
        end else if (flush) begin
            w_ptr_bin  <= {PTR_WIDTH+1{1'b0}};
            w_ptr_gray <= {PTR_WIDTH+1{1'b0}};
        end else if (wr_en && !full) begin
            mem_array[w_ptr_bin[PTR_WIDTH-1:0]] <= wdata;
            w_ptr_bin  <= w_ptr_bin_next;
            w_ptr_gray <= w_ptr_gray_next;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_ptr_bin  <= {PTR_WIDTH+1{1'b0}};
            r_ptr_gray <= {PTR_WIDTH+1{1'b0}};
        end else if (flush) begin
            r_ptr_bin  <= {PTR_WIDTH+1{1'b0}};
            r_ptr_gray <= {PTR_WIDTH+1{1'b0}};
        end else if (rd_en && !empty) begin
            r_ptr_bin  <= r_ptr_bin_next;
            r_ptr_gray <= r_ptr_gray_next;
        end
    end

endmodule
