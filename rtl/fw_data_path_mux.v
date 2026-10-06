
`timescale 1ns/1ps

// Data-path interface between the DMA master, bus matrix, and drain engine.
module fw_data_path_mux #(
    parameter ID_WIDTH   = 4,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // -------------------------------------------------------------
    // Tín hiệu điều khiển từ Top-Level (dma_bus_firewall.v)
    // -------------------------------------------------------------
    input  wire [1:0]            wr_owner,      // 2'b00: NONE, 2'b01: ALLOW, 2'b10: DRAIN
    input  wire [1:0]            rd_owner,      // 2'b00: NONE, 2'b01: ALLOW, 2'b10: DRAIN
    input  wire                  wr_aw_done,    // Cờ báo AW đã handshake downstream (chốt chặn Gate G3)

    // -------------------------------------------------------------
    // DMA master (Firewall slave interface)
    // -------------------------------------------------------------
    // W channel
    input  wire                  s_axi_wvalid,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s_axi_wstrb,
    input  wire                  s_axi_wlast,
    output reg                  s_axi_wready,
    // B channel
    output reg [ID_WIDTH-1:0]   s_axi_bid,
    output reg [1:0]            s_axi_bresp,
    output reg                  s_axi_bvalid,
    input  wire                  s_axi_bready,
    // R channel
    output reg [ID_WIDTH-1:0]   s_axi_rid,
    output reg [DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0]            s_axi_rresp,
    output reg                  s_axi_rlast,
    output reg                  s_axi_rvalid,
    input  wire                  s_axi_rready,

    // -------------------------------------------------------------
    // Bus matrix (Firewall master interface)
    // -------------------------------------------------------------
    // W channel
    output reg                  m_axi_wvalid,
    output reg [DATA_WIDTH-1:0] m_axi_wdata,
    output reg [STRB_WIDTH-1:0] m_axi_wstrb,
    output reg                  m_axi_wlast,
    input  wire                  m_axi_wready,
    // B channel
    input  wire [ID_WIDTH-1:0]   m_axi_bid,
    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output reg                  m_axi_bready,
    // R channel
    input  wire [ID_WIDTH-1:0]   m_axi_rid,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rlast,
    input  wire                  m_axi_rvalid,
    output reg                  m_axi_rready,

    // -------------------------------------------------------------
    // Drain engine (Internal write/read interfaces nối tới fw_drain_fsm.v)
    // -------------------------------------------------------------
    // Write Drain
    output reg                  w_drain_wvalid,
    output reg                  w_drain_wlast,
    input  wire                  w_drain_wready,
    input  wire                  w_drain_bvalid,
    input  wire [ID_WIDTH-1:0]   w_drain_bid,
    input  wire [1:0]            w_drain_bresp,
    output reg                  w_drain_bready,
    // Read Drain
    output reg                  r_drain_rready,
    input  wire                  r_drain_rvalid,
    input  wire [ID_WIDTH-1:0]   r_drain_rid,
    input  wire [DATA_WIDTH-1:0] r_drain_rdata,
    input  wire [1:0]            r_drain_rresp,
    input  wire                  r_drain_rlast,

    // -------------------------------------------------------------
    // Honeypot sink interfaces (fw_honeypot_sink.v)
    // -------------------------------------------------------------
    // Write Honeypot
    output reg                  hp_wvalid,
    output reg [DATA_WIDTH-1:0] hp_wdata,
    output reg [STRB_WIDTH-1:0] hp_wstrb,
    output reg                  hp_wlast,
    input  wire                 hp_wready,
    input  wire                 hp_bvalid,
    input  wire [ID_WIDTH-1:0]  hp_bid,
    input  wire [1:0]           hp_bresp,
    output reg                  hp_bready,
    // Read Honeypot
    output reg                  hp_rready,
    input  wire                 hp_rvalid,
    input  wire [ID_WIDTH-1:0]  hp_rid,
    input  wire [DATA_WIDTH-1:0] hp_rdata,
    input  wire [1:0]           hp_rresp,
    input  wire                 hp_rlast
);
    
    localparam OWNER_NONE     = 2'b00;
    localparam OWNER_ALLOW    = 2'b01;
    localparam OWNER_DRAIN    = 2'b10;
    localparam OWNER_HONEYPOT = 2'b11;

    wire _unused_mux = &{1'b0, clk, rst_n, OWNER_NONE};

    // Write channel muxing logic based on ownership
    always @(*) begin
        // Default assignments to avoid latches
        m_axi_wvalid = 0;
        m_axi_wdata  = 0;
        m_axi_wstrb  = 0;
        m_axi_wlast  = 0;
        s_axi_wready = 0;
        w_drain_wvalid = 0;
        w_drain_wlast  = 0;
        hp_wvalid    = 0;
        hp_wdata     = 0;
        hp_wstrb     = 0;
        hp_wlast     = 0;
        case (wr_owner)
            OWNER_ALLOW: if (wr_aw_done == 0) begin
                m_axi_wvalid = 0;
                s_axi_wready = 0;
            end else begin
                m_axi_wvalid = s_axi_wvalid;
                m_axi_wdata  = s_axi_wdata;
                m_axi_wstrb  = s_axi_wstrb;
                m_axi_wlast  = s_axi_wlast;
                s_axi_wready = m_axi_wready;
            end
            OWNER_DRAIN: begin
                w_drain_wvalid = s_axi_wvalid;
                w_drain_wlast  = s_axi_wlast;
                s_axi_wready   = w_drain_wready;
            end
            OWNER_HONEYPOT: if (wr_aw_done == 0) begin
                s_axi_wready = 0;
                hp_wvalid    = 0;
                hp_wlast     = 0;
            end else begin
                hp_wvalid    = s_axi_wvalid;
                hp_wdata     = s_axi_wdata;
                hp_wstrb     = s_axi_wstrb;
                hp_wlast     = s_axi_wlast;
                s_axi_wready = hp_wready;
            end
            default: begin
                m_axi_wvalid = 0;
                s_axi_wready = 0;
            end
        endcase
    end

    // B channel muxing logic based on ownership
    always @(*) begin
        // Default assignments to avoid latches
        m_axi_bready   = 0;
        s_axi_bvalid   = 0; 
        s_axi_bid      = 0; 
        s_axi_bresp    = 0;
        w_drain_bready = 0;
        hp_bready      = 0;
        case (wr_owner)
            OWNER_ALLOW: begin
                m_axi_bready = s_axi_bready;
                s_axi_bvalid = m_axi_bvalid;
                s_axi_bid    = m_axi_bid;
                s_axi_bresp  = m_axi_bresp;
            end
            OWNER_DRAIN: begin
                w_drain_bready = s_axi_bready;
                s_axi_bvalid   = w_drain_bvalid;
                s_axi_bid      = w_drain_bid;
                s_axi_bresp    = w_drain_bresp;
            end
            OWNER_HONEYPOT: begin
                hp_bready    = s_axi_bready;
                s_axi_bvalid = hp_bvalid;
                s_axi_bid    = hp_bid;
                s_axi_bresp  = hp_bresp;
            end
            default: begin
                m_axi_bready = 0;
            end
        endcase
    end

    // R channel muxing logic based on ownership
    always @(*) begin
        // Default assignments to avoid latches
        m_axi_rready   = 0;
        s_axi_rvalid   = 0;
        s_axi_rid      = 0;
        s_axi_rdata    = 0;
        s_axi_rresp    = 0;
        s_axi_rlast    = 0;
        r_drain_rready = 0;
        hp_rready      = 0;
        case (rd_owner)
            OWNER_ALLOW: begin
                m_axi_rready = s_axi_rready;
                s_axi_rvalid = m_axi_rvalid;
                s_axi_rid    = m_axi_rid;
                s_axi_rdata  = m_axi_rdata;
                s_axi_rresp  = m_axi_rresp;
                s_axi_rlast  = m_axi_rlast;
            end
            OWNER_DRAIN: begin
                r_drain_rready = s_axi_rready;
                s_axi_rvalid   = r_drain_rvalid;
                s_axi_rid      = r_drain_rid;
                s_axi_rdata    = r_drain_rdata;
                s_axi_rresp    = r_drain_rresp;
                s_axi_rlast    = r_drain_rlast;
            end
            OWNER_HONEYPOT: begin
                hp_rready    = s_axi_rready;
                s_axi_rvalid = hp_rvalid;
                s_axi_rid    = hp_rid;
                s_axi_rdata  = hp_rdata;
                s_axi_rresp  = hp_rresp;
                s_axi_rlast  = hp_rlast;
            end
            default: begin
                m_axi_rready = 0;
            end
        endcase
    end
endmodule
