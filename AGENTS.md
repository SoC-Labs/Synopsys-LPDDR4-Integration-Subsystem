# AGENTS.md

## Project Overview

Synopsys LPDDR4 DRAM Integration Subsystem: wraps Synopsys UMCTL2 controller + multiPHY into an AXI-based DRAM subsystem with UVM verification environment, driven from C firmware via DPI-C.

## Environment Setup

```bash
source set_env.sh  # Sets LPDDR4_PROJECT_DIR to $(pwd)
```

Required external tools/paths (set before building):
- `DESIGNWARE_HOME` — DesignWare VIP (needed for `dw_vip_setup` and SVT models)
- `VCS_HOME` — Synopsys VCS simulator
- `SYNOPSYS_LPDDR4_UMCTL2_DIR` — UMCTL2 IP netlists (default: `/research/synopsys/lpddr4/megaSoC_lpddr4/megaSoC_lpddr4/`)
- `SYNOPSYS_LPDDR4_multiPHY_DIR` — PHY IP directory
- `SYNOPSYS_LPDDR4_multiPHY_LIB_DIR` — PHY library files
- `SYNOPSYS_PHYINIT_PATH` — PHY init software (used by `make build_phyinit`)

## Build & Simulation Commands

```bash
source set_env.sh              # Set LPDDR4_PROJECT_DIR (required before any make target)
make first_time_setup          # Build VIP models + setup PHY init dev files (required once, or if verif/models/ or sw/libs/userCustom missing)
make build_phyinit             # Generate sw/libs/phyinit.c from template + output files
make compile_vcs TESTNAME=foo  # Compile RTL with VCS (output: sim/build/simv)
make run_vcs TESTNAME=foo      # Run simulation headless (default: dram_tests)
make sim_vcs TESTNAME=foo      # Run simulation with Verdi GUI
make compile_axi_vcs           # Compile standalone AXI VIP testbench (output: sim/build/simv)
make run_axi_vcs               # Run AXI simulation (uses axi_tests.c)
make setup_phyinit_dev         # Copy userCustom/ and doc/ into sw/libs/
make commit_phyinit_changes    # Push userCustom changes back to PHY init source
make clean_phyinit             # Remove phyinit.so, sw/libs/phyinit, and sw/libs/phyinit.c
```

Firmware compilation (C → .so for DPI-C) happens automatically as part of `run_vcs`/`sim_vcs`. The compile command (from `flows/simulate.mk`):
```bash
cc -fPIC -I $(SIM_BUILD_DIR) -I $(FW_TEST_DIR)/../libs -I $(VCS_HOME)/include -I $(FW_TEST_DIR)../build -shared -o $@ $(FW_TEST_DIR)/$(TESTNAME).c
```
Note: `-I $(FW_TEST_DIR)../build` resolves to `sw/tests/../build` = `sw/build`. The `phyinit.so` is linked automatically as a dependency.

## Key Architecture

- `rtl/dram_wrapper.sv` — Top-level integration: instantiates UMCTL2, PHY, SRAM, APB mux, reset controller
- `verif/lpddr4_tb.sv` — Top testbench: clock/reset, DDR model, APB driver, DUT instantiation. Exports DPI-C `sayHello()` and `endSim()`; imports `something()` from firmware via `initial #100 something()`.
- `verif/dpi_apb.sv` — UVM APB VIP environment + DPI-C bridge: exposes `sv_apb3_read/write` and `sv_apb4_read/write` to C firmware via DPI-C scope (`lpddr4_tb.u_dpi_apb`)
- `verif/ddr_apb_driver.sv` — Standalone APB4 driver module (separate from the DPI-C bridge)
- `verif/dpi_axi.sv` — UVM AXI VIP environment + DPI-C bridge (`sv_axi_write/read`)
- `verif/axi4_svt_adapter.sv` — SVT AXI VIP ↔ repo `axi4` bus adapter
- `flist/tb.vc` / `flist/axi_tb.vc` — VCS file lists for DPI-APB and AXI testbenches respectively
- `flist/interfaces.vc` / `flist/dram_wrapper.vc` — Included via `tb.vc`; define interface declarations and wrapper file lists
- `flist/IP/` — File lists for Synopsys IP blocks (uMCTL2, LPDDR4PHY, CMSDK)
- `sw/tests/*.c` — DPI-C test firmware
- `sw/libs/apb_access.h` — C API for APB3/APB4 read/write from firmware tests
- `sw/libs/axi_access.h` — C API for AXI write/read from firmware tests
- `sw/libs/phyinit.c` — Auto-generated PHY init sequence (do not edit; rebuilt by `make build_phyinit`)
- `sw/libs/userCustom/` — PHY init customization source (gitignored; copied by `make setup_phyinit_dev`)
- `verif/models/` — Extracted SVT VIP models (gitignored; rebuilt with `make first_time_setup`)

