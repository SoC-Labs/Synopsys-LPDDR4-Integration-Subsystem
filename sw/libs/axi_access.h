#ifndef AXI_ACCESS_H
#define AXI_ACCESS_H

#include <stdint.h>
#include "svdpi.h"

extern void sv_axi_write(unsigned long long addr, unsigned long long data, unsigned int burst_length);
extern void sv_axi_read(unsigned long long addr, unsigned long long *data, unsigned int burst_length);

#define AXI_TIMEOUT_ERROR 0xDEADBEEFDEADBEEFULL

static inline void axi_set_dpi_scope(void) {
    svScope scope = svGetScopeFromName("axi_tb.u_dpi_axi");
    if (scope != NULL) {
        svSetScope(scope);
    }
}

static inline void axi_set_tb_scope(void) {
    svScope scope = svGetScopeFromName("axi_tb");
    if (scope != NULL) {
        svSetScope(scope);
    }
}

static inline void axi_write(uint64_t addr, uint64_t data) {
    axi_set_dpi_scope();
    sv_axi_write(addr, data, 1);
}

static inline void axi_read(uint64_t addr, uint64_t *data) {
    axi_set_dpi_scope();
    sv_axi_read(addr, data, 1);
}

static inline void axi_burst_write(uint64_t addr, uint64_t data, unsigned int len) {
    axi_set_dpi_scope();
    sv_axi_write(addr, data, len);
}

static inline void axi_burst_read(uint64_t addr, uint64_t *data, unsigned int len) {
    axi_set_dpi_scope();
    sv_axi_read(addr, data, len);
}

static inline int axi_write_check(uint64_t addr, uint64_t data) {
    uint64_t readback;
    axi_write(addr, data);
    axi_read(addr, &readback);
    return (readback == data) ? 0 : -1;
}

#endif