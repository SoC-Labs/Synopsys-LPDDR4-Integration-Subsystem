#ifndef AXI_ACCESS_H
#define AXI_ACCESS_H

#include <stdint.h>
#include "svdpi.h"

extern void sv_axi_write(unsigned long long addr, unsigned long long data, unsigned int burst_length);
extern void sv_axi_read(unsigned long long addr, unsigned long long *data, unsigned int burst_length);
extern void sv_axi_write_strb(unsigned long long addr, unsigned long long data, unsigned int burst_length, unsigned char strb);
extern void sv_axi_queue(int is_write, unsigned long long addr, unsigned long long data, unsigned int burst_length, unsigned int id, unsigned char strb);
extern void sv_axi_run_queue(unsigned int *not_done);
extern unsigned long long sv_axi_queue_beat(unsigned int idx, unsigned int beat);
extern void sv_axi_narrow(int is_write, unsigned long long addr, unsigned long long data, unsigned int size_bytes, unsigned char strb, unsigned long long *rdata);
extern unsigned int sv_axi_last_read_len(void);
extern unsigned long long sv_axi_last_read_beat(unsigned int idx);

#define AXI_TIMEOUT_ERROR 0xDEADBEEFDEADBEEFULL

static inline void axi_set_dpi_scope(void) {
    svScope scope = svGetScopeFromName("lpddr4_tb.u_dpi_axi");
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

// Write with a byte strobe (bit n enables data byte n) applied to every beat
static inline void axi_write_strb(uint64_t addr, uint64_t data, uint8_t strb) {
    axi_set_dpi_scope();
    sv_axi_write_strb(addr, data, 1, strb);
}

static inline void axi_burst_read(uint64_t addr, uint64_t *data, unsigned int len) {
    axi_set_dpi_scope();
    sv_axi_read(addr, data, len);
}

// Beats of the most recent axi_read/axi_burst_read (0xDEADBEEF... if idx is out of range)
static inline unsigned int axi_last_read_len(void) {
    axi_set_dpi_scope();
    return sv_axi_last_read_len();
}

static inline uint64_t axi_last_read_beat(unsigned int idx) {
    axi_set_dpi_scope();
    return sv_axi_last_read_beat(idx);
}

// Queued (concurrent) transactions: queue several, then run them together.
// Writes put beat i = data + i, as axi_burst_write does. Returns the number
// of transactions that did not complete.
static inline void axi_queue_write(uint64_t addr, uint64_t data, unsigned int len, unsigned int id) {
    axi_set_dpi_scope();
    sv_axi_queue(1, addr, data, len, id, 0xff);
}

static inline void axi_queue_write_strb(uint64_t addr, uint64_t data, unsigned int len, unsigned int id, uint8_t strb) {
    axi_set_dpi_scope();
    sv_axi_queue(1, addr, data, len, id, strb);
}

static inline void axi_queue_read(uint64_t addr, unsigned int len, unsigned int id) {
    axi_set_dpi_scope();
    sv_axi_queue(0, addr, 0, len, id, 0xff);
}

static inline unsigned int axi_run_queue(void) {
    unsigned int not_done = 0;
    axi_set_dpi_scope();
    sv_axi_run_queue(&not_done);
    return not_done;
}

// Beat of the idx-th queued transaction (in queue order) of the last run
static inline uint64_t axi_queue_beat(unsigned int idx, unsigned int beat) {
    axi_set_dpi_scope();
    return sv_axi_queue_beat(idx, beat);
}

// Single-beat narrow transfers (size 1, 2 or 4 bytes)
static inline void axi_narrow_write(uint64_t addr, uint64_t data, unsigned int size, uint8_t strb) {
    unsigned long long dummy;
    axi_set_dpi_scope();
    sv_axi_narrow(1, addr, data, size, strb, &dummy);
}

static inline uint64_t axi_narrow_read(uint64_t addr, unsigned int size) {
    unsigned long long rd = 0;
    axi_set_dpi_scope();
    sv_axi_narrow(0, addr, 0, size, 0xff, &rd);
    return rd;
}

static inline int axi_write_check(uint64_t addr, uint64_t data) {
    uint64_t readback;
    axi_write(addr, data);
    axi_read(addr, &readback);
    return (readback == data) ? 0 : -1;
}

#endif