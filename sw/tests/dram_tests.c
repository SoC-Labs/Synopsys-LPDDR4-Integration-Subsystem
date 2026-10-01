#include "vc_hdrs.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "apb_access.h"
#include "axi_access.h"

extern void endSim();
extern void phyinit();

int no_training=0;

void apb3_bit_set(uint32_t addr, uint32_t bit){
    uint32_t reg;
    apb3_read(addr, &reg); // read
    reg = reg | (1<<bit); // modify
    apb3_write(addr, reg);
    return;
}
void apb3_bit_clear(uint32_t addr, uint32_t bit){
    uint32_t reg;
    apb3_read(addr, &reg); // read
    reg = reg & (~((uint32_t)1<<bit)); // modify
    apb3_write(addr, reg);
    return;
}

// uMCTL2 registers relevant to an LPDDR4 single-rank, single-port build.
// Offsets are the standard uMCTL2 map -- check against the databook register
// table. Registers not present in this configuration read back as 0.
typedef struct { const char *name; uint32_t addr; } umctl2_reg_t;

static const umctl2_reg_t umctl2_regs[] = {
    {"MSTR",       0x000}, {"STAT",       0x004},
    {"MRCTRL0",    0x010}, {"MRCTRL1",    0x014},
    {"DERATEEN",   0x020}, {"DERATEINT",  0x024},
    {"PWRCTL",     0x030}, {"PWRTMG",     0x034}, {"HWLPCTL",    0x038},
    {"RFSHCTL0",   0x050}, {"RFSHCTL1",   0x054}, {"RFSHCTL3",   0x060},
    {"RFSHTMG",    0x064}, {"RFSHTMG1",   0x068},
    {"ECCCFG0",    0x070}, {"ECCCFG1",    0x074},
    {"CRCPARCTL0", 0x0c0},
    {"INIT0",      0x0d0}, {"INIT1",      0x0d4}, {"INIT2",      0x0d8},
    {"INIT3",      0x0dc}, {"INIT4",      0x0e0}, {"INIT5",      0x0e4},
    {"INIT6",      0x0e8}, {"INIT7",      0x0ec},
    {"DIMMCTL",    0x0f0}, {"RANKCTL",    0x0f4},
    {"DRAMTMG0",   0x100}, {"DRAMTMG1",   0x104}, {"DRAMTMG2",   0x108},
    {"DRAMTMG3",   0x10c}, {"DRAMTMG4",   0x110}, {"DRAMTMG5",   0x114},
    {"DRAMTMG6",   0x118}, {"DRAMTMG7",   0x11c}, {"DRAMTMG8",   0x120},
    {"DRAMTMG12",  0x130}, {"DRAMTMG13",  0x134}, {"DRAMTMG14",  0x138},
    {"ZQCTL0",     0x180}, {"ZQCTL1",     0x184}, {"ZQCTL2",     0x188},
    {"DFITMG0",    0x190}, {"DFITMG1",    0x194}, {"DFILPCFG0",  0x198},
    {"DFIUPD0",    0x1a0}, {"DFIUPD1",    0x1a4}, {"DFIUPD2",    0x1a8},
    {"DFIMISC",    0x1b0}, {"DFITMG2",    0x1b4}, {"DFISTAT",    0x1bc},
    {"DBICTL",     0x1c0}, {"DFIPHYMSTR", 0x1c4},
    {"ADDRMAP1",   0x204}, {"ADDRMAP2",   0x208}, {"ADDRMAP3",   0x20c},
    {"ADDRMAP4",   0x210}, {"ADDRMAP5",   0x214}, {"ADDRMAP6",   0x218},
    {"ADDRMAP7",   0x21c}, {"ADDRMAP9",   0x224}, {"ADDRMAP10",  0x228},
    {"ADDRMAP11",  0x22c},
    {"ODTCFG",     0x240}, {"ODTMAP",     0x244},
    {"SCHED",      0x250}, {"SCHED1",     0x254},
    {"PERFHPR1",   0x25c}, {"PERFLPR1",   0x264}, {"PERFWR1",    0x26c},
    {"DBG0",       0x300}, {"DBG1",       0x304}, {"DBGCMD",     0x30c},
    {"SWCTL",      0x320}, {"SWSTAT",     0x324}, {"SWCTLSTATIC",0x328},
    {"PCCFG",      0x400}, {"PCFGR_0",    0x404}, {"PCFGW_0",    0x408},
    {"PCTRL_0",    0x490}, {"PCFGQOS0_0", 0x494},
};

// Read-only dump; lines are prefixed REGDUMP so they can be grepped/diffed
void dump_umctl2_regs(const char *tag){
    uint32_t val;
    printf("REGDUMP ---- %s ----\n", tag);
    for (unsigned i = 0; i < sizeof(umctl2_regs)/sizeof(umctl2_regs[0]); i++) {
        apb3_read(umctl2_regs[i].addr, &val);
        printf("REGDUMP [%s] %-11s 0x%03x = 0x%08x\n",
               tag, umctl2_regs[i].name, umctl2_regs[i].addr, val);
    }
}

// Write a controller register and read it back; prints REGPROG lines so a
// wrong field position (readback != written) shows up in the log.
static int prog_errors = 0;
static int mutation_run = 0;
void prog_reg(const char *name, uint32_t addr, uint32_t val){
    uint32_t rb;
    apb3_write(addr, val);
    apb3_read(addr, &rb);
    printf("REGPROG %-10s 0x%03x <= 0x%08x readback 0x%08x%s\n",
           name, addr, val, rb, (rb == val) ? "" : "  MISMATCH");
    if (rb != val) prog_errors++;
}

// ----------------------------------------------------------------------
// Functional tests. Each returns its error count and prints at most a few
// mismatch lines so the log stays readable.
// ----------------------------------------------------------------------

// Report one mismatch (first 10 per test only)
static void report_mismatch(const char *test, int errors, uint64_t addr,
                            uint64_t act, uint64_t exp){
    if (errors < 10)
        printf("  ERROR [%s] addr 0x%08llx: got 0x%016llX expected 0x%016llX\n",
               test, (unsigned long long)addr, (unsigned long long)act,
               (unsigned long long)exp);
}

static unsigned dfi_count(unsigned kind);

