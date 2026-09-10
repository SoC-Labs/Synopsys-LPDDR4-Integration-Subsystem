module axi_tb();

    export "DPI-C" function sayHello;
    export "DPI-C" function endSim;
    import "DPI-C" context task something();
    initial #100 something();

    function int sayHello();
        $display("Hello world");
        sayHello = 1;
    endfunction

    function void endSim();
        $display("End Sim called");
        $finish;
    endfunction

    wire CLK;
    wire RSTn;
    clk_rst_ctrl u_clk_rst_ctrl(
        .clk(CLK),
        .rstn(RSTn)
    );

    parameter ID_W = 9;
    axi4 #(.DATA_W(64), .ID_W(ID_W), .ADDR_W(33)) DRAM_AXI();

    dpi_axi u_dpi_axi(
        .ACLK(CLK),
        .ARESETn(RSTn),
        .DRAM_AXI(DRAM_AXI)
    );

endmodule