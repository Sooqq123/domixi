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
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0001] = 64'b1101001000110011110010110100000001011110111101010001100000111111;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0010] = 64'b1000001001110101100000111110101100001111010101001000011100100101;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0011] = 64'b1000100110101000010011101010010000101000101100010011001010100111;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0100] = 64'b1111010010111101100111100101011010111100101100111111101000111110;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0101] = 64'b0110001001111101011111000010110101010000101000111101001111110011;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0110] = 64'b0010000001011001000011001110110101010101010001111101010011110111;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b0111] = 64'b0001101011000111110111001101010000101110000100011101110010010001;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b1000] = 64'b0011101010100010111101010111001101010111101110010111001001000000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1153 [4'b1001] = 64'b0010010011110100000011111110111011010010111001101100000110101000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0000] = 64'b1101011111111100101110000111001011010110110001000001111100000000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0001] = 64'b0011111000111110100000100010110101010101000111010100001101111011;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0010] = 64'b0011110100001000111101110011011001101110111000100100100100011011;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0011] = 64'b1101011111001110011100010010100000111101011100100110111101110111;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0100] = 64'b1101101101100010001110011110010000110001110101000001010011101100;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0101] = 64'b0011111111000100111000101010111110101011001101000101100101100010;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0110] = 64'b0111011000000100011111100011001101001011110010100111000101010110;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b0111] = 64'b0101001111001011110010010001000011110111110000110011001101100101;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b1000] = 64'b0110010000001011011010101010111011100010101110110011111110110101;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1157 [4'b1001] = 64'b0010011001001101000000000100011001100010000000110111111001110101;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0000] = 64'b1001110100011000010000110110100100001101010111100001000011100000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0001] = 64'b0111011101010111000011010000101010001010001111100111111011001001;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0010] = 64'b1111011110111010101100110000110111001110000111101010001111111100;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0011] = 64'b1100001001101100000111011110101001110100110011001110110001000000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0100] = 64'b0000010111100101111101111010111010011110001110100111000000100100;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0101] = 64'b0110000011011100010111011110111101010000101001110010010010110001;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0110] = 64'b1010000100011001111010000100011100010100110101001001000110100000;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b0111] = 64'b0011001111100001110011011100110011000110011111001010110110101111;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b1000] = 64'b1100111111010100101011010100111011111111100101011000100101101011;
    UUT.dut.$auto$proc_rom.\cc:155:do_switch$1161 [4'b1001] = 64'b0101111000011010111000110101110110101111010100101000101010101110;

    // state 0
    PI_s1_awlen = 8'b01000000;
    PI_s1_awmid = 4'b0001;
    PI_s1_armid = 4'b0011;
    PI_s1_arlen = 8'b00000000;
    PI_s1_arvalid = 1'b0;
    PI_s1_awvalid = 1'b1;
    PI_s1_araddr = 32'b11111010110010000100001010100011;
    PI_s1_awaddr = 32'b11111010110010000100001010100011;
    PI_s1_awsize = 3'b110;
    PI_s1_arsize = 3'b110;
    PI_resetn = 1'b0;
    PI_cpu_telemetry_trap = 1'b1;
    PI_cpu_telemetry_stall = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_s1_awlen <= 8'b01101000;
      PI_s1_awmid <= 4'b0000;
      PI_s1_armid <= 4'b1001;
      PI_s1_arlen <= 8'b00010000;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b11111010101101000100101111111100;
      PI_s1_awaddr <= 32'b00000000000000110101000000100000;
      PI_s1_awsize <= 3'b000;
      PI_s1_arsize <= 3'b011;
      PI_resetn <= 1'b0;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_s1_awlen <= 8'b01000001;
      PI_s1_awmid <= 4'b0000;
      PI_s1_armid <= 4'b0001;
      PI_s1_arlen <= 8'b00000000;
      PI_s1_arvalid <= 1'b1;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b11010110111101100000101001000010;
      PI_s1_awaddr <= 32'b00001001001000000100010101111001;
      PI_s1_awsize <= 3'b100;
      PI_s1_arsize <= 3'b011;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    // state 3
    if (cycle == 2) begin
      PI_s1_awlen <= 8'b00111000;
      PI_s1_awmid <= 4'b0010;
      PI_s1_armid <= 4'b0101;
      PI_s1_arlen <= 8'b10100001;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b01110110111101000110100000001010;
      PI_s1_awaddr <= 32'b00010100101101100111000001111100;
      PI_s1_awsize <= 3'b011;
      PI_s1_arsize <= 3'b110;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    // state 4
    if (cycle == 3) begin
      PI_s1_awlen <= 8'b00101000;
      PI_s1_awmid <= 4'b1001;
      PI_s1_armid <= 4'b0110;
      PI_s1_arlen <= 8'b00000010;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b01000111000101001110111100101110;
      PI_s1_awaddr <= 32'b00000110011000001110010110100101;
      PI_s1_awsize <= 3'b000;
      PI_s1_arsize <= 3'b110;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b0;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 5
    if (cycle == 4) begin
      PI_s1_awlen <= 8'b11010000;
      PI_s1_awmid <= 4'b1010;
      PI_s1_armid <= 4'b1010;
      PI_s1_arlen <= 8'b11111101;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b00010101001001111100010111111010;
      PI_s1_awaddr <= 32'b01000011001000110000010111111010;
      PI_s1_awsize <= 3'b010;
      PI_s1_arsize <= 3'b001;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b0;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 6
    if (cycle == 5) begin
      PI_s1_awlen <= 8'b01110100;
      PI_s1_awmid <= 4'b1111;
      PI_s1_armid <= 4'b1111;
      PI_s1_arlen <= 8'b01110100;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b00011011101010000111001111000101;
      PI_s1_awaddr <= 32'b00011011101010000111001111000101;
      PI_s1_awsize <= 3'b110;
      PI_s1_arsize <= 3'b110;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b0;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 7
    if (cycle == 6) begin
      PI_s1_awlen <= 8'b00000000;
      PI_s1_awmid <= 4'b1011;
      PI_s1_armid <= 4'b1110;
      PI_s1_arlen <= 8'b00000011;
      PI_s1_arvalid <= 1'b1;
      PI_s1_awvalid <= 1'b1;
      PI_s1_araddr <= 32'b10111011100000011110100000010001;
      PI_s1_awaddr <= 32'b10001011100001110110001111101000;
      PI_s1_awsize <= 3'b110;
      PI_s1_arsize <= 3'b011;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    // state 8
    if (cycle == 7) begin
      PI_s1_awlen <= 8'b01001000;
      PI_s1_awmid <= 4'b0010;
      PI_s1_armid <= 4'b0010;
      PI_s1_arlen <= 8'b01000000;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b11001100101110101111011111011101;
      PI_s1_awaddr <= 32'b10001101101010110010011111011101;
      PI_s1_awsize <= 3'b000;
      PI_s1_arsize <= 3'b001;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b0;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 9
    if (cycle == 8) begin
      PI_s1_awlen <= 8'b10100011;
      PI_s1_awmid <= 4'b1001;
      PI_s1_armid <= 4'b1001;
      PI_s1_arlen <= 8'b10100011;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b00111000110101011000111000110101;
      PI_s1_awaddr <= 32'b10010000110010010001111000110101;
      PI_s1_awsize <= 3'b110;
      PI_s1_arsize <= 3'b110;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 10
    if (cycle == 9) begin
      PI_s1_awlen <= 8'b01100000;
      PI_s1_awmid <= 4'b1100;
      PI_s1_armid <= 4'b0000;
      PI_s1_arlen <= 8'b11010010;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b10010000110101101000011010111001;
      PI_s1_awaddr <= 32'b00001111000100110000000010010000;
      PI_s1_awsize <= 3'b010;
      PI_s1_arsize <= 3'b111;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 11
    if (cycle == 10) begin
      PI_s1_awlen <= 8'b10000000;
      PI_s1_awmid <= 4'b0010;
      PI_s1_armid <= 4'b0010;
      PI_s1_arlen <= 8'b01010100;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b0;
      PI_s1_araddr <= 32'b01010001110110000010101101100110;
      PI_s1_awaddr <= 32'b01010001110110000010101101100110;
      PI_s1_awsize <= 3'b110;
      PI_s1_arsize <= 3'b100;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b1;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    // state 12
    if (cycle == 11) begin
      PI_s1_awlen <= 8'b00000000;
      PI_s1_awmid <= 4'b0001;
      PI_s1_armid <= 4'b0001;
      PI_s1_arlen <= 8'b00000100;
      PI_s1_arvalid <= 1'b1;
      PI_s1_awvalid <= 1'b1;
      PI_s1_araddr <= 32'b10010001001010000110110000000000;
      PI_s1_awaddr <= 32'b10010101011010000110000000000000;
      PI_s1_awsize <= 3'b110;
      PI_s1_arsize <= 3'b100;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b0;
      PI_cpu_telemetry_stall <= 1'b1;
    end

    // state 13
    if (cycle == 12) begin
      PI_s1_awlen <= 8'b01111001;
      PI_s1_awmid <= 4'b0001;
      PI_s1_armid <= 4'b0100;
      PI_s1_arlen <= 8'b10000000;
      PI_s1_arvalid <= 1'b0;
      PI_s1_awvalid <= 1'b1;
      PI_s1_araddr <= 32'b00000110000000000000000000010100;
      PI_s1_awaddr <= 32'b11110000010011011010000100001010;
      PI_s1_awsize <= 3'b111;
      PI_s1_arsize <= 3'b000;
      PI_resetn <= 1'b1;
      PI_cpu_telemetry_trap <= 1'b0;
      PI_cpu_telemetry_stall <= 1'b0;
    end

    genclock <= cycle < 13;
    cycle <= cycle + 1;
  end
endmodule
