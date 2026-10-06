// Testbench for fw_data_path_mux
`timescale 1ns / 1ps

module tb_fw_data_path_mux;
    parameter ID_WIDTH   = 4;
    parameter DATA_WIDTH = 32;
    parameter STRB_WIDTH = DATA_WIDTH / 8;

    reg                  clk;
    reg                  rst_n;

    // Control from Top
    reg  [1:0]           wr_owner;
    reg  [1:0]           rd_owner;
    reg                  wr_aw_done;

    // DMA Master (Firewall Slave)
    reg                  s_axi_wvalid;
    reg  [DATA_WIDTH-1:0] s_axi_wdata;
    reg  [STRB_WIDTH-1:0] s_axi_wstrb;
    reg                  s_axi_wlast;
    wire                 s_axi_wready;

    wire [ID_WIDTH-1:0]  s_axi_bid;
    wire [1:0]           s_axi_bresp;
    wire                 s_axi_bvalid;
    reg                  s_axi_bready;

    wire [ID_WIDTH-1:0]  s_axi_rid;
    wire [DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0]           s_axi_rresp;
    wire                 s_axi_rlast;
    wire                 s_axi_rvalid;
    reg                  s_axi_rready;

    // Bus Matrix (Firewall Master)
    wire                 m_axi_wvalid;
    wire [DATA_WIDTH-1:0] m_axi_wdata;
    wire [STRB_WIDTH-1:0] m_axi_wstrb;
    wire                 m_axi_wlast;
    reg                  m_axi_wready;

    reg  [ID_WIDTH-1:0]  m_axi_bid;
    reg  [1:0]           m_axi_bresp;
    reg                  m_axi_bvalid;
    wire                 m_axi_bready;

    reg  [ID_WIDTH-1:0]  m_axi_rid;
    reg  [DATA_WIDTH-1:0] m_axi_rdata;
    reg  [1:0]           m_axi_rresp;
    reg                  m_axi_rlast;
    reg                  m_axi_rvalid;
    wire                 m_axi_rready;

    // Drain Engine
    wire                 w_drain_wvalid;
    wire                 w_drain_wlast;
    reg                  w_drain_wready;
    reg                  w_drain_bvalid;
    reg  [ID_WIDTH-1:0]  w_drain_bid;
    reg  [1:0]           w_drain_bresp;
    wire                 w_drain_bready;

    wire                 r_drain_rready;
    reg                  r_drain_rvalid;
    reg  [ID_WIDTH-1:0]  r_drain_rid;
    reg  [DATA_WIDTH-1:0] r_drain_rdata;
    reg  [1:0]           r_drain_rresp;
    reg                  r_drain_rlast;

    wire                 hp_wvalid;
    wire [DATA_WIDTH-1:0] hp_wdata;
    wire [STRB_WIDTH-1:0] hp_wstrb;
    wire                 hp_wlast;
    reg                  hp_wready;
    reg                  hp_bvalid;
    reg  [ID_WIDTH-1:0]  hp_bid;
    reg  [1:0]           hp_bresp;
    wire                 hp_bready;
    wire                 hp_rready;
    reg                  hp_rvalid;
    reg  [ID_WIDTH-1:0]  hp_rid;
    reg  [DATA_WIDTH-1:0] hp_rdata;
    reg  [1:0]           hp_rresp;
    reg                  hp_rlast;

    // Local constants
    localparam OWNER_NONE  = 2'b00;
    localparam OWNER_ALLOW = 2'b01;
    localparam OWNER_DRAIN = 2'b10;
    localparam OWNER_HONEYPOT = 2'b11;

    integer errors = 0;

    // Instantiate Unit Under Test (UUT)
    fw_data_path_mux #(
        .ID_WIDTH(ID_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_owner(wr_owner),
        .rd_owner(rd_owner),
        .wr_aw_done(wr_aw_done),

        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),

        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_rid(s_axi_rid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),

        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),

        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),

        .w_drain_wvalid(w_drain_wvalid),
        .w_drain_wlast(w_drain_wlast),
        .w_drain_wready(w_drain_wready),
        .w_drain_bvalid(w_drain_bvalid),
        .w_drain_bid(w_drain_bid),
        .w_drain_bresp(w_drain_bresp),
        .w_drain_bready(w_drain_bready),

        .r_drain_rready(r_drain_rready),
        .r_drain_rvalid(r_drain_rvalid),
        .r_drain_rid(r_drain_rid),
        .r_drain_rdata(r_drain_rdata),
        .r_drain_rresp(r_drain_rresp),
        .r_drain_rlast(r_drain_rlast),

        .hp_wvalid(hp_wvalid),
        .hp_wdata(hp_wdata),
        .hp_wstrb(hp_wstrb),
        .hp_wlast(hp_wlast),
        .hp_wready(hp_wready),
        .hp_bvalid(hp_bvalid),
        .hp_bid(hp_bid),
        .hp_bresp(hp_bresp),
        .hp_bready(hp_bready),
        .hp_rready(hp_rready),
        .hp_rvalid(hp_rvalid),
        .hp_rid(hp_rid),
        .hp_rdata(hp_rdata),
        .hp_rresp(hp_rresp),
        .hp_rlast(hp_rlast)
    );

    // Clock generator (100MHz, 10ns period)
    always #5 clk = ~clk;

    task check_assert;
        input condition;
        input [8*120-1:0] msg;
        begin
            if (!condition) begin
                $display("[ERROR] at %0t ps: %0s", $time, msg);
                errors = errors + 1;
            end
        end
    endtask

    initial begin


        // -------------------------------------------------------------
        // Initialize all signals
        // -------------------------------------------------------------
        clk          = 0;
        rst_n        = 0;
        wr_owner     = OWNER_NONE;
        rd_owner     = OWNER_NONE;
        wr_aw_done   = 0;

        s_axi_wvalid = 0;
        s_axi_wdata  = 32'h0;
        s_axi_wstrb  = 4'h0;
        s_axi_wlast  = 0;
        s_axi_bready = 0;
        s_axi_rready = 0;

        m_axi_wready = 0;
        m_axi_bid    = 4'h0;
        m_axi_bresp  = 2'b00;
        m_axi_bvalid = 0;
        m_axi_rid    = 4'h0;
        m_axi_rdata  = 32'h0;
        m_axi_rresp  = 2'b00;
        m_axi_rlast  = 0;
        m_axi_rvalid = 0;

        w_drain_wready = 0;
        w_drain_bvalid = 0;
        w_drain_bid    = 4'h0;
        w_drain_bresp  = 2'b00;

        r_drain_rvalid = 0;
        r_drain_rid    = 4'h0;
        r_drain_rdata  = 32'h0;
        r_drain_rresp  = 2'b00;
        r_drain_rlast  = 0;

        hp_wready = 0;
        hp_bvalid = 0;
        hp_bid    = 4'h0;
        hp_bresp  = 2'b00;
        hp_rvalid = 0;
        hp_rid    = 4'h0;
        hp_rdata  = 32'h0;
        hp_rresp  = 2'b00;
        hp_rlast  = 0;

        #20;
        rst_n = 1;
        #10;

        $display("\n========================================================");
        $display("   STARTING UNIT TESTS FOR fw_data_path_mux");
        $display("========================================================");

        // =============================================================
        // CASE 1: MUX-01 - Reset & OWNER_NONE
        // =============================================================
        $display("\n[CASE 1] Test OWNER_NONE: Traffic must be blocked fail-closed");
        wr_owner = OWNER_NONE;
        rd_owner = OWNER_NONE;
        wr_aw_done = 0;
        s_axi_wvalid = 1;
        s_axi_wdata = 32'hDEAD_BEEF;
        s_axi_wstrb = 4'hF;
        s_axi_wlast = 1;
        m_axi_wready = 1;
        w_drain_wready = 1;
        #1;
        check_assert(s_axi_wready == 1'b0, "CASE 1: s_axi_wready must be 0 in OWNER_NONE");
        check_assert(m_axi_wvalid == 1'b0, "CASE 1: m_axi_wvalid must be 0 in OWNER_NONE");
        check_assert(w_drain_wvalid == 1'b0, "CASE 1: w_drain_wvalid must be 0 in OWNER_NONE");
        check_assert(s_axi_bvalid == 1'b0, "CASE 1: s_axi_bvalid must be 0 in OWNER_NONE");
        check_assert(s_axi_rvalid == 1'b0, "CASE 1: s_axi_rvalid must be 0 in OWNER_NONE");

        s_axi_wvalid = 0;
        #10;

        // =============================================================
        // CASE 2: MUX-06 - Gate G3 W-before-AW Blocking
        // =============================================================
        $display("\n[CASE 2] Test Gate G3: WVALID asserted before AW completes");
        wr_owner = OWNER_ALLOW;
        wr_aw_done = 0; // AW not handshaked downstream yet!
        s_axi_wvalid = 1;
        s_axi_wdata = 32'hCAFE_BABE;
        m_axi_wready = 1;
        #1;
        check_assert(s_axi_wready == 1'b0, "CASE 2: G3 must block s_axi_wready when wr_aw_done=0");
        check_assert(m_axi_wvalid == 1'b0, "CASE 2: G3 must block m_axi_wvalid when wr_aw_done=0");
        check_assert(w_drain_wvalid == 1'b0, "CASE 2: Drain must not see traffic for allowed write");

        #10;

        // =============================================================
        // CASE 3: MUX-02 - Allowed Write & B Response Handshake
        // =============================================================
        $display("\n[CASE 3] Test Allowed Write & Response: wr_owner=ALLOW, wr_aw_done=1");
        wr_aw_done = 1; // AW completed!
        s_axi_wvalid = 1;
        s_axi_wdata = 32'h1234_5678;
        s_axi_wstrb = 4'hF;
        s_axi_wlast = 1;
        m_axi_wready = 1;
        #1;
        check_assert(s_axi_wready == 1'b1, "CASE 3: s_axi_wready must match m_axi_wready");
        check_assert(m_axi_wvalid == 1'b1, "CASE 3: m_axi_wvalid must pass s_axi_wvalid");
        check_assert(m_axi_wdata == 32'h1234_5678, "CASE 3: m_axi_wdata mismatch");
        check_assert(m_axi_wstrb == 4'hF, "CASE 3: m_axi_wstrb mismatch");
        check_assert(m_axi_wlast == 1'b1, "CASE 3: m_axi_wlast mismatch");
        check_assert(w_drain_wvalid == 1'b0, "CASE 3: w_drain_wvalid must stay 0");

        // Write Response (B channel)
        m_axi_bvalid = 1;
        m_axi_bid = 4'h5;
        m_axi_bresp = 2'b00; // OKAY
        s_axi_bready = 1;
        #1;
        check_assert(s_axi_bvalid == 1'b1, "CASE 3: s_axi_bvalid must match m_axi_bvalid");
        check_assert(s_axi_bid == 4'h5, "CASE 3: s_axi_bid mismatch");
        check_assert(s_axi_bresp == 2'b00, "CASE 3: s_axi_bresp mismatch");
        check_assert(m_axi_bready == 1'b1, "CASE 3: m_axi_bready must match s_axi_bready");
        check_assert(w_drain_bready == 1'b0, "CASE 3: w_drain_bready must stay 0");

        s_axi_wvalid = 0;
        m_axi_bvalid = 0;
        s_axi_bready = 0;
        wr_owner = OWNER_NONE;
        wr_aw_done = 0;
        #10;

        // =============================================================
        // CASE 4: MUX-03 - Denied Write (Routed into Drain, Matrix isolated)
        // =============================================================
        $display("\n[CASE 4] Test Denied Write: wr_owner=DRAIN");
        wr_owner = OWNER_DRAIN;
        s_axi_wvalid = 1;
        s_axi_wdata = 32'hBAD0_BAD0;
        s_axi_wstrb = 4'hF;
        s_axi_wlast = 1;
        w_drain_wready = 1;
        m_axi_wready = 1; // Matrix ready is 1, but must NOT receive anything
        #1;
        check_assert(m_axi_wvalid == 1'b0, "CASE 4: m_axi_wvalid MUST be 0 in DRAIN mode!");
        check_assert(w_drain_wvalid == 1'b1, "CASE 4: w_drain_wvalid must receive s_axi_wvalid");
        check_assert(w_drain_wlast == 1'b1, "CASE 4: w_drain_wlast must receive s_axi_wlast");
        check_assert(s_axi_wready == 1'b1, "CASE 4: s_axi_wready must match w_drain_wready");

        // Write Drain B Response (DECERR)
        w_drain_bvalid = 1;
        w_drain_bid = 4'h7;
        w_drain_bresp = 2'b11; // DECERR
        s_axi_bready = 1;
        #1;
        check_assert(s_axi_bvalid == 1'b1, "CASE 4: s_axi_bvalid must match w_drain_bvalid");
        check_assert(s_axi_bid == 4'h7, "CASE 4: s_axi_bid mismatch from drain");
        check_assert(s_axi_bresp == 2'b11, "CASE 4: s_axi_bresp mismatch from drain");
        check_assert(w_drain_bready == 1'b1, "CASE 4: w_drain_bready must receive s_axi_bready");
        check_assert(m_axi_bready == 1'b0, "CASE 4: m_axi_bready must be 0 in DRAIN mode");

        s_axi_wvalid = 0;
        w_drain_bvalid = 0;
        s_axi_bready = 0;
        wr_owner = OWNER_NONE;
        #10;

        // =============================================================
        // CASE 5: MUX-04 - Allowed Read
        // =============================================================
        $display("\n[CASE 5] Test Allowed Read: rd_owner=ALLOW");
        rd_owner = OWNER_ALLOW;
        s_axi_rready = 1;
        m_axi_rvalid = 1;
        m_axi_rid    = 4'h9;
        m_axi_rdata  = 32'hFEED_FACE;
        m_axi_rresp  = 2'b00;
        m_axi_rlast  = 1;
        #1;
        check_assert(m_axi_rready == 1'b1, "CASE 5: m_axi_rready must receive s_axi_rready");
        check_assert(r_drain_rready == 1'b0, "CASE 5: r_drain_rready must stay 0");
        check_assert(s_axi_rvalid == 1'b1, "CASE 5: s_axi_rvalid must receive m_axi_rvalid");
        check_assert(s_axi_rid == 4'h9, "CASE 5: s_axi_rid mismatch");
        check_assert(s_axi_rdata == 32'hFEED_FACE, "CASE 5: s_axi_rdata mismatch");
        check_assert(s_axi_rresp == 2'b00, "CASE 5: s_axi_rresp mismatch");
        check_assert(s_axi_rlast == 1'b1, "CASE 5: s_axi_rlast mismatch");

        s_axi_rready = 0;
        m_axi_rvalid = 0;
        rd_owner = OWNER_NONE;
        #10;

        // =============================================================
        // CASE 6: MUX-05 - Denied Read (Dummy data from Drain)
        // =============================================================
        $display("\n[CASE 6] Test Denied Read: rd_owner=DRAIN");
        rd_owner = OWNER_DRAIN;
        s_axi_rready = 1;
        // Inject matrix rvalid to verify negative isolation
        m_axi_rvalid = 1;
        m_axi_rdata  = 32'hFFFF_FFFF;
        // Drain generates dummy beat
        r_drain_rvalid = 1;
        r_drain_rid    = 4'hA;
        r_drain_rdata  = 32'h0000_0000;
        r_drain_rresp  = 2'b11; // DECERR
        r_drain_rlast  = 1;
        #1;
        check_assert(m_axi_rready == 1'b0, "CASE 6: m_axi_rready must be 0 in DRAIN mode");
        check_assert(r_drain_rready == 1'b1, "CASE 6: r_drain_rready must receive s_axi_rready");
        check_assert(s_axi_rvalid == 1'b1, "CASE 6: s_axi_rvalid must match r_drain_rvalid");
        check_assert(s_axi_rdata == 32'h0000_0000, "CASE 6: s_axi_rdata must match drain dummy data");
        check_assert(s_axi_rresp == 2'b11, "CASE 6: s_axi_rresp must be DECERR");
        check_assert(s_axi_rid == 4'hA, "CASE 6: s_axi_rid mismatch");

        s_axi_rready = 0;
        m_axi_rvalid = 0;
        r_drain_rvalid = 0;
        rd_owner = OWNER_NONE;
        #10;

        // =============================================================
        // CASE 7: MUX-10 - Simultaneous Write Denied & Read Allowed
        // =============================================================
        $display("\n[CASE 7] Test Simultaneous Operations: Write Denied & Read Allowed");
        wr_owner = OWNER_DRAIN;
        rd_owner = OWNER_ALLOW;

        s_axi_wvalid = 1;
        s_axi_wdata  = 32'h1111_2222;
        w_drain_wready = 1;

        s_axi_rready = 1;
        m_axi_rvalid = 1;
        m_axi_rdata  = 32'h3333_4444;
        #1;
        // Write checks (into drain)
        check_assert(m_axi_wvalid == 1'b0, "CASE 7: Write must not touch Matrix");
        check_assert(w_drain_wvalid == 1'b1, "CASE 7: Write must go to Drain");
        check_assert(s_axi_wready == 1'b1, "CASE 7: s_axi_wready from drain");
        // Read checks (from matrix)
        check_assert(m_axi_rready == 1'b1, "CASE 7: Read must go to Matrix");
        check_assert(r_drain_rready == 1'b0, "CASE 7: Drain must not see Read ready");
        check_assert(s_axi_rdata == 32'h3333_4444, "CASE 7: Read data from matrix");

        s_axi_wvalid = 0;
        s_axi_rready = 0;
        m_axi_rvalid = 0;
        wr_owner = OWNER_NONE;
        rd_owner = OWNER_NONE;
        #10;

        // =============================================================
        // CASE 8: MUX-08 - Backpressure Stall Stability
        // =============================================================
        $display("\n[CASE 8] Test Backpressure: Matrix stalls WREADY");
        wr_owner = OWNER_ALLOW;
        wr_aw_done = 1;
        s_axi_wvalid = 1;
        s_axi_wdata = 32'h5555_AAAA;
        m_axi_wready = 0; // Matrix backpressures!
        #1;
        check_assert(s_axi_wready == 1'b0, "CASE 8: s_axi_wready must reflect stall");
        check_assert(m_axi_wvalid == 1'b1, "CASE 8: m_axi_wvalid remains stable high");
        check_assert(m_axi_wdata == 32'h5555_AAAA, "CASE 8: m_axi_wdata must stay stable");

        // Release stall
        m_axi_wready = 1;
        #1;
        check_assert(s_axi_wready == 1'b1, "CASE 8: s_axi_wready opens when stall clears");

        s_axi_wvalid = 0;
        wr_owner = OWNER_NONE;
        wr_aw_done = 0;
        #20;

        // =============================================================
        // CASE 9: Honeypot write and response stay isolated from Matrix
        // =============================================================
        $display("\n[CASE 9] Test Honeypot Write & Response");
        wr_owner = OWNER_HONEYPOT;
        wr_aw_done = 1;
        s_axi_wvalid = 1;
        s_axi_wdata = 32'hC0DE_CAFE;
        s_axi_wstrb = 4'hF;
        s_axi_wlast = 1;
        hp_wready = 1;
        m_axi_wready = 1;
        #1;
        check_assert(hp_wvalid == 1'b1, "CASE 9: hp_wvalid must receive s_axi_wvalid");
        check_assert(hp_wdata == 32'hC0DE_CAFE, "CASE 9: hp_wdata mismatch");
        check_assert(hp_wstrb == 4'hF, "CASE 9: hp_wstrb mismatch");
        check_assert(hp_wlast == 1'b1, "CASE 9: hp_wlast mismatch");
        check_assert(s_axi_wready == 1'b1, "CASE 9: s_axi_wready must match hp_wready");
        check_assert(m_axi_wvalid == 1'b0, "CASE 9: honeypot write must not reach Matrix");
        check_assert(w_drain_wvalid == 1'b0, "CASE 9: honeypot write must not reach drain");

        hp_bvalid = 1;
        hp_bid = 4'hC;
        hp_bresp = 2'b00;
        s_axi_bready = 1;
        #1;
        check_assert(s_axi_bvalid == 1'b1, "CASE 9: s_axi_bvalid must match hp_bvalid");
        check_assert(s_axi_bid == 4'hC, "CASE 9: s_axi_bid mismatch from honeypot");
        check_assert(s_axi_bresp == 2'b00, "CASE 9: s_axi_bresp mismatch from honeypot");
        check_assert(hp_bready == 1'b1, "CASE 9: hp_bready must receive s_axi_bready");
        check_assert(m_axi_bready == 1'b0, "CASE 9: Matrix B channel must remain isolated");
        check_assert(w_drain_bready == 1'b0, "CASE 9: drain B channel must remain isolated");

        s_axi_wvalid = 0;
        hp_bvalid = 0;
        s_axi_bready = 0;
        hp_wready = 0;
        wr_owner = OWNER_NONE;
        wr_aw_done = 0;
        #10;

        // =============================================================
        // CASE 10: Honeypot read stays isolated from Matrix and drain
        // =============================================================
        $display("\n[CASE 10] Test Honeypot Read");
        rd_owner = OWNER_HONEYPOT;
        s_axi_rready = 1;
        hp_rvalid = 1;
        hp_rid = 4'hD;
        hp_rdata = 32'hA561_5EED;
        hp_rresp = 2'b00;
        hp_rlast = 1;
        m_axi_rvalid = 1;
        r_drain_rvalid = 1;
        #1;
        check_assert(hp_rready == 1'b1, "CASE 10: hp_rready must receive s_axi_rready");
        check_assert(s_axi_rvalid == 1'b1, "CASE 10: s_axi_rvalid must match hp_rvalid");
        check_assert(s_axi_rid == 4'hD, "CASE 10: s_axi_rid mismatch from honeypot");
        check_assert(s_axi_rdata == 32'hA561_5EED, "CASE 10: s_axi_rdata mismatch from honeypot");
        check_assert(s_axi_rresp == 2'b00, "CASE 10: s_axi_rresp mismatch from honeypot");
        check_assert(s_axi_rlast == 1'b1, "CASE 10: s_axi_rlast mismatch from honeypot");
        check_assert(m_axi_rready == 1'b0, "CASE 10: Matrix R channel must remain isolated");
        check_assert(r_drain_rready == 1'b0, "CASE 10: drain R channel must remain isolated");

        s_axi_rready = 0;
        hp_rvalid = 0;
        m_axi_rvalid = 0;
        r_drain_rvalid = 0;
        rd_owner = OWNER_NONE;
        #20;

        // =============================================================
        // SUMMARY REPORT
        // =============================================================
        $display("\n========================================================");
        if (errors == 0) begin
            $display("   PASS: tb_fw_data_path_mux");
            $display("   All 10 test scenarios passed with 0 errors!");
        end else begin
            $display("   FAIL: tb_fw_data_path_mux (%0d errors detected)", errors);
        end
        $display("========================================================\n");

        $finish;
    end
endmodule
