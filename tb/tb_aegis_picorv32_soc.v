`timescale 1ns/1ps

// Real frontend integration regression:
//   PicoRV32 -> native/APB bridge -> (firewall APB + DMA APB)
//   DMA AXI master -> real dma_bus_firewall -> AXI memory model
//   dma_bus_firewall.aegis_nmi_irq -> PicoRV32 dedicated NMI input
//
// The CPU firmware configures the firewall and DMA through the bridge.  The
// invalid instruction at the end of the firmware intentionally raises the
// PicoRV32 trap path so the HDC level-3/NMI route is exercised by a real CPU
// output rather than by a testbench-only trap stimulus.

module tb_aegis_picorv32_soc;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------------
    // PicoRV32 native memory side and APB bridge
    // ---------------------------------------------------------------------
    wire        cpu_ext_mem_valid;
    wire        cpu_ext_mem_instr;
    wire [31:0] cpu_ext_mem_addr;
    wire [31:0] cpu_ext_mem_wdata;
    wire [3:0]  cpu_ext_mem_wstrb;
    wire        cpu_ext_mem_ready;
    wire [31:0] cpu_ext_mem_rdata;

    wire [31:0] cpu_fw_paddr;
    wire        cpu_fw_psel;
    wire        cpu_fw_penable;
    wire        cpu_fw_pwrite;
    wire [31:0] cpu_fw_pwdata;
    wire [2:0]  cpu_fw_pprot;
    wire [31:0] cpu_fw_prdata;
    wire        cpu_fw_pready;
    wire        cpu_fw_pslverr;

    wire [31:0] cpu_dma_paddr;
    wire        cpu_dma_psel;
    wire        cpu_dma_penable;
    wire        cpu_dma_pwrite;
    wire [31:0] cpu_dma_pwdata;
    wire [31:0] cpu_dma_prdata;
    wire        cpu_dma_pready;
    wire        cpu_dma_pslverr;

    wire aegis_nmi_irq;
    wire cpu_irq3;
    wire cpu_trap;
    wire cpu_stall;

    assign cpu_ext_mem_ready = 1'b1;

    reg [31:0] firmware [0:255];
    assign cpu_ext_mem_rdata = (cpu_ext_mem_addr[31:10] == 22'd0) ?
                               firmware[cpu_ext_mem_addr[9:2]] :
                               32'h0000_0000;

    aegis_picorv32_apb_bridge #(
        .CPU_PROGADDR_IRQ(32'h0000_0100)
    ) u_cpu_bridge (
        .clk                  (clk),
        .rst_n                (rst_n),
        .ext_mem_valid        (cpu_ext_mem_valid),
        .ext_mem_instr        (cpu_ext_mem_instr),
        .ext_mem_addr         (cpu_ext_mem_addr),
        .ext_mem_wdata        (cpu_ext_mem_wdata),
        .ext_mem_wstrb        (cpu_ext_mem_wstrb),
        .ext_mem_ready        (cpu_ext_mem_ready),
        .ext_mem_rdata        (cpu_ext_mem_rdata),
        .fw_paddr             (cpu_fw_paddr),
        .fw_psel              (cpu_fw_psel),
        .fw_penable          (cpu_fw_penable),
        .fw_pwrite           (cpu_fw_pwrite),
        .fw_pwdata           (cpu_fw_pwdata),
        .fw_pprot            (cpu_fw_pprot),
        .fw_prdata           (cpu_fw_prdata),
        .fw_pready           (cpu_fw_pready),
        .fw_pslverr          (cpu_fw_pslverr),
        .dma_paddr            (cpu_dma_paddr),
        .dma_psel             (cpu_dma_psel),
        .dma_penable         (cpu_dma_penable),
        .dma_pwrite          (cpu_dma_pwrite),
        .dma_pwdata          (cpu_dma_pwdata),
        .dma_prdata          (cpu_dma_prdata),
        .dma_pready          (cpu_dma_pready),
        .dma_pslverr         (cpu_dma_pslverr),
        .aegis_nmi_irq       (aegis_nmi_irq),
        .cpu_irq3             (cpu_irq3),
        .cpu_trap             (cpu_trap),
        .cpu_stall            (cpu_stall)
    );

    // ---------------------------------------------------------------------
    // DMA controller -> real firewall upstream AXI
    // ---------------------------------------------------------------------
    wire        dma_irq;
    wire        dma_ctx_valid;
    wire [31:0] dma_ctx_src_addr;
    wire [31:0] dma_ctx_dst_addr;
    wire [31:0] dma_ctx_byte_len;
    wire        dma_ctx_done;

    wire [31:0] dma_araddr;
    wire [3:0]  dma_arid;
    wire [7:0]  dma_arlen;
    wire [2:0]  dma_arsize;
    wire [1:0]  dma_arburst;
    wire [2:0]  dma_arprot;
    wire        dma_arvalid;
    wire        dma_arready;
    wire [31:0] dma_rdata;
    wire        dma_rlast;
    wire        dma_rvalid;
    wire [3:0]  dma_rid;
    wire [1:0]  dma_rresp;
    wire        dma_rready;
    wire [31:0] dma_awaddr;
    wire [3:0]  dma_awid;
    wire [7:0]  dma_awlen;
    wire [2:0]  dma_awsize;
    wire [1:0]  dma_awburst;
    wire        dma_awvalid;
    wire        dma_awready;
    wire [31:0] dma_wdata;
    wire [3:0]  dma_wstrb;
    wire        dma_wlast;
    wire        dma_wvalid;
    wire        dma_wready;
    wire [3:0]  dma_bid;
    wire [1:0]  dma_bresp;
    wire        dma_bvalid;
    wire        dma_bready;

    dma_controller u_dma (
        .clk              (clk),
        .rst_n            (rst_n),
        .psel             (cpu_dma_psel),
        .penable          (cpu_dma_penable),
        .pwrite           (cpu_dma_pwrite),
        .paddr            (cpu_dma_paddr),
        .pwdata           (cpu_dma_pwdata),
        .prdata           (cpu_dma_prdata),
        .pready           (cpu_dma_pready),
        .pslverr          (cpu_dma_pslverr),
        .dma_irq          (dma_irq),
        .dma_ctx_valid    (dma_ctx_valid),
        .dma_ctx_src_addr (dma_ctx_src_addr),
        .dma_ctx_dst_addr (dma_ctx_dst_addr),
        .dma_ctx_byte_len (dma_ctx_byte_len),
        .dma_ctx_done     (dma_ctx_done),
        .m_axi_araddr     (dma_araddr),
        .m_axi_arid       (dma_arid),
        .m_axi_arlen      (dma_arlen),
        .m_axi_arsize     (dma_arsize),
        .m_axi_arburst    (dma_arburst),
        .m_axi_prot       (dma_arprot),
        .m_axi_arvalid    (dma_arvalid),
        .m_axi_arready    (dma_arready),
        .m_axi_rdata      (dma_rdata),
        .m_axi_rlast      (dma_rlast),
        .m_axi_rvalid     (dma_rvalid),
        .m_axi_rid        (dma_rid),
        .m_axi_rresp      (dma_rresp),
        .m_axi_rready     (dma_rready),
        .m_axi_awaddr     (dma_awaddr),
        .m_axi_awid       (dma_awid),
        .m_axi_awlen      (dma_awlen),
        .m_axi_awsize     (dma_awsize),
        .m_axi_awburst    (dma_awburst),
        .m_axi_awvalid    (dma_awvalid),
        .m_axi_awready    (dma_awready),
        .m_axi_wdata      (dma_wdata),
        .m_axi_wstrb      (dma_wstrb),
        .m_axi_wlast      (dma_wlast),
        .m_axi_wvalid     (dma_wvalid),
        .m_axi_wready     (dma_wready),
        .m_axi_bid        (dma_bid),
        .m_axi_bresp      (dma_bresp),
        .m_axi_bvalid     (dma_bvalid),
        .m_axi_bready     (dma_bready)
    );

    // ---------------------------------------------------------------------
    // Real dma_bus_firewall instance and downstream AXI memory model
    // ---------------------------------------------------------------------
    wire [31:0] fw_s_apb_prdata;
    wire        fw_s_apb_pready;
    wire        fw_s_apb_pslverr;
    wire        aegis_anomaly_alert;
    wire [1:0]  aegis_threat_level;
    wire        aegis_honey_hit;
    wire        sec_irq;

    wire [3:0]  mem_awid;
    wire [31:0] mem_awaddr;
    wire [7:0]  mem_awlen;
    wire [2:0]  mem_awsize;
    wire [1:0]  mem_awburst;
    wire [2:0]  mem_awprot;
    wire [3:0]  mem_awcache;
    wire        mem_awlock;
    wire [3:0]  mem_awqos;
    wire [3:0]  mem_awregion;
    wire        mem_awvalid;
    wire        mem_awready;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire        mem_wlast;
    wire        mem_wvalid;
    wire        mem_wready;
    wire [3:0]  mem_bid;
    wire [1:0]  mem_bresp;
    wire        mem_bvalid;
    wire        mem_bready;
    wire [3:0]  mem_arid;
    wire [31:0] mem_araddr;
    wire [7:0]  mem_arlen;
    wire [2:0]  mem_arsize;
    wire [1:0]  mem_arburst;
    wire [2:0]  mem_arprot;
    wire [3:0]  mem_arcache;
    wire        mem_arlock;
    wire [3:0]  mem_arqos;
    wire [3:0]  mem_arregion;
    wire        mem_arvalid;
    wire        mem_arready;
    wire [3:0]  mem_rid;
    wire [31:0] mem_rdata;
    wire [1:0]  mem_rresp;
    wire        mem_rlast;
    wire        mem_rvalid;
    wire        mem_rready;

    dma_bus_firewall u_firewall (
        .clk                 (clk),
        .rst_n               (rst_n),
        .test_mode           (1'b0),
        .s_apb_paddr         (cpu_fw_paddr),
        .s_apb_psel          (cpu_fw_psel),
        .s_apb_penable       (cpu_fw_penable),
        .s_apb_pwrite        (cpu_fw_pwrite),
        .s_apb_pwdata        (cpu_fw_pwdata),
        .s_apb_pprot         (cpu_fw_pprot),
        .s_apb_prdata        (fw_s_apb_prdata),
        .s_apb_pready        (fw_s_apb_pready),
        .s_apb_pslverr       (fw_s_apb_pslverr),
        .dma_ctx_valid       (dma_ctx_valid),
        .dma_ctx_src_addr    (dma_ctx_src_addr),
        .dma_ctx_dst_addr    (dma_ctx_dst_addr),
        .dma_ctx_byte_len    (dma_ctx_byte_len),
        .dma_ctx_done        (dma_ctx_done),
        .sec_irq             (sec_irq),
        .cpu_telemetry_trap  (cpu_trap),
        .cpu_telemetry_stall (cpu_stall),
        .aegis_nmi_irq       (aegis_nmi_irq),
        .aegis_anomaly_alert (aegis_anomaly_alert),
        .aegis_threat_level  (aegis_threat_level),
        .aegis_honey_hit     (aegis_honey_hit),
        .s_axi_awid          (dma_awid),
        .s_axi_awaddr        (dma_awaddr),
        .s_axi_awlen         (dma_awlen),
        .s_axi_awsize        (dma_awsize),
        .s_axi_awburst       (dma_awburst),
        .s_axi_awprot        (dma_arprot),
        .s_axi_awvalid       (dma_awvalid),
        .s_axi_awready       (dma_awready),
        .s_axi_wdata         (dma_wdata),
        .s_axi_wstrb         (dma_wstrb),
        .s_axi_wlast         (dma_wlast),
        .s_axi_wvalid        (dma_wvalid),
        .s_axi_wready        (dma_wready),
        .s_axi_bid           (dma_bid),
        .s_axi_bresp         (dma_bresp),
        .s_axi_bvalid        (dma_bvalid),
        .s_axi_bready        (dma_bready),
        .s_axi_arid          (dma_arid),
        .s_axi_araddr        (dma_araddr),
        .s_axi_arlen         (dma_arlen),
        .s_axi_arsize        (dma_arsize),
        .s_axi_arburst       (dma_arburst),
        .s_axi_arprot        (dma_arprot),
        .s_axi_arvalid       (dma_arvalid),
        .s_axi_arready       (dma_arready),
        .s_axi_rid           (dma_rid),
        .s_axi_rdata         (dma_rdata),
        .s_axi_rresp         (dma_rresp),
        .s_axi_rlast         (dma_rlast),
        .s_axi_rvalid        (dma_rvalid),
        .s_axi_rready        (dma_rready),
        .m_axi_awid          (mem_awid),
        .m_axi_awaddr        (mem_awaddr),
        .m_axi_awlen         (mem_awlen),
        .m_axi_awsize        (mem_awsize),
        .m_axi_awburst       (mem_awburst),
        .m_axi_awprot        (mem_awprot),
        .m_axi_awcache       (mem_awcache),
        .m_axi_awlock        (mem_awlock),
        .m_axi_awqos         (mem_awqos),
        .m_axi_awregion      (mem_awregion),
        .m_axi_awvalid       (mem_awvalid),
        .m_axi_awready       (mem_awready),
        .m_axi_wdata         (mem_wdata),
        .m_axi_wstrb         (mem_wstrb),
        .m_axi_wlast         (mem_wlast),
        .m_axi_wvalid        (mem_wvalid),
        .m_axi_wready        (mem_wready),
        .m_axi_bid           (mem_bid),
        .m_axi_bresp         (mem_bresp),
        .m_axi_bvalid        (mem_bvalid),
        .m_axi_bready        (mem_bready),
        .m_axi_arid          (mem_arid),
        .m_axi_araddr        (mem_araddr),
        .m_axi_arlen         (mem_arlen),
        .m_axi_arsize        (mem_arsize),
        .m_axi_arburst       (mem_arburst),
        .m_axi_arprot        (mem_arprot),
        .m_axi_arcache       (mem_arcache),
        .m_axi_arlock        (mem_arlock),
        .m_axi_arqos         (mem_arqos),
        .m_axi_arregion      (mem_arregion),
        .m_axi_arvalid       (mem_arvalid),
        .m_axi_arready       (mem_arready),
        .m_axi_rid           (mem_rid),
        .m_axi_rdata         (mem_rdata),
        .m_axi_rresp         (mem_rresp),
        .m_axi_rlast         (mem_rlast),
        .m_axi_rvalid        (mem_rvalid),
        .m_axi_rready        (mem_rready)
    );

    assign cpu_fw_prdata = fw_s_apb_prdata;
    assign cpu_fw_pready = fw_s_apb_pready;
    assign cpu_fw_pslverr = fw_s_apb_pslverr;

    // ---------------------------------------------------------------------
    // AXI memory model: one outstanding read and one outstanding write.
    // ---------------------------------------------------------------------
    reg [31:0] backing_mem [0:1023];
    reg        read_active;
    reg [31:0] read_addr;
    reg [7:0]  read_len;
    reg [7:0]  read_beat;
    reg [3:0]  read_id;
    reg        write_active;
    reg [31:0] write_addr;
    reg [7:0]  write_len;
    reg [7:0]  write_beat;
    reg [3:0]  write_id;
    reg        b_active;
    reg [3:0]  b_id_reg;
    integer i;

    function [9:0] mem_index(input [31:0] addr);
        mem_index = addr[11:2];
    endfunction

    assign mem_arready = !read_active;
    assign mem_rvalid  = read_active;
    assign mem_rid     = read_id;
    assign mem_rdata   = backing_mem[mem_index(read_addr + {22'd0, read_beat, 2'b00})];
    assign mem_rresp   = 2'b00;
    assign mem_rlast   = read_active && (read_beat == read_len);

    assign mem_awready = !write_active && !b_active;
    assign mem_wready  = write_active;
    assign mem_bvalid  = b_active;
    assign mem_bid     = b_id_reg;
    assign mem_bresp   = 2'b00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_active  <= 1'b0;
            read_addr    <= 32'd0;
            read_len     <= 8'd0;
            read_beat    <= 8'd0;
            read_id      <= 4'd0;
            write_active <= 1'b0;
            write_addr   <= 32'd0;
            write_len    <= 8'd0;
            write_beat   <= 8'd0;
            write_id     <= 4'd0;
            b_active     <= 1'b0;
            b_id_reg     <= 4'd0;
            for (i = 0; i < 1024; i = i + 1)
                backing_mem[i] <= 32'd0;
            for (i = 0; i < 16; i = i + 1)
                backing_mem[i] <= 32'hA500_0000 + i;
        end else begin
            if (!read_active && mem_arvalid && mem_arready) begin
                read_active <= 1'b1;
                read_addr   <= mem_araddr;
                read_len    <= mem_arlen;
                read_beat   <= 8'd0;
                read_id     <= mem_arid;
            end else if (read_active && mem_rready) begin
                if (read_beat == read_len)
                    read_active <= 1'b0;
                else
                    read_beat <= read_beat + 1'b1;
            end

            if (!write_active && !b_active && mem_awvalid && mem_awready) begin
                write_active <= 1'b1;
                write_addr   <= mem_awaddr;
                write_len    <= mem_awlen;
                write_beat   <= 8'd0;
                write_id     <= mem_awid;
            end

            if (write_active && mem_wvalid && mem_wready) begin
                backing_mem[mem_index(write_addr + {22'd0, write_beat, 2'b00})]
                    <= mem_wdata;
                if (mem_wlast || (write_beat == write_len)) begin
                    write_active <= 1'b0;
                    b_active     <= 1'b1;
                    b_id_reg     <= write_id;
                end else begin
                    write_beat <= write_beat + 1'b1;
                end
            end

            if (b_active && mem_bready)
                b_active <= 1'b0;
        end
    end

    // ---------------------------------------------------------------------
    // Firmware and end-to-end checks
    // ---------------------------------------------------------------------
    integer failures = 0;
    integer cpu_fw_writes = 0;
    integer cpu_dma_writes = 0;
    integer downstream_reads = 0;
    integer downstream_writes = 0;
    integer apb_protocol_failures = 0;
    reg prev_fw_psel = 1'b0;
    reg prev_fw_penable = 1'b0;
    reg prev_dma_psel = 1'b0;
    reg prev_dma_penable = 1'b0;
    reg trap_seen = 1'b0;
    reg nmi_seen = 1'b0;
    reg irq3_seen = 1'b0;
    reg nmi_service_seen = 1'b0;
    reg nmi_mask_bypassed_seen = 1'b0;
    reg threat_level_3_seen = 1'b0;
    reg anomaly_alert_seen = 1'b0;
    reg ctx_seen = 1'b0;
    reg ctx_done_seen = 1'b0;

    task check;
        input condition;
        input [8*160-1:0] message;
        begin
            if (!condition) begin
                failures = failures + 1;
                $display("[FAIL] %0s", message);
            end else begin
                $display("[PASS] %0s", message);
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            if (cpu_fw_penable && !cpu_fw_psel) begin
                apb_protocol_failures = apb_protocol_failures + 1;
                $display("[FAIL] Firewall APB PENABLE asserted without PSEL");
            end
            if (cpu_fw_penable && !prev_fw_penable && !prev_fw_psel) begin
                apb_protocol_failures = apb_protocol_failures + 1;
                $display("[FAIL] Firewall APB access phase was not preceded by setup");
            end
            if (cpu_dma_penable && !cpu_dma_psel) begin
                apb_protocol_failures = apb_protocol_failures + 1;
                $display("[FAIL] DMA APB PENABLE asserted without PSEL");
            end
            if (cpu_dma_penable && !prev_dma_penable && !prev_dma_psel) begin
                apb_protocol_failures = apb_protocol_failures + 1;
                $display("[FAIL] DMA APB access phase was not preceded by setup");
            end
            if (cpu_fw_psel && cpu_fw_penable && cpu_fw_pwrite)
                cpu_fw_writes = cpu_fw_writes + 1;
            if (cpu_dma_psel && cpu_dma_penable && cpu_dma_pwrite)
                cpu_dma_writes = cpu_dma_writes + 1;
            if (mem_arvalid && mem_arready)
                downstream_reads = downstream_reads + 1;
            if (mem_awvalid && mem_awready)
                downstream_writes = downstream_writes + 1;
            if (cpu_trap)
                trap_seen = 1'b1;
            if (aegis_nmi_irq)
                nmi_seen = 1'b1;
            if (aegis_threat_level == 2'b11)
                threat_level_3_seen = 1'b1;
            if (aegis_anomaly_alert)
                anomaly_alert_seen = 1'b1;
            if (cpu_irq3)
                irq3_seen = 1'b1;
            if (u_cpu_bridge.u_picorv32.irq_active) begin
                nmi_service_seen = 1'b1;
                if (u_cpu_bridge.u_picorv32.irq_mask[3])
                    nmi_mask_bypassed_seen = 1'b1;
            end
            if (dma_ctx_valid)
                ctx_seen = 1'b1;
            if (dma_ctx_done)
                ctx_done_seen = 1'b1;
            prev_fw_psel    <= cpu_fw_psel;
            prev_fw_penable <= cpu_fw_penable;
            prev_dma_psel    <= cpu_dma_psel;
            prev_dma_penable <= cpu_dma_penable;
        end else begin
            prev_fw_psel     <= 1'b0;
            prev_fw_penable  <= 1'b0;
            prev_dma_psel    <= 1'b0;
            prev_dma_penable <= 1'b0;
        end
    end

    initial begin
        // FW static region 0: 0x2000_0000..0x2000_00FF, secure RW.
        firmware[0]  = 32'h4000_00B7; // lui   x1, 0x40000 (FW APB)
        firmware[1]  = 32'h2000_0137; // lui   x2, 0x20000
        firmware[2]  = 32'h0220_A023; // sw    x2, 0x20(x1)
        firmware[3]  = 32'h0FF1_0113; // addi  x2, x2, 0xff
        firmware[4]  = 32'h0220_A223; // sw    x2, 0x24(x1)
        firmware[5]  = 32'h8000_0137; // lui   x2, 0x80000
        firmware[6]  = 32'h00F1_0113; // addi  x2, x2, 15
        firmware[7]  = 32'h0220_A423; // sw    x2, 0x28(x1)
        firmware[8]  = 32'h0000_0113; // addi  x2, x0, 0
        firmware[9]  = 32'h0220_A623; // sw    x2, 0x2c(x1)
        // DMA descriptor and START through CPU-to-DMA APB window.
        firmware[10] = 32'h4000_10B7; // lui   x1, 0x40001
        firmware[11] = 32'h2000_0137; // lui   x2, 0x20000
        firmware[12] = 32'h0020_A223; // sw    x2, 4(x1)
        firmware[13] = 32'h1001_0113; // addi  x2, x2, 0x100
        firmware[14] = 32'h0020_A423; // sw    x2, 8(x1)
        firmware[15] = 32'h0400_0113; // addi  x2, x0, 64
        firmware[16] = 32'h0020_A623; // sw    x2, 12(x1)
        firmware[17] = 32'h0030_0113; // addi  x2, x0, 3 (START|IRQ_EN)
        firmware[18] = 32'h0020_A023; // sw    x2, 0(x1)
        // Allow enough time for the 16-beat DMA transaction, then trap.
        firmware[19] = 32'h0C80_0193; // addi  x3, x0, 200
        firmware[20] = 32'hFFF1_8193; // addi  x3, x3, -1
        firmware[21] = 32'hFE01_9EE3; // bne   x3, x0, -4
        firmware[22] = 32'h0000_0000; // illegal instruction -> PicoRV32 trap
        for (i = 23; i < 256; i = i + 1)
            firmware[i] = 32'h0000_0013; // nop padding
        firmware[64] = 32'h0000_006f; // NMI handler: jal x0, 0

        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        repeat (2500) @(posedge clk);

        $display("[INFO] cpu_fw_writes=%0d cpu_dma_writes=%0d downstream_reads=%0d downstream_writes=%0d",
                 cpu_fw_writes, cpu_dma_writes, downstream_reads, downstream_writes);
        check(cpu_fw_writes == 4, "PicoRV32 performed complete firewall region configuration");
        check(cpu_dma_writes == 4, "PicoRV32 performed complete DMA descriptor/START sequence");
        check(apb_protocol_failures == 0, "CPU-to-APB bridge obeyed setup/access phase ordering");
        check(ctx_seen, "Real DMA controller raised context-valid into real firewall");
        check(downstream_reads > 0, "Real DMA read traffic crossed real firewall to memory");
        check(downstream_writes > 0, "Real DMA write traffic crossed real firewall to memory");
        check(ctx_done_seen, "Real DMA completed and released context");
        check(dma_irq, "DMA completion IRQ/status reached integrated controller output");
        check(trap_seen, "PicoRV32 produced the telemetry trap from firmware");
        check(nmi_seen, "AEGIS level-3 reflex generated an NMI pulse");
        check(irq3_seen, "AEGIS NMI remained visible on the compatibility cpu_irq3 output");
        check(nmi_service_seen, "PicoRV32 serviced the dedicated AEGIS NMI");
        check(nmi_mask_bypassed_seen, "Dedicated AEGIS NMI bypassed the ordinary IRQ mask");
        check(threat_level_3_seen, "HDC classified the real PicoRV32 trap as level 3");
        check(anomaly_alert_seen, "Integrated AEGIS anomaly alert asserted on CPU trap");
        check(aegis_honey_hit == 1'b0, "Legitimate integrated DMA did not hit honey-pot");

        for (i = 0; i < 16; i = i + 1)
            check(backing_mem[64 + i] == (32'hA500_0000 + i),
                  "Integrated DMA preserved source data at destination");

        if (failures == 0) begin
            $display("[PASS] tb_aegis_picorv32_soc");
            $finish;
        end else begin
            $display("[FAIL] tb_aegis_picorv32_soc failures=%0d", failures);
            $fatal(1);
        end
    end

    initial begin
        repeat (4000) @(posedge clk);
        $fatal(1, "TIMEOUT: tb_aegis_picorv32_soc");
    end

endmodule
