`timescale 1ns/1ps

// ==============================================================================
// Module: dma_bus_firewall
// Description: Production Top-Level DMA-Aware Bus Firewall IP
// Current backend target. The SDC/source manifest are derived from the 94
// declared ports in this module; resolve any external canonical-pin mismatch
// before using this interface for full-SoC signoff.
// ==============================================================================

module dma_bus_firewall (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        test_mode,

    // APB4 Control & Status Interface
    input  wire [31:0] s_apb_paddr,
    input  wire        s_apb_psel,
    input  wire        s_apb_penable,
    input  wire        s_apb_pwrite,
    input  wire [31:0] s_apb_pwdata,
    input  wire [2:0]  s_apb_pprot,
    output wire [31:0] s_apb_prdata,
    output wire        s_apb_pready,
    output wire        s_apb_pslverr,

    // DMA Controller Dedicated Sideband Interface & Security IRQ
    input  wire        dma_ctx_valid,
    input  wire [31:0] dma_ctx_src_addr,
    input  wire [31:0] dma_ctx_dst_addr,
    input  wire [31:0] dma_ctx_byte_len,
    input  wire        dma_ctx_done,
    output wire        sec_irq,

    // AEGIS-RISC Bio-Inspired Immune Sideband & Telemetry
    input  wire        cpu_telemetry_trap,
    input  wire        cpu_telemetry_stall,
    output wire        aegis_nmi_irq,
    output wire        aegis_anomaly_alert,
    output wire [1:0]  aegis_threat_level,
    output wire        aegis_honey_hit,

    // Upstream AXI4 Slave Interface (from DMA Controller Core)
    // Write Address Channel
    input  wire [3:0]  s_axi_awid,
    input  wire [31:0] s_axi_awaddr,
    input  wire [7:0]  s_axi_awlen,
    input  wire [2:0]  s_axi_awsize,
    input  wire [1:0]  s_axi_awburst,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    // Write Data Channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wlast,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    // Write Response Channel
    output wire [3:0]  s_axi_bid,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    // Read Address Channel
    input  wire [3:0]  s_axi_arid,
    input  wire [31:0] s_axi_araddr,
    input  wire [7:0]  s_axi_arlen,
    input  wire [2:0]  s_axi_arsize,
    input  wire [1:0]  s_axi_arburst,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    // Read Data Channel
    output wire [3:0]  s_axi_rid,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rlast,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Downstream AXI4 Master Interface (to System Interconnect Matrix)
    // Write Address Channel
    output reg  [3:0]  m_axi_awid,
    output reg  [31:0] m_axi_awaddr,
    output reg  [7:0]  m_axi_awlen,
    output reg  [2:0]  m_axi_awsize,
    output reg  [1:0]  m_axi_awburst,
    output reg  [2:0]  m_axi_awprot,
    output wire [3:0]  m_axi_awcache,
    output wire        m_axi_awlock,
    output wire [3:0]  m_axi_awqos,
    output wire [3:0]  m_axi_awregion,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    // Write Data Channel
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    // Write Response Channel
    input  wire [3:0]  m_axi_bid,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    // Read Address Channel
    output reg  [3:0]  m_axi_arid,
    output reg  [31:0] m_axi_araddr,
    output reg  [7:0]  m_axi_arlen,
    output reg  [2:0]  m_axi_arsize,
    output reg  [1:0]  m_axi_arburst,
    output reg  [2:0]  m_axi_arprot,
    output wire [3:0]  m_axi_arcache,
    output wire        m_axi_arlock,
    output wire [3:0]  m_axi_arqos,
    output wire [3:0]  m_axi_arregion,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    // Read Data Channel
    input  wire [3:0]  m_axi_rid,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready
);

    // =========================================================================
    // Reset Synchronizer: Asynchronous assert, synchronous deassert
    // In test_mode (scan test), bypass synchronizer to allow direct reset control
    // =========================================================================
    reg rst_n_sync1;
    reg rst_n_sync2;
    wire rst_n_synced = test_mode ? rst_n : rst_n_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_n_sync1 <= 1'b0;
            rst_n_sync2 <= 1'b0;
        end else begin
            rst_n_sync1 <= 1'b1;
            rst_n_sync2 <= rst_n_sync1;
        end
    end

    // =========================================================================
    // 1. Constant Tie-Offs on Downstream Master Interface
    // =========================================================================
    assign m_axi_awcache  = 4'b0000;
    assign m_axi_awlock   = 1'b0;
    assign m_axi_awqos    = 4'b0000;
    assign m_axi_awregion = 4'b0000;

    assign m_axi_arcache  = 4'b0000;
    assign m_axi_arlock   = 1'b0;
    assign m_axi_arqos    = 4'b0000;
    assign m_axi_arregion = 4'b0000;

    // Owner Encoding
    localparam [1:0] OWNER_NONE     = 2'b00;
    localparam [1:0] OWNER_ALLOW    = 2'b01;
    localparam [1:0] OWNER_DRAIN    = 2'b10;
    localparam [1:0] OWNER_HONEYPOT = 2'b11;

    // Owner tracking registers
    reg [1:0] wr_owner;
    reg [1:0] rd_owner;
    reg       wr_aw_done;

    // =========================================================================
    // 2. Stage 1: Address Pipeline Slice
    // =========================================================================
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
    reg         pipe_s1_awready;

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
    reg         pipe_s1_arready;

    fw_axi_address_slice u_address_slice (
        .clk                    (clk),
        .rst_n                  (rst_n_synced),
        .s_axi_awvalid          (s_axi_awvalid),
        .s_axi_awaddr           (s_axi_awaddr),
        .s_axi_awid             (s_axi_awid),
        .s_axi_awlen            (s_axi_awlen),
        .s_axi_awsize           (s_axi_awsize),
        .s_axi_awburst          (s_axi_awburst),
        .s_axi_awprot           (s_axi_awprot),
        .s_axi_awready          (s_axi_awready),
        .pipe_s1_awvalid        (pipe_s1_awvalid),
        .pipe_s1_awend          (pipe_s1_awend),
        .pipe_s1_awaddr         (pipe_s1_awaddr),
        .pipe_s1_awid           (pipe_s1_awid),
        .pipe_s1_awlen          (pipe_s1_awlen),
        .pipe_s1_awsize         (pipe_s1_awsize),
        .pipe_s1_awburst        (pipe_s1_awburst),
        .pipe_s1_awprot         (pipe_s1_awprot),
        .pipe_s1_aw_profile_err (pipe_s1_aw_profile_err),
        .pipe_s1_aw_overflow_err(pipe_s1_aw_overflow_err),
        .pipe_s1_aw_4kb_err     (pipe_s1_aw_4kb_err),
        .pipe_s1_awready        (pipe_s1_awready),
        .s_axi_arvalid          (s_axi_arvalid),
        .s_axi_araddr           (s_axi_araddr),
        .s_axi_arid             (s_axi_arid),
        .s_axi_arlen            (s_axi_arlen),
        .s_axi_arsize           (s_axi_arsize),
        .s_axi_arburst          (s_axi_arburst),
        .s_axi_arprot           (s_axi_arprot),
        .s_axi_arready          (s_axi_arready),
        .pipe_s1_arvalid        (pipe_s1_arvalid),
        .pipe_s1_araddr         (pipe_s1_araddr),
        .pipe_s1_arend          (pipe_s1_arend),
        .pipe_s1_arid           (pipe_s1_arid),
        .pipe_s1_arlen          (pipe_s1_arlen),
        .pipe_s1_arsize         (pipe_s1_arsize),
        .pipe_s1_arburst        (pipe_s1_arburst),
        .pipe_s1_arprot         (pipe_s1_arprot),
        .pipe_s1_ar_profile_err (pipe_s1_ar_profile_err),
        .pipe_s1_ar_overflow_err(pipe_s1_ar_overflow_err),
        .pipe_s1_ar_4kb_err     (pipe_s1_ar_4kb_err),
        .pipe_s1_arready        (pipe_s1_arready)
    );

    // =========================================================================
    // 3. Dynamic Context Tracker
    // =========================================================================
    wire [31:0] dyn_rgn4_base;
    wire [31:0] dyn_rgn4_limit;
    wire        dyn_rgn4_active;
    wire [31:0] dyn_rgn5_base;
    wire [31:0] dyn_rgn5_limit;
    wire        dyn_rgn5_active;
    wire        ctx_fault_event_valid;
    wire [3:0]  ctx_fault_event_code;
    wire [31:0] ctx_fault_event_addr;
    wire [3:0]  ctx_fault_event_id;
    wire        auto_ctx_en;

    fw_context_tracker u_context_tracker (
        .clk                  (clk),
        .rst_n                (rst_n_synced),
        .dma_ctx_valid        (dma_ctx_valid),
        .dma_ctx_src_addr     (dma_ctx_src_addr),
        .dma_ctx_dst_addr     (dma_ctx_dst_addr),
        .dma_ctx_byte_len     (dma_ctx_byte_len),
        .dma_ctx_done         (dma_ctx_done),
        .auto_ctx_en          (auto_ctx_en),
        .dyn_rgn4_base        (dyn_rgn4_base),
        .dyn_rgn4_limit       (dyn_rgn4_limit),
        .dyn_rgn4_active      (dyn_rgn4_active),
        .dyn_rgn5_base        (dyn_rgn5_base),
        .dyn_rgn5_limit       (dyn_rgn5_limit),
        .dyn_rgn5_active      (dyn_rgn5_active),
        .ctx_fault_event_valid(ctx_fault_event_valid),
        .ctx_fault_event_code (ctx_fault_event_code),
        .ctx_fault_event_addr (ctx_fault_event_addr),
        .ctx_fault_event_id   (ctx_fault_event_id)
    );

    // =========================================================================
    // 4. APB4 Register Bank & Fault Logger
    // =========================================================================
    // Immutable write-owner & read-owner tracking registers (declared before use)
    reg [31:0] denied_awaddr;
    reg [3:0]  denied_awid;
    reg [7:0]  denied_awlen;
    reg [2:0]  denied_awsize;
    reg [3:0]  acl_r_id;
    reg [7:0]  acl_r_len;

    wire        fw_en;
    wire        irq_en;
    wire        err_mode;

    reg         w_fault_event_valid;
    reg  [3:0]  w_fault_event_code;
    wire [31:0] w_fault_event_addr = denied_awaddr;
    wire [3:0]  w_fault_event_id   = denied_awid;
    wire [7:0]  w_fault_event_len  = denied_awlen;
    wire [2:0]  w_fault_event_size = denied_awsize;

    reg         r_fault_event_valid;
    reg  [3:0]  r_fault_event_code;
    reg  [31:0] r_fault_event_addr;
    wire [3:0]  r_fault_event_id   = acl_r_id;
    wire [7:0]  r_fault_event_len  = acl_r_len;
    reg  [2:0]  r_fault_event_size;

    wire [255:0]     rgn_base;
    wire [255:0]     rgn_limit;
    wire [31:0]      reg_aegis_status;
    wire [31:0]      reg_aegis_fingerprint;
    wire [31:0]      reg_aegis_honey_count;
    wire [31:0]      reg_aegis_caps;
    wire [31:0]      reg_aegis_event_meta;
    wire [31:0]      reg_aegis_event_addr;
    wire [31:0]      reg_aegis_event_time;
    wire [31:0]      reg_aegis_event_ctrl;
    wire             aegis_fifo_pop_pulse;
    wire             aegis_clear_overflow_pulse;
    wire             aegis_irq_ack_pulse;
    wire             aegis_unquarantine_pulse;
    wire [3:0]       aegis_unquarantine_mid;
    wire             fifo_overflow_containment;
    wire             hdc_busy;
    wire             hdc_telemetry_overrun;
    wire [1:0]       mtd_trans_action;
    wire             mtd_rate_limit_stall;
    wire [15:0]      mtd_active_key;
    wire [15:0]      mtd_scrambler_state;
    wire [15:0]      aegis_quarantine_mask;
    wire [31:0]      aegis_attack_fingerprint;
    wire [31:0]      mtd_morph_addr;
    wire             mtd_honey_hit;
    wire             mtd_jitter_active;
    wire             mtd_force_drain;
    wire [7:0]       rgn_active;
    wire [7:0]       rgn_read;
    wire [7:0]       rgn_write;
    wire [7:0]       rgn_secure;
    wire [7:0]       rgn_priv;
    wire [31:0]      rgn_mid;
    wire [31:0]      rgn_mask;

    // Honey-Pot AXI Sink Interface Signals
    reg              hp_awvalid;
    wire             hp_awready;
    reg  [3:0]       hp_awid;
    reg  [31:0]      hp_awaddr;
    reg  [7:0]       hp_awlen;
    reg  [2:0]       hp_awsize;
    reg  [1:0]       hp_awburst;

    wire             hp_wvalid;
    wire             hp_wready;
    wire [31:0]      hp_wdata;
    wire [3:0]       hp_wstrb;
    wire             hp_wlast;

    wire             hp_bvalid;
    wire             hp_bready;
    wire [3:0]       hp_bid;
    wire [1:0]       hp_bresp;

    reg              hp_arvalid;
    wire             hp_arready;
    reg  [3:0]       hp_arid;
    reg  [31:0]      hp_araddr;
    reg  [7:0]       hp_arlen;
    reg  [2:0]       hp_arsize;
    reg  [1:0]       hp_arburst;

    wire             hp_rvalid;
    wire             hp_rready;
    wire [3:0]       hp_rid;
    wire [31:0]      hp_rdata;
    wire [1:0]       hp_rresp;
    wire             hp_rlast;

    wire [15:0]      hp_scrambler_state;
    wire [31:0]      hp_honey_count;
    wire             hp_sink_busy;
    wire             hp_wlast_err;

    fw_apb_regs u_apb_regs (
        .clk                        (clk),
        .rst_n                      (rst_n_synced),
        .s_apb_paddr                (s_apb_paddr),
        .s_apb_psel                 (s_apb_psel),
        .s_apb_penable              (s_apb_penable),
        .s_apb_pwrite               (s_apb_pwrite),
        .s_apb_pwdata               (s_apb_pwdata),
        .s_apb_pprot                (s_apb_pprot),
        .s_apb_prdata               (s_apb_prdata),
        .s_apb_pready               (s_apb_pready),
        .s_apb_pslverr              (s_apb_pslverr),
        .fw_en                      (fw_en),
        .irq_en                     (irq_en),
        .auto_ctx_en                (auto_ctx_en),
        .err_mode                   (err_mode),
        .sec_irq                    (sec_irq),
        .w_fault_event_valid        (w_fault_event_valid),
        .w_fault_event_code         (w_fault_event_code),
        .w_fault_event_addr         (w_fault_event_addr),
        .w_fault_event_id           (w_fault_event_id),
        .w_fault_event_len          (w_fault_event_len),
        .w_fault_event_size         (w_fault_event_size),
        .r_fault_event_valid        (r_fault_event_valid),
        .r_fault_event_code         (r_fault_event_code),
        .r_fault_event_addr         (r_fault_event_addr),
        .r_fault_event_id           (r_fault_event_id),
        .r_fault_event_len          (r_fault_event_len),
        .r_fault_event_size         (r_fault_event_size),
        .ctx_fault_event_valid      (ctx_fault_event_valid),
        .ctx_fault_event_code       (ctx_fault_event_code),
        .ctx_fault_event_addr       (ctx_fault_event_addr),
        .ctx_fault_event_id         (ctx_fault_event_id),
        .dyn_rgn4_base              (dyn_rgn4_base),
        .dyn_rgn4_limit             (dyn_rgn4_limit),
        .dyn_rgn4_active            (dyn_rgn4_active),
        .dyn_rgn5_base              (dyn_rgn5_base),
        .dyn_rgn5_limit             (dyn_rgn5_limit),
        .dyn_rgn5_active            (dyn_rgn5_active),
        .rgn_base                   (rgn_base),
        .rgn_limit                  (rgn_limit),
        .rgn_active                 (rgn_active),
        .rgn_read                   (rgn_read),
        .rgn_write                  (rgn_write),
        .rgn_secure                 (rgn_secure),
        .rgn_priv                   (rgn_priv),
        .rgn_mid                    (rgn_mid),
        .rgn_mask                   (rgn_mask),
        .reg_aegis_status_in        (reg_aegis_status),
        .reg_aegis_fingerprint_in   (reg_aegis_fingerprint),
        .reg_aegis_honey_count_in   (hp_honey_count),
        .reg_aegis_caps_in          (reg_aegis_caps),
        .reg_aegis_event_meta_in    (reg_aegis_event_meta),
        .reg_aegis_event_addr_in    (reg_aegis_event_addr),
        .reg_aegis_event_time_in    (reg_aegis_event_time),
        .reg_aegis_event_ctrl_in    (reg_aegis_event_ctrl),
        .aegis_fifo_pop_pulse       (aegis_fifo_pop_pulse),
        .aegis_clear_overflow_pulse (aegis_clear_overflow_pulse),
        .aegis_irq_ack_pulse        (aegis_irq_ack_pulse),
        .aegis_unquarantine_pulse   (aegis_unquarantine_pulse),
        .aegis_unquarantine_mid     (aegis_unquarantine_mid)
    );

    // =========================================================================
    // 5. Stage 2: Parallel ACL Matcher
    // =========================================================================
    reg         req_valid;
    wire        req_ready;
    reg         req_is_write;
    reg  [31:0] req_start;
    reg  [7:0]  req_len;
    reg  [2:0]  req_size;
    reg  [3:0]  req_id;
    reg  [2:0]  req_prot;
    reg         req_profile_err;
    reg         req_overflow_err;
    reg         req_4kb_err;

    wire        decision_valid;
    wire [3:0]  decision_allow;
    wire [3:0]  decision_fault_code;
    wire [3:0]  decision_id;
    wire [7:0]  decision_len;
    wire        decision_err_mode;

    fw_acl_matcher #(
        .REGION_COUNT(8),
        .ID_WIDTH(4)
    ) u_acl_matcher (
        .clk                (clk),
        .rst_n              (rst_n_synced),
        .req_valid          (req_valid),
        .req_ready          (req_ready),
        .req_is_write       (req_is_write),
        .req_start          (req_start),
        .req_len            (req_len),
        .req_size           (req_size),
        .req_id             (req_id),
        .req_prot           (req_prot),
        .req_profile_err    (req_profile_err),
        .req_overflow_err   (req_overflow_err),
        .req_4kb_err        (req_4kb_err),
        .fw_en              (fw_en),
        .err_mode           (err_mode),
        .rgn_base           (rgn_base),
        .rgn_limit          (rgn_limit),
        .rgn_active         (rgn_active),
        .rgn_read           (rgn_read),
        .rgn_write          (rgn_write),
        .rgn_secure         (rgn_secure),
        .rgn_priv           (rgn_priv),
        .rgn_mid            (rgn_mid),
        .rgn_mask           (rgn_mask),
        .decision_valid     (decision_valid),
        .decision_ready     (1'b1), // Top immediately processes decision
        .decision_allow     (decision_allow),
        .decision_fault_code(decision_fault_code),
        .decision_id        (decision_id),
        .decision_len       (decision_len),
        .decision_err_mode  (decision_err_mode)
    );

    // =========================================================================
    // 6. Protocol Drain FSM (Write & Read Drain Wrapper)
    // =========================================================================
    reg         acl_w_fault;
    wire [3:0]  acl_w_id  = denied_awid;
    wire [7:0]  acl_w_len = denied_awlen;
    reg         acl_w_err_mode;
    wire        w_drain_wvalid;
    wire        w_drain_wlast;
    wire        w_drain_wready;
    wire        w_drain_bvalid;
    wire [3:0]  w_drain_bid;
    wire [1:0]  w_drain_bresp;
    wire        w_drain_bready;
    wire        w_framing_fault_valid;
    wire [3:0]  w_framing_fault_code;

    reg         acl_r_fault;
    reg         acl_r_err_mode;
    wire        r_drain_rvalid;
    wire        r_drain_rready;
    wire [3:0]  r_drain_rid;
    wire [31:0] r_drain_rdata;
    wire [1:0]  r_drain_rresp;
    wire        r_drain_rlast;

    fw_drain_fsm u_drain_fsm (
        .clk                  (clk),
        .rst_n                (rst_n_synced),
        .acl_w_fault          (acl_w_fault),
        .acl_w_id             (acl_w_id),
        .acl_w_len            (acl_w_len),
        .acl_w_err_mode       (acl_w_err_mode),
        .w_drain_wvalid       (w_drain_wvalid),
        .w_drain_wlast        (w_drain_wlast),
        .w_drain_wready       (w_drain_wready),
        .w_drain_bvalid       (w_drain_bvalid),
        .w_drain_bid          (w_drain_bid),
        .w_drain_bresp        (w_drain_bresp),
        .w_drain_bready       (w_drain_bready),
        .w_framing_fault_valid(w_framing_fault_valid),
        .w_framing_fault_code (w_framing_fault_code),
        .acl_r_fault          (acl_r_fault),
        .acl_r_id             (acl_r_id),
        .acl_r_len            (acl_r_len),
        .acl_r_err_mode       (acl_r_err_mode),
        .r_drain_rvalid       (r_drain_rvalid),
        .r_drain_rready       (r_drain_rready),
        .r_drain_rid          (r_drain_rid),
        .r_drain_rdata        (r_drain_rdata),
        .r_drain_rresp        (r_drain_rresp),
        .r_drain_rlast        (r_drain_rlast)
    );

    // =========================================================================
    // 7. Cut-Through Data Path Mux
    // =========================================================================
    fw_data_path_mux #(
        .ID_WIDTH(4),
        .DATA_WIDTH(32)
    ) u_data_path_mux (
        .clk           (clk),
        .rst_n         (rst_n_synced),
        .wr_owner      (wr_owner),
        .rd_owner      (rd_owner),
        .wr_aw_done    (wr_aw_done),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wlast   (s_axi_wlast),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bid     (s_axi_bid),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_rid     (s_axi_rid),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rlast   (s_axi_rlast),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bid     (m_axi_bid),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_rid     (m_axi_rid),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
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

    // =========================================================================
    // 8. Matcher Scheduling & Arbitration Logic
    // =========================================================================
    reg matcher_inflight_valid;
    reg matcher_inflight_is_write;
    reg [31:0] matcher_inflight_addr;
    reg [2:0]  matcher_inflight_size;
    reg arb_priority_write;

    // Immutable write-owner metadata (held from denied decision to B handshake, declared above)

    wire can_issue_write = pipe_s1_awvalid && (wr_owner == OWNER_NONE) &&
                           (!matcher_inflight_valid) && !mtd_rate_limit_stall;
    wire can_issue_read  = pipe_s1_arvalid && (rd_owner == OWNER_NONE) &&
                           (!matcher_inflight_valid) && !mtd_rate_limit_stall;

    always @(*) begin
        req_valid        = 1'b0;
        req_is_write     = 1'b0;
        req_start        = 32'h0;
        req_len          = 8'h0;
        req_size         = 3'b010;
        req_id           = 4'h0;
        req_prot         = 3'b001;
        req_profile_err  = 1'b0;
        req_overflow_err = 1'b0;
        req_4kb_err      = 1'b0;
        pipe_s1_awready  = 1'b0;
        pipe_s1_arready  = 1'b0;

        if (can_issue_write && can_issue_read) begin
            if (arb_priority_write) begin
                req_valid        = 1'b1;
                req_is_write     = 1'b1;
                req_start        = pipe_s1_awaddr;
                req_len          = pipe_s1_awlen;
                req_size         = pipe_s1_awsize;
                req_id           = pipe_s1_awid;
                req_prot         = pipe_s1_awprot;
                req_profile_err  = pipe_s1_aw_profile_err;
                req_overflow_err = pipe_s1_aw_overflow_err;
                req_4kb_err      = pipe_s1_aw_4kb_err;
                pipe_s1_awready  = req_ready;
            end else begin
                req_valid        = 1'b1;
                req_is_write     = 1'b0;
                req_start        = pipe_s1_araddr;
                req_len          = pipe_s1_arlen;
                req_size         = pipe_s1_arsize;
                req_id           = pipe_s1_arid;
                req_prot         = pipe_s1_arprot;
                req_profile_err  = pipe_s1_ar_profile_err;
                req_overflow_err = pipe_s1_ar_overflow_err;
                req_4kb_err      = pipe_s1_ar_4kb_err;
                pipe_s1_arready  = req_ready;
            end
        end else if (can_issue_write) begin
            req_valid        = 1'b1;
            req_is_write     = 1'b1;
            req_start        = pipe_s1_awaddr;
            req_len          = pipe_s1_awlen;
            req_size         = pipe_s1_awsize;
            req_id           = pipe_s1_awid;
            req_prot         = pipe_s1_awprot;
            req_profile_err  = pipe_s1_aw_profile_err;
            req_overflow_err = pipe_s1_aw_overflow_err;
            req_4kb_err      = pipe_s1_aw_4kb_err;
            pipe_s1_awready  = req_ready;
        end else if (can_issue_read) begin
            req_valid        = 1'b1;
            req_is_write     = 1'b0;
            req_start        = pipe_s1_araddr;
            req_len          = pipe_s1_arlen;
            req_size         = pipe_s1_arsize;
            req_id           = pipe_s1_arid;
            req_prot         = pipe_s1_arprot;
            req_profile_err  = pipe_s1_ar_profile_err;
            req_overflow_err = pipe_s1_ar_overflow_err;
            req_4kb_err      = pipe_s1_ar_4kb_err;
            pipe_s1_arready  = req_ready;
        end
    end

    // Handshakes on responses
    wire b_terminal = s_axi_bvalid && s_axi_bready;
    wire r_terminal = s_axi_rvalid && s_axi_rready && s_axi_rlast;

    // =========================================================================
    // 9. Main Orchestration & Owner FSM Sequential Block
    // =========================================================================
    always @(posedge clk or negedge rst_n_synced) begin
        if (!rst_n_synced) begin
            wr_owner               <= OWNER_NONE;
            rd_owner               <= OWNER_NONE;
            wr_aw_done             <= 1'b0;
            matcher_inflight_valid <= 1'b0;
            matcher_inflight_is_write <= 1'b0;
            matcher_inflight_addr  <= 32'h0;
            matcher_inflight_size  <= 3'b010;
            arb_priority_write     <= 1'b1;

            m_axi_awvalid <= 1'b0;
            m_axi_awid    <= 4'h0;
            m_axi_awaddr  <= 32'h0;
            m_axi_awlen   <= 8'h0;
            m_axi_awsize  <= 3'b010;
            m_axi_awburst <= 2'b01;
            m_axi_awprot  <= 3'b001;

            hp_awvalid    <= 1'b0;
            hp_awid       <= 4'h0;
            hp_awaddr     <= 32'h0;
            hp_awlen      <= 8'h0;
            hp_awsize     <= 3'b010;
            hp_awburst    <= 2'b01;

            m_axi_arvalid <= 1'b0;
            m_axi_arid    <= 4'h0;
            m_axi_araddr  <= 32'h0;
            m_axi_arlen   <= 8'h0;
            m_axi_arsize  <= 3'b010;
            m_axi_arburst <= 2'b01;
            m_axi_arprot  <= 3'b001;

            hp_arvalid    <= 1'b0;
            hp_arid       <= 4'h0;
            hp_araddr     <= 32'h0;
            hp_arlen      <= 8'h0;
            hp_arsize     <= 3'b010;
            hp_arburst    <= 2'b01;

            acl_w_fault   <= 1'b0;
            acl_w_err_mode<= 1'b0;

            acl_r_fault   <= 1'b0;
            acl_r_id      <= 4'h0;
            acl_r_len     <= 8'h0;
            acl_r_err_mode<= 1'b0;

            w_fault_event_valid <= 1'b0;
            w_fault_event_code  <= 4'h0;

            r_fault_event_valid <= 1'b0;
            r_fault_event_code  <= 4'h0;
            r_fault_event_addr  <= 32'h0;
            r_fault_event_size  <= 3'b000;

            denied_awaddr <= 32'h0;
            denied_awid   <= 4'h0;
            denied_awlen  <= 8'h0;
            denied_awsize <= 3'b000;
        end else begin
            // Default 1-cycle pulses
            acl_w_fault         <= 1'b0;
            acl_r_fault         <= 1'b0;
            w_fault_event_valid <= 1'b0;
            r_fault_event_valid <= 1'b0;

            // Handle Downstream AW handshake
            if (m_axi_awvalid && m_axi_awready) begin
                m_axi_awvalid <= 1'b0;
                wr_aw_done    <= 1'b1;
            end
            if (hp_awvalid && hp_awready) begin
                hp_awvalid <= 1'b0;
                wr_aw_done <= 1'b1;
            end

            // Handle Downstream AR handshake
            if (m_axi_arvalid && m_axi_arready) begin
                m_axi_arvalid <= 1'b0;
            end
            if (hp_arvalid && hp_arready) begin
                hp_arvalid <= 1'b0;
            end

            // Release Write Owner on B channel handshake
            if (b_terminal) begin
                wr_owner   <= OWNER_NONE;
                wr_aw_done <= 1'b0;
            end

            // Release Read Owner on final R channel handshake
            if (r_terminal) begin
                rd_owner <= OWNER_NONE;
            end

            // Framing fault pulse from drain FSM
            if (w_framing_fault_valid) begin
                w_fault_event_valid <= 1'b1;
                w_fault_event_code  <= w_framing_fault_code;
            end

            // Track request sent to Matcher
            if (req_valid && req_ready) begin
                matcher_inflight_valid    <= 1'b1;
                matcher_inflight_is_write <= req_is_write;
                matcher_inflight_addr     <= req_start;
                matcher_inflight_size     <= req_size;
                arb_priority_write        <= ~req_is_write; // Toggle priority
            end

            // Process Decision from Matcher (Multi-bit Safe Token Verification)
            if (decision_valid) begin
                matcher_inflight_valid <= 1'b0;

                if (matcher_inflight_is_write) begin
                    if (decision_allow == 4'b1010 && !aegis_quarantine_mask[decision_id]) begin
                        if ((aegis_threat_level == 2'b10 || mtd_trans_action == 2'b10) && !hp_sink_busy) begin
                            wr_owner    <= OWNER_HONEYPOT;
                            wr_aw_done  <= 1'b0;
                            hp_awvalid  <= 1'b1;
                            hp_awid     <= decision_id;
                            hp_awaddr   <= mtd_morph_addr;
                            hp_awlen    <= decision_len;
                            hp_awsize   <= matcher_inflight_size;
                            hp_awburst  <= 2'b01; // INCR
                        end else if (aegis_threat_level == 2'b11 || mtd_trans_action == 2'b11 || (aegis_threat_level == 2'b10 && hp_sink_busy)) begin
                            // Breach or Honeypot Sink not ready -> Fail-secure to DRAIN
                            wr_owner            <= OWNER_DRAIN;
                            wr_aw_done          <= 1'b0;
                            acl_w_fault         <= 1'b1;
                            acl_w_err_mode      <= decision_err_mode;
                            denied_awaddr       <= matcher_inflight_addr;
                            denied_awid         <= decision_id;
                            denied_awlen        <= decision_len;
                            denied_awsize       <= matcher_inflight_size;
                            w_fault_event_valid <= 1'b1;
                            w_fault_event_code  <= 4'b1110;
                        end else begin
                            // ALLOW / RATE_LIMIT: Forward downstream with address preserved
                            wr_owner      <= OWNER_ALLOW;
                            wr_aw_done    <= 1'b0;
                            m_axi_awvalid <= 1'b1;
                            m_axi_awid    <= decision_id;
                            m_axi_awaddr  <= matcher_inflight_addr;
                            m_axi_awlen   <= decision_len;
                            m_axi_awsize  <= matcher_inflight_size;
                            m_axi_awburst <= 2'b01; // INCR
                            m_axi_awprot  <= 3'b001;
                        end
                    end else begin
                        if (aegis_threat_level == 2'b10 && mtd_trans_action == 2'b10 && !hp_sink_busy) begin
                            wr_owner    <= OWNER_HONEYPOT;
                            wr_aw_done  <= 1'b0;
                            hp_awvalid  <= 1'b1;
                            hp_awid     <= decision_id;
                            hp_awaddr   <= mtd_morph_addr;
                            hp_awlen    <= decision_len;
                            hp_awsize   <= matcher_inflight_size;
                            hp_awburst  <= 2'b01;
                        end else begin
                            wr_owner            <= OWNER_DRAIN;
                            wr_aw_done          <= 1'b0;
                            acl_w_fault         <= 1'b1;
                            acl_w_err_mode      <= decision_err_mode;
                            denied_awaddr       <= matcher_inflight_addr;
                            denied_awid         <= decision_id;
                            denied_awlen        <= decision_len;
                            denied_awsize       <= matcher_inflight_size;
                            w_fault_event_valid <= 1'b1;
                            w_fault_event_code  <= (decision_allow != 4'b0101) ? 4'b1110 :
                                                   {decision_fault_code[2], decision_fault_code[1], 1'b1, 1'b0};
                        end
                    end
                end else begin
                    // Read Transaction
                    if (decision_allow == 4'b1010 && !aegis_quarantine_mask[decision_id]) begin
                        if ((aegis_threat_level == 2'b10 || mtd_trans_action == 2'b10) && !hp_sink_busy) begin
                            rd_owner   <= OWNER_HONEYPOT;
                            hp_arvalid <= 1'b1;
                            hp_arid    <= decision_id;
                            hp_araddr  <= mtd_morph_addr;
                            hp_arlen   <= decision_len;
                            hp_arsize  <= matcher_inflight_size;
                            hp_arburst <= 2'b01;
                        end else if (aegis_threat_level == 2'b11 || mtd_trans_action == 2'b11 || (aegis_threat_level == 2'b10 && hp_sink_busy)) begin
                            // Breach or Honeypot Sink not ready -> Fail-secure to DRAIN
                            rd_owner            <= OWNER_DRAIN;
                            acl_r_fault         <= 1'b1;
                            acl_r_id            <= decision_id;
                            acl_r_len           <= decision_len;
                            acl_r_err_mode      <= decision_err_mode;
                            r_fault_event_valid <= 1'b1;
                            r_fault_event_code  <= 4'b1111;
                            r_fault_event_addr  <= matcher_inflight_addr;
                            r_fault_event_size  <= matcher_inflight_size;
                        end else begin
                            // ALLOW / RATE_LIMIT: Forward downstream with address preserved
                            rd_owner      <= OWNER_ALLOW;
                            m_axi_arvalid <= 1'b1;
                            m_axi_arid    <= decision_id;
                            m_axi_araddr  <= matcher_inflight_addr;
                            m_axi_arlen   <= decision_len;
                            m_axi_arsize  <= matcher_inflight_size;
                            m_axi_arburst <= 2'b01; // INCR
                            m_axi_arprot  <= 3'b001;
                        end
                    end else begin
                        if (aegis_threat_level == 2'b10 && mtd_trans_action == 2'b10 && !hp_sink_busy) begin
                            rd_owner   <= OWNER_HONEYPOT;
                            hp_arvalid <= 1'b1;
                            hp_arid    <= decision_id;
                            hp_araddr  <= mtd_morph_addr;
                            hp_arlen   <= decision_len;
                            hp_arsize  <= matcher_inflight_size;
                            hp_arburst <= 2'b01;
                        end else begin
                            rd_owner            <= OWNER_DRAIN;
                            acl_r_fault         <= 1'b1;
                            acl_r_id            <= decision_id;
                            acl_r_len           <= decision_len;
                            acl_r_err_mode      <= decision_err_mode;
                            r_fault_event_valid <= 1'b1;
                            r_fault_event_code  <= (decision_allow != 4'b0101) ? 4'b1111 :
                                                   {decision_fault_code[2], decision_fault_code[1], 1'b0, 1'b1};
                            r_fault_event_addr  <= matcher_inflight_addr;
                            r_fault_event_size  <= matcher_inflight_size;
                        end
                    end
                end
            end
        end
    end

    // =========================================================================
    // 10. AEGIS-RISC Bio-Inspired Immune System Engine
    // =========================================================================
    wire safe_cpu_trap  = cpu_telemetry_trap;
    wire safe_cpu_stall = cpu_telemetry_stall;

    assign aegis_honey_hit = mtd_honey_hit;

    wire [3:0] hdc_overrun_mid;
    wire [31:0] aegis_closed_loop_fingerprint;

    fw_hdc_sense #(
        .RAPID_THRESH(8'd16)
    ) u_hdc_sense (
        .clk                 (clk),
        .resetn              (rst_n_synced),
        .clear_overflow_pulse(aegis_clear_overflow_pulse),
        .s1_awvalid          (pipe_s1_awvalid),
        .s1_awaddr           (pipe_s1_awaddr),
        .s1_awlen            (pipe_s1_awlen),
        .s1_awsize           (pipe_s1_awsize),
        .s1_awmid            (pipe_s1_awid),
        .s1_arvalid          (pipe_s1_arvalid),
        .s1_araddr           (pipe_s1_araddr),
        .s1_arlen            (pipe_s1_arlen),
        .s1_arsize           (pipe_s1_arsize),
        .s1_armid            (pipe_s1_arid),
        .cpu_telemetry_trap  (safe_cpu_trap),
        .cpu_telemetry_stall (safe_cpu_stall),
        .threat_level        (aegis_threat_level),
        .hdc_anomaly_alert   (aegis_anomaly_alert),
        .attack_fingerprint  (aegis_attack_fingerprint),
        .closed_loop_fingerprint(aegis_closed_loop_fingerprint),
        .hdc_busy            (hdc_busy),
        .telemetry_overrun   (hdc_telemetry_overrun),
        .overrun_mid         (hdc_overrun_mid)
    );

    fw_honeypot_sink u_honeypot_sink (
        .clk                 (clk),
        .rst_n               (rst_n_synced),
        .hp_awvalid          (hp_awvalid),
        .hp_awready          (hp_awready),
        .hp_awid             (hp_awid),
        .hp_awaddr           (hp_awaddr),
        .hp_awlen            (hp_awlen),
        .hp_awsize           (hp_awsize),
        .hp_awburst          (hp_awburst),
        .hp_wvalid           (hp_wvalid),
        .hp_wready           (hp_wready),
        .hp_wdata            (hp_wdata),
        .hp_wstrb            (hp_wstrb),
        .hp_wlast            (hp_wlast),
        .hp_bvalid           (hp_bvalid),
        .hp_bready           (hp_bready),
        .hp_bid              (hp_bid),
        .hp_bresp            (hp_bresp),
        .hp_arvalid          (hp_arvalid),
        .hp_arready          (hp_arready),
        .hp_arid             (hp_arid),
        .hp_araddr           (hp_araddr),
        .hp_arlen            (hp_arlen),
        .hp_arsize           (hp_arsize),
        .hp_arburst          (hp_arburst),
        .hp_rvalid           (hp_rvalid),
        .hp_rready           (hp_rready),
        .hp_rid              (hp_rid),
        .hp_rdata            (hp_rdata),
        .hp_rresp            (hp_rresp),
        .hp_rlast            (hp_rlast),
        .scrambler_state_out (hp_scrambler_state),
        .honey_trans_count   (hp_honey_count),
        .sink_busy           (hp_sink_busy),
        .wlast_err           (hp_wlast_err)
    );

    fw_mtd_engine u_mtd_engine (
        .clk               (clk),
        .resetn            (rst_n_synced),
        .threat_level      (aegis_threat_level),
        .telemetry_overrun (hdc_telemetry_overrun),
        .overrun_mid       (hdc_overrun_mid),
        .sink_ready        (!hp_sink_busy),
        .orig_valid        (matcher_inflight_valid),
        .orig_is_write     (matcher_inflight_is_write),
        .orig_addr         (matcher_inflight_addr),
        .orig_len          (decision_len),
        .orig_id           (decision_id),
        .trans_action      (mtd_trans_action),
        .morph_addr        (mtd_morph_addr),
        .honey_pot_hit     (mtd_honey_hit),
        .rate_limit_stall  (mtd_rate_limit_stall),
        .jitter_active     (mtd_jitter_active),
        .force_drain_req   (mtd_force_drain),
        .scrambler_state_out(mtd_scrambler_state),
        .active_key        (mtd_active_key)
    );

    fw_closed_loop_ctrl u_closed_loop (
        .clk                       (clk),
        .resetn                    (rst_n_synced),
        .threat_level              (aegis_threat_level),
        .hdc_anomaly_alert         (aegis_anomaly_alert),
        .honey_pot_hit             (mtd_honey_hit),
        .force_drain_req           (mtd_force_drain),
        .attack_fingerprint        (aegis_closed_loop_fingerprint),
        .current_mid               (decision_id),
        .telemetry_overrun         (hdc_telemetry_overrun),
        .overrun_mid               (hdc_overrun_mid),
        .event_addr                (matcher_inflight_addr),
        .event_len                 (decision_len),
        .event_size                (matcher_inflight_size),
        .event_is_write            (matcher_inflight_is_write),
        .event_reason              ({2'b00, decision_fault_code}),
        .fifo_pop_pulse            (aegis_fifo_pop_pulse),
        .clear_overflow_pulse      (aegis_clear_overflow_pulse),
        .irq_ack_pulse             (aegis_irq_ack_pulse),
        .unquarantine_pulse        (aegis_unquarantine_pulse),
        .unquarantine_mid          (aegis_unquarantine_mid),
        .clear_forensics_pulse     (1'b0),
        .aegis_nmi_irq             (aegis_nmi_irq),
        .quarantine_mask           (aegis_quarantine_mask),
        .fifo_overflow_containment (fifo_overflow_containment),
        .reg_aegis_status          (reg_aegis_status),
        .reg_aegis_fingerprint     (reg_aegis_fingerprint),
        .reg_aegis_honey_count     (reg_aegis_honey_count),
        .reg_aegis_caps            (reg_aegis_caps),
        .reg_aegis_event_meta      (reg_aegis_event_meta),
        .reg_aegis_event_addr      (reg_aegis_event_addr),
        .reg_aegis_event_time      (reg_aegis_event_time),
        .reg_aegis_event_ctrl      (reg_aegis_event_ctrl)
    );

    wire _unused_top_fw = &{1'b0,
        hdc_busy,
        fifo_overflow_containment,
        hp_scrambler_state,
        hp_wlast_err,
        mtd_active_key,
        mtd_scrambler_state,
        mtd_jitter_active,
        pipe_s1_awend,
        pipe_s1_awburst,
        pipe_s1_arend,
        pipe_s1_arburst,
        irq_en,
        reg_aegis_honey_count
    };

endmodule
