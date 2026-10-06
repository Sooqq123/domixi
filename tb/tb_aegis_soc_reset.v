`timescale 1ns/1ps

// Top-level reset contract regression.  The bridge and DMA consume the SoC
// synchronizer output while the Firewall owns its own synchronizer.  In
// functional mode both paths must assert immediately and deassert together
// after two rising edges; test_mode intentionally bypasses both synchronizers.
module tb_aegis_soc_reset;
    reg clk = 1'b0;
    // Start high so the explicit transition at t=1 exercises asynchronous
    // assertion; a declaration-time 1'b0 would not trigger negedge reset.
    reg rst_n = 1'b1;
    reg test_mode = 1'b0;
    always #5 clk = ~clk;

    wire        ext_mem_valid;
    wire        ext_mem_instr;
    wire [31:0] ext_mem_addr;
    wire [31:0] ext_mem_wdata;
    wire [3:0]  ext_mem_wstrb;
    reg         ext_mem_ready = 1'b1;
    reg  [31:0] ext_mem_rdata = 32'b0;
    wire        cpu_irq3;
    wire        cpu_trap;
    wire        cpu_stall;
    wire        dma_irq;
    wire        sec_irq;
    wire        aegis_nmi_irq;
    wire        aegis_anomaly_alert;
    wire [1:0]  aegis_threat_level;
    wire        aegis_honey_hit;
    wire [3:0]  m_axi_awid;
    wire [31:0] m_axi_awaddr;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire [2:0]  m_axi_awprot;
    wire [3:0]  m_axi_awcache;
    wire        m_axi_awlock;
    wire [3:0]  m_axi_awqos;
    wire [3:0]  m_axi_awregion;
    wire        m_axi_awvalid;
    reg         m_axi_awready = 1'b0;
    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    reg         m_axi_wready = 1'b0;
    reg  [3:0]  m_axi_bid = 4'b0;
    reg  [1:0]  m_axi_bresp = 2'b0;
    reg         m_axi_bvalid = 1'b0;
    wire        m_axi_bready;
    wire [3:0]  m_axi_arid;
    wire [31:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire [2:0]  m_axi_arprot;
    wire [3:0]  m_axi_arcache;
    wire        m_axi_arlock;
    wire [3:0]  m_axi_arqos;
    wire [3:0]  m_axi_arregion;
    wire        m_axi_arvalid;
    reg         m_axi_arready = 1'b0;
    reg  [3:0]  m_axi_rid = 4'b0;
    reg  [31:0] m_axi_rdata = 32'b0;
    reg  [1:0]  m_axi_rresp = 2'b0;
    reg         m_axi_rlast = 1'b0;
    reg         m_axi_rvalid = 1'b0;
    wire        m_axi_rready;

    integer failures = 0;

    aegis_soc_top dut (.*);

    task expect_reset_state;
        input expected;
        begin
            if (dut.rst_n_synced !== expected) begin
                $display("[FAIL] SoC rst_n_synced expected %b got %b", expected, dut.rst_n_synced);
                failures = failures + 1;
            end
            if (dut.u_firewall.rst_n_synced !== expected) begin
                $display("[FAIL] Firewall rst_n_synced expected %b got %b", expected, dut.u_firewall.rst_n_synced);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        #1 rst_n = 1'b0;
        #1;
        expect_reset_state(1'b0);

        // Functional reset: synchronous deassertion after exactly two edges.
        rst_n = 1'b1;
        @(posedge clk); #1;
        expect_reset_state(1'b0);
        @(posedge clk); #1;
        expect_reset_state(1'b1);

        // Asynchronous assertion must clear both synchronizers mid-cycle.
        #2 rst_n = 1'b0;
        #1 expect_reset_state(1'b0);

        // Scan/test mode deliberately bypasses the synchronizers.
        test_mode = 1'b1;
        rst_n = 1'b1;
        #1 expect_reset_state(1'b1);
        rst_n = 1'b0;
        #1 expect_reset_state(1'b0);

        if (failures == 0) begin
            $display("[PASS] tb_aegis_soc_reset reset contract");
        end else begin
            $display("[FAIL] tb_aegis_soc_reset failures=%0d", failures);
        end
        $finish;
    end
endmodule
