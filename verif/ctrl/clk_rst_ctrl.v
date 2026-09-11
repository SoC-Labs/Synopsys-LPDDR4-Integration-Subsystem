
module clk_rst_ctrl (
    output reg     clk,
    output reg     rstn
);



initial begin
    clk <= 1'b0;
    rstn <= 1'b1;
    #5 clk <=1'b1;
    #20 rstn <= 1'b0;
    #20 rstn <= 1'b1;
end

always @(clk)
    #1 clk <= !clk;

endmodule
