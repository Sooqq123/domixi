`timescale 1ns/1ps

module dma_axi_master #(
    parameter FIFO_DEPTH = 32,
    parameter ID_WIDTH   = 4
)(
    input  wire                    aclk,
    input  wire                    aresetn,

    input  wire [31:0]             cfg_src_addr,
    input  wire [31:0]             cfg_dst_addr,
    input  wire [31:0]             cfg_byte_len,
    input  wire                    cfg_start,

    output reg                     status_busy,
    output reg                     status_done,
    output reg                     status_error,

    input  wire                    fifo_full,
    input  wire                    fifo_empty,
    input  wire [5:0]              fifo_count,
    output reg                     fifo_wr_en,
    output reg  [31:0]             fifo_wdata,
    output reg                     fifo_rd_en,
    output reg                     fifo_flush,
    input  wire [31:0]             fifo_rdata,

    output reg  [31:0]             m_axi_araddr,
    output wire [ID_WIDTH-1:0]     m_axi_arid,
    output reg  [7:0]              m_axi_arlen,
    output wire [2:0]              m_axi_arsize,
    output wire [1:0]              m_axi_arburst,
    output wire [2:0]              m_axi_prot,
    output reg                     m_axi_arvalid,
    input  wire                    m_axi_arready,
    input  wire [31:0]             m_axi_rdata,
    input  wire                    m_axi_rlast,
    input  wire                    m_axi_rvalid,
    input  wire [ID_WIDTH-1:0]     m_axi_rid,
    input  wire [1:0]              m_axi_rresp,
    output reg                     m_axi_rready,

    output reg  [31:0]             m_axi_awaddr,
    output wire [ID_WIDTH-1:0]     m_axi_awid,
    output reg  [7:0]              m_axi_awlen,
    output wire [2:0]              m_axi_awsize,
    output wire [1:0]              m_axi_awburst,
    output reg                     m_axi_awvalid,
    input  wire                    m_axi_awready,
    output reg  [31:0]             m_axi_wdata,
    output wire [3:0]              m_axi_wstrb,
    output reg                     m_axi_wlast,
    output reg                     m_axi_wvalid,
    input  wire                    m_axi_wready,
    input  wire [ID_WIDTH-1:0]     m_axi_bid,
    input  wire [1:0]              m_axi_bresp,
    input  wire                    m_axi_bvalid,
    output reg                     m_axi_bready
);

    localparam [1:0] AXI_OKAY = 2'b00;

    assign m_axi_arsize  = 3'b010;
    assign m_axi_arburst = 2'b01;
    assign m_axi_awsize  = 3'b010;
    assign m_axi_awburst = 2'b01;
    assign m_axi_arid    = {ID_WIDTH{1'b0}};
    assign m_axi_awid    = {ID_WIDTH{1'b0}};
    assign m_axi_prot    = 3'b001;
    assign m_axi_wstrb   = 4'b1111;

    function [7:0] calc_burst_len;
        input [11:0] addr_low;
        input [31:0] bytes_left;
        reg   [31:0] beats_left;
        reg   [31:0] bytes_to_4kb;
        reg   [31:0] beats_to_4kb;
        reg   [31:0] max_beats;
        begin
            bytes_to_4kb = 32'd4096 - {20'd0, addr_low};
            beats_to_4kb = bytes_to_4kb >> 2;
            beats_left   = (bytes_left + 32'd3) >> 2;
            max_beats    = (beats_left < 32'd16) ? beats_left : 32'd16;
            if (beats_to_4kb < max_beats)
                max_beats = beats_to_4kb;
            calc_burst_len = (max_beats == 32'd0) ? 8'd0 : max_beats[7:0] - 8'd1;
        end
    endfunction

    function [31:0] calc_burst_bytes;
        input [11:0] addr_low;
        input [31:0] bytes_left;
        reg   [7:0]  burst_len;
        begin
            burst_len = calc_burst_len(addr_low, bytes_left);
            calc_burst_bytes = ({24'd0, burst_len} + 32'd1) << 2;
        end
    endfunction

    localparam [1:0] R_IDLE = 2'd0;
    localparam [1:0] R_ADDR = 2'd1;
    localparam [1:0] R_DATA = 2'd2;

    localparam [2:0] W_IDLE  = 3'd0;
    localparam [2:0] W_ADDR  = 3'd1;
    localparam [2:0] W_DATA  = 3'd2;
    localparam [2:0] W_RESP  = 3'd3;
    localparam [2:0] W_FLUSH = 3'd4;

    reg [1:0] r_state;
    reg [2:0] w_state;

    reg [31:0] read_addr_ptr;
    reg [31:0] write_addr_ptr;
    reg [31:0] read_bytes_left;
    reg [31:0] write_bytes_left;
    reg [31:0] r_burst_bytes_reg;
    reg [31:0] w_burst_bytes_reg;
    reg [8:0]  r_beats_remaining;
    reg [7:0]  w_burst_len_reg;
    reg [7:0]  w_burst_cnt;
    reg        read_active;
    reg        write_active;
    reg        dma_running;
    reg        abort_latched;

    wire [7:0] rd_beats_needed = calc_burst_len(read_addr_ptr[11:0], read_bytes_left) + 8'd1;
    wire [7:0] wr_beats_needed = calc_burst_len(write_addr_ptr[11:0], write_bytes_left) + 8'd1;
    // Keep FIFO occupancy arithmetic at the same width as the AXI beat
    // counters.  fifo_count is six bits in the FIFO implementation, while
    // the burst counters are eight bits.
    localparam [7:0] FIFO_DEPTH_8 = FIFO_DEPTH;
    wire [7:0] fifo_count_ext = {2'b00, fifo_count};
    wire [7:0] fifo_free = FIFO_DEPTH_8 - fifo_count_ext;

    wire read_beat_handshake =
        (r_state == R_DATA) && m_axi_rvalid && m_axi_rready;
    wire read_expected_final = (r_beats_remaining == 9'd1);
    wire read_framing_error = read_beat_handshake &&
        (m_axi_rlast != read_expected_final);
    wire read_response_error = read_beat_handshake &&
        ((m_axi_rresp != AXI_OKAY) ||
         (m_axi_rid != {ID_WIDTH{1'b0}}) || read_framing_error);

    wire write_response_error =
        (w_state == W_RESP) && m_axi_bvalid && m_axi_bready &&
        ((m_axi_bresp != AXI_OKAY) || (m_axi_bid != {ID_WIDTH{1'b0}}));

    // Includes same-cycle response failures so the peer channel cannot issue
    // another address in the cycle before abort_latched is registered.
    wire abort_request = abort_latched || read_response_error || write_response_error;

    // Read channel: an AR payload is held until handshake. Once accepted, a
    // correctly framed error response is drained through exactly ARLEN+1
    // beats. An early or missing final RLAST closes the violated channel on
    // that handshake so a malformed peer cannot hold the DMA busy forever.
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state           <= R_IDLE;
            m_axi_araddr      <= 32'd0;
            m_axi_arlen       <= 8'd0;
            m_axi_arvalid     <= 1'b0;
            m_axi_rready      <= 1'b0;
            read_addr_ptr     <= 32'd0;
            read_bytes_left   <= 32'd0;
            r_burst_bytes_reg <= 32'd0;
            r_beats_remaining <= 9'd0;
            read_active       <= 1'b0;
            fifo_wr_en        <= 1'b0;
            fifo_wdata        <= 32'd0;
        end else begin
            fifo_wr_en <= 1'b0;

            case (r_state)
                R_IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    if (cfg_start && !read_active && (cfg_byte_len != 32'd0)) begin
                        read_addr_ptr   <= cfg_src_addr;
                        read_bytes_left <= cfg_byte_len;
                        read_active     <= 1'b1;
                        r_state         <= R_ADDR;
                    end
                end

                R_ADDR: begin
                    m_axi_rready <= 1'b0;
                    if (m_axi_arvalid) begin
                        // VALID and payload remain unchanged until READY.
                        if (m_axi_arready) begin
                            m_axi_arvalid <= 1'b0;
                            m_axi_rready  <= 1'b1;
                            r_beats_remaining <= {1'b0, m_axi_arlen} + 9'd1;
                            r_state       <= R_DATA;
                        end
                    end else if (abort_request || (read_bytes_left == 32'd0)) begin
                        read_active <= 1'b0;
                        r_state     <= R_IDLE;
                    end else if (!fifo_full && (fifo_free >= rd_beats_needed)) begin
                        m_axi_araddr      <= read_addr_ptr;
                        m_axi_arlen       <= calc_burst_len(read_addr_ptr[11:0], read_bytes_left);
                        r_burst_bytes_reg <= calc_burst_bytes(read_addr_ptr[11:0], read_bytes_left);
                        m_axi_arvalid     <= 1'b1;
                    end
                end

                R_DATA: begin
                    m_axi_rready <= 1'b1;
                    if (read_beat_handshake) begin
                        if (!abort_request && (m_axi_rresp == AXI_OKAY) &&
                            (m_axi_rid == {ID_WIDTH{1'b0}})) begin
                            fifo_wdata <= m_axi_rdata;
                            fifo_wr_en <= 1'b1;
                        end

                        if (read_framing_error) begin
                            // Do not wait for a peer that violated ARLEN/RLAST.
                            // abort_request is true in this cycle, preventing
                            // the malformed beat from entering the FIFO.
                            m_axi_rready <= 1'b0;
                            r_beats_remaining <= 9'd0;
                            read_active <= 1'b0;
                            r_state     <= R_IDLE;
                        end else if (read_expected_final) begin
                            m_axi_rready <= 1'b0;
                            r_beats_remaining <= 9'd0;
                            if (!abort_request) begin
                                read_addr_ptr   <= read_addr_ptr + r_burst_bytes_reg;
                                read_bytes_left <= read_bytes_left - r_burst_bytes_reg;
                                r_state         <= R_ADDR;
                            end else begin
                                read_active <= 1'b0;
                                r_state     <= R_IDLE;
                            end
                        end else begin
                            r_beats_remaining <= r_beats_remaining - 9'd1;
                        end
                    end
                end

                default: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    read_active   <= 1'b0;
                    r_state       <= R_IDLE;
                end
            endcase
        end
    end

    // Write channel: WVALID and FIFO pop are forbidden before AW handshake.
    // An accepted AW is completed through W/B before abort cleanup begins.
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state           <= W_IDLE;
            m_axi_awaddr      <= 32'd0;
            m_axi_awlen       <= 8'd0;
            m_axi_awvalid     <= 1'b0;
            m_axi_wdata       <= 32'd0;
            m_axi_wlast       <= 1'b0;
            m_axi_wvalid      <= 1'b0;
            m_axi_bready      <= 1'b0;
            write_addr_ptr    <= 32'd0;
            write_bytes_left  <= 32'd0;
            w_burst_bytes_reg <= 32'd0;
            w_burst_len_reg   <= 8'd0;
            w_burst_cnt       <= 8'd0;
            write_active      <= 1'b0;
            fifo_rd_en        <= 1'b0;
            fifo_flush        <= 1'b0;
        end else begin
            fifo_rd_en <= 1'b0;
            fifo_flush <= 1'b0;

            case (w_state)
                W_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_wlast   <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    if (cfg_start && !write_active && (cfg_byte_len != 32'd0)) begin
                        write_addr_ptr   <= cfg_dst_addr;
                        write_bytes_left <= cfg_byte_len;
                        write_active     <= 1'b1;
                        w_state          <= W_ADDR;
                    end
                end

                W_ADDR: begin
                    m_axi_wvalid <= 1'b0;
                    m_axi_wlast  <= 1'b0;
                    m_axi_bready <= 1'b0;
                    if (m_axi_awvalid) begin
                        // A presented AW cannot be withdrawn on abort.
                        if (m_axi_awready) begin
                            m_axi_awvalid <= 1'b0;
                            w_burst_cnt   <= 8'd0;
                            w_state       <= W_DATA;
                        end
                    end else if (abort_request) begin
                        w_state <= W_FLUSH;
                    end else if (write_bytes_left == 32'd0) begin
                        write_active <= 1'b0;
                        w_state      <= W_IDLE;
                    end else if (fifo_count_ext >= wr_beats_needed) begin
                        m_axi_awaddr      <= write_addr_ptr;
                        m_axi_awlen       <= calc_burst_len(write_addr_ptr[11:0], write_bytes_left);
                        w_burst_len_reg   <= calc_burst_len(write_addr_ptr[11:0], write_bytes_left);
                        w_burst_bytes_reg <= calc_burst_bytes(write_addr_ptr[11:0], write_bytes_left);
                        m_axi_awvalid     <= 1'b1;
                    end
                end

                W_DATA: begin
                    // fifo_rd_en is observed by the FIFO on the following
                    // edge. Wait for that pop to retire before sampling the
                    // next combinational FIFO head.
                    if (!m_axi_wvalid && !fifo_rd_en && !fifo_empty) begin
                        m_axi_wdata  <= fifo_rdata;
                        m_axi_wlast  <= (w_burst_cnt == w_burst_len_reg);
                        m_axi_wvalid <= 1'b1;
                    end

                    if (m_axi_wvalid && m_axi_wready) begin
                        fifo_rd_en   <= 1'b1;
                        m_axi_wvalid <= 1'b0;
                        m_axi_wlast  <= 1'b0;
                        if (m_axi_wlast) begin
                            m_axi_bready <= 1'b1;
                            w_state      <= W_RESP;
                        end else begin
                            w_burst_cnt <= w_burst_cnt + 8'd1;
                        end
                    end
                end

                W_RESP: begin
                    m_axi_bready <= 1'b1;
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        if (abort_request) begin
                            w_state <= W_FLUSH;
                        end else begin
                            write_addr_ptr   <= write_addr_ptr + w_burst_bytes_reg;
                            write_bytes_left <= write_bytes_left - w_burst_bytes_reg;
                            w_state          <= W_ADDR;
                        end
                    end
                end

                W_FLUSH: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_wlast   <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    if (!fifo_empty) begin
                        fifo_flush <= 1'b1;
                    end else begin
                        write_active <= 1'b0;
                        w_state      <= W_IDLE;
                    end
                end

                default: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_wlast   <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    write_active  <= 1'b0;
                    w_state       <= W_IDLE;
                end
            endcase
        end
    end

    // Exactly one terminal event is emitted after both AXI sides are quiescent
    // and the FIFO is empty. Failed transfers never emit status_done.
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            status_busy   <= 1'b0;
            status_done   <= 1'b0;
            status_error  <= 1'b0;
            dma_running   <= 1'b0;
            abort_latched <= 1'b0;
        end else begin
            status_done  <= 1'b0;
            status_error <= 1'b0;

            if (cfg_start && !dma_running && (cfg_byte_len != 32'd0)) begin
                status_busy   <= 1'b1;
                dma_running   <= 1'b1;
                abort_latched <= 1'b0;
            end else if (dma_running) begin
                if (read_response_error || write_response_error)
                    abort_latched <= 1'b1;

                if (abort_request && !read_active && !write_active && fifo_empty) begin
                    status_busy   <= 1'b0;
                    status_error  <= 1'b1;
                    dma_running   <= 1'b0;
                    abort_latched <= 1'b0;
                end else if (!abort_request && !read_active && !write_active && fifo_empty) begin
                    status_busy   <= 1'b0;
                    status_done   <= 1'b1;
                    dma_running   <= 1'b0;
                end
            end
        end
    end

endmodule
