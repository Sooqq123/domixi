module fw_axi_contract_formal (
    input wire        clk,
    input wire        rst_n,

    input wire        s_axi_awvalid,
    input wire [31:0] s_axi_awaddr,
    input wire [3:0]  s_axi_awid,
    input wire [7:0]  s_axi_awlen,
    input wire [2:0]  s_axi_awsize,
    input wire [1:0]  s_axi_awburst,
    input wire [2:0]  s_axi_awprot,
    input wire        pipe_s1_awready,
    input wire        s_axi_arvalid,
    input wire [31:0] s_axi_araddr,
    input wire [3:0]  s_axi_arid,
    input wire [7:0]  s_axi_arlen,
    input wire [2:0]  s_axi_arsize,
    input wire [1:0]  s_axi_arburst,
    input wire [2:0]  s_axi_arprot,
    input wire        pipe_s1_arready,

    input wire [1:0]  wr_owner,
    input wire [1:0]  rd_owner,
    input wire        wr_aw_done,
    input wire        s_axi_wvalid,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire        s_axi_wlast,
    input wire        s_axi_bready,
    input wire        s_axi_rready,
    input wire        m_axi_wready,
    input wire [3:0]  m_axi_bid,
    input wire [1:0]  m_axi_bresp,
    input wire        m_axi_bvalid,
    input wire [3:0]  m_axi_rid,
    input wire [31:0] m_axi_rdata,
    input wire [1:0]  m_axi_rresp,
    input wire        m_axi_rlast,
    input wire        m_axi_rvalid,
    input wire        w_drain_wready,
    input wire        w_drain_bvalid,
    input wire [3:0]  w_drain_bid,
    input wire [1:0]  w_drain_bresp,
    input wire        r_drain_rvalid,
    input wire [3:0]  r_drain_rid,
    input wire [31:0] r_drain_rdata,
    input wire [1:0]  r_drain_rresp,
    input wire        r_drain_rlast,
    input wire        hp_wready,
    input wire        hp_bvalid,
    input wire [3:0]  hp_bid,
    input wire [1:0]  hp_bresp,
    input wire        hp_rvalid,
    input wire [3:0]  hp_rid,
    input wire [31:0] hp_rdata,
    input wire [1:0]  hp_rresp,
    input wire        hp_rlast
);

    localparam [1:0] OWNER_NONE     = 2'b00;
    localparam [1:0] OWNER_ALLOW    = 2'b01;
    localparam [1:0] OWNER_DRAIN    = 2'b10;
    localparam [1:0] OWNER_HONEYPOT = 2'b11;

    wire        s_axi_awready;
    wire        s_axi_arready;
    wire        pipe_s1_awvalid;
    wire [31:0] pipe_s1_awend;
    wire [31:0] pipe_s1_awaddr;
    wire [3:0]  pipe_s1_awid;
    wire [7:0]  pipe_s1_awlen;
    wire [2:0]  pipe_s1_awsize;
    wire [1:0]  pipe_s1_awburst;
    wire [2:0]  pipe_s1_awprot;
    wire        pipe_s1_aw_profile_err;
    wire        pipe_s1_aw_overflow_err;
    wire        pipe_s1_aw_4kb_err;
    wire        pipe_s1_arvalid;
    wire [31:0] pipe_s1_araddr;
    wire [31:0] pipe_s1_arend;
    wire [3:0]  pipe_s1_arid;
    wire [7:0]  pipe_s1_arlen;
    wire [2:0]  pipe_s1_arsize;
    wire [1:0]  pipe_s1_arburst;
    wire [2:0]  pipe_s1_arprot;
    wire        pipe_s1_ar_profile_err;
    wire        pipe_s1_ar_overflow_err;
    wire        pipe_s1_ar_4kb_err;

    fw_axi_address_slice u_slice (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .s_axi_awvalid         (s_axi_awvalid),
        .s_axi_awaddr          (s_axi_awaddr),
        .s_axi_awid            (s_axi_awid),
        .s_axi_awlen           (s_axi_awlen),
        .s_axi_awsize          (s_axi_awsize),
        .s_axi_awburst         (s_axi_awburst),
        .s_axi_awprot          (s_axi_awprot),
        .s_axi_awready         (s_axi_awready),
        .pipe_s1_awvalid       (pipe_s1_awvalid),
        .pipe_s1_awend         (pipe_s1_awend),
        .pipe_s1_awaddr        (pipe_s1_awaddr),
        .pipe_s1_awid          (pipe_s1_awid),
        .pipe_s1_awlen         (pipe_s1_awlen),
        .pipe_s1_awsize        (pipe_s1_awsize),
        .pipe_s1_awburst       (pipe_s1_awburst),
        .pipe_s1_awprot        (pipe_s1_awprot),
        .pipe_s1_aw_profile_err(pipe_s1_aw_profile_err),
        .pipe_s1_aw_overflow_err(pipe_s1_aw_overflow_err),
        .pipe_s1_aw_4kb_err    (pipe_s1_aw_4kb_err),
        .pipe_s1_awready       (pipe_s1_awready),
        .s_axi_arvalid         (s_axi_arvalid),
        .s_axi_araddr          (s_axi_araddr),
        .s_axi_arid            (s_axi_arid),
        .s_axi_arlen           (s_axi_arlen),
        .s_axi_arsize          (s_axi_arsize),
        .s_axi_arburst         (s_axi_arburst),
        .s_axi_arprot          (s_axi_arprot),
        .s_axi_arready         (s_axi_arready),
        .pipe_s1_arvalid       (pipe_s1_arvalid),
        .pipe_s1_araddr        (pipe_s1_araddr),
        .pipe_s1_arend         (pipe_s1_arend),
        .pipe_s1_arid          (pipe_s1_arid),
        .pipe_s1_arlen         (pipe_s1_arlen),
        .pipe_s1_arsize        (pipe_s1_arsize),
        .pipe_s1_arburst       (pipe_s1_arburst),
        .pipe_s1_arprot        (pipe_s1_arprot),
        .pipe_s1_ar_profile_err(pipe_s1_ar_profile_err),
        .pipe_s1_ar_overflow_err(pipe_s1_ar_overflow_err),
        .pipe_s1_ar_4kb_err    (pipe_s1_ar_4kb_err),
        .pipe_s1_arready       (pipe_s1_arready)
    );

    wire        s_axi_wready;
    wire [3:0]  s_axi_bid;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    wire [3:0]  s_axi_rid;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rlast;
    wire        s_axi_rvalid;
    wire        m_axi_wvalid;
    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_bready;
    wire        m_axi_rready;
    wire        w_drain_wvalid;
    wire        w_drain_wlast;
    wire        w_drain_bready;
    wire        r_drain_rready;
    wire        hp_wvalid;
    wire [31:0] hp_wdata;
    wire [3:0]  hp_wstrb;
    wire        hp_wlast;
    wire        hp_bready;
    wire        hp_rready;

    fw_data_path_mux u_mux (
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_owner       (wr_owner),
        .rd_owner       (rd_owner),
        .wr_aw_done     (wr_aw_done),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bid      (s_axi_bid),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_rid      (s_axi_rid),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bid      (m_axi_bid),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_rid      (m_axi_rid),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .w_drain_wvalid(w_drain_wvalid),
        .w_drain_wlast (w_drain_wlast),
        .w_drain_wready(w_drain_wready),
        .w_drain_bvalid(w_drain_bvalid),
        .w_drain_bid   (w_drain_bid),
        .w_drain_bresp (w_drain_bresp),
        .w_drain_bready(w_drain_bready),
        .r_drain_rready(r_drain_rready),
        .r_drain_rvalid(r_drain_rvalid),
        .r_drain_rid   (r_drain_rid),
        .r_drain_rdata (r_drain_rdata),
        .r_drain_rresp (r_drain_rresp),
        .r_drain_rlast (r_drain_rlast),
        .hp_wvalid     (hp_wvalid),
        .hp_wdata      (hp_wdata),
        .hp_wstrb      (hp_wstrb),
        .hp_wlast      (hp_wlast),
        .hp_wready     (hp_wready),
        .hp_bvalid     (hp_bvalid),
        .hp_bid        (hp_bid),
        .hp_bresp      (hp_bresp),
        .hp_bready     (hp_bready),
        .hp_rready     (hp_rready),
        .hp_rvalid     (hp_rvalid),
        .hp_rid        (hp_rid),
        .hp_rdata      (hp_rdata),
        .hp_rresp      (hp_rresp),
        .hp_rlast      (hp_rlast)
    );

    // Reset is held for two cycles so all assertions start from a known state.
    reg [2:0] reset_counter = 3'd0;
    always @(posedge clk) begin
        if (reset_counter < 3'd3)
            reset_counter <= reset_counter + 1'b1;
    end

    always @(*) begin
        if (reset_counter < 3'd2)
            assume(!rst_n);
        else
            assume(rst_n);
    end

    wire [87:0] aw_bundle = {
        pipe_s1_awvalid, pipe_s1_awend, pipe_s1_awaddr, pipe_s1_awid,
        pipe_s1_awlen, pipe_s1_awsize, pipe_s1_awburst, pipe_s1_awprot,
        pipe_s1_aw_profile_err, pipe_s1_aw_overflow_err, pipe_s1_aw_4kb_err
    };
    wire [87:0] ar_bundle = {
        pipe_s1_arvalid, pipe_s1_arend, pipe_s1_araddr, pipe_s1_arid,
        pipe_s1_arlen, pipe_s1_arsize, pipe_s1_arburst, pipe_s1_arprot,
        pipe_s1_ar_profile_err, pipe_s1_ar_overflow_err, pipe_s1_ar_4kb_err
    };
    reg        aw_hold_q;
    reg [87:0] aw_bundle_q;
    reg        ar_hold_q;
    reg [87:0] ar_bundle_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            aw_hold_q <= 1'b0;
            ar_hold_q <= 1'b0;
            aw_bundle_q <= 88'd0;
            ar_bundle_q <= 88'd0;
        end else begin
            if (aw_hold_q)
                assert(aw_bundle == aw_bundle_q);
            if (ar_hold_q)
                assert(ar_bundle == ar_bundle_q);

            aw_hold_q <= pipe_s1_awvalid && !pipe_s1_awready;
            ar_hold_q <= pipe_s1_arvalid && !pipe_s1_arready;
            if (pipe_s1_awvalid && !pipe_s1_awready)
                aw_bundle_q <= aw_bundle;
            if (pipe_s1_arvalid && !pipe_s1_arready)
                ar_bundle_q <= ar_bundle;
        end
    end

    // DRAIN and HONEYPOT are never allowed to reach protected memory.
    always @(*) begin
        if ((wr_owner != OWNER_ALLOW) || !wr_aw_done)
            assert(!m_axi_wvalid);
        if (wr_owner != OWNER_ALLOW)
            assert(!m_axi_bready);
        if (rd_owner != OWNER_ALLOW)
            assert(!m_axi_rready);
        if (wr_owner == OWNER_NONE)
            assert(!s_axi_wready && !s_axi_bvalid);
        if (rd_owner == OWNER_NONE)
            assert(!s_axi_rvalid);
    end

    // AXI source-hold assumptions and mux output stability under backpressure.
    wire [37:0] m_b_bundle = {m_axi_bvalid, m_axi_bid, m_axi_bresp};
    wire [37:0] d_b_bundle = {w_drain_bvalid, w_drain_bid, w_drain_bresp};
    wire [37:0] h_b_bundle = {hp_bvalid, hp_bid, hp_bresp};
    wire [69:0] m_r_bundle = {m_axi_rvalid, m_axi_rid, m_axi_rdata, m_axi_rresp, m_axi_rlast};
    wire [69:0] d_r_bundle = {r_drain_rvalid, r_drain_rid, r_drain_rdata, r_drain_rresp, r_drain_rlast};
    wire [69:0] h_r_bundle = {hp_rvalid, hp_rid, hp_rdata, hp_rresp, hp_rlast};
    wire [37:0] s_b_bundle = {s_axi_bvalid, s_axi_bid, s_axi_bresp};
    wire [69:0] s_r_bundle = {s_axi_rvalid, s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast};
    reg        b_hold_q;
    reg [1:0]  b_owner_q;
    reg [37:0] b_bundle_q;
    reg        r_hold_q;
    reg [1:0]  r_owner_q;
    reg [69:0] r_bundle_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            b_hold_q <= 1'b0;
            b_owner_q <= OWNER_NONE;
            b_bundle_q <= 38'd0;
            r_hold_q <= 1'b0;
            r_owner_q <= OWNER_NONE;
            r_bundle_q <= 70'd0;
        end else begin
            if (b_hold_q) begin
                assume(wr_owner == b_owner_q);
                case (b_owner_q)
                    OWNER_ALLOW: assume(m_b_bundle == b_bundle_q);
                    OWNER_DRAIN: assume(d_b_bundle == b_bundle_q);
                    OWNER_HONEYPOT: assume(h_b_bundle == b_bundle_q);
                    default: begin end
                endcase
                assert(s_b_bundle == b_bundle_q);
            end
            if (r_hold_q) begin
                assume(rd_owner == r_owner_q);
                case (r_owner_q)
                    OWNER_ALLOW: assume(m_r_bundle == r_bundle_q);
                    OWNER_DRAIN: assume(d_r_bundle == r_bundle_q);
                    OWNER_HONEYPOT: assume(h_r_bundle == r_bundle_q);
                    default: begin end
                endcase
                assert(s_r_bundle == r_bundle_q);
            end

            b_hold_q <= s_axi_bvalid && !s_axi_bready;
            r_hold_q <= s_axi_rvalid && !s_axi_rready;
            b_owner_q <= wr_owner;
            r_owner_q <= rd_owner;
            if (s_axi_bvalid && !s_axi_bready) begin
                case (wr_owner)
                    OWNER_ALLOW: b_bundle_q <= m_b_bundle;
                    OWNER_DRAIN: b_bundle_q <= d_b_bundle;
                    OWNER_HONEYPOT: b_bundle_q <= h_b_bundle;
                    default: b_bundle_q <= s_b_bundle;
                endcase
            end
            if (s_axi_rvalid && !s_axi_rready) begin
                case (rd_owner)
                    OWNER_ALLOW: r_bundle_q <= m_r_bundle;
                    OWNER_DRAIN: r_bundle_q <= d_r_bundle;
                    OWNER_HONEYPOT: r_bundle_q <= h_r_bundle;
                    default: r_bundle_q <= s_r_bundle;
                endcase
            end
        end
    end

endmodule
