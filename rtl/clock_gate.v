module clock_gate (
    input  wire clk,
    input  wire enable,
    output wire gated_clk
);

  reg enable_latch;

  // Transparent when clk is low (negelatch behavior)
  always_latch begin
    if (!clk)
      enable_latch = enable;
  end

  // AND gate to mask the clock safely
  assign gated_clk = clk & enable_latch;

endmodule
