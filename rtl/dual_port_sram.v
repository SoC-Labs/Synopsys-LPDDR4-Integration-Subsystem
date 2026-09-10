// Dual Port RAM module design

module dual_port_sram(
  input wire [63:0] din, //input data
  input wire [7:0] mask,
  input wire [6:0] r_addr, wr_addr, //Port A and Port B address
  input wire we, re, //write enable for Port A and Port B
  input wire clk, //clk
  output reg [63:0] dout //output data at Port A and Port B
);

  reg [6:0] bram0 [7:0]; //8*64 bit ram
  reg [6:0] bram1 [7:0]; //8*64 bit ram
  reg [6:0] bram2 [7:0]; //8*64 bit ram
  reg [6:0] bram3 [7:0]; //8*64 bit ram
  reg [6:0] bram4 [7:0]; //8*64 bit ram
  reg [6:0] bram5 [7:0]; //8*64 bit ram
  reg [6:0] bram6 [7:0]; //8*64 bit ram
  reg [6:0] bram7 [7:0]; //8*64 bit ram


  always @ (posedge clk)
    begin
      if(we&mask[0])
        bram0[wr_addr] <= din[ 7: 0];
      if(we&mask[1])
        bram1[wr_addr] <= din[15: 8];
      if(we&mask[2])
        bram2[wr_addr] <= din[23:16];
      if(we&mask[3])
        bram3[wr_addr] <= din[31:24];
      if(we&mask[4])
        bram4[wr_addr] <= din[39:32];
      if(we&mask[5])
        bram5[wr_addr] <= din[47:40];
      if(we&mask[6])
        bram6[wr_addr] <= din[55:48];
      if(we&mask[7])
        bram7[wr_addr] <= din[63:56];

    end

  always @ (posedge clk)
    begin
      if(re)
        dout <= {bram7[r_addr],bram6[r_addr],bram5[r_addr],bram4[r_addr],bram3[r_addr],bram2[r_addr],bram1[r_addr],bram0[r_addr]};
    end

endmodule
