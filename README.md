# Synopsys LPDDR4 Integration Subsystem

Wraps the Synopsys UMCTL2 controller + multiPHY into an AXI-based DRAM subsystem with a UVM verification environment driven from C firmware via DPI-C.

## Prerequisites

Required external tools and paths (set in your shell before building):

| Variable | Description |
|---|---|
| `DESIGNWARE_HOME` | DesignWare / SVT VIP root |
| `VCS_HOME` | Synopsys VCS simulator |
| `SYNOPSYS_LPDDR4_UMCTL2_DIR` | UMCTL2 IP netlists |
| `SYNOPSYS_LPDDR4_multiPHY_DIR` | PHY IP directory |
| `SYNOPSYS_LPDDR4_multiPHY_LIB_DIR` | PHY library files |
| `SYNOPSYS_PHYINIT_PATH` | PHY init software |

## Environment Setup

```bash
source set_env.sh          # Sets LPDDR4_PROJECT_DIR to $(pwd)
```

## Quick Start

```bash
source set_env.sh
make first_time_setup      # Build VIP models (required once, or if verif/models/ is missing)
make compile_vcs           # Compile RTL with VCS → sim/build/simv
make run_vcs               # Run simulation headless (default: dram_tests)
make sim_vcs               # Run simulation with Verdi GUI
```

### Compile and run a specific test

```bash
make compile_vcs TESTNAME=test_apb_access
make run_vcs TESTNAME=test_apb_access
```

### Standalone AXI VIP testbench (SVT AXI master)

```bash
make compile_axi_vcs       # Compile the AXI-only testbench → sim/build/simv
make run_axi_vcs           # Run the AXI simulation
```

Output logs go to `sim/<testname>/logs/run_<testname>.log` (or `sim/axi/axi_tests/logs/run_axi_tests.log` for the AXI flow).

## Adding a New Test

1. Create `sw/tests/<name>.c` defining `void something()`.
2. The test is compiled to a shared library automatically by `make run_vcs`.
3. Call exported DPI-C functions from the testbench: `sayHello()` and `endSim()`.

### Firmware pattern

```c
#include "vc_hdrs.h"
#include "apb_access.h"    // or "axi_access.h" for AXI tests
extern void endSim();

void something() {
    uint32_t rdata;
    apb3_read(0x601c, &rdata);
    apb4_read(0x0000, &rdata);
    endSim();
}
```

### C API reference

**`sw/libs/apb_access.h`** — APB3/APB4 read/write via DPI-C:
- `apb3_read(addr, &data)`, `apb3_write(addr, data)`
- `apb4_read(addr, &data)`, `apb4_write(addr, data)`
- `apb3_write_check(addr, data)`, `apb4_write_check(addr, data)`

**`sw/libs/axi_access.h`** — AXI write/read via DPI-C:
- `axi_write(addr, data)`, `axi_read(addr, &data)`
- `axi_burst_write(addr, data, len)`, `axi_burst_read(addr, &data, len)`
- `axi_write_check(addr, data)`

## Key Architecture

- `rtl/dram_wrapper.sv` — Top-level integration: UMCTL2, PHY, SRAM, APB mux, reset controller
- `verif/lpddr4_tb.sv` — Top testbench: clock/reset, DDR model, APB driver, DUT instantiation
- `verif/dpi_apb.sv` — UVM APB VIP environment + DPI-C bridge (`sv_apb3_read/write`, `sv_apb4_read/write`)
- `verif/dpi_axi.sv` — UVM AXI VIP environment + DPI-C bridge (`sv_axi_write/read`)
- `verif/axi4_svt_adapter.sv` — SVT AXI VIP ↔ repo `axi4` bus adapter
- `verif/models/` — Extracted SVT VIP models (gitignored; rebuilt with `make first_time_setup`)
- `flist/tb.vc` / `flist/axi_tb.vc` — VCS file lists
- `sw/tests/*.c` — DPI-C test firmware
- `sw/libs/phyinit.c` — Auto-generated PHY init sequence

## Important Conventions

- **VCS + UVM only** — No other simulator support is configured.
- **`verif/models/` is gitignored** — Never modify; regenerate with `make first_time_setup` if missing.
- **`sim/` and `sw/build/` are gitignored** — Simulation artifacts and compiled `.so` files.
- **Default test** — `make run_vcs` runs `dram_tests` by default. Override with `TESTNAME=foo`.
- **Two APB buses** — `DRAM_CFG_APB` (APB3, UMCTL2) and `DRAM_PHY_CFG_APB` (APB4, PHY config).
- **File lists depend on env vars** — `flist/tb.vc` references `$LPDDR4_PROJECT_DIR`, `$SYNOPSYS_LPDDR4_UMCTL2_DIR`, etc. VCS compilation fails if unset.
