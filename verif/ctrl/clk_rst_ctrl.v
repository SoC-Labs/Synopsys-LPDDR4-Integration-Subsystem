`timescale 1ps/1fs

module clk_rst_ctrl (
    output reg     clk,
    output reg     rstn
);



initial begin
    clk <= 1'b0;
    // Reset asserted from time 0 so no logic runs with X state before reset
    // (previously released at 0, asserted at 25 ns); released at 45 ns.
    rstn <= 1'b0;
    #5000 clk <=1'b1;
    #40000 rstn <= 1'b1;
end

always @(clk)
    #1250 clk <= !clk;

endmodule