// T1: one 256-beat INCR burst; the AXI sequence writes beat i as (base + i).
// 256 x 8 bytes = 2KB = exactly one DRAM row, so this checks the data path
// and column bits only.
int test_burst(void){
    const uint64_t     axi_addr = 0x00000000ULL;
    const uint64_t     base     = 0x1122334455667788ULL;
    const unsigned int beats    = 256;
    uint64_t rd_data = 0;
    int errors = 0;

    printf("=== T1: burst write/read (%u beats at 0x%08llx) ===\n",
           beats, (unsigned long long)axi_addr);
    // ACT count per burst shows the page policy: 256 beats = 2KB = one row,
    // so with row hits the write/read each need very few ACTIVATEs
    unsigned act0 = dfi_count(0);
    axi_burst_write(axi_addr, base, beats);
    unsigned act1 = dfi_count(0);
    axi_burst_read(axi_addr, &rd_data, beats);
    unsigned act2 = dfi_count(0);
    printf("  ACTIVATEs: %u during the write burst, %u during the read burst\n",
           act1 - act0, act2 - act1);

    unsigned int got = axi_last_read_len();
    if (got != beats) {
        printf("  ERROR [T1] read returned %u beats, expected %u\n", got, beats);
        errors++;
    }
    for (unsigned int i = 0; i < got && i < beats; i++) {
        uint64_t exp = base + i, act = axi_last_read_beat(i);
        if (act != exp) report_mismatch("T1", errors++, axi_addr + 8*i, act, exp);
    }
    printf("  %u beats compared, %d mismatch(es)\n", got, errors);

    // Page-policy probe: 16 separate 32-byte writes to consecutive addresses
    // in one row (like cache-line writebacks), then 16 separate reads. With
    // forced auto-precharge every transaction needs its own ACTIVATE.
    const uint64_t row_addr = 0x00200000ULL;       // row 128, bank 0
    act0 = dfi_count(0);
    for (unsigned i = 0; i < 16; i++) axi_burst_write(row_addr + 32*i, base + 4*i, 4);
    act1 = dfi_count(0);
    for (unsigned i = 0; i < 16; i++) {
        axi_burst_read(row_addr + 32*i, &rd_data, 4);
        for (unsigned b = 0; b < 4; b++) {
            uint64_t act = axi_last_read_beat(b), exp = base + 4*i + b;
            if (act != exp) report_mismatch("T1-row", errors++, row_addr + 32*i + 8*b, act, exp);
        }
    }
    act2 = dfi_count(0);
    printf("  16 separate 32B writes/reads in one row: %u / %u ACTIVATEs\n", act1 - act0, act2 - act1);
    return errors;
}

// T2: address-map walk. The configured map (16-bit DRAM words, AXI byte
// address) is: column = AXI[10:1], bank = AXI[13:11], row = AXI[27:14],
// 256MB total. Write a unique value at every single-bit address, every bank
// and several rows of one bank, then read everything back. If two AXI
// addresses aliased to the same DRAM location, the later write would
// overwrite the earlier one and show up as a mismatch.
#define T2_MAX_ADDRS 64
static uint64_t t2_pattern(uint64_t addr){
    // upper word = ~addr, lower word = addr: unique for every address < 4GB
    return ((uint64_t)(~addr & 0xffffffffULL) << 32) | (addr & 0xffffffffULL);
}

int test_address_walk(void){
    uint64_t addrs[T2_MAX_ADDRS];
    int n = 0, errors = 0;

    #define T2_ADD(a) do { uint64_t _a = (a); int _dup = 0;          \
        for (int _i = 0; _i < n; _i++) if (addrs[_i] == _a) _dup = 1; \
        if (!_dup && n < T2_MAX_ADDRS) addrs[n++] = _a; } while (0)

    T2_ADD(0x0ULL);
    for (int k = 3; k <= 27; k++) T2_ADD(1ULL << k);           // every address bit
    for (int b = 0; b < 8; b++)   T2_ADD((5ULL << 14) | ((uint64_t)b << 11) | 0x40); // all banks, row 5
    const uint64_t rows[] = {1, 2, 0x155, 0x1000, 0x2aaa, 0x3fff};
    for (unsigned i = 0; i < sizeof(rows)/sizeof(rows[0]); i++)
        T2_ADD((rows[i] << 14) | (3ULL << 11) | 0x80);          // row switches, bank 3
    T2_ADD(0x0ffffff8ULL);                                     // last 8 bytes of 256MB
    #undef T2_ADD

    printf("=== T2: address walk (%d addresses) ===\n", n);
    for (int i = 0; i < n; i++) axi_write(addrs[i], t2_pattern(addrs[i]));
    for (int i = 0; i < n; i++) {
        uint64_t act = 0, exp = t2_pattern(addrs[i]);
        axi_read(addrs[i], &act);
        if (act != exp) report_mismatch("T2", errors++, addrs[i], act, exp);
    }
    printf("  %d addresses compared, %d mismatch(es)\n", n, errors);
    return errors;
}

// T3: partial (byte-strobed) writes. Each case initialises a location with
// a full write, overwrites selected bytes with a strobed write, and checks
// the merge. The last case merges two partial writes into one location.
// This matters because DM is disabled in the DRAM (MR13 DMD=1): the
// controller must turn sub-sized writes into read-modify-write (its RMW support).
//
// Neighbour integrity: one BL16 burst is 32 bytes = 4 AXI beats, so every
// single-beat write is itself a partial burst write. Cases share bursts
// (region + 8*i), so after all cases every location is re-read to check that
// later writes did not disturb earlier neighbours. A dedicated 4-beat case
// then updates beats 1 and 2 of one burst and checks beats 0 and 3.
static uint64_t strb_mask(uint8_t strb){
    uint64_t m = 0;
    for (int b = 0; b < 8; b++) if (strb & (1u << b)) m |= 0xffULL << (8*b);
    return m;
}

