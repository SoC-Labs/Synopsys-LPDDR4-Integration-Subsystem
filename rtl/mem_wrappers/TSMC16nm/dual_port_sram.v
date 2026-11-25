// Dual Port RAM module design

module dual_port_sram(
  input wire [63:0] din, //input data
  input wire [7:0] mask,
  input wire [6:0] r_addr, wr_addr, //Port A and Port B address
  input wire we, re, //write enable for Port A and Port B
  input wire clk, //clk
  output reg [63:0] dout //output data at Port A and Port B
);

wire [63:0] b_wem = {{8{~mask[7]}}, {8{~mask[6]}}, {8{~mask[5]}}, {8{~mask[4]}}, {8{~mask[3]}}, {8{~mask[2]}}, {8{~mask[1]}}, {8{~mask[0]}}};

// dual port SRAM instance
// Port A is write port and Port B is read port
TSDN16FFCLLULVTA128X64M4WSHO u_sram(
    .CLKA(clk),
    .AA(wr_addr),
    .DA(din),   // Write data input
    .BWEBA(b_wem),   // Bit write enable for port A
    .WEBA(~we),   // Write enable for port A
    .CEBA(~we),   // Chip enable for port A
    .QA(),

    .CLKB(clk),
    .AB(r_addr),   // Address for port B
    .DB(64'd0),   // Write data input for port B (not used)
    .BWEBB({64{1'b1}}),
    .WEBB(1'b1),
    .CEBB(~re),   // Chip enable for port B
    .QB(dout),   // Read data output for port B

    .SLP(1'b0),
    .DSLP(1'b0),
    .SD(1'b0),
    .PUDELAY(),
    .WTSEL(2'b01),
    .RTSEL(2'b01)
);


endmodule
