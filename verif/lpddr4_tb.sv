module lpddr4_tb();

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

    wire        DDR_RESET_n;
    wire        DDR_CK_t;
    wire        DDR_CK_c;
    wire [1:0]  DDR_CKE;
    wire [1:0]  DDR_CS;
    wire [5:0]  DDR_CA;
    wire        DDR_ODT;
    wire [1:0]  DDR_DQS_t;
    wire [1:0]  DDR_DQS_c;
    wire [15:0] DDR_DQ;
    wire [1:0]  DDR_DMI;
    wire        DDR_ALERT_N;
    supply1     DDR_VREF;
    wire        DDR_ZN_SENSE;
    wire        DDR_ZN;

    assign DDR_ZN_SENSE = 1'b0;
    pullup(DDR_ALERT_N);

    parameter ID_W = 9;
    axi4 #(.DATA_W(64), .ID_W(ID_W), .ADDR_W(33)) DRAM_AXI();
    qchannel DRAM_SYS_Qchannel();
    qchannel DRAM_DDRC_Qchannel();

    assign DRAM_SYS_Qchannel.qreqn = 1'b1;
    assign DRAM_DDRC_Qchannel.qreqn = 1'b1;

    apb3 DRAM_CFG_APB();
    apb4 DRAM_PHY_CFG_APB();

    dpi_apb u_dpi_apb(
        .PCLK(CLK),
        .PRESETn(RSTn),
        .DRAM_CFG_APB_master(DRAM_CFG_APB),
        .DRAM_PHY_CFG_APB_master(DRAM_PHY_CFG_APB)
    );

    // SVT AXI master VIP attached to the wrapper's subordinate AXI port.
    // Not enabled yet: the UVM test is suppressed (ENABLE=0) and the internal
    // slave VIP is not connected (CONNECT_SLAVE=0) so dram_wrapper remains the
    // sole subordinate.  Testing comes later.
    dpi_axi #(
        .CONNECT_SLAVE(1'b0),
        .ENABLE(1'b0)
    ) u_dpi_axi(
        .ACLK(CLK),
        .ARESETn(RSTn),
        .DRAM_AXI(DRAM_AXI)
    );

    lpddr_model memory(
        .ck_c    (DDR_CK_t),
        .ck_t    (DDR_CK_c),
        .cke     (DDR_CKE[0]),
        .cs_n    (DDR_CS[0]),
        .odt     (1'b0),
        .ca      (DDR_CA),
        .dm      (DDR_DMI),
        .dqs_t   (DDR_DQS_t),
        .dqs_c   (DDR_DQS_c),
        .dq      (DDR_DQ),
        .reset_n (DDR_RESET_n)
    );

    dram_wrapper #(.ID_W(ID_W)) u_dram_wrapper(
        .ACLK(CLK),
        .ARESETn(RSTn),
        .PCLK(CLK),
        .PRESETn(RSTn),
        .DRAM_AXI(DRAM_AXI),
        .DRAM_AXI_AWQOS(4'h0),
        .DRAM_AXI_ARQOS(4'h0),
        .DRAM_CFG_APB(DRAM_CFG_APB),
        .DRAM_PHY_CFG_APB(DRAM_PHY_CFG_APB),
        .DRAM_SYS_Qchannel(DRAM_SYS_Qchannel),
        .DRAM_DDRC_Qchannel(DRAM_DDRC_Qchannel),
        .PHY_IRQ(),
        .ecc_corrected_err_intr(),
        .ecc_corrected_err_intr_fault(),
        .ecc_uncorrected_err_intr(),
        .ecc_uncorrected_err_intr_fault(),
        .dfi_alert_err_intr(),
        .derate_temp_limit_intr(),
        .derate_temp_limit_intr_fault(),
        .DDR4_RESET_N(DDR_RESET_n),
        .DDR4_CK_T(DDR_CK_t),
        .DDR4_CK_C(DDR_CK_c),
        .DDR4_CKE(DDR_CKE),
        .DDR4_CS_N(DDR_CS),
        .DDR4_ADR(DDR_CA),
        .DDR4_ODT(DDR_ODT),
        .DDR4_DQS_T(DDR_DQS_t),
        .DDR4_DQS_C(DDR_DQS_c),
        .DDR4_DQ(DDR_DQ),
        .DDR4_DM_DBI_N(DDR_DMI),
        .DDR4_ALERT_N(DDR_ALERT_N),
        .DDR4_VREF(DDR_VREF),
        .DDR4_ZN_SENSE(DDR_ZN_SENSE),
        .DDR4_ZN(DDR_ZN)
    );

endmodule