int test_partial_writes(void){
    const uint64_t region = 0x00100000ULL;     // row 64, away from T1/T2 data
    const uint64_t init   = 0x0123456789abcdefULL;
    const uint64_t newd   = 0xfedcba9876543210ULL;
    const uint8_t strbs[] = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
                             0x03, 0x0c, 0x30, 0xc0, 0x0f, 0xf0, 0x3c, 0x81,
                             0x55, 0xaa, 0x7e, 0xfe};
    const int ncases = sizeof(strbs)/sizeof(strbs[0]);
    uint64_t final_exp[sizeof(strbs)/sizeof(strbs[0])];
    int errors = 0;

    printf("=== T3: partial writes (%d strobe patterns + 1 merge) ===\n", ncases);
    for (int i = 0; i < ncases; i++) {
        uint64_t addr = region + 8ULL*i, act = 0;
        uint64_t m    = strb_mask(strbs[i]);
        uint64_t exp  = (init & ~m) | (newd & m);
        final_exp[i]  = exp;
        axi_write(addr, init);
        axi_write_strb(addr, newd, strbs[i]);
        axi_read(addr, &act);
        if (act != exp) {
            if (errors < 10) printf("  strobe 0x%02x:\n", strbs[i]);
            report_mismatch("T3", errors++, addr, act, exp);
        }
    }

    // Two partial writes into the same location
    {
        uint64_t addr = region + 0x800, act = 0;
        uint64_t d1 = 0x1111111111111111ULL, d2 = 0x2222222222222222ULL;
        uint64_t exp = (init & ~strb_mask(0x0f) & ~strb_mask(0xf0))
                     | (d1 & strb_mask(0x0f)) | (d2 & strb_mask(0xf0));
        axi_write(addr, init);
        axi_write_strb(addr, d1, 0x0f);
        axi_write_strb(addr, d2, 0xf0);
        axi_read(addr, &act);
        if (act != exp) {
            if (errors < 10) printf("  merge 0x0f then 0xf0:\n");
            report_mismatch("T3", errors++, addr, act, exp);
        }
    }
    printf("  %d cases compared, %d mismatch(es)\n", ncases + 1, errors);

    // Neighbour re-check: every case location still holds its final value
    int nb_errors = 0;
    for (int i = 0; i < ncases; i++) {
        uint64_t addr = region + 8ULL*i, act = 0;
        axi_read(addr, &act);
        if (act != final_exp[i]) report_mismatch("T3-neighbour", nb_errors++, addr, act, final_exp[i]);
    }
    printf("  neighbour re-check: %d locations, %d mismatch(es)\n", ncases, nb_errors);
    errors += nb_errors;

    // One 32-byte burst: fill 4 beats, full-write beat 1, strobe-write beat 2,
    // then burst-read all 4 and check beats 0 and 3 were untouched
    {
        const uint64_t baddr = region + 0x1000;          // 32-byte aligned
        const uint64_t base  = 0xa0a0a0a0a0a0a0a0ULL;    // burst writes base + i
        const uint64_t b1    = 0x5a5a5a5a5a5a5a5aULL;
        const uint64_t b2    = 0x3c3c3c3c3c3c3c3cULL;
        uint64_t exp[4], rd = 0;
        exp[0] = base + 0;
        exp[1] = b1;
        exp[2] = ((base + 2) & ~strb_mask(0x0f)) | (b2 & strb_mask(0x0f));
        exp[3] = base + 3;
        int bb_errors = 0;

        axi_burst_write(baddr, base, 4);
        axi_write(baddr + 8, b1);
        axi_write_strb(baddr + 16, b2, 0x0f);
        axi_burst_read(baddr, &rd, 4);
        if (axi_last_read_len() != 4) {
            printf("  ERROR [T3-burst] read returned %u beats, expected 4\n", axi_last_read_len());
            bb_errors++;
        }
        for (unsigned i = 0; i < 4 && i < axi_last_read_len(); i++) {
            uint64_t act = axi_last_read_beat(i);
            if (act != exp[i]) report_mismatch("T3-burst", bb_errors++, baddr + 8*i, act, exp[i]);
        }
        printf("  burst neighbour case: 4 beats, %d mismatch(es)\n", bb_errors);
        errors += bb_errors;
    }
    return errors;
}

// T4: timing stress. Transactions are queued and run concurrently so the
// controller has several requests outstanding and issues commands close
// together. All bursts are 4 beats, 32-byte aligned (one full BL16 burst,
// so no RMW). The memory model's timing checks are the main pass criterion;
// data is compared as well.
//   (a) bank interleave: 16 bursts over 8 banks x 2 rows  -> tRRD, tFAW, tRC
//   (b) row thrash: 8 bursts alternating 2 rows of bank 6  -> tRP, tRAS, tRC
//   (c) mixed: reads of (a) interleaved with writes to new rows -> wr2rd, rd2wr
#define T4_ADDR(row, bank) (((uint64_t)(row) << 14) | ((uint64_t)(bank) << 11) | 0x200)
static uint64_t t4_data(uint64_t addr){ return 0xb000000000000000ULL | (addr << 8); }

// Compare the 4 beats of queued transaction idx against t4_data(addr) + i
static int t4_check(const char *tag, unsigned idx, uint64_t addr){
    int errors = 0;
    for (unsigned b = 0; b < 4; b++) {
        uint64_t act = axi_queue_beat(idx, b), exp = t4_data(addr) + b;
        if (act != exp) report_mismatch(tag, errors++, addr + 8*b, act, exp);
    }
    return errors;
}

static int t4_run(const char *tag){
    unsigned not_done = axi_run_queue();
    if (not_done) printf("  ERROR [%s] %u transaction(s) did not complete\n", tag, not_done);
    return (int)not_done;
}

int test_timing_stress(void){
    uint64_t a[16], b[8], c[8];
    int errors = 0;

    printf("=== T4: timing stress (concurrent transactions) ===\n");

    // (a) bank interleave
    for (int k = 0; k < 16; k++) a[k] = T4_ADDR(100 + k/8, k % 8);
    for (int k = 0; k < 16; k++) axi_queue_write(a[k], t4_data(a[k]), 4, 1 + k % 4);
    errors += t4_run("T4a-wr");
    for (int k = 0; k < 16; k++) axi_queue_read(a[k], 4, 1 + k % 4);
    errors += t4_run("T4a-rd");
    int ea = 0;
    for (int k = 0; k < 16; k++) ea += t4_check("T4a", k, a[k]);
    printf("  (a) bank interleave : 16 bursts, %d mismatch(es)\n", ea);
    errors += ea;

    // (b) row thrash in one bank
    for (int k = 0; k < 8; k++) b[k] = T4_ADDR(200 + (k & 1), 6) + 0x20 * (k / 2);
    for (int k = 0; k < 8; k++) axi_queue_write(b[k], t4_data(b[k]), 4, 1 + k % 4);
    errors += t4_run("T4b-wr");
    for (int k = 0; k < 8; k++) axi_queue_read(b[k], 4, 1 + k % 4);
    errors += t4_run("T4b-rd");
    int eb = 0;
    for (int k = 0; k < 8; k++) eb += t4_check("T4b", k, b[k]);
    printf("  (b) row thrash      : 8 bursts, %d mismatch(es)\n", eb);
    errors += eb;

    // (c) mixed: read (a) locations while writing new rows, then read those back
    for (int k = 0; k < 8; k++) c[k] = T4_ADDR(300 + k/4, (k * 3) % 8);
    for (int k = 0; k < 8; k++) {
        axi_queue_read(a[k], 4, 1 + k % 4);                  // queue index 2k
        axi_queue_write(c[k], t4_data(c[k]), 4, 5 + k % 4);  // queue index 2k+1
    }
    errors += t4_run("T4c-mix");
    int ec = 0;
    for (int k = 0; k < 8; k++) ec += t4_check("T4c-rd", 2*k, a[k]);
    for (int k = 0; k < 8; k++) axi_queue_read(c[k], 4, 1 + k % 4);
    errors += t4_run("T4c-rd");
    for (int k = 0; k < 8; k++) ec += t4_check("T4c-wr", k, c[k]);
    printf("  (c) mixed rd/wr     : 16 bursts, %d mismatch(es)\n", ec);
    errors += ec;

    return errors;
}