## Firmware Entry Point

Each test in `sw/tests/<name>.c` must define `void something()`. The testbench imports this via DPI-C (`verif/lpddr4_tb.sv:7`).

Available test files:
- `dram_tests.c` — Default test. Tests APB3 (UMCTL2), APB4 (PHY), and AXI write/read/burst. Includes both `apb_access.h` and `axi_access.h`. Has a `no_training` variable (0 by default) to skip training registers.
- `axi_tests.c` — AXI-only test. Uses `axi_write`, `axi_read`, `axi_burst_write`, `axi_burst_read`, `axi_write_check`. Calls `axi_set_tb_scope()` before `endSim()`.
- `test_apb_access.c` — APB3/APB4 read/write test. Calls `apb_set_tb_scope()` before `endSim()`.
- `hello.c` — Minimal example. Only test that calls `sayHello()`. Calls `apb_set_tb_scope()` before `sayHello()`.

Common DPI-C functions available to firmware:
- `endSim()` — Terminates simulation (exported from testbench)
- `sayHello()` — Returns int, prints "Hello world" (exported from testbench; only used by `hello.c`)
- `apb_set_tb_scope()` — Sets APB DPI-C scope to `lpddr4_tb`
- `axi_set_tb_scope()` — Sets AXI DPI-C scope to `axi_tb`
- `apb3_read(addr, &data)`, `apb3_write(addr, data)` — APB3 (UMCTL2 config bus)
- `apb4_read(addr, &data)`, `apb4_write(addr, data)` — APB4 (PHY config bus)
- `apb3_write_check(addr, data)`, `apb4_write_check(addr, data)` — APB write verification
- `axi_write(addr, data)`, `axi_read(addr, &data)` — AXI access
- `axi_burst_write(addr, data, len)`, `axi_burst_read(addr, &data, len)` — AXI burst
- `axi_write_check(addr, data)` — AXI write verification (in `axi_access.h`)

Example pattern (`sw/tests/dram_tests.c` — the default test):
```c
#include "vc_hdrs.h"
#include "apb_access.h"
#include "axi_access.h"
extern void endSim();
extern void phyinit();
void something() {
    // ... APB3 register programming ...
    phyinit();  // Call PHY init from sw/libs/phyinit.so
    // ... AXI test ...
    apb_set_tb_scope();
    endSim();
}
```

## Important Conventions

