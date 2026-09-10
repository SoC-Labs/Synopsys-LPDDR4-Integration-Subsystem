#ifndef APB_ACCESS_H
#define APB_ACCESS_H

#include <stdint.h>
#include "svdpi.h"

extern void sv_apb3_write(uint32_t addr, uint32_t data);
extern void sv_apb3_read(uint32_t addr, uint32_t *data);
extern void sv_apb4_write(uint32_t addr, uint32_t data);
extern void sv_apb4_read(uint32_t addr, uint32_t *data);

#define APB_TIMEOUT_ERROR 0xDEADBEEF

static inline void apb_set_dpi_scope(void) {
    svScope scope = svGetScopeFromName("lpddr4_tb.u_dpi_apb");
    if (scope != NULL) {
        svSetScope(scope);
    }
}

static inline void apb_set_tb_scope(void) {
    svScope scope = svGetScopeFromName("lpddr4_tb");
    if (scope != NULL) {
        svSetScope(scope);
    }
}

static inline void apb3_write(uint32_t addr, uint32_t data) {
    apb_set_dpi_scope();
    sv_apb3_write(addr, data);
}

static inline void apb3_read(uint32_t addr, uint32_t *data) {
    apb_set_dpi_scope();
    sv_apb3_read(addr, data);
}

static inline void apb4_write(uint32_t addr, uint32_t data) {
    apb_set_dpi_scope();
    sv_apb4_write(addr, data);
}

static inline void apb4_read(uint32_t addr, uint32_t *data) {
    apb_set_dpi_scope();
    sv_apb4_read(addr, data);
}

static inline int apb3_write_check(uint32_t addr, uint32_t data) {
    uint32_t readback;
    apb3_write(addr, data);
    apb3_read(addr, &readback);
    return (readback == data) ? 0 : -1;
}

static inline int apb4_write_check(uint32_t addr, uint32_t data) {
    uint32_t readback;
    apb4_write(addr, data);
    apb4_read(addr, &readback);
    return (readback == data) ? 0 : -1;
}

#endif