// ----------------------------------------------------------------------
// Testbench helpers (lpddr4_tb): DFI command counter and simulation delay
// ----------------------------------------------------------------------
extern unsigned int sv_dfi_cmd_count(unsigned int kind);
extern void sv_wait_ns(unsigned int ns);
enum { DFI_ACT = 0, DFI_REF = 1, DFI_SRE = 2, DFI_SRX = 3 };

static unsigned dfi_count(unsigned kind){ apb_set_tb_scope(); return sv_dfi_cmd_count(kind); }
static void     wait_us(unsigned us)    { apb_set_tb_scope(); sv_wait_ns(us * 1000); }
static unsigned op_mode(void)           { uint32_t v; apb3_read(0x4, &v); return v & 7; }

// T5: retention across refresh and self-refresh.
// A data set of 16 bursts (8 banks x 2 rows) is written once, then after each
// scenario read back and checked:
//   (a) idle 16us with self-refresh disabled -> controller must issue REFs
//       (tREFI 3.9us, so >= 3 expected)
//   (b) idle 16us with self-refresh enabled -> automatic SR entry after the
//       PWRTMG.selfref_to_x32 idle time (reset value ~5.1us), STAT = 3,
//       then the read wakes it (SRX)
//   (c) software-requested self-refresh via PWRCTL.selfref_sw
//   (d) continuous concurrent traffic across several refresh intervals, so
//       REFs land in the middle of traffic (tRFC is exercised; also used by
//       the tRFC mutation run)
#define T5_ADDR(k) (((uint64_t)(400 + (k)/8) << 14) | ((uint64_t)((k) % 8) << 11) | 0x400)

static int t5_verify(const char *tag){
    int errors = 0;
    for (int k = 0; k < 16; k++) axi_queue_read(T5_ADDR(k), 4, 1 + k % 4);
    errors += t4_run(tag);
    for (int k = 0; k < 16; k++) errors += t4_check(tag, k, T5_ADDR(k));
    return errors;
}

int test_retention(void){
    int errors = 0, e;
    unsigned r0, r1, s0, x0, polls;

    printf("=== T5: retention (refresh, self-refresh) ===\n");
    for (int k = 0; k < 16; k++) axi_queue_write(T5_ADDR(k), t4_data(T5_ADDR(k)), 4, 1 + k % 4);
    errors += t4_run("T5-init");

    // (a) refresh only
    apb3_bit_clear(0x30, 0);                       // PWRCTL.selfref_en = 0
    r0 = dfi_count(DFI_REF);
    wait_us(16);
    r1 = dfi_count(DFI_REF);
    e = t5_verify("T5a");
    if (r1 - r0 < 3) { printf("  ERROR [T5a] only %u REF in 16us (expected >= 3)\n", r1 - r0); e++; }
    printf("  (a) idle 16us, SR off : %u REF, %d error(s)\n", r1 - r0, e);
    errors += e;

    // (b) automatic self-refresh on idle
    apb3_bit_set(0x30, 0);                         // PWRCTL.selfref_en = 1
    s0 = dfi_count(DFI_SRE); x0 = dfi_count(DFI_SRX);
    wait_us(16);
    unsigned mode_idle = op_mode();
    unsigned sre = dfi_count(DFI_SRE) - s0;
    e = t5_verify("T5b");                          // access wakes the controller
    unsigned srx = dfi_count(DFI_SRX) - x0;
    if (mode_idle != 3) { printf("  ERROR [T5b] STAT.operating_mode = %u after 16us idle (expected 3)\n", mode_idle); e++; }
    if (sre < 1)        { printf("  ERROR [T5b] no SRE issued\n"); e++; }
    if (srx < 1)        { printf("  ERROR [T5b] no SRX issued on access\n"); e++; }
    printf("  (b) idle 16us, SR on  : mode %u, %u SRE, %u SRX, %d error(s)\n", mode_idle, sre, srx, e);
    errors += e;

    // (c) software-requested self-refresh
    e = 0;
    apb3_bit_clear(0x30, 0);                       // no automatic SR while testing SW SR
    s0 = dfi_count(DFI_SRE); x0 = dfi_count(DFI_SRX);
    apb3_bit_set(0x30, 5);                         // PWRCTL.selfref_sw = 1
    polls = 0;
    while (op_mode() != 3 && polls++ < 2000) ;
    unsigned mode_sw = op_mode();
    wait_us(5);
    apb3_bit_clear(0x30, 5);                       // PWRCTL.selfref_sw = 0
    polls = 0;
    while (op_mode() == 3 && polls++ < 2000) ;
    unsigned mode_after = op_mode();
    e += t5_verify("T5c");
    if (mode_sw != 3)    { printf("  ERROR [T5c] did not enter self-refresh (mode %u)\n", mode_sw); e++; }
    if (mode_after == 3) { printf("  ERROR [T5c] did not leave self-refresh\n"); e++; }
    printf("  (c) software SR       : entered mode %u, left to mode %u, %u SRE, %u SRX, %d error(s)\n",
           mode_sw, mode_after, dfi_count(DFI_SRE) - s0, dfi_count(DFI_SRX) - x0, e);
    errors += e;

    // (d) traffic across refreshes: keep reading until >= 3 REFs have landed
    e = 0;
    r0 = dfi_count(DFI_REF);
    int loops = 0;
    while (dfi_count(DFI_REF) - r0 < 3 && loops < 60) { e += t5_verify("T5d"); loops++; }
    r1 = dfi_count(DFI_REF);
    if (r1 - r0 < 3) { printf("  ERROR [T5d] only %u REF during traffic\n", r1 - r0); e++; }
    printf("  (d) traffic x%d loops  : %u REF during traffic, %d error(s)\n", loops, r1 - r0, e);
    errors += e;

    apb3_bit_set(0x30, 0);                         // restore PWRCTL.selfref_en = 1
    return errors;
}

// T6: constrained-random traffic checked against a C shadow model.
// 64 slots of 64 bytes (8 beats) at random 64-byte-aligned addresses across
// the whole 256MB. Each batch runs 8 concurrent operations on 8 distinct
// slots (so there are no same-address hazards inside a batch): random
// read/write, random start beat and length inside the slot (so bursts are
// often partial or straddle a 32-byte BL16 boundary -> RMW), and a random
// byte strobe on a quarter of the writes. Reads are checked against the
// shadow; writes then update it. Seed: DRAM_SEED env var (default 1).
#define T6_SLOTS   64
#define T6_BATCHES 40
#define T6_OPS      8
static uint64_t t6_rng;
static uint64_t t6_rand(void){             // 64-bit LCG, high bits are good enough
    t6_rng = t6_rng * 6364136223846793005ULL + 1442695040888963407ULL;
    return t6_rng >> 17;
}

