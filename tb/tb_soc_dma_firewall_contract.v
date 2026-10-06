`timescale 1ns/1ps

`ifndef FIREWALL_DUT
`define FIREWALL_DUT dma_bus_firewall
`endif

module tb_soc_dma_firewall_contract;
    localparam [31:0] FW_BASE  = 32'h1000_0000;
    localparam [31:0] DMA_BASE = 32'h1000_1000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    reg  [31:0] apb_paddr;
    reg  [31:0] apb_pwdata;
    reg         apb_pwrite;
    reg         apb_psel;
    reg         apb_penable;

    wire        fw_psel   = apb_psel && (apb_paddr[15:12] == 4'h0);
    wire [31:0] fw_prdata;
    wire        fw_pready;
    wire        fw_pslverr;

    wire        dma_psel  = apb_psel && (apb_paddr[15:12] == 4'h1);
    wire [31:0] dma_prdata;
    wire        dma_pready;
    wire        dma_pslverr;
    wire        dma_irq;

    wire dma_ctx_valid;
    wire [31:0] dma_ctx_src_addr;
    wire [31:0] dma_ctx_dst_addr;
    wire [31:0] dma_ctx_byte_len;
    wire dma_ctx_done;

    wire [31:0] dma_araddr;
    wire [3:0] dma_arid;
    wire [7:0] dma_arlen;
    wire [2:0] dma_arsize;
    wire [1:0] dma_arburst;
    wire [2:0] dma_prot;
    wire dma_arvalid;
    wire dma_arready;
    wire [31:0] dma_rdata;
    wire dma_rlast;
    wire dma_rvalid;
    wire [3:0] dma_rid;
    wire [1:0] dma_rresp;
    wire dma_rready;
    wire [31:0] dma_awaddr;
    wire [3:0] dma_awid;
    wire [7:0] dma_awlen;
    wire [2:0] dma_awsize;
    wire [1:0] dma_awburst;
    wire dma_awvalid;
    wire dma_awready;
    wire [31:0] dma_wdata;
    wire [3:0] dma_wstrb;
    wire dma_wlast;
    wire dma_wvalid;
    wire dma_wready;
    wire [3:0] dma_bid;
    wire [1:0] dma_bresp;
    wire dma_bvalid;
    wire dma_bready;

    wire [3:0] matrix_awid;
    wire [31:0] matrix_awaddr;
    wire [7:0] matrix_awlen;
    wire [2:0] matrix_awsize;
    wire [1:0] matrix_awburst;
    wire [2:0] matrix_awprot;
    wire [3:0] matrix_awcache;
    wire matrix_awlock;
    wire [3:0] matrix_awqos;
    wire [3:0] matrix_awregion;
    wire matrix_awvalid;
    wire [31:0] matrix_wdata;
    wire [3:0] matrix_wstrb;
    wire matrix_wlast;
    wire matrix_wvalid;
    wire matrix_bready;
    wire [3:0] matrix_arid;
    wire [31:0] matrix_araddr;
    wire [7:0] matrix_arlen;
    wire [2:0] matrix_arsize;
    wire [1:0] matrix_arburst;
    wire [2:0] matrix_arprot;
    wire [3:0] matrix_arcache;
    wire matrix_arlock;
    wire [3:0] matrix_arqos;
    wire [3:0] matrix_arregion;
    wire matrix_arvalid;
    wire matrix_rready;
    wire sec_irq;

    integer failures = 0;
    integer matrix_request_count = 0;
    integer context_done_count = 0;
    integer timeout_count;
    reg [31:0] status_value;

    dma_controller u_dma (
        .clk(clk), .rst_n(rst_n),
        .psel(dma_psel), .penable(apb_penable), .pwrite(apb_pwrite),
        .paddr(apb_paddr), .pwdata(apb_pwdata), .prdata(dma_prdata),
        .pready(dma_pready), .pslverr(dma_pslverr), .dma_irq(dma_irq),
        .dma_ctx_valid(dma_ctx_valid), .dma_ctx_src_addr(dma_ctx_src_addr),
        .dma_ctx_dst_addr(dma_ctx_dst_addr), .dma_ctx_byte_len(dma_ctx_byte_len),
        .dma_ctx_done(dma_ctx_done),
        .m_axi_araddr(dma_araddr), .m_axi_arid(dma_arid),
        .m_axi_arlen(dma_arlen), .m_axi_arsize(dma_arsize),
        .m_axi_arburst(dma_arburst), .m_axi_prot(dma_prot),
        .m_axi_arvalid(dma_arvalid), .m_axi_arready(dma_arready),
        .m_axi_rdata(dma_rdata), .m_axi_rlast(dma_rlast),
        .m_axi_rvalid(dma_rvalid), .m_axi_rid(dma_rid),
        .m_axi_rresp(dma_rresp), .m_axi_rready(dma_rready),
        .m_axi_awaddr(dma_awaddr), .m_axi_awid(dma_awid),
        .m_axi_awlen(dma_awlen), .m_axi_awsize(dma_awsize),
        .m_axi_awburst(dma_awburst), .m_axi_awvalid(dma_awvalid),
        .m_axi_awready(dma_awready), .m_axi_wdata(dma_wdata),
        .m_axi_wstrb(dma_wstrb), .m_axi_wlast(dma_wlast),
        .m_axi_wvalid(dma_wvalid), .m_axi_wready(dma_wready),
        .m_axi_bid(dma_bid), .m_axi_bresp(dma_bresp),
        .m_axi_bvalid(dma_bvalid), .m_axi_bready(dma_bready)
    );

    `FIREWALL_DUT u_firewall (
        .clk(clk), .rst_n(rst_n), .test_mode(1'b0),
        .s_apb_paddr(apb_paddr), .s_apb_psel(fw_psel), .s_apb_penable(apb_penable),
        .s_apb_pwrite(apb_pwrite), .s_apb_pwdata(apb_pwdata), .s_apb_pprot(3'b001),
        .s_apb_prdata(fw_prdata), .s_apb_pready(fw_pready), .s_apb_pslverr(fw_pslverr),
        .dma_ctx_valid(dma_ctx_valid), .dma_ctx_src_addr(dma_ctx_src_addr),
        .dma_ctx_dst_addr(dma_ctx_dst_addr), .dma_ctx_byte_len(dma_ctx_byte_len),
        .dma_ctx_done(dma_ctx_done), .sec_irq(sec_irq),
        .cpu_telemetry_trap(1'b0), .cpu_telemetry_stall(1'b0),
        .aegis_nmi_irq(), .aegis_anomaly_alert(), .aegis_threat_level(), .aegis_honey_hit(),
        .s_axi_awid(dma_awid), .s_axi_awaddr(dma_awaddr),
        .s_axi_awlen(dma_awlen), .s_axi_awsize(dma_awsize),
        .s_axi_awburst(dma_awburst), .s_axi_awprot(dma_prot),
        .s_axi_awvalid(dma_awvalid), .s_axi_awready(dma_awready),
        .s_axi_wdata(dma_wdata), .s_axi_wstrb(dma_wstrb),
        .s_axi_wlast(dma_wlast), .s_axi_wvalid(dma_wvalid),
        .s_axi_wready(dma_wready), .s_axi_bid(dma_bid),
        .s_axi_bresp(dma_bresp), .s_axi_bvalid(dma_bvalid),
        .s_axi_bready(dma_bready),
        .s_axi_arid(dma_arid), .s_axi_araddr(dma_araddr),
        .s_axi_arlen(dma_arlen), .s_axi_arsize(dma_arsize),
        .s_axi_arburst(dma_arburst), .s_axi_arprot(dma_prot),
        .s_axi_arvalid(dma_arvalid), .s_axi_arready(dma_arready),
        .s_axi_rid(dma_rid), .s_axi_rdata(dma_rdata),
        .s_axi_rresp(dma_rresp), .s_axi_rlast(dma_rlast),
        .s_axi_rvalid(dma_rvalid), .s_axi_rready(dma_rready),
        .m_axi_awid(matrix_awid), .m_axi_awaddr(matrix_awaddr),
        .m_axi_awlen(matrix_awlen), .m_axi_awsize(matrix_awsize),
        .m_axi_awburst(matrix_awburst), .m_axi_awprot(matrix_awprot),
        .m_axi_awcache(matrix_awcache), .m_axi_awlock(matrix_awlock),
        .m_axi_awqos(matrix_awqos), .m_axi_awregion(matrix_awregion),
        .m_axi_awvalid(matrix_awvalid), .m_axi_awready(1'b1),
        .m_axi_wdata(matrix_wdata), .m_axi_wstrb(matrix_wstrb),
        .m_axi_wlast(matrix_wlast), .m_axi_wvalid(matrix_wvalid),
        .m_axi_wready(1'b1), .m_axi_bid(4'd0), .m_axi_bresp(2'b00),
        .m_axi_bvalid(1'b0), .m_axi_bready(matrix_bready),
        .m_axi_arid(matrix_arid), .m_axi_araddr(matrix_araddr),
        .m_axi_arlen(matrix_arlen), .m_axi_arsize(matrix_arsize),
        .m_axi_arburst(matrix_arburst), .m_axi_arprot(matrix_arprot),
        .m_axi_arcache(matrix_arcache), .m_axi_arlock(matrix_arlock),
        .m_axi_arqos(matrix_arqos), .m_axi_arregion(matrix_arregion),
        .m_axi_arvalid(matrix_arvalid), .m_axi_arready(1'b1),
        .m_axi_rid(4'd0), .m_axi_rdata(32'd0), .m_axi_rresp(2'b00),
        .m_axi_rlast(1'b0), .m_axi_rvalid(1'b0),
        .m_axi_rready(matrix_rready)
    );

    task check;
        input condition;
        input [8*112-1:0] message;
        begin
            if (!condition) begin
                failures = failures + 1;
                $display("[FAIL] %0s", message);
            end
        end
    endtask

    task apb_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(negedge clk);
            apb_paddr = address;
            apb_pwdata = data;
            apb_pwrite = 1'b1;
            apb_psel = 1'b1;
            apb_penable = 1'b0;
            @(negedge clk);
            apb_penable = 1'b1;
            @(posedge clk);
            #1;
            if (address[15:12] == 4'h1)
                check(dma_pready && !dma_pslverr, "DMA APB write accepted");
            else
                check(fw_pready && !fw_pslverr, "Firewall APB write accepted");
            @(negedge clk);
            apb_psel = 1'b0;
            apb_penable = 1'b0;
            apb_pwrite = 1'b0;
        end
    endtask

    task apb_read;
        input [31:0] address;
        output [31:0] data;
        begin
            @(negedge clk);
            apb_paddr = address;
            apb_pwrite = 1'b0;
            apb_psel = 1'b1;
            apb_penable = 1'b0;
            @(negedge clk);
            apb_penable = 1'b1;
            @(posedge clk);
            #1;
            if (address[15:12] == 4'h1) begin
                check(dma_pready && !dma_pslverr, "DMA APB read accepted");
                data = dma_prdata;
            end else begin
                check(fw_pready && !fw_pslverr, "Firewall APB read accepted");
                data = fw_prdata;
            end
            @(negedge clk);
            apb_psel = 1'b0;
            apb_penable = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            if (matrix_awvalid || matrix_wvalid || matrix_arvalid)
                matrix_request_count = matrix_request_count + 1;
            if (dma_ctx_done)
                context_done_count = context_done_count + 1;
        end
    end

    initial begin
        apb_psel = 1'b0;
        apb_penable = 1'b0;
        apb_pwrite = 1'b0;
        apb_paddr = 32'd0;
        apb_pwdata = 32'd0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Configure Firewall to disable auto dynamic context so unconfigured DMA is default-denied
        apb_write(FW_BASE + 32'h00, 32'h0000_0009); // FW_EN=1, AUTO_CTX_EN=0, ERR_MODE=1

        apb_write(DMA_BASE + 32'h04, 32'h2000_0000);
        apb_write(DMA_BASE + 32'h08, 32'h2000_0100);
        apb_write(DMA_BASE + 32'h0C, 32'd64);
        apb_write(DMA_BASE + 32'h00, 32'h0000_0003);

        timeout_count = 0;
        while (!dma_ctx_valid && timeout_count < 100) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end
        check(dma_ctx_valid, "DMA context becomes active after START");

        timeout_count = 0;
        while (!dma_irq && timeout_count < 400) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end
        check(dma_irq, "default-deny DECERR drives DMA terminal error interrupt");
        repeat (2) @(posedge clk);

        apb_read(DMA_BASE + 32'h10, status_value);
        check(status_value[0] == 1'b0, "DMA BUSY clears after denied transfer retires");
        check(status_value[1] == 1'b0, "denied transfer does not set DONE");
        check(status_value[2] == 1'b1, "denied transfer sets ERROR");
        check(!dma_ctx_valid, "DMA context is released at error terminal");
        check(context_done_count == 1, "DMA emits one context-done pulse");
        check(matrix_request_count == 0, "default-denied traffic never reaches Matrix");

        if (failures == 0) begin
            $display("PASS: tb_soc_dma_firewall_contract (PRODUCTION FIREWALL IP)");
            $finish;
        end
        $fatal(1, "FAIL: tb_soc_dma_firewall_contract failures=%0d", failures);
    end

    initial begin
        repeat (800) @(posedge clk);
        $fatal(1, "TIMEOUT: tb_soc_dma_firewall_contract");
    end
endmodule
