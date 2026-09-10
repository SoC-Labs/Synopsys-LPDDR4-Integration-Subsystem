
TESTNAME?=test_apb_access

SIM_BASE_DIR=$(LPDDR4_PROJECT_DIR)/sim
SIM_BUILD_DIR=$(SIM_BASE_DIR)/build
SIM_DIR=$(SIM_BASE_DIR)/$(TESTNAME)
TBENCH_VC = $(LPDDR4_PROJECT_DIR)/flist/tb.vc

FW_BUILD_DIR=$(LPDDR4_PROJECT_DIR)/sw/build
FW_TEST_DIR=$(LPDDR4_PROJECT_DIR)/sw/tests

TEST_SO=$(FW_BUILD_DIR)/$(TESTNAME).so
TEST_SO_NO=$(FW_BUILD_DIR)/$(TESTNAME)


# VCS options
COVERAGE ?= 0
LINT ?= 0
VCS_OPTIONS    = +ddr_squashz_to_0 +vcs+lic+wait +v2k -sverilog -override_timescale=1ns/100fs -debug +plusarg_save -debug_access+pp+dmptf+thread -debug_region=cell+encrypt -notice 
VCS_SIM_OPTION = +ddr_squashz_to_0 +vcs+lic+wait +vcs+flush+log -assert nopostproc
VCS_VC_OPTIONS = -f $(TBENCH_VC) 
VCS_OPTIONS   += -ntb_opts uvm -full64 -sverilog $(DESIGNWARE_HOME)/vip/svt/common/latest/C/lib/amd64/libmemserver.so

ifeq ($(COVERAGE),1)
VCS_OPTIONS += -cm line+cond+fsm+tgl+branch
VCS_SIM_OPTION += -cm line+cond+fsm+tgl+branch
endif

ifeq ($(LINT),1)
VCS_OPTIONS += +lint=all
endif



compile_vcs: $(SIM_BASE_DIR) $(SIM_BUILD_DIR)
	cd $(SIM_BUILD_DIR); vcs $(VCS_OPTIONS) -f $(TBENCH_VC) -kdb $(DEFINES_VC)  | tee compile_vcs.log

run_vcs: $(SIM_DIR) $(TEST_SO)
	mkdir -p $(SIM_DIR)
	@echo quit > $(SIM_DIR)/quit.do
	@if [ ! -d $(SIM_DIR)/logs ] ; then \
	  mkdir -p $(SIM_DIR)/logs; \
	fi
	cd $(SIM_DIR); $(SIM_BUILD_DIR)/simv $(VCS_SIM_OPTION) -sv_lib $(TEST_SO_NO)  < quit.do | tee logs/run_$(TESTNAME).log ;


sim_vcs: $(SIM_DIR) $(TEST_SO)
	mkdir -p $(SIM_DIR)
	@echo quit > $(SIM_DIR)/quit.do
	@if [ ! -d $(SIM_DIR)/logs ] ; then \
	  mkdir -p $(SIM_DIR)/logs; \
	fi
	cd $(SIM_DIR); $(SIM_BUILD_DIR)/simv $(VCS_SIM_OPTION) -gui -sv_lib $(TEST_SO_NO) &


$(TEST_SO): $(FW_TEST_DIR)/$(TESTNAME).c $(FW_BUILD_DIR)
	cc -fPIC -I $(SIM_BUILD_DIR) -I $(FW_TEST_DIR)/../libs -I $(VCS_HOME)/include  -shared -o $@ $(FW_TEST_DIR)/$(TESTNAME).c

# Recipe to create directories
$(SIM_BUILD_DIR) $(SIM_BASE_DIR) $(SIM_DIR):
	@mkdir -p $@
