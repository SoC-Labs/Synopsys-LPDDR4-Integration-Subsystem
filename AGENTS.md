# AGENTS.md

## Project Overview

Synopsys LPDDR4 DRAM Integration Subsystem: wraps Synopsys UMCTL2 controller + multiPHY into an AXI-based DRAM subsystem with UVM verification environment.

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
make first_time_setup          # Build VIP models (required once, or if verif/models/ is missing)
make build_phyinit             # Generate sw/libs/phyinit.c from template + output files
make compile_vcs               # Compile RTL with VCS (output: sim/build/simv)
make run_vcs TESTNAME=hello    # Run simulation headless (default: test_apb_access)
make sim_vcs TESTNAME=hello    # Run simulation with Verdi GUI
```

Firmware compilation (C → .so for DPI-C) happens automatically as part of `run_vcs`/`sim_vcs`. Manual build:
```bash
cc -fPIC -I sim/build -I sw/libs -I $VCS_HOME/include -shared -o sw/build/hello.so sw/tests/hello.c
```

## Key Architecture

- `rtl/dram_wrapper.sv` — Top-level integration: instantiates UMCTL2, PHY, SRAM, APB mux, reset controller
- `verif/lpddr4_tb.sv` — Top testbench: clock/reset, DDR model, APB driver, DUT instantiation
- `verif/dpi_apb.sv` — UVM APB VIP environment + DPI-C bridge: exposes `sv_apb3_read/write` and `sv_apb4_read/write` to C firmware via DPI-C scope (`lpddr4_tb.u_dpi_apb`)
- `verif/ddr_apb_driver.sv` — Standalone APB4 driver module (separate from the DPI-C bridge)
- `flist/tb.vc` — Master file list for VCS compilation (references IP file lists via `-f`; requires `LPDDR4_PROJECT_DIR` set)
- `flist/IP/` — File lists for Synopsys IP blocks (uMCTL2, LPDDR4PHY, CMSDK)
- `sw/tests/*.c` — DPI-C test firmware (see Firmware Entry Point below)
- `sw/libs/apb_access.h` — C API for APB3/APB4 read/write from firmware tests
- `sw/libs/phyinit.c` — Auto-generated PHY init sequence (do not edit; rebuilt by `make build_phyinit`)

## Firmware Entry Point

Each test in `sw/tests/<name>.c` must define `void something()`. This is called by the testbench via DPI-C import (`verif/lpddr4_tb.sv:5-6`). Tests call `sayHello()` and `endSim()` (exported from the testbench) to signal status and terminate.

Example pattern (from `sw/tests/test_apb_access.c`):
```c
#include "vc_hdrs.h"
#include "apb_access.h"
extern void endSim();
void something() {
    uint32_t rdata;
    apb3_read(0x601c, &rdata);   // APB3 (UMCTL2 config bus)
    apb4_read(0x0000, &rdata);   // APB4 (PHY config bus)
    endSim();
}
```

## Important Conventions

- **VCS + UVM only** — This project is tightly coupled to Synopsys VCS and UVM. No other simulator support is configured.
- **`verif/models/` is gitignored and DO NOT TOUCH** — External golden reference files from Synopsys DesignWare. Must be regenerated with `make first_time_setup` if missing. Never modify files here.
- **`sim/` is gitignored** — All simulation artifacts go here (one subdirectory per test).
- **`sw/build/` is gitignored** — Compiled firmware shared objects go here.
- **Test selection** — Set `TESTNAME=foo` to run a specific test. Firmware must exist at `sw/tests/foo.c`. Default test is `test_apb_access`.
- **Define macros** — Critical defines (`LP4_STD`, `DFI_MODE1`, `LPDDR4`, `lpddr4_proc`, etc.) are in root `Makefile`. Do not duplicate or omit them.
- **Two APB buses** — `DRAM_CFG_APB` (APB3, for UMCTL2) and `DRAM_PHY_CFG_APB` (APB4, for PHY config). Both are driven by the DPI-C APB bridge (`verif/dpi_apb.sv`).
- **File lists depend on env vars** — `flist/tb.vc` and `flist/IP/*.vc` reference `$LPDDR4_PROJECT_DIR`, `$SYNOPSYS_LPDDR4_UMCTL2_DIR`, etc. VCS compilation will fail if these are unset.