int test_random(void){
    static uint64_t slot_addr[T6_SLOTS];
    static uint64_t shadow[T6_SLOTS][8];
    const char *seed_env = getenv("DRAM_SEED");
    unsigned long seed = seed_env ? strtoul(seed_env, NULL, 0) : 1;
    int errors = 0, nreads = 0, nwrites = 0, nstrb = 0;
    t6_rng = seed;

    printf("=== T6: random traffic (seed %lu, %d batches x %d ops) ===\n", seed, T6_BATCHES, T6_OPS);

    // Pick distinct slots and initialise them with known data
    for (int s = 0; s < T6_SLOTS; s++) {
        uint64_t a; int dup;
        do {
            a = (t6_rand() % (256ULL << 20)) & ~0x3fULL;
            dup = 0;
            for (int j = 0; j < s; j++) if (slot_addr[j] == a) dup = 1;
        } while (dup);
        slot_addr[s] = a;
        uint64_t base = t6_rand();
        for (int b = 0; b < 8; b++) shadow[s][b] = base + b;
        axi_queue_write(a, base, 8, 1 + s % 4);
        if (s % 16 == 15) errors += t4_run("T6-init");
    }

    for (int batch = 0; batch < T6_BATCHES; batch++) {
        int slot[T6_OPS], wr[T6_OPS], start[T6_OPS], len[T6_OPS];
        uint64_t data[T6_OPS]; uint8_t strb[T6_OPS];
        for (int i = 0; i < T6_OPS; i++) {
            int dup;
            do {
                slot[i] = t6_rand() % T6_SLOTS;
                dup = 0;
                for (int j = 0; j < i; j++) if (slot[j] == slot[i]) dup = 1;
            } while (dup);
            wr[i]    = t6_rand() & 1;
            start[i] = t6_rand() % 8;
            len[i]   = 1 + t6_rand() % (8 - start[i]);
            data[i]  = t6_rand();
            strb[i]  = (wr[i] && (t6_rand() % 4 == 0)) ? (uint8_t)(1 + t6_rand() % 255) : 0xff;
            uint64_t addr = slot_addr[slot[i]] + 8ULL * start[i];
            unsigned id = 1 + t6_rand() % 8;
            if (wr[i]) axi_queue_write_strb(addr, data[i], len[i], id, strb[i]);
            else       axi_queue_read(addr, len[i], id);
        }
        errors += t4_run("T6");
        for (int i = 0; i < T6_OPS; i++) {
            uint64_t *sh = &shadow[slot[i]][start[i]];
            uint64_t addr = slot_addr[slot[i]] + 8ULL * start[i];
            if (!wr[i]) {
                nreads++;
                for (int b = 0; b < len[i]; b++) {
                    uint64_t act = axi_queue_beat(i, b);
                    if (act != sh[b]) report_mismatch("T6", errors++, addr + 8*b, act, sh[b]);
                }
            } else {
                uint64_t m = strb_mask(strb[i]);
                nwrites++; if (strb[i] != 0xff) nstrb++;
                for (int b = 0; b < len[i]; b++) sh[b] = (sh[b] & ~m) | ((data[i] + b) & m);
            }
        }
    }

    // Final sweep: every slot must match the shadow
    for (int s = 0; s < T6_SLOTS; s += 16) {
        for (int j = 0; j < 16; j++) axi_queue_read(slot_addr[s + j], 8, 1 + j % 4);
        errors += t4_run("T6-final");
        for (int j = 0; j < 16; j++)
            for (int b = 0; b < 8; b++) {
                uint64_t act = axi_queue_beat(j, b);
                if (act != shadow[s + j][b])
                    report_mismatch("T6-final", errors++, slot_addr[s + j] + 8*b, act, shadow[s + j][b]);
            }
    }
    printf("  %d reads, %d writes (%d strobed), final sweep of %d slots, %d mismatch(es)\n",
           nreads, nwrites, nstrb, T6_SLOTS, errors);
    return errors;
}

// T8: narrow AXI transfers (AxSIZE < 64 bit), single beat, every aligned
// offset for 8-, 16- and 32-bit sizes. Each case starts from a known 64-bit
// word, does a narrow write, checks the whole word with a full 64-bit read
// (right lane changed, neighbours intact), then reads the bytes back with a
// narrow read.
// The SVT AXI VIP uses right-justified ("packed") data and strobes for
// narrow transfers in its default configuration and places them on the
// correct byte lanes itself, so data/strobe are passed right-justified here.
// (A first version passed bus-lane strobes; every non-zero offset then wrote
// nothing, which is how the convention was identified.)
int test_narrow(void){
    const uint64_t region = 0x00300000ULL;          // row 192, bank 0
    const uint64_t init   = 0x0011223344556677ULL;
    const unsigned sizes[] = {1, 2, 4};
    int errors = 0, cases = 0;

    printf("=== T8: narrow transfers (8/16/32-bit, all aligned offsets) ===\n");
    for (unsigned si = 0; si < 3; si++) {
        unsigned sz = sizes[si];
        uint64_t vmask = (sz == 8) ? ~0ULL : ((1ULL << (8*sz)) - 1);
        for (unsigned off = 0; off < 8; off += sz) {
            uint64_t word = region + 8ULL * cases;
            uint64_t addr = word + off;
            uint64_t v    = (0xa5c3e1f0b4d29687ULL + 0x0101010101010101ULL * cases) & vmask;
            uint8_t  strb  = (uint8_t)((1u << sz) - 1);        // right-justified
            uint64_t lanes = strb_mask((uint8_t)(strb << off)); // bytes on the bus
            uint64_t exp_word = (init & ~lanes) | ((v << (8*off)) & lanes);
            uint64_t act = 0;

            axi_write(word, init);
            axi_narrow_write(addr, v, sz, strb);
            axi_read(word, &act);
            if (act != exp_word) {
                if (errors < 10) printf("  size %u offset %u (write):\n", sz, off);
                report_mismatch("T8-write", errors++, word, act, exp_word);
            }

            uint64_t rd = axi_narrow_read(addr, sz);
            if ((rd & vmask) != v) {
                if (errors < 10) printf("  size %u offset %u (read):\n", sz, off);
                report_mismatch("T8-read", errors++, addr, rd & vmask, v);
            }
            cases++;
        }
    }
    printf("  %d cases, %d mismatch(es)\n", cases, errors);
    return errors;
}

