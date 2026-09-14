`timescale 1ps/1fs

module clk_rst_ctrl (
    output reg     clk,
    output reg     rstn
);



initial begin
    clk <= 1'b0;
    rstn <= 1'b1;
    #5000 clk <=1'b1;
    #20000 rstn <= 1'b0;
    #20000 rstn <= 1'b1;
end

always @(clk)
    #625 clk <= !clk;

endmodule