- **VCS + UVM only** — No other simulator support is configured.
- **`verif/models/` is gitignored and DO NOT TOUCH** — External golden reference files from Synopsys DesignWare. Must be regenerated with `make first_time_setup` if missing. Never modify files here.
- **`sim/` is gitignored** — All simulation artifacts go here (one subdirectory per test).
- **`sw/build/` is gitignored** — Compiled firmware shared objects go here.
- **Default test is `dram_tests`** — Per `simulate.mk` (`TESTNAME?=dram_tests`). Override with `TESTNAME=foo`. Firmware must exist at `sw/tests/foo.c`.
- **`hello.c` is a minimal example** — The only test that calls `sayHello()`. `dram_tests.c`, `axi_tests.c`, and `test_apb_access.c` do not.
- **Define macros** — Critical defines (`LP4_STD`, `DFI_MODE1`, `LPDDR4`, `lpddr4_proc`, `SVT_LPDDR_TIMESCALE`, etc.) are in root `Makefile`. Do not duplicate or omit them.
- **Two APB buses** — `DRAM_CFG_APB` (APB3, for UMCTL2) and `DRAM_PHY_CFG_APB` (APB4, for PHY config). Both are driven by the DPI-C APB bridge (`verif/dpi_apb.sv`).
- **File lists depend on env vars** — `flist/tb.vc` and `flist/IP/*.vc` reference `$LPDDR4_PROJECT_DIR`, `$SYNOPSYS_LPDDR4_UMCTL2_DIR`, etc. VCS compilation will fail if these are unset.
- **PHY init flow** — `first_time_setup` runs `setup_phyinit_dev` which copies `userCustom/` and `doc/` into `sw/libs/`. Edit files in `sw/libs/userCustom/`, then `make build_phyinit` to regenerate `sw/libs/phyinit.c`. Use `make commit_phyinit_changes` to push back.
- **Output logs** — go to `sim/<testname>/logs/run_<testname>.log` (or `sim/axi/axi_tests/logs/run_axi_tests.log` for the AXI flow).
- **PHY init build rule** — `$(PHYINIT_C)` rule is in `flows/simulate.mk` (lines 94-97). It concatenates `phyinit_template.c` + `dwc_ddrphy_phyinit_out_lpddr4_train1d.txt` + `}`. The `build_phyinit` target runs the phyinit tool which generates ALL output files (`train1d.txt`, `devinit_skiptrain.txt`, etc.) in `sw/libs/phyinit/`.
- **Training fix (COMPLETED)** — Changed `$(PHYINIT_C)` rule in `flows/simulate.mk` to concatenate `train1d.txt` instead of `devinit_skiptrain.txt`. Training now executes (44 "Training squash Z" messages), reducing errors from 135 to 126. Root cause: phyinit Makefile hardcodes `-skip_train 2` for devinit target; `SequenceCtrl` values do NOT control training.
- **Simulation runs normally** — takes a long time because training firmware is running, not stuck. `B_startClockResetPhy` using `apb3_write` is correct — the reset controller is on the APB3 bus (UMCTL2).
- **`dram_tests.c` includes `axi_access.h`** — It performs both APB and AXI operations. The `no_training` variable (0 by default) controls whether training registers are skipped.
- **`set_data_prop` handle types** — `SVT_CMD_NULL_HANDLE` (-1) enables nested dot-separated path resolution (e.g., `"err_check.common_err_check.enable_checks(refresh_timing_group)"`). `cfg_handle` (obtained via `get_data_prop("cfg", ...)`) is a configuration object handle that ONLY supports simple property names. Using dot-separated paths with `cfg_handle` causes `Invalid Arguments` errors. See `verif/lpddr_model.v` lines 174-198.
- **SVT VIP configuration** — `verif/lpddr_model.v` `initialize_inst()` configures the SVT memory model. `memory.set_data_prop(is_valid, `SVT_CMD_NULL_HANDLE, "err_check.common_err_check.enable_checks(...)")` is the correct pattern to disable check groups. `memory.set_data_prop(is_valid, cfg_handle, "bypass_initialization"/"bypass_trainings")` works for simple properties on `cfg_handle`.
- **Reference test files** — `ts.lpddr4_error_group_disable_write_test.v` and `ts.lpddr4_error_empty_group_disable_write_test.v` (in `verif/models/lpddr_vip/examples/verilog/lpddr_svt/tb_lpddr4_svt_verilog_basic_sys/tests/`) demonstrate correct `SET_DATA_PROP_W_CHECK`/`ENABLE_CHECK` usage with `SVT_CMD_NULL_HANDLE`. The `SET_DATA_PROP_W_CHECK` and `ENABLE_CHECK` macros are defined in `lpddr4_svt_macros_util.v` (not in `flist/tb.vc` include path; must be included separately).
- **`vip_set_data_prop` vs `memory.set_data_prop`** — Both call the same `test_top.memory.set_data_prop` method. `vip_set_data_prop("memory", handle, propname, ...)` just wraps `test_top.memory.set_data_prop(is_valid, handle, propname, ...)`. The `vip_` utilities (`vip_get_data_prop`, `vip_set_data_prop`, `vip_apply_data`, `vip_display_data`) are defined in `lpddr4_svt_vip_util.v` and `lpddr4_svt_macros_util.v` — NOT in the `flist/tb.vc` include path.
- **`SVT_CMD_NULL_HANDLE` definition** — `` `define SVT_CMD_NULL_HANDLE -1 `` in `svt_cmd_defines.svi` (under `verif/models/lpddr_vip/include/sverilog/`).
- **Error fix (COMPLETED)** — Changed `cfg_handle` to `SVT_CMD_NULL_HANDLE` in `verif/lpddr_model.v` lines 181-186 for `enable_checks` calls. This eliminated 6 `set_data_prop Invalid Arguments` errors and reduced UVM_ERRORs from 346 to 2. The 2 remaining errors are unrelated to the fix: `selfrefresh_refresh_selfrefresh_sequence_check` and `invalid_input_clock_frequency_check`.
