module dwc_ddrphy_pmu_iccm_ram 
                 #(
  parameter  par_data_msb =  31,
  parameter  par_be_msb   =  3,
  parameter  par_addr_msb =  19,
  parameter  par_addr_lsb =  2
                  )
                                       (
  input				ls,	   // light sleep control - no behavioural modelling needed.
  input                                clk,      // clock input
  input   [par_data_msb: 0]            din,      // write data input
  input   [par_addr_msb:par_addr_lsb]  addr,     // address for read or write
  input                                cs,       // RAM chip select, active high
  input                                we,       // memory write enable, active high
  input   [par_be_msb             :0]  wem,      // byte write enables, active high
  output  [par_data_msb           :0]  dout      // read data output
                                       );


wire [31:0] b_wem = {{8{wem[3]}}, {8{wem[2]}}, {8{wem[1]}}, {8{wem[0]}}};

iccm_sram u_sram(
    .Q(dout),
    .CLK(clk),
    .CEN(~cs),
    .GWEN(~we),
    .A(addr),
    .D(din),
    .WEN(b_wem),
    .STOV(1'b0),
    .EMA(3'b011),
    .EMAW(2'b01),
    .EMAS(1'b0),
    .RET1N(1'b1)
);

endmodule
