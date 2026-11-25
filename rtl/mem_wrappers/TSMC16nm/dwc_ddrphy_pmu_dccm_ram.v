module dwc_ddrphy_pmu_dccm_ram (
  input				ls,	   // light sleep control - no behavioural modelling needed.
  input                           clk,      // clock input
  input   [31:0]      din,      // write data input

  input   [14:2]       addr,     // address for read or write
  input                           cs,       // RAM enable
  input                           we,       // memory write enable
  input   [3:0]        wem,      // byte write enables
  output  [31:0]      dout      // read data output
  
);
wire [31:0] b_wem = {{8{~wem[3]}}, {8{~wem[2]}}, {8{~wem[1]}}, {8{~wem[0]}}};

TS1N16FFCLLULVTA8192X32M8SWSHO u_sram(
    .Q(dout),
    .CLK(clk),
    .CEB(~cs),
    .WEB(~we),
    .A(addr),
    .D(din),
    .BWEB(b_wem),

    .SLP(ls),
    .DSLP(1'b0),
    .SD(1'b0),
    .PUDELAY(),
    .RTSEL(2'b01),
    .WTSEL(2'b00)
);

endmodule