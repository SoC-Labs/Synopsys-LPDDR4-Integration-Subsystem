`default_nettype wire

module dram_wrapper #(
    parameter ID_W=6
    )(
    input  wire             ACLK,
    input  wire             ARESETn,

    input  wire             PCLK,
    input  wire             PRESETn,

    axi4.subordinate        DRAM_AXI,
    input  wire [3:0]       DRAM_AXI_AWQOS,
    input  wire [3:0]       DRAM_AXI_ARQOS,
    apb3.subordinate        DRAM_CFG_APB,
    apb4.subordinate        DRAM_PHY_CFG_APB,

    // Low power interfaces
    qchannel.subordinate    DRAM_SYS_Qchannel,
    qchannel.subordinate    DRAM_DDRC_Qchannel,

    // Interrupt signals
    output wire             PHY_IRQ,
    output wire             ecc_corrected_err_intr,
    output wire             ecc_corrected_err_intr_fault,
    output wire             ecc_uncorrected_err_intr,
    output wire             ecc_uncorrected_err_intr_fault,
    output wire             dfi_alert_err_intr,
    output wire             derate_temp_limit_intr,
    output wire             derate_temp_limit_intr_fault,

    // LPDDR4 Signals
    output wire             DDR4_RESET_N,
    output wire             DDR4_CK_T,
    output wire             DDR4_CK_C,
    output wire [1:0]       DDR4_CKE,
    output wire [1:0]       DDR4_CS_N,
    output wire [5:0]       DDR4_ADR,
    output wire             DDR4_ODT,
    inout  wire [1:0]       DDR4_DQS_T,
    inout  wire [1:0]       DDR4_DQS_C,
    inout  wire [15:0]      DDR4_DQ,
    inout  wire [1:0]       DDR4_DM_DBI_N,

    inout  wire             DDR4_ALERT_N,
    inout  wire             DDR4_VREF,
    input  wire             DDR4_ZN_SENSE,
    output wire             DDR4_ZN
);


assign DRAM_SYS_Qchannel.qdeny = 1'b0;
assign DRAM_DDRC_Qchannel.qdeny = 1'b0;

// Write Data RAM interface signals
wire [63:0]     wdataram_din;
wire [63:0]     wdataram_dout;
wire [7:0]      wdataram_mask;
wire            wdataram_wr;
wire            wdataram_re;
wire [6:0]      wdataram_waddr;
wire [6:0]      wdataram_raddr;
// DFI interface signals
wire [1:0]      dfi_act_n;
wire [39:0]     dfi_address;
wire [5:0]      dfi_bank;
wire [1:0]      dfi_freq_ratio;
wire [3:0]      dfi_bg;
wire [1:0]      dfi_cas_n;
wire [1:0]      dfi_ras_n;
wire [1:0]      dfi_we_n;
wire [1:0]      dfi_cke;
wire [1:0]      dfi_cs;

wire [1:0]      dfi_odt;
wire [1:0]      dfi_reset_n;

wire [95:0]     dfi_wrdata;
wire [11:0]     dfi_wrdata_mask;
wire [5:0]      dfi_wrdata_en;

wire [95:0]     dfi_rddata;
wire [5:0]      dfi_rddata_en;
wire [5:0]      dfi_rddata_valid;

wire [11:0]     dfi_rddata_dbi;  // read data DBI from PHY (active low)

wire [5:0]      dfi_wrdata_cs;
wire [5:0]      dfi_rddata_cs;

wire            ctl_idle;
wire            dfi_reset_n_in;
wire            dfi_reset_n_ref;
wire            init_mr_done_in;
wire            init_mr_done_out;

wire            dfi_ctrlupd_ack;           // this ack is from PHY
wire            dfi_ctrlupd_ack2;          // this ack is from IO Calib
wire            dfi_ctrlupd_req;

wire            dfi_dram_clk_disable;

wire [1:0]      dfi_parity_in;

wire [1:0]      dfi_alert_n;
wire            dfi_init_complete;

wire            dfi_init_start;
wire [4:0]      dfi_frequency;

wire            dfi_geardown_en;

wire            dfi_lp_req;         // DFI LP request
wire            dfi_lp_ack;         // DFI LP acknowledge
wire            dfi_phyupd_req;     // DFI PHY update request 
wire            dfi_phyupd_ack;     // DFI PHY update acknowledge 

wire [1:0]      dfi_phyupd_type;  // DFI PHY update type 
wire [3:0]      dfi_lp_wakeup;    // DFI LP wakeup

wire            dfi_phymstr_req;        // DFI PHY Master Interface request
wire [1:0]      dfi_phymstr_cs_state;   // DFI PHY Master Interface CS state
wire            dfi_phymstr_state_sel;  // DFI PHY Master Interface state select
wire [1:0]      dfi_phymstr_type;       // DFI PHY Master Interface time type
wire            dfi_phymstr_ack;        // DFI PHY Master Interface acknowledge

// Interrupt signals
wire            dwc_ddrphy_int_n;
wire            dis_regs_ecc_syndrome;

assign PHY_IRQ = ~dwc_ddrphy_int_n;
// CCM SRAM Connections
wire [31:0]  iccm_data_dout;
wire [31:0]  iccm_data_din;
wire [14:0]  iccm_data_addr;
wire         iccm_data_ce;
wire         iccm_data_we;
wire [ 3:0]  iccm_data_wem;

wire [31:0]  dccm_data_dout;
wire [31:0]  dccm_data_din;
wire [14:0]  dccm_data_addr;
wire         dccm_data_ce;
wire         dccm_data_we;
wire [3:0]   dccm_data_wem;

assign iccm_data_addr[1:0]=2'b00;
assign dccm_data_addr[1:0]=2'b00;

wire        pmu_sram_clk_gated;

wire        ddr_phy_reset;
wire        ddr_phy_pwrok;
wire        ddr_core_rstn;

apb3        DRAM_RST_CTRL_APB();
apb3        DRAM_CFG_APB_i();

assign DRAM_RST_CTRL_APB.paddr = DRAM_CFG_APB.paddr;
assign DRAM_RST_CTRL_APB.penable = DRAM_CFG_APB.penable;
assign DRAM_RST_CTRL_APB.pwrite = DRAM_CFG_APB.pwrite;
assign DRAM_RST_CTRL_APB.pwdata = DRAM_CFG_APB.pwdata;

assign DRAM_CFG_APB_i.paddr = DRAM_CFG_APB.paddr;
assign DRAM_CFG_APB_i.penable = DRAM_CFG_APB.penable;
assign DRAM_CFG_APB_i.pwrite = DRAM_CFG_APB.pwrite;
assign DRAM_CFG_APB_i.pwdata = DRAM_CFG_APB.pwdata;
assign DRAM_PHY_CFG_APB.prdata[31:16]=16'h0000;

wire [5:0] DRAM_CFG_APB_i_psel_mux;
assign DRAM_CFG_APB_i.psel = |DRAM_CFG_APB_i_psel_mux;
cmsdk_apb_slave_mux #(
    .PORT0_ENABLE(1),
    .PORT1_ENABLE(1),
    .PORT2_ENABLE(1),
    .PORT3_ENABLE(1),
    .PORT4_ENABLE(1),
    .PORT5_ENABLE(1),
    .PORT6_ENABLE(1),
    .PORT7_ENABLE(0),
    .PORT8_ENABLE(0),
    .PORT9_ENABLE(0),
    .PORT10_ENABLE(0),
    .PORT11_ENABLE(0),
    .PORT12_ENABLE(0),
    .PORT13_ENABLE(0),
    .PORT14_ENABLE(0),
    .PORT15_ENABLE(0)
) u_ddr_ctrl_mux (
    .DECODE4BIT(DRAM_CFG_APB.paddr[15:12]),
    .PSEL(DRAM_CFG_APB.psel),

    .PSEL0(DRAM_CFG_APB_i_psel_mux[0]),
    .PREADY0(DRAM_CFG_APB_i.pready),
    .PRDATA0(DRAM_CFG_APB_i.prdata),
    .PSLVERR0(DRAM_CFG_APB_i.pslverr),

    .PSEL1(DRAM_CFG_APB_i_psel_mux[1]),
    .PREADY1(DRAM_CFG_APB_i.pready),
    .PRDATA1(DRAM_CFG_APB_i.prdata),
    .PSLVERR1(DRAM_CFG_APB_i.pslverr),

    .PSEL2(DRAM_CFG_APB_i_psel_mux[2]),
    .PREADY2(DRAM_CFG_APB_i.pready),
    .PRDATA2(DRAM_CFG_APB_i.prdata),
    .PSLVERR2(DRAM_CFG_APB_i.pslverr),

    .PSEL3(DRAM_CFG_APB_i_psel_mux[3]),
    .PREADY3(DRAM_CFG_APB_i.pready),
    .PRDATA3(DRAM_CFG_APB_i.prdata),
    .PSLVERR3(DRAM_CFG_APB_i.pslverr),

    .PSEL4(DRAM_CFG_APB_i_psel_mux[4]),
    .PREADY4(DRAM_CFG_APB_i.pready),
    .PRDATA4(DRAM_CFG_APB_i.prdata),
    .PSLVERR4(DRAM_CFG_APB_i.pslverr),

    .PSEL5(DRAM_CFG_APB_i_psel_mux[5]),
    .PREADY5(DRAM_CFG_APB_i.pready),
    .PRDATA5(DRAM_CFG_APB_i.prdata),
    .PSLVERR5(DRAM_CFG_APB_i.pslverr),

    .PSEL6(DRAM_RST_CTRL_APB.psel),
    .PREADY6(DRAM_RST_CTRL_APB.pready),
    .PRDATA6(DRAM_RST_CTRL_APB.prdata),
    .PSLVERR6(DRAM_RST_CTRL_APB.pslverr),

    .PREADY(DRAM_CFG_APB.pready),
    .PRDATA(DRAM_CFG_APB.prdata),
    .PSLVERR(DRAM_CFG_APB.pslverr)

);

phy_reset_ctrl u_ddr_phy_reset_ctrl(
    .pclk(PCLK),
    .presetn(PRESETn),
    .paddr(DRAM_RST_CTRL_APB.paddr[11:0]),
    .pwrite(DRAM_RST_CTRL_APB.pwrite),
    .psel(DRAM_RST_CTRL_APB.psel),
    .penable(DRAM_RST_CTRL_APB.penable),
    .pwdata(DRAM_RST_CTRL_APB.pwdata),
    .pready(DRAM_RST_CTRL_APB.pready),
    .prdata(DRAM_RST_CTRL_APB.prdata),
    .pslverr(DRAM_RST_CTRL_APB.pslverr),
    .ddrphy_pwrok(ddr_phy_pwrok),
    .ddrphy_reset(ddr_phy_reset),
    .ddrcore_rstn(ddr_core_rstn)
);

DWC_ddr_umctl2 u_snps_ddr_ctrl (
    .core_ddrc_core_clk(ACLK),
    .core_ddrc_rstn(ddr_core_rstn),

    .aresetn_0(ARESETn),
    .aclk_0(ACLK),
// AXI Port 0 Write Address Channel
//-----------------------------------------------
    .awid_0(DRAM_AXI.AWID),
    .awaddr_0(DRAM_AXI.AWADDR[30:0]),
    .awlen_0(DRAM_AXI.AWLEN),
    .awsize_0(DRAM_AXI.AWSIZE),
    .awburst_0(DRAM_AXI.AWBURST),
    .awlock_0(DRAM_AXI.AWLOCK),
    .awcache_0(DRAM_AXI.AWCACHE),
    .awprot_0(DRAM_AXI.AWPROT),
    .awvalid_0(DRAM_AXI.AWVALID),
    .awready_0(DRAM_AXI.AWREADY),
    .awqos_0(DRAM_AXI_AWQOS),
    .awurgent_0(1'b0),
    .awpoison_0(1'b0),
    .awpoison_intr_0(),
    .awregion_0(4'h0),
    .waq_wcount_0(),
    .waq_pop_0(),
    .waq_push_0(),
    .waq_split_0(),
    .awautopre_0(DRAM_AXI.AWVALID),
// AXI Port 0 Write Data Channel
    .wdata_0(DRAM_AXI.WDATA),
    .wstrb_0(DRAM_AXI.WSTRB),
    .wlast_0(DRAM_AXI.WLAST),
    .wvalid_0(DRAM_AXI.WVALID),
    .wready_0(DRAM_AXI.WREADY),
// AXI Port 0 Write Response Channel
//-----------------------------------------------
    .bid_0(DRAM_AXI.BID),
    .bresp_0(DRAM_AXI.BRESP),
    .bvalid_0(DRAM_AXI.BVALID),
    .bready_0(DRAM_AXI.BREADY),

// AXI Port 0 Read Address Channel
//-----------------------------------------------
    .arid_0(DRAM_AXI.ARID),
    .araddr_0(DRAM_AXI.ARADDR[30:0]),
    .arlen_0(DRAM_AXI.ARLEN),
    .arsize_0(DRAM_AXI.ARSIZE),
    .arburst_0(DRAM_AXI.ARBURST),
    .arlock_0(DRAM_AXI.ARLOCK),
    .arcache_0(DRAM_AXI.ARCACHE),
    .arprot_0(DRAM_AXI.ARPROT),
    .arvalid_0(DRAM_AXI.ARVALID),
    .arready_0(DRAM_AXI.ARREADY),
    .arqos_0(DRAM_AXI_ARQOS),
    .arpoison_0(1'b0),
    .arpoison_intr_0(),
    .arregion_0(4'h0),
    .arurgent_0(1'b0),
    .raq_wcount_0(),
    .raq_pop_0(),
    .raq_push_0(),
    .raq_split_0(),
    .arautopre_0(DRAM_AXI.ARVALID),
// AXI Port 0 Read Data Channel
//-----------------------------------------------
    .rid_0(DRAM_AXI.RID),
    .rdata_0(DRAM_AXI.RDATA),
    .rresp_0(DRAM_AXI.RRESP),
    .rlast_0(DRAM_AXI.RLAST),
    .rvalid_0(DRAM_AXI.RVALID),
    .rready_0(DRAM_AXI.RREADY),

    .csysreq_0(DRAM_SYS_Qchannel.qreqn),
    .csysack_0(DRAM_SYS_Qchannel.qacceptn),
    .cactive_0(DRAM_SYS_Qchannel.qactive),

    .wdataram_din(wdataram_din),
    .wdataram_dout(wdataram_dout),
    .wdataram_mask(wdataram_mask),
    .wdataram_wr(wdataram_wr),
    .wdataram_waddr(wdataram_waddr),
    .wdataram_re(wdataram_re),
    .wdataram_raddr(wdataram_raddr),

//--------------------------------------------------------------------------------
// Interface signals for use of external SRAM for crc_parity_retry_wdata_fifo
//--------------------------------------------------------------------------------

    .hif_mrr_data(),
    .hif_mrr_data_valid(),

    .csysreq_ddrc(DRAM_DDRC_Qchannel.qreqn),
    .csysack_ddrc(DRAM_DDRC_Qchannel.qacceptn),
    .cactive_ddrc(DRAM_DDRC_Qchannel.qactive),
    .stat_ddrc_reg_selfref_type(),



    .lpr_credit_cnt(),
    .hpr_credit_cnt(),
    .wr_credit_cnt(),

    .pa_rmask(2'b00),

    .pa_wmask(2'b00),

    .dfi_act_n(dfi_act_n),
    .dfi_address(dfi_address),
    .dfi_bank(dfi_bank),

    .dfi_freq_ratio(dfi_freq_ratio),
    .dfi_bg(dfi_bg),
    .dfi_cas_n(dfi_cas_n),
    .dfi_cke(dfi_cke),
    .dfi_cs(dfi_cs),
    .dfi_odt(dfi_odt),
    .dfi_ras_n(dfi_ras_n),
    .dfi_reset_n(dfi_reset_n),
    .dfi_we_n(dfi_we_n),
    .dfi_reset_n_in(1'b1),
    .init_mr_done_in(1'b1),

    .dfi_wrdata(dfi_wrdata),
    .dfi_wrdata_en(dfi_wrdata_en),
    .dfi_wrdata_mask(dfi_wrdata_mask),

    .dfi_rddata(dfi_rddata),
    .dfi_rddata_en(dfi_rddata_en),
    .dfi_rddata_valid({2'b00,dfi_rddata_valid[3:0]}),
    .dfi_rddata_dbi(dfi_rddata_dbi),
    
    .dfi_wrdata_cs(dfi_wrdata_cs),
    .dfi_rddata_cs(dfi_rddata_cs),


    .ctl_idle(ctl_idle),

    .dfi_ctrlupd_req(dfi_ctrlupd_req),
    .dfi_ctrlupd_ack(dfi_ctrlupd_ack),
    .dfi_ctrlupd_ack2(1'b0),

    .dfi_dram_clk_disable(dfi_dram_clk_disable),

    .dfi_parity_in(dfi_parity_in),
    .dfi_alert_n(2'b11),

    .dfi_init_complete(dfi_init_complete),

    .dfi_init_start(dfi_init_start),

    .dfi_frequency(dfi_frequency),

    .dfi_phyupd_req(dfi_phyupd_req),

    .dfi_phyupd_type(dfi_phyupd_type),

    .dfi_phyupd_ack(dfi_phyupd_ack),

    .dfi_lp_req(dfi_lp_req),
    .dfi_lp_wakeup(dfi_lp_wakeup),
    .dfi_lp_ack(dfi_lp_ack),

    .dfi_phymstr_req(dfi_phymstr_req),

    .dfi_phymstr_cs_state(dfi_phymstr_cs_state[0]),

    .dfi_phymstr_state_sel(dfi_phymstr_state_sel),

    .dfi_phymstr_type(dfi_phymstr_type),

    .dfi_phymstr_ack(dfi_phymstr_ack),

    .dis_regs_ecc_syndrome(1'b0),
    .ecc_corrected_err_intr(ecc_corrected_err_intr),
    .ecc_corrected_err_intr_fault(ecc_corrected_err_intr_fault),
    .ecc_uncorrected_err_intr(ecc_uncorrected_err_intr),
    .ecc_uncorrected_err_intr_fault(ecc_uncorrected_err_intr_fault),

    .dfi_alert_err_intr(dfi_alert_err_intr),
    .scanmode(1'b0),
    .scan_resetn(ARESETn),

    .pclk(PCLK),
    .presetn(PRESETn),
    .paddr(DRAM_CFG_APB_i.paddr[11:0]),
    .pwdata(DRAM_CFG_APB_i.pwdata),
    .pwrite(DRAM_CFG_APB_i.pwrite),
    .psel(DRAM_CFG_APB_i.psel),
    .penable(DRAM_CFG_APB_i.penable),
    .pready(DRAM_CFG_APB_i.pready),
    .prdata(DRAM_CFG_APB_i.prdata),
    .pslverr(DRAM_CFG_APB_i.pslverr),

    .hif_refresh_req_bank(),

    .derate_temp_limit_intr(derate_temp_limit_intr),
    .derate_temp_limit_intr_fault(derate_temp_limit_intr_fault)
);

dram_PHY u_dram_PHY(
    .APBCLK(PCLK),
    .DfiClk(ACLK),
    .DfiCtlClk(ACLK),
    .BypassPclk(ACLK),

    .PRESETn_APB(~ddr_phy_reset),

    .Reset(ddr_phy_reset),
    .PwrOk(ddr_phy_pwrok),
    .PADDR_APB(DRAM_PHY_CFG_APB.paddr),
    .PWRITE_APB(DRAM_PHY_CFG_APB.pwrite),
    .PSELx_APB(DRAM_PHY_CFG_APB.psel),
    .PENABLE_APB(DRAM_PHY_CFG_APB.penable),
    .PWDATA_APB(DRAM_PHY_CFG_APB.pwdata[15:0]),
    .PSTRB_APB(DRAM_PHY_CFG_APB.pstrb[1:0]),
    .PPROT_APB(DRAM_PHY_CFG_APB.pprot),
    .PREADY_APB(DRAM_PHY_CFG_APB.pready),
    .PRDATA_APB(DRAM_PHY_CFG_APB.prdata[15:0]),
    .PSLVERR_APB(DRAM_PHY_CFG_APB.pslverr),
    .PPROT_PIN(3'h1),

    .dfi_reset_n(dfi_reset_n[0]),
    .dfi0_ctrlupd_ack(dfi_ctrlupd_ack),
    .dfi0_ctrlupd_req(dfi_ctrlupd_req),
    .dfi0_phyupd_ack(dfi_phyupd_ack),
    .dfi0_phyupd_req(dfi_phyupd_req),
    .dfi0_phyupd_type(dfi_phyupd_type),
    .dfi0_dram_clk_disable(dfi_dram_clk_disable),
    .dfi0_freq(dfi_frequency),
    .dfi0_freq_ratio(dfi_freq_ratio),
    .dfi0_init_complete(dfi_init_complete),
    .dfi0_init_start(dfi_init_start),
    .dfi0_phymstr_ack(dfi_phymstr_ack),
    .dfi0_phymstr_cs_state(dfi_phymstr_cs_state),
    .dfi0_phymstr_req(dfi_phymstr_req),
    .dfi0_phymstr_state_sel(dfi_phymstr_state_sel),
    .dfi0_phymstr_type(dfi_phymstr_type),

    .dfi0_address_P0(dfi_address[5:0]),
    .dfi0_address_P1(dfi_address[25:20]),
    .dfi0_address_P2(6'h0),
    .dfi0_address_P3(6'h0),
    .dfi0_cke_P0(dfi_cke),
    .dfi0_cke_P1(dfi_cke),
    .dfi0_cke_P2(dfi_cke),
    .dfi0_cke_P3(dfi_cke),
    .dfi0_cs_P0({1'b1,dfi_cs[0]}),
    .dfi0_cs_P1({1'b1,dfi_cs[1]}),
    .dfi0_cs_P2(2'b11),
    .dfi0_cs_P3(2'b11),
    .dfi0_lp_ack(dfi_lp_ack),
    .dfi0_lp_ctrl_req(dfi_lp_req),
    .dfi0_lp_data_req(dfi_lp_req),
    .dfi0_lp_wakeup(dfi_lp_wakeup),
    .dfi0_error(),
    .dfi0_error_info(),

    .dfi_wrdata_P0(dfi_wrdata[31:0]),
    .dfi_wrdata_P1(dfi_wrdata[63:32]),
    .dfi_wrdata_P2(32'd0),
    .dfi_wrdata_P3(32'd0),
    .dfi_wrdata_cs_n_P0({dfi_wrdata_cs[1:0],dfi_wrdata_cs[1:0]}),
    .dfi_wrdata_cs_n_P1({dfi_wrdata_cs[3:2],dfi_wrdata_cs[3:2]}),
    .dfi_wrdata_cs_n_P2(4'b1111),
    .dfi_wrdata_cs_n_P3(4'b1111),
    .dfi_wrdata_en_P0(dfi_wrdata_en[1:0]),
    .dfi_wrdata_en_P1(dfi_wrdata_en[3:2]),
    .dfi_wrdata_en_P2(2'b00),
    .dfi_wrdata_en_P3(2'b00),
    .dfi_wrdata_mask_P0(dfi_wrdata_mask[3:0]),
    .dfi_wrdata_mask_P1(dfi_wrdata_mask[7:4]),
    .dfi_wrdata_mask_P2(4'b0000),
    .dfi_wrdata_mask_P3(4'b0000),
    .dfi_rddata_W0(dfi_rddata[31:0]),
    .dfi_rddata_W1(dfi_rddata[63:32]),
    .dfi_rddata_W2(),
    .dfi_rddata_W3(),
    .dfi_rddata_cs_n_P0({dfi_rddata_cs[1:0],dfi_rddata_cs[1:0]}),
    .dfi_rddata_cs_n_P1({dfi_rddata_cs[3:2],dfi_rddata_cs[3:2]}),
    .dfi_rddata_cs_n_P2(4'b1111),
    .dfi_rddata_cs_n_P3(4'b1111),
    .dfi_rddata_dbi_W0(dfi_rddata_dbi[3:0]),
    .dfi_rddata_dbi_W1(dfi_rddata_dbi[7:4]),
    .dfi_rddata_dbi_W2(),
    .dfi_rddata_dbi_W3(),
    .dfi_rddata_en_P0(dfi_rddata_en[1:0]),
    .dfi_rddata_en_P1(dfi_rddata_en[3:2]),
    .dfi_rddata_en_P2(2'b00),
    .dfi_rddata_en_P3(2'b00),
    .dfi_rddata_valid_W0(dfi_rddata_valid[1:0]),
    .dfi_rddata_valid_W1(dfi_rddata_valid[3:2]),
    .dfi_rddata_valid_W2(),
    .dfi_rddata_valid_W3(),

    .WSI(1'b0),
    .TDRCLK(ACLK),
    .WRSTN(ARESETn),
    .DdrPhyCsrCmdTdrShiftEn(1'b0),
    .DdrPhyCsrCmdTdrCaptureEn(1'b0),
    .DdrPhyCsrCmdTdrUpdateEn(1'b0),
    .DdrPhyCsrCmdTdr_Tdo(),
    .DdrPhyCsrRdDataTdrShiftEn(1'b0),
    .DdrPhyCsrRdDataTdrCaptureEn(1'b0),
    .DdrPhyCsrRdDataTdrUpdateEn(1'b0),
    .DdrPhyCsrRdDataTdr_Tdo(),

    .dwc_ddrphy_int_n(dwc_ddrphy_int_n),
    .dwc_ddrphy_dto(),

    .atpg_se(6'h00),
    .atpg_si(86'd0),
    .atpg_so(),
    .atpg_mode(1'b0),
    .atpg_lu_ctrl(6'h00),
    .atpg_RDQSClk(ACLK),
    .atpg_Pclk(ACLK),
    .atpg_TxDllClk(ACLK),

    .iccm_data_dout(iccm_data_dout),
    .iccm_data_din(iccm_data_din),
    .iccm_data_addr(iccm_data_addr[14:2]),
    .iccm_data_ce(iccm_data_ce),
    .iccm_data_we(iccm_data_we),
    .iccm_data_wem(iccm_data_wem),
    .dccm_data_dout(dccm_data_dout),
    .dccm_data_din(dccm_data_din),
    .dccm_data_addr(dccm_data_addr[14:2]),
    .dccm_data_ce(dccm_data_ce),
    .dccm_data_we(dccm_data_we),
    .dccm_data_wem(dccm_data_wem),
    .pmu_sram_clk_gated(pmu_sram_clk_gated),

    .BypassModeEnAC(1'b0),
    .BypassOutEnAC(12'h000),
    .BypassOutDataAC(12'h000),
    .BypassInDataAC(),
    .BypassModeEnDAT(1'b0),
    .BypassOutEnDAT(24'd0),
    .BypassOutDataDAT(24'd0),
    .BypassInDataDAT(),
    .BypassModeEnMASTER(1'b0),
    .BypassOutEnMASTER(2'b00),
    .BypassOutDataMASTER(2'b00),
    .BypassInDataMASTER(),

    // Bumps
    .DDR4_CK_T(DDR4_CK_T),
    .DDR4_CK_C(DDR4_CK_C),
    .DDR4_CKE(DDR4_CKE),
    .DDR4_CS_N(DDR4_CS_N),
    .DDR4_ADR(DDR4_ADR),
    .DDR4_ODT(DDR4_ODT),
    .DDR4_DQS_T(DDR4_DQS_T),
    .DDR4_DQS_C(DDR4_DQS_C),
    .DDR4_DQ(DDR4_DQ),
    .DDR4_DM_DBI_N(DDR4_DM_DBI_N),

    .BP_MEMRESET_L(DDR4_RESET_N),
    .BP_ALERT_N(DDR4_ALERT_N),
    .BP_VREF(DDR4_VREF),
    .BP_ZN_SENSE(DDR4_ZN_SENSE),
    .BP_ZN(DDR4_ZN)
);

dual_port_sram u_wdataram(
    .din(wdataram_din),
    .mask(wdataram_mask),
    .r_addr(wdataram_raddr),
    .wr_addr(wdataram_waddr),
    .we(wdataram_wr),
    .re(wdataram_re),
    .clk(ACLK),
    .dout(wdataram_dout)
);

dwc_ddrphy_pmu_iccm_ram #(
    .par_addr_msb(14),
    .par_addr_lsb(2)
    )
u_iccm(
    .ls(1'b0),
    .clk(pmu_sram_clk_gated),
    .addr(iccm_data_addr[14:2]),
    .dout(iccm_data_dout),
    .din(iccm_data_din),
    .cs(iccm_data_ce),
    .we(iccm_data_we),
    .wem(iccm_data_wem)
);
dwc_ddrphy_pmu_dccm_ram u_dccm (
    .clk(pmu_sram_clk_gated),
    .addr(dccm_data_addr[14:2]),
    .dout(dccm_data_dout),
    .din(dccm_data_din),
    .cs(dccm_data_ce),
    .ls(1'b0),
    .we(dccm_data_we),
    .wem(dccm_data_wem)
);

endmodule
