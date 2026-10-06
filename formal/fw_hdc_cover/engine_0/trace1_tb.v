`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [7:0] PI_s1_awlen;
  reg [3:0] PI_s1_awmid;
  reg [3:0] PI_s1_armid;
  reg [7:0] PI_s1_arlen;
  reg [0:0] PI_s1_arvalid;
  reg [0:0] PI_s1_awvalid;
  wire [0:0] PI_clk = clock;
  reg [31:0] PI_s1_araddr;
  reg [31:0] PI_s1_awaddr;
  reg [2:0] PI_s1_awsize;
  reg [2:0] PI_s1_arsize;
  reg [0:0] PI_resetn;
  reg [0:0] PI_cpu_telemetry_trap;
  reg [0:0] PI_cpu_telemetry_stall;
  fw_hdc_cover UUT (
    .s1_awlen(PI_s1_awlen),
    .s1_awmid(PI_s1_awmid),
    .s1_armid(PI_s1_armid),
    .s1_arlen(PI_s1_arlen),
    .s1_arvalid(PI_s1_arvalid),
    .s1_awvalid(PI_s1_awvalid),
    .clk(PI_clk),
    .s1_araddr(PI_s1_araddr),
    .s1_awaddr(PI_s1_awaddr),
    .s1_awsize(PI_s1_awsize),
    .s1_arsize(PI_s1_arsize),
    .resetn(PI_resetn),
    .cpu_telemetry_trap(PI_cpu_telemetry_trap),
    .cpu_telemetry_stall(PI_cpu_telemetry_stall)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$2143  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$2111  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$2117  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$2123  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$2129  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$2135  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$2141  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$2147  = 1'b1;
    UUT.dut._witness_.anyinit_procdff_1836 = 64'b0000000000000000000000000000000000000000000000010000001000000000;
    UUT.dut._witness_.anyinit_procdff_1841 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_1846 = 2'b11;
    UUT.dut._witness_.anyinit_procdff_1851 = 2'b00;
    UUT.dut._witness_.anyinit_procdff_1856 = 4'b0000;
    UUT.dut._witness_.anyinit_procdff_1861 = 11'b00010000000;
    UUT.dut._witness_.anyinit_procdff_1866 = 11'b10000000000;
    UUT.dut._witness_.anyinit_procdff_1871 = 11'b01000000001;
    UUT.dut._witness_.anyinit_procdff_1876 = 11'b00000000001;
    UUT.dut._witness_.anyinit_procdff_1881 = 2'b10;
    UUT.dut._witness_.anyinit_procdff_1886 = 32'b00000000000000000000000000000001;
    UUT.dut._witness_.anyinit_procdff_1891 = 32'b00000000000000000010000000000001;
    UUT.dut._witness_.anyinit_procdff_1896 = 32'b00000000000000000000000000000000;
    UUT.dut._witness_.anyinit_procdff_1911 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_1916 = 4'b0001;
    UUT.dut._witness_.anyinit_procdff_1921 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_1926 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1931 = 2'b00;
    UUT.dut._witness_.anyinit_procdff_1936 = 64'b0000000000000000000000000000000000001000000000000000000000000000;
    UUT.dut._witness_.anyinit_procdff_1941 = 64'b0000000000000000000000000000000000000000000000000000000000000001;
    UUT.dut._witness_.anyinit_procdff_1986 = 12'b100111110111;
    UUT.dut._witness_.anyinit_procdff_1991 = 8'b01100001;
    UUT.dut._witness_.anyinit_procdff_1996 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_2001 = 4'b0010;
    UUT.dut._witness_.anyinit_procdff_2006 = 4'b1000;
    UUT.dut._witness_.anyinit_procdff_2011 = 8'b10100000;
    UUT.dut._witness_.anyinit_procdff_2016 = 4'b0010;
    UUT.reset_counter = 2'b00;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0000] = 64'b0110101110001010111001101111110001100110010001010000001100000000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0000] = 64'b1101011111111100101110000111001011010110110001000001111100000000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0000] = 64'b1001110100011000010000110110100100001101010111100001000011100000;

    // state 0
    PI_s1_awlen = 8'b11110000;
    PI_s1_awmid = 4'b0000;
    PI_s1_armid = 4'b0011;
    PI_s1_arlen = 8'b00000000;
    PI_s1_arvalid = 1'b1;
    PI_s1_awvalid = 1'b0;
    PI_s1_araddr = 32'b01001010110010101111100011110011;
    PI_s1_awaddr = 32'b00000001001101000001000100001100;
    PI_s1_awsize = 3'b001;
    PI_s1_arsize = 3'b110;
    PI_resetn = 1'b0;
    PI_cpu_telemetry_trap = 1'b1;
    PI_cpu_telemetry_stall = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_s1_awlen <= 8'b00000000;
      PI_s1_awmid <= 4'b0110;
      PI_s1_armid <= 4'b1000;
      PI_s1_arlen <= 8'b10001000;
      PI_s1_arvalid <= 1'b1;
      PI_s1_awvalid <= 1'b1;
      PI_s1_araddr <= 32'b00000100101110110000010000000111;
      PI_s1_awaddr <= 32'b01111011010001001101100101111000;
      PI_s1_awsize <= 3'b000;
      PI_s1_arsize <= 3'b011;
      PI_resetn <= 1'b0;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_s1_awlen <= 8'b01000001;
      PI_s1_awmid <= 4'b0110;
      PI_s1_armid <= 4'b0011;
      PI_s1_arlen <= 8'b00101011;
      PI_s1_arvalid <= 1'b1;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b11000011010111001000011000111011;
      PI_s1_awaddr <= 32'b00001000001100110000100000000100;
      PI_s1_awsize <= 3'b000;
      PI_s1_arsize <= 3'b111;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 3
    if (cycle == 2) begin
      PI_s1_awlen <= 8'b10010100;
      PI_s1_awmid <= 4'b0110;
      PI_s1_armid <= 4'b1001;
      PI_s1_arlen <= 8'b00000101;
      PI_s1_arvalid <= 1'b1;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b10011000010101011100100001001000;
      PI_s1_awaddr <= 32'b00000011001010100100000000000111;
      PI_s1_awsize <= 3'b011;
      PI_s1_arsize <= 3'b100;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    genclock <= cycle < 3;
    cycle <= cycle + 1;
  end
endmodule
