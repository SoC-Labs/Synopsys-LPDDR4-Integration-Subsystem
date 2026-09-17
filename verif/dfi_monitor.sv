module dfi_monitor(

    // DFI Interface
    input  wire         dfi_reset_n,
    input  wire         dfi0_ctrlupd_ack,
    input  wire         dfi0_ctrlupd_req,
    input  wire         dfi0_phyupd_ack,
    input  wire         dfi0_phyupd_req,
    input  wire [1:0]   dfi0_phyupd_type,
    input  wire         dfi0_dram_clk_disable,
    input  wire [4:0]   dfi0_freq,
    input  wire [1:0]   dfi0_freq_ratio,
    input  wire         dfi0_init_complete,
    input  wire         dfi0_init_start,
    input  wire         dfi0_phymstr_ack,
    input  wire [1:0]   dfi0_phymstr_cs_state,
    input  wire         dfi0_phymstr_req,
    input  wire         dfi0_phymstr_state_sel,
    input  wire [1:0]   dfi0_phymstr_type,
    input  wire [5:0]   dfi0_address_P0,
    input  wire [5:0]   dfi0_address_P1,
    input  wire [1:0]   dfi0_cke_P0,
    input  wire [1:0]   dfi0_cke_P1,
    input  wire [1:0]   dfi0_cs_P0,
    input  wire [1:0]   dfi0_cs_P1,
    input  wire         dfi0_lp_ack,
    input  wire         dfi0_lp_ctrl_req,
    input  wire         dfi0_lp_data_req,
    input  wire  [3:0]  dfi0_lp_wakeup,
    input  wire         dfi0_error,
    input  wire [3:0]   dfi0_error_info,
    input  wire [31:0]  dfi_wrdata_P0,
    input  wire [31:0]  dfi_wrdata_P1,
    input  wire [3:0]   dfi_wrdata_cs_n_P0,
    input  wire [3:0]   dfi_wrdata_cs_n_P1,
    input  wire [1:0]   dfi_wrdata_en_P0,
    input  wire [1:0]   dfi_wrdata_en_P1,
    input  wire [3:0]   dfi_wrdata_mask_P0,
    input  wire [3:0]   dfi_wrdata_mask_P1,
    input  wire [31:0]  dfi_rddata_W0,
    input  wire [31:0]  dfi_rddata_W1,
    input  wire [3:0]   dfi_rddata_cs_n_P0,
    input  wire [3:0]   dfi_rddata_cs_n_P1,
    input  wire [3:0]   dfi_rddata_dbi_W0,
    input  wire [3:0]   dfi_rddata_dbi_W1,
    input  wire [1:0]   dfi_rddata_en_P0,
    input  wire [1:0]   dfi_rddata_en_P1,
    input  wire [1:0]   dfi_rddata_valid_W0,
    input  wire [1:0]   dfi_rddata_valid_W1


);

svt_dfi_1_to_2_ratio_frequency_if dfi_if();

assign dfi_if.dfi_address_p = dfi0_address_P0;


initial begin
    //uvm_config_db#(svt_dfi_)
end

endmodule
