

module phy_reset_ctrl(
    input  wire         pclk,
    input  wire         presetn,

    input  wire [11:0]  paddr,
    input  wire         pwrite,
    input  wire         psel,
    input  wire         penable,
    input  wire [31:0]  pwdata,
    output wire         pready,
    output reg  [31:0]  prdata,
    output wire         pslverr,

    output reg          ddrphy_pwrok,
    output reg          ddrphy_reset,
    output reg          ddrcore_rstn,
    output reg          ddrctrl_presetn,
    output reg          ddrctrl_aclken,
    output reg          ddrctrl_pclken
);

wire apb_read_en;
wire apb_write_en;
wire [5:0] apb_wr_sel;

// APB Control
assign apb_read_en = psel & (~pwrite);
assign apb_write_en = psel & (~penable) & pwrite;

assign pready = 1'b1; // Always ready
assign pslverr = 1'b0; // Always OK

assign apb_wr_sel[0] = ((paddr[4:2]==3'h0)&apb_write_en) ? 1'b1: 1'b0;
assign apb_wr_sel[1] = ((paddr[4:2]==3'h1)&apb_write_en) ? 1'b1: 1'b0;
assign apb_wr_sel[2] = ((paddr[4:2]==3'h2)&apb_write_en) ? 1'b1: 1'b0;
assign apb_wr_sel[3] = ((paddr[4:2]==3'h3)&apb_write_en) ? 1'b1: 1'b0;
assign apb_wr_sel[4] = ((paddr[4:2]==3'h4)&apb_write_en) ? 1'b1: 1'b0;
assign apb_wr_sel[5] = ((paddr[4:2]==3'h5)&apb_write_en) ? 1'b1: 1'b0;

always @(posedge pclk or negedge presetn) begin
    if(~presetn)
        ddrphy_reset <= 1'b0;
    else begin
        if(apb_wr_sel[0]) begin
            ddrphy_reset <= pwdata[0];
        end
    end
end

always @(posedge pclk or negedge presetn) begin
    if(~presetn)
        ddrphy_pwrok <= 1'b0;
    else begin
        if(apb_wr_sel[1]) begin
            ddrphy_pwrok <= pwdata[0];
        end
    end
end

always @(posedge pclk or negedge presetn) begin
    if(~presetn)
        ddrcore_rstn <= 1'b1;
    else begin
        if(apb_wr_sel[2]) begin
            ddrcore_rstn <= pwdata[0];
        end
    end
end

always @(posedge pclk or negedge presetn) begin
    if(~presetn)
        ddrctrl_presetn <= 1'b1;
    else begin
        if(apb_wr_sel[3]) begin
            ddrctrl_presetn <= pwdata[0];
        end
    end
end

always @(posedge pclk or negedge presetn) begin
    if(~presetn)
        ddrctrl_aclken <= 1'b0;
    else begin
        if(apb_wr_sel[3]) begin
            ddrctrl_aclken <= pwdata[0];
        end
    end
end

always @(posedge pclk or negedge presetn) begin
    if(~presetn)
        ddrctrl_pclken <= 1'b0;
    else begin
        if(apb_wr_sel[3]) begin
            ddrctrl_pclken <= pwdata[0];
        end
    end
end

always @(apb_read_en or paddr or ddrctrl_pclken or ddrphy_pwrok or ddrcore_rstn or ddrctrl_aclken or ddrphy_reset or  ddrctrl_presetn or prdata) begin
    case(apb_read_en)
        1'b1: begin
            case(paddr[4:2])
                3'h0: prdata = {31'd0,ddrphy_reset};
                3'h1: prdata = {31'd0,ddrphy_pwrok};
                3'h2: prdata = {31'd0,ddrcore_rstn};
                3'h3: prdata = {31'd0,ddrctrl_presetn};
                3'h4: prdata = {31'd0,ddrctrl_aclken};
                3'h5: prdata = {31'd0,ddrctrl_pclken};
                3'h7: prdata = 32'h534C4951;
                default: prdata = 32'hDEADBEEF;
            endcase
        end
        1'b0:
            prdata = 32'd0;
    endcase
end



endmodule