void something() {
    printf("DRAM Tests\n");

    printf("** Start DDR CTRL Init **\n");
    uint32_t tmp;

    // Assert the core_ddrc_rstn and aresetn_n resets
    for(int i=0;i<32;i++){apb3_write(0x6008,0x0);} //DDR_RESET_CTRL->CORE_RSTn=0; 
    // Assert presetn
    for(int i=0;i<32;i++){apb3_write(0x600C,0x0);} //DDR_RESET_CTRL->CORE_PRESETn=0;
    // Enable clocks
    apb3_write(0x6010,0x1);
    for(int i=0;i<128;i++){apb3_write(0x6014,0x1);} //DDR_RESET_CTRL->CORE_PRESETn=0;
    // De-assert presetn once the clocks are active and stable
    // Allow 128 cycles for synchronization of presetn to core_ddrc_core_clk and aclk domains and to
    for(int i=0;i<256;i++){apb3_write(0x600C,0x1);} //DDR_RESET_CTRL->CORE_PRESETn=1;

    // Snapshot of reset values before any controller register is written
    dump_umctl2_regs("reset values");

    // Program MSTR (static: must be written while core_ddrc_rstn is asserted).
    // Reset value is 0x00040001 = DDR3 (bit 0), BL8 (burst_rdwr=4), so only
    // setting bit 5 left DDR3 *and* LPDDR4 selected. Write the whole register:
    //   [0]     ddr3        = 0
    //   [5]     lpddr4      = 1
    //   [19:16] burst_rdwr  = 8  (BL16, mandatory for LPDDR4)
    // active_ranks [25:24] only exists in multi-rank controller builds; this is a
    // single-rank build so the field is absent and must be left 0.
    apb3_write(0x0, 0x00080020);
    apb3_read(0x0, &tmp);
    printf("MSTR = 0x%08x (expected 0x00080020)\n", tmp);

    // ------------------------------------------------------------------
    // Static/quasi-dynamic controller setup, written while core_ddrc_rstn
    // is still asserted. Target: LPDDR4-1600 x16, 1 rank, 8 banks,
    // 14 row / 10 col bits (2Gb), DFI 1:2, controller clock 2.5 ns.
    // DRAM timings come from the memory model config in the run log;
    // RL/WL/nWR/DBI from the phyinit MR values (P-state 0):
    //   MR1=0x24 (nWR=16, WR preamble 2tCK)  MR2=0x12 (RL=14, WL=8 set A)
    //   MR3=0x09 (RD/WR DBI off)             MR13=0x28 (DMD=1: DM disabled)
    // Controller clocks = ceil(nCK/2), nCK = ceil(t/1.25ns), rounding up
    // everywhere so every minimum delay is met.
    // DFI timing (DFITMG0/1/2) values follow the PHY documentation's DFI
    // timing tables for this PHY build (no DFI pipeline stages) and the
    // phyinit configuration used here; see the per-register notes below.
    // ------------------------------------------------------------------

    // Timing
    //   t_ras_min=17 (42ns), t_ras_max=27 (70.2us/1024), t_faw=16 (40ns),
    //   wr2pre=17 (WL+BL/2+nWR+1 = 33 nCK)
    prog_reg("DRAMTMG0",  0x100, 0x11101b11);
    //   t_rc=26 (tRAS+tRPab = 63ns), rd2pre=4 (BL/2+max(8,tRTP)-8 = 8 nCK), t_xp=4
    prog_reg("DRAMTMG1",  0x104, 0x0004041a);
    //   wr2rd=13 (WL+BL/2+tWTR+1 = 25 nCK), rd2wr=10 (RL+BL/2+tDQSCK+WPRE+RPST-WL = 20 nCK),
    //   read_latency=7 (RL/2), write_latency=4 (WL/2)
    prog_reg("DRAMTMG2",  0x108, 0x04070a0d);
    //   t_mrd=6 (14ns), t_mrw=5 (10 nCK); t_mod left at reset (DDR3/4 only)
    prog_reg("DRAMTMG3",  0x10c, 0x0050600c);
    //   t_rp=9 (tRPab 21ns), t_rrd=4 (10ns), t_ccd=4 (8 nCK), t_rcd=8 (18ns)
    prog_reg("DRAMTMG4",  0x110, 0x08040409);
    //   t_cke=3, t_ckesr=6 (tSR 15ns), t_cksre/t_cksrx left at (larger) reset
    prog_reg("DRAMTMG5",  0x114, 0x05050603);
    //   t_xsr=55 (tRFCab+7.5ns = 137.5ns)
    prog_reg("DRAMTMG14", 0x138, 0x00000037);

    // DFITMG0, latencies in DFI PHY clocks (= memory clocks, use_dfi_phy_clk=1;
    // the controller halves them internally in 1:2 mode), for RL 14 / WL 8:
    //   dfi_tphy_wrlat  = 4
    //   dfi_tphy_wrdata = 2
    //   dfi_t_rddata_en = 9
    //   dfi_t_ctrl_delay = 7 (reset): the PHY needs about 2 DFI clocks here,
    //     7 is kept as a minimum-wait margin.
    prog_reg("DFITMG0",   0x190, 0x07898204);
    // DFITMG1.dfi_t_wrdata_delay [20:16] = 31 (field maximum; reset was 0):
    //   the PHY needs roughly 18 memory clocks plus its trained write-DQS
    //   delay, so the maximum covers any trained value. It only delays
    //   low-power / clock-stop entry after a write.
    //   dfi_t_dram_clk_enable/disable [4:0]/[12:8] kept at reset (4).
    prog_reg("DFITMG1",   0x194, 0x001f0404);
    // DFITMG2: dfi_tphy_wrcslat = 4 [5:0], dfi_tphy_rdcslat = 9 [13:8], the
    //   same values as wrlat / rddata_en; when dfi_*data_cs_n is asserted
    //   (reset was 2 / 2).
    prog_reg("DFITMG2",   0x1b4, 0x00000904);

    // Refresh: t_rfc_min=52 (tRFCab 130ns), t_rfc_nom_x1_x32=48 (tREFI 3.904us)
    prog_reg("RFSHTMG",   0x064, 0x00300034);

    // Mode register copies (used after self-refresh exit / MRR, and must
    // match what phyinit trained the DRAM with)
    prog_reg("INIT3",     0x0dc, 0x00240012);  // mr=MR1,   emr=MR2
    prog_reg("INIT4",     0x0e0, 0x00090028);  // emr2=MR3, emr3=MR13
    prog_reg("INIT6",     0x0e8, 0x0033002b);  // mr4=MR11, mr5=MR12
    prog_reg("INIT7",     0x0ec, 0x0018002b);  // mr22=MR22, mr6=MR14

    // DM/DBI off to match MR13.DMD=1 and MR3 DBI-RD/WR=0 (reset had dm_en=1)
    prog_reg("DBICTL",    0x1c0, 0x00000000);

    // Address map, HIF word address (16-bit words):
    //   col b0..b9 = HIF[9:0], bank b0..b2 = HIF[12:10], row b0..b13 = HIF[26:13]
    //   27 bits x 2 bytes = 256MB = 2Gb
    prog_reg("ADDRMAP1",  0x204, 0x00080808);  // bank b0/b1/b2 = base 2/3/4 + 8
    prog_reg("ADDRMAP2",  0x208, 0x00000000);  // col b2..b5 identity
    prog_reg("ADDRMAP3",  0x20c, 0x00000000);  // col b6..b9 identity
    prog_reg("ADDRMAP4",  0x210, 0x00001f1f);  // col b10/b11 unused
    prog_reg("ADDRMAP5",  0x214, 0x07070707);  // row b0, b1, b2..b10, b11 +7
    prog_reg("ADDRMAP6",  0x218, 0x0f0f0707);  // row b12/b13 +7, b14/b15 unused
    prog_reg("ADDRMAP7",  0x21c, 0x00000f0f);  // row b16/b17 unused

    // T7 mutation check: DRAM_MUTATE=timing deliberately programs timings that
    // are too tight. The memory model must then report tRCD/tRFC violations;
    // if it does not, its timing checkers are not active and a "0 errors"
    // result proves nothing.
    const char *mutate = getenv("DRAM_MUTATE");
    mutation_run = (mutate != NULL && strcmp(mutate, "timing") == 0);
    if (mutation_run) {
        printf("MUTATION ACTIVE: t_rcd=4 (needs 8), t_rfc_min=10 (needs 52)\n");
        prog_reg("DRAMTMG4",  0x110, 0x04040409);
        prog_reg("RFSHTMG",   0x064, 0x0030000a);
    }

    printf("REGPROG done, %d readback mismatch(es)\n", prog_errors);

    // Program DWC_ddr_umctl2 registers
        //Note 1: When running training with the PHY. The following controller registers must be programmed to
        //these values at this stage:
        //  INIT0.skip_dram_init=2’b11
        //  PWRCTL.selfref_sw=1’b1
        //Programming them as follows is only allowed for simulation purposes when skipping training:
        //  INIT0.skip_dram_init=0
        //  (that is, SDRAM INIT through the controller)
        //  PWRCTL.selfref_sw=0

    if(no_training){
        apb3_bit_clear(0xd0,30);
        apb3_bit_clear(0xd0,31);
        apb3_bit_clear(0x30, 5);
    } else {
        apb3_bit_set(0xd0, 30);
        apb3_bit_set(0xd0, 31);
        apb3_bit_set(0x30,5);
    }

    // Disable self-refresh, power down and assertion of dfi_dram_clk_disable by
    // setting RFSHCTL3.dis_auto_refresh= 1, PWRCTL.powerdown_en = 0,
    // PWRCTL.selfref_en = 0, and PWRCTL.en_dfi_dram_clk_disable =0
    apb3_bit_set(0x60, 0);
    apb3_bit_clear(0x30, 1);
    apb3_bit_clear(0x30, 0);
    apb3_bit_clear(0x30, 3);

    // Set SWCTL.sw_done to ‘0’
    //   If UMCTL2_OCCAP_EN=1 && OCCAPCCFG.occap_en=1, require polling
    //   SWSTAT.sw_done_ack after setting SWCTL.sw_done to ‘0'
    apb3_bit_clear(0x320, 0);

    apb3_read(0x3e0,&tmp); // Read OCCAPCCFG
    if((tmp & 1) != 0){
        apb3_read(0x324,&tmp);
        while(tmp==0){apb3_read(0x324,&tmp);}
        printf("SWSTAT.B.sw_done_ack != 0\n");
    }    

    // Set DFIMISC.dfi_init_complete_en to ‘0' (mask transition in phy_dfi_init_complete)
    apb3_bit_clear(0x1b0, 0);
    
    // Set SWCTL.sw_done to ‘1' (poll swstat.sw_donw_ack)
    apb3_bit_set(0x320, 0);
    
    apb3_read(0x324,&tmp);
    while(tmp==0){
        apb3_read(0x324,&tmp);
    }

    for(int i=0;i<32;i++){apb3_write(0x6008,0x1);} //DDR_RESET_CTRL->CORE_RSTn=1;

    // Start PHY initialization and training by
    // accessing relevant PUB registers
    printf("** Start DDR PHY Init **\n");
    phyinit();
    printf("** Finish DDR PHY Init **\n");

    // 9 Poll the PUB register
    //  APBONLY.UctShadowRegs[0]=1’b0 
    //apb4_read(0x340010,&tmp);
    //while((tmp&0x1)!=0){apb4_read(0x340010,&tmp);}
    //// 10 Read the PUB Register
    ////    APBONLY.UctWriteOnlyShadow for training status
    //apb4_read(0x3400C8,&tmp);
    //printf("APBONLY.UctWriteOnlyShadow: 0x%08x\n",tmp);
//
    //// Write the PUB Register
    ////  APBONLY.DctWriteProt = 0 phy_init See PUB databook for details
    //apb4_write(0x3400C4,0);
    //printf("Wrote 0 to ABPONLY.DctWriteProt\n");
    //// Poll the PUB register
    //// APBONLY.UctShadowRegs[0]=1’b1 phy_init See PUB databook for details
    //apb4_read(0x340010,&tmp);
    //while((tmp&0x1)==0){
    //    apb4_read(0x340010,&tmp);
    //}
    //apb4_read(0x3400C8,&tmp);
//
    //printf("APBONLY.UctWriteOnlyShadow: 0x%08x\n",tmp);
//
    //// 13 Write the PUB Register
    ////  APBONLY.DctWriteProt= 1 phy_init See PUB databook for details
    //apb4_write(0x3400C4,1);
    //printf("Wrote 1 to ABPONLY.DctWriteProt\n");

    // 14 Poll the PUB register MASTER.CalBusy=0 phy_init See PUB databook for details
    apb4_read(0x8025c,&tmp);
    while((tmp!=0)){apb4_read(0x8025c,&tmp);}

    // 15 Set SWCTL.sw_done to ‘0’
    //  If UMCTL2_OCCAP_EN=1 && OCCAPCCFG.occap_en=1, require polling
    // SWSTAT.sw_done_ack after setting SWCTL.sw_done to ‘0’
    apb3_bit_clear(0x320,0);
    printf("Wrote 0 to SWCTL.B.sw_done\n");
    apb3_read(0x3e0,&tmp); // Read OCCAPCCFG
    if((tmp & 1) != 0){
        apb3_read(0x324,&tmp);
        while(tmp==0){apb3_read(0x324,&tmp);}
        printf("SWSTAT.B.sw_done_ack != 0\n");
    }    

    // 16 Set DFIMISC.dfi_init_start to ‘1’ 
    apb3_bit_set(0x1b0,5);
    printf("Wrote 1 to DFIMISC.B.dfi_init_start\n");

    // 17 Set SWCTL.sw_done to ‘1’ phy_init
    // Require polling SWSTAT.sw_done_ack after setting SWCTL.sw_done to 1
    apb3_bit_set(0x320,0);
    printf("Wrote 1 to SWCTL.B.sw_done\n");

    apb3_read(0x324,&tmp);
    while(tmp==0){apb3_read(0x324,&tmp);}
    printf("SWSTAT.B.sw_done_ack != 0\n");

    // 18 Poll DFISTAT.dfi_init_complete=1 phy_init
    apb3_read(0x1bc,&tmp);
    while((tmp&1)==0){apb3_read(0x1bc,&tmp);}
    printf("DFISTAT.B.dfi_init_complete != 0\n");

    // 19 Set SWCTL.sw_done to ‘0’
    // If UMCTL2_OCCAP_EN=1 && OCCAPCCFG.occap_en=1, require polling
    // SWSTAT.sw_done_ack after setting SWCTL.sw_done to ‘0’
    apb3_bit_clear(0x320,0);
    printf("Wrote 0 to SWCTL.B.sw_done\n");

    // 20 Set DFIMISC.dfi_init_start to ‘0’ 
    apb3_bit_clear(0x1b0,5);
    printf("Wrote 0 to DFIMISC.B.dfi_init_start\n");

    // 21 The following registers may need to be
    // updated after training has completed:
    // ■ RANKCTL.diff_rank_wr_gap
    // ■ RANKCTL.diff_rank_rd_gap
    // ■ DRAMTMG2.rd2wr
    // ■ DRAMTMG2.wr2rd
    // ■ DRAMTMG9.wr2rd_s
    // ■ RANKCTL.diff_rank_wr_gap_msb
    // ■ RANKCTL.diff_rank_rd_gap_msb
    // ■ RANKCTL1.wr2rd_dr
    // ■ DFITMG1.dfi_t_wrdata_delay
    // Also, the following registers related to VREF
    // setting may need to be updated after 2D
    // Training has completed:
    // ■ INIT7.mr6
    // ■ INIT6.mr5

    // 22 Set DFIMISC.dfi_init_complete_en to ‘1’ 
    apb3_bit_set(0x1b0,0);
    printf("Wrote 1 to DFIMISC.B.dfi_init_complete_en\n");

    //23 Set PWRCTL.selfref_sw to ‘0’ 
    apb3_bit_clear(0x30,5);
    printf("Wrote 0 to PWRCTL.B.selfref_sw\n");

    // 24 Set SWCTL.sw_done to ‘1’ 
    // Require polling SWSTAT.sw_done_ack after setting SWCTL.sw_done to 1
    apb3_bit_set(0x320,0);
    printf("Wrote 1 to SWCTL.B.sw_done\n");
    apb3_read(0x324,&tmp);
    while(tmp==0){apb3_read(0x324,&tmp);}
    printf("SWSTAT.B.sw_done_ack != 0\n");

    // 25 Wait for DWC_ddr_umctl2 to move to normal
    // operating mode by monitoring STAT.operating_mode signal
    // operating_mode: 0=init 1=normal 2=power-down 3=self-refresh.
    // Wait specifically for normal (1); the old (tmp&7)!=0 check also passed
    // on self-refresh, which is how the controller got stuck unnoticed.
    int polls = 0;
    apb3_read(0x4,&tmp);
    while (((tmp&7)!=1) && (polls++ < 2000)) {apb3_read(0x4,&tmp);}
    printf("STAT = 0x%08x (operating_mode=%u) after init, %d polls\n", tmp, tmp&7, polls);
    if ((tmp&7)!=1) {
        printf("ERROR: controller did not reach normal operating mode\n");
        apb_set_tb_scope();
        endSim();
        return;
    }

    // Snapshot after init: diff against the reset snapshot to see what changed
    dump_umctl2_regs("after init");

    // SNPS_MCTL2_DDRC->RFSHCTL3.B.dis_auto_refresh = 0;
    // SNPS_MCTL2_DDRC->PWRCTL.B.powerdown_en = 1;
    // SNPS_MCTL2_DDRC->PWRCTL.B.selfref_en=1;
    // SNPS_MCTL2_DDRC->PWRCTL.B.en_dfi_dram_clk_disable=1;
    apb3_bit_clear(0x60, 0);
    apb3_bit_set(0x30, 1);
    apb3_bit_set(0x30, 0);
    apb3_bit_set(0x30, 3);


    apb3_write(0x490,1);
    apb3_read(0x490,&tmp); // read PCTRL
    printf("PCTRL_n = 0x%08x\n",tmp);

    // Debug: controller state right before the first AXI access, after
    // self-refresh/power-down have been re-enabled above
    apb3_read(0x4,&tmp);
    printf("STAT = 0x%08x (operating_mode=%u) before AXI write\n", tmp, tmp&7);
    apb3_read(0x1bc,&tmp);
    printf("DFISTAT = 0x%08x\n", tmp);

    // ------------------------------------------------------------------
    // Functional tests. PHY training dominates run time, so all tests run
    // in one simulation after a single init.
    // ------------------------------------------------------------------
    int t1 = test_burst();
    int t2 = test_address_walk();
    int t3 = test_partial_writes();
    int t4 = test_timing_stress();
    int t5 = test_retention();
    int t6 = test_random();
    int t8 = test_narrow();

    printf("=== Test summary ===\n");
    printf("  T1 burst          : %s (%d errors)\n", t1 ? "FAIL" : "PASS", t1);
    printf("  T2 address walk   : %s (%d errors)\n", t2 ? "FAIL" : "PASS", t2);
    printf("  T3 partial writes : %s (%d errors)\n", t3 ? "FAIL" : "PASS", t3);
    printf("  T4 timing stress  : %s (%d errors)\n", t4 ? "FAIL" : "PASS", t4);
    printf("  T5 retention      : %s (%d errors)\n", t5 ? "FAIL" : "PASS", t5);
    printf("  T6 random traffic : %s (%d errors)\n", t6 ? "FAIL" : "PASS", t6);
    printf("  T8 narrow xfers   : %s (%d errors)\n", t8 ? "FAIL" : "PASS", t8);
    unsigned trfc = dfi_count(4);
    printf("  tRFC check        : %s (%u violations)\n", trfc ? "FAIL" : "PASS", trfc);

    // Firmware-side verdict; UVM_ERROR/FATAL from the memory model are
    // reported separately in the UVM summary and must also be 0.
    int data_errors = t1 + t2 + t3 + t4 + t5 + t6 + t8 + (int)trfc;
    if (mutation_run)
        printf("DRAM_TEST RESULT: MUTATION RUN - expect memory-model tRCD/tRFC UVM_ERRORs\n");
    else if (data_errors == 0 && prog_errors == 0)
        printf("DRAM_TEST RESULT: PASS\n");
    else
        printf("DRAM_TEST RESULT: FAIL (data_errors=%d, reg_prog_errors=%d)\n",
               data_errors, prog_errors);
    apb_set_tb_scope();
    endSim();
}