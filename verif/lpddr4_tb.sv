`include "uvm_pkg.sv"

import uvm_pkg::*;


`timescale 1ps/1fs
module lpddr4_tb();

    export "DPI-C" function sayHello;
    export "DPI-C" function endSim;
    import "DPI-C" context task something();
    initial #40000 something();

    initial begin
        run_test("combined_test");
    end

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

    dpi_axi u_dpi_axi(
        .ACLK(CLK),
        .ARESETn(RSTn),
        .DRAM_AXI(DRAM_AXI)
    );

    // Memory model clock pair: previously connected swapped (ck_c <- CK_t,
    // ck_t <- CK_c). Corrected; A/B runs showed identical results either way.
    lpddr_model memory(
        .ck_t    (DDR_CK_t),
        .ck_c    (DDR_CK_c),
        .cke     (DDR_CKE[0]),
        .cs      (DDR_CS[0]),
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
        .DDR4_CS(DDR_CS),
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

`define PHY_DFI u_dram_wrapper.u_dram_PHY

dfi_monitor u_dfi_monitor(
    .dfi_reset_n(`PHY_DFI.dfi_reset_n),
    .dfi0_ctrlupd_ack(`PHY_DFI.dfi0_ctrlupd_ack),
    .dfi0_ctrlupd_req(`PHY_DFI.dfi0_ctrlupd_req),
    .dfi0_phyupd_ack(`PHY_DFI.dfi0_phyupd_ack),
    .dfi0_phyupd_req(`PHY_DFI.dfi0_phyupd_req),
    .dfi0_phyupd_type(`PHY_DFI.dfi0_phyupd_type),
    .dfi0_dram_clk_disable(`PHY_DFI.dfi0_dram_clk_disable),
    .dfi0_freq(`PHY_DFI.dfi0_freq),
    .dfi0_freq_ratio(`PHY_DFI.dfi0_freq_ratio),
    .dfi0_init_complete(`PHY_DFI.dfi0_init_complete),
    .dfi0_init_start(`PHY_DFI.dfi0_init_start),
    .dfi0_phymstr_ack(`PHY_DFI.dfi0_phymstr_ack),
    .dfi0_phymstr_cs_state(`PHY_DFI.dfi0_phymstr_cs_state),
    .dfi0_phymstr_req(`PHY_DFI.dfi0_phymstr_req),
    .dfi0_phymstr_state_sel(`PHY_DFI.dfi0_phymstr_state_sel),
    .dfi0_phymstr_type(`PHY_DFI.dfi0_phymstr_type),
    .dfi0_address_P0(`PHY_DFI.dfi0_address_P0),
    .dfi0_address_P1(`PHY_DFI.dfi0_address_P1),
    .dfi0_cke_P0(`PHY_DFI.dfi0_cke_P0),
    .dfi0_cke_P1(`PHY_DFI.dfi0_cke_P1),
    .dfi0_cs_P0(`PHY_DFI.dfi0_cs_P0),
    .dfi0_cs_P1(`PHY_DFI.dfi0_cs_P1),
    .dfi0_lp_ack(`PHY_DFI.dfi0_lp_ack),
    .dfi0_lp_ctrl_req(`PHY_DFI.dfi0_lp_ctrl_req),
    .dfi0_lp_data_req(`PHY_DFI.dfi0_lp_data_req),
    .dfi0_lp_wakeup(`PHY_DFI.dfi0_lp_wakeup),
    .dfi0_error(`PHY_DFI.dfi0_error),
    .dfi0_error_info(`PHY_DFI.dfi0_error_info),
    .dfi_wrdata_P0(`PHY_DFI.dfi_wrdata_P0),
    .dfi_wrdata_P1(`PHY_DFI.dfi_wrdata_P1),
    .dfi_wrdata_cs_n_P0(`PHY_DFI.dfi_wrdata_cs_n_P0),
    .dfi_wrdata_cs_n_P1(`PHY_DFI.dfi_wrdata_cs_n_P1),
    .dfi_wrdata_en_P0(`PHY_DFI.dfi_wrdata_en_P0),
    .dfi_wrdata_en_P1(`PHY_DFI.dfi_wrdata_en_P1),
    .dfi_wrdata_mask_P0(`PHY_DFI.dfi_wrdata_mask_P0),
    .dfi_wrdata_mask_P1(`PHY_DFI.dfi_wrdata_mask_P1),
    .dfi_rddata_W0(`PHY_DFI.dfi_rddata_W0),
    .dfi_rddata_W1(`PHY_DFI.dfi_rddata_W1),
    .dfi_rddata_cs_n_P0(`PHY_DFI.dfi_rddata_cs_n_P0),
    .dfi_rddata_cs_n_P1(`PHY_DFI.dfi_rddata_cs_n_P1),
    .dfi_rddata_dbi_W0(`PHY_DFI.dfi_rddata_dbi_W0),
    .dfi_rddata_dbi_W1(`PHY_DFI.dfi_rddata_dbi_W1),
    .dfi_rddata_en_P0(`PHY_DFI.dfi_rddata_en_P0),
    .dfi_rddata_en_P1(`PHY_DFI.dfi_rddata_en_P1),
    .dfi_rddata_valid_W0(`PHY_DFI.dfi_rddata_valid_W0),
    .dfi_rddata_valid_W1(`PHY_DFI.dfi_rddata_valid_W1)
);

// ----------------------------------------------------------------------
// DFI command counter + wait helper for the C tests (retention/self-refresh).
// Decodes the first CA cycle of LPDDR4 commands on the controller's DFI
// output (P0 = dfi_address[5:0]/dfi_cs[0], P1 = dfi_address[25:20]/dfi_cs[1]).
// Kinds: 0 = ACT, 1 = REF, 2 = SRE, 3 = SRX, 4 = tRFC violations.
//
// tRFC check: the LPDDR4 memory model does not flag tRFC in this
// configuration (shown by a mutation run), so ACT/REF sooner than tRFCab
// after an all-bank REF is reported here as a UVM_ERROR.
// ----------------------------------------------------------------------
export "DPI-C" function sv_dfi_cmd_count;
export "DPI-C" task sv_wait_ns;

int unsigned dfi_cmd_cnt [5];
realtime     last_ref_time = -1s;
localparam realtime T_RFCAB = 130ns;   // 2Gb die, from the memory model config

task automatic dfi_cmd_seen(input int kind, input realtime t);
    if (kind < 0) return;
    dfi_cmd_cnt[kind]++;
    if ((kind == 0 || kind == 1) && (t - last_ref_time) < T_RFCAB) begin
        dfi_cmd_cnt[4]++;
        uvm_report_error("TRFC_CHECK", $sformatf("%s %0.2f ns after REF (tRFCab = %0.0f ns)",
                         kind == 0 ? "ACT" : "REF", (t - last_ref_time) / 1ns, T_RFCAB / 1ns));
    end
    if (kind == 1) last_ref_time = t;
endtask

function automatic int dfi_cmd_kind(input logic [5:0] ca);
    if (ca[1:0] == 2'b01)      return 0;  // ACT-1
    if (ca[4:0] == 5'b01000)   return 1;  // REF
    if (ca[4:0] == 5'b11000)   return 2;  // SRE
    if (ca[4:0] == 5'b10100)   return 3;  // SRX
    return -1;
endfunction

// P1 is one DRAM clock (half a DFI clock) after P0
always @(posedge CLK) begin
    if (u_dram_wrapper.dfi_cs[0] === 1'b1)
        dfi_cmd_seen(dfi_cmd_kind(u_dram_wrapper.dfi_address[5:0]), $realtime);
    if (u_dram_wrapper.dfi_cs[1] === 1'b1)
        dfi_cmd_seen(dfi_cmd_kind(u_dram_wrapper.dfi_address[25:20]), $realtime + 1.25ns);
end

function int unsigned sv_dfi_cmd_count(input int unsigned kind);
    return (kind < 5) ? dfi_cmd_cnt[kind] : 0;
endfunction

task automatic sv_wait_ns(input int unsigned ns);
    #(ns * 1ns);
endtask

// Debug waveform: wrapper-level AXI/DFI/low-power signals, enabled with
// +DUMP_WRAPPER. Starts late (default 920 us, override +DUMP_START_US=<n>)
// to skip PHY training and keep the FSDB small.
initial begin
    int unsigned dump_start_us = 920;
    if ($test$plusargs("DUMP_WRAPPER")) begin
        void'($value$plusargs("DUMP_START_US=%d", dump_start_us));
        #(dump_start_us * 1us);
        $display("[DUMP_WRAPPER] FSDB signal dump started at %0t", $realtime);
        $fsdbDumpvars(1, lpddr4_tb.u_dram_wrapper);
        $fsdbDumpvars(0, lpddr4_tb.DRAM_AXI);
    end
end

endmodule
