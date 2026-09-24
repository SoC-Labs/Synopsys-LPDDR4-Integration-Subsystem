# How to use repo
Get from https://github.com/SoC-Labs/Synopsys-LPDDR4-Integration-Subsystem
```
git clone https://github.com/SoC-Labs/Synopsys-LPDDR4-Integration-Subsystem.git
```

## First time Setup
```
source set_env.sh
make first_time_setup
```
This will build the vip models and setup phyinit development.

# PHYINIT
The phyinit firmware is generated using the code here:
```
/research/synopsys/lpddr4/synopsys/dwc_lpddr4_multiphy_v2_firmware/latest/phyinit/Latest/software/lpddr4
```

The first_time_setup will copy the userCustom directory into ./sw/libs/userCustom. The only files you should really need to change in here are:

sw/libs/userCustom/dwc_ddrphy_phyinit_setDefault.c

sw/libs/userCustom/dwc_ddrphy_phyinit_userCustom_overrideUserInput.c

If you want to read about what these files do, first_time_setup also copies the documentation into ./sw/libs/docs

The phyinit firmware should be build automatically, however it may not see changes from the userCustom directory so you may need to run
```
make clean_phyinit
```

## !! IF YOU MAKE CHANGES TO FILES IN USERCUSTOM!!

If you make any fixed to the files in userCustom Please run
```
make commit_phyinit_changes
```

This will copy the changes back to the root directory (in /research) so we can reuse these changes across project like megaSoC.


# Simulating
RTL is compiled using
```
make compile_vcs
```

and then tests run using
```
make run_vcs
```
The default test is dram_tests (found in ./sw/tests/dram_tests.c)

The c-code is compiled separate to the RTL, so you only have to recompile if you change RTL.

## Current Status

The PHY gets initialised

The controller is initialised

AXI writes are captured by controller FIFO

Then nothing happens. Controller should write over DFI interface to PHY but it doesn't

## UVM WARNINGS/ERRORS So far

### Mem controller assertion
Comes from memory controller before clock and reset, I think this is just x's in the controller and should be fine
```
ERROR: Assertion 'ERROR_REG_LPR_NUM_ENTRIES_PROGRAMMED_AFTER_RESET' failed
```

### Clock frequency too high
This is slightly concerning as the PHY should start in the BOOT frequency as described in the documentation. As far as I can tell this is automatically controller by the PHY but for some reason it is using the full speed output from the PLL to do initialisation

```
lpddr4_tb_memory_memory_LPDDR_AGENT [register_fail:initialization_group:LPDDR4:tckb_during_initialization_for_mrw_mrr_cmd_check] Description: During the initialization when MRW/MRR command is issued, clock period shall be within the defined range of tCKb (18ns to 100ns), Reference: LPDDR4C JEDEC Spec:3.3 Power-Up, Initialization & Power-Off Procedure / Initialization Timing Parameters - During Initialization MRW should be performed at boot clock within time period[18.000000ns, 100.000000ns], Actual clock period =1.248000ns
```


### Uninitialised memory
During initialisation you will see a lot of
```
lpddr4_tb_memory_memory_LPDDR_AGENT.mem_sequencer [SNPS/SVT/MEM/CORE/RD_B4_WR] Address: 0x0000000000000000 a location was read before it was initialized or written
```
These can be ignored as it is expected for the PHY to read from address before they're initialised properly

### ICCO too high

Not sure where this message actually comes from
I imagine this is a problem from the phy initialising in a behavioural environment
```
Warning!! Icco =    2mA, is too high, vp is the vref of vreg_v2i @ time = 928416 ns!
```

### AXI Write incomplete

The main error here at the end is that the AXI write starts but never completes

```
UVM_INFO /eda/synopsys/2022-23/RHELx86/VC-VIP-SOC_2022.12/vip/svt/amba_svt/U-2022.12/axi_master_svt/sverilog/src/vcs/svt_axi_base_master_common.svp(3358) @ 943898750000: uvm_test_top.dpi_axi_test.axi_system_env.master[0] [send_write_addr] {OBJECT_NUM('d100000) PORT_ID('d0) PORT_NAME() TYPE(WRITE)    ID('h1) PROT_TYPE(DATA_SECURE_NORMAL) ADDR('h0) LENGTH('d256) SIZE(BURST_SIZE_64BIT) BURST_TYPE(INCR) CACHE_TYPE('d0)  }Transaction started
UVM_INFO /eda/synopsys/2022-23/RHELx86/VC-VIP-SOC_2022.12/vip/svt/common/T-2022.09/sverilog/src/vcs/svt_timer.svp(436) @ 946781250000: uvm_test_top.dpi_axi_test.axi_system_env.master[0] [main] monitor.wvalid_wready_timer has expired.
UVM_FATAL /eda/synopsys/2022-23/RHELx86/VC-VIP-SOC_2022.12/vip/svt/amba_svt/U-2022.12/axi_master_svt/sverilog/src/vcs/svt_axi_base_master_common.svp(10390) @ 946781250000: uvm_test_top.dpi_axi_test.axi_system_env.master[0] [wait_for_wready] {OBJECT_NUM('d100000) PORT_ID('d0) PORT_NAME() TYPE(WRITE) COHERENT_XACT_TYPE(READNOSNOOP) ID('h1) SECURE('d1) ADDR('h0) CACHE_TYPE('d0)      START_TIME(943898750000) } Timed out waiting for wready after wvalid assertion. Timeout = 'd1000 clock cyclesWatchdog Timer = svt_axi_system_configuration::wready_watchdog_timeout,  If the current timer value 'd       1000 clock cycles is not sufficient for the DUT to respond, increase the timeout variable svt_axi_system_configuration::wready_watchdog_timeout to match the maximum expected delay from DUT. To disable the timer, set svt_axi_system_configuration::wready_watchdog_timeout to zero. In this case, the VIP will indefinitely wait for the signal from DUT. If the signal is never received, it may result in simulation hang. This timeout might result in protocol violation errors as VIP assumes signal is not going to be recieved and proceeds with next beat, But if DUT sends it after some delay it might result in all sorts of protocol voilations
```

## Unfinished work

Currently there is a dfi monitor that does nothing here:
verif/dfi_monitor.sv

Ideally this should actually monitor interaction on the DFI bus