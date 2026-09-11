
include ./flows/simulate.mk

DEFINES_VC += +define+LP4_STD +define+DFI_MODE1 +define+LPDDR4 +define+lpddr4_proc 
DEFINES_VC += +define+UVM_DISABLE_AUTO_ITEM_RECORDING +define+UVM_PACKER_MAX_BYTES=1500000 +define+DFI_ACTIVE +define+SVT_DFI_MAX_DATA_WIDTH=32 +define+SVT_DFI_SLICE_WIDTH=8 +define+SVT_DFI_MAX_RANK_WIDTH=2 +define+SVT_DFI_MAX_BL=32 +define+SVT_DFI_RAND_CMD_PHASE_DDR 
DEFINES_VC += +define+UVM_VERBOSITY=UVM_FULL  +define+SYNOPSYS_SV +define+SVT_UVM_TECHNOLOGY +define+SVT_MEM_DPI_OK +define+SVT_APB_MAX_DATA_WIDTH=32
DEFINES_VC += +define+DWC_DDRPHY_NO_PG_PINS_MACROS +define+DWC_DDRPHY_TECH__CDCBUF__DISABLE_BEHAVIORAL_VERILOG 
DEFINES_VC += +define+DWC_DDRPHY_HWEMUL +define+DWC_DDRPHY_HWEMUL_PLL +define+DWC_DDRPHY_HWEMUL_SIM +define+DWC_DDRPHY_SIMPLE_MODEL
DEFINES_VC += +define+DWC_DDRPHY_DRVBE_SIMPLE +define+DWC_DDRPHY_HWEMUL_CGRC +define+DWC_DDRPHY_MODEL_ASYNCMSFLOP_AS_DFF
DEFINES_VC += +define+SVT_LPDDR_CA_WIDTH=6 +define+SVT_LPDDR_MAX_DQS_WIDTH=2 +define+SVT_LPDDR_MAX_DQ_WIDTH=16 +define+SVT_LPDDR4_MAX_DMI_WIDTH=2

SYNOPSYS_LPDDR4_UMCTL2_DIR ?= /research/synopsys/lpddr4/megaSoC_lpddr4/megaSoC_lpddr4/
SYNOPSYS_LPDDR4_multiPHY_DIR ?= /research/synopsys/lpddr4_m_phy_megasoc
SYNOPSYS_LPDDR4_multiPHY_LIB_DIR ?= /research/synopsys/LPDDR4-m-PHY-V2_TSMC_16FFC/synopsys/dwc_lpddr4_multiphy_v2_tsmc16ffc18/Latest
SYNOPSYS_PHYINIT_PATH?=/research/synopsys/LPDDR4-m-PHY-V2_TSMC_16FFC/synopsys/dwc_lpddr4_multiphy_v2_tsmc16ffc18/Latest/phyinit/Latest/software/lpddr4

# Make variables visible to target shells
export DEFINES_VC
export SYNOPSYS_LPDDR4_UMCTL2_DIR
export SYNOPSYS_LPDDR4_multiPHY_DIR
export SYNOPSYS_LPDDR4_multiPHY_LIB_DIR

build_vip_models:
	mkdir -p $(LPDDR4_PROJECT_DIR)/verif/models/
	$(DESIGNWARE_HOME)/bin/dw_vip_setup -path $(LPDDR4_PROJECT_DIR)/verif/models/lpddr_vip -e lpddr_svt/tb_lpddr4_svt_verilog_basic_sys -svlog
	$(DESIGNWARE_HOME)/bin/dw_vip_setup -path $(LPDDR4_PROJECT_DIR)/verif/models/apb_driver -e amba_svt/tb_apb_svt_uvm_basic_sys -svlog
	$(DESIGNWARE_HOME)/bin/dw_vip_setup -path $(LPDDR4_PROJECT_DIR)/verif/models/axi_driver -e amba_svt/tb_axi_svt_uvm_basic_sys -svlog

build_phyinit:
	make -C $(SYNOPSYS_PHYINIT_PATH) OUTDIR=$(LPDDR4_PROJECT_DIR)/sw/libs/phyinit CUSTDIR=$(LPDDR4_PROJECT_DIR)/sw/libs/userCustom

setup_phyinit_dev:
	cp -r $(SYNOPSYS_PHYINIT_PATH)/userCustom $(LPDDR4_PROJECT_DIR)/sw/libs
	cp -r $(SYNOPSYS_PHYINIT_PATH)/doc $(LPDDR4_PROJECT_DIR)/sw/libs

commit_phyinit_changes:
	cp -r $(LPDDR4_PROJECT_DIR)/sw/libs/userCustom $(SYNOPSYS_PHYINIT_PATH)/

first_time_setup: build_vip_models setup_phyinit_dev

clean_phyinit:
	rm $(LPDDR4_PROJECT_DIR)/sw/build/phyinit.so
	rm -rf $(LPDDR4_PROJECT_DIR)/sw/libs/phyinit
	rm $(LPDDR4_PROJECT_DIR)/sw/libs/phyinit.c
