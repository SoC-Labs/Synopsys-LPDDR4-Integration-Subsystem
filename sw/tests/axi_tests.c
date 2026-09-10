#include "vc_hdrs.h"
#include <stdio.h>
#include "axi_access.h"

extern void endSim();

void something() {
    uint64_t rdata;
    int err = 0;

    printf("=== AXI Access Test ===\n");

    printf("AXI write 0x40 to 0x00008000\n");
    axi_write(0x00008000ULL, 0x40ULL);

    printf("AXI read from 0x00008000\n");
    axi_read(0x00008000ULL, &rdata);
    printf("  readback: 0x%016llX\n", (unsigned long long)rdata);
    if (rdata != 0x40ULL) {
        printf("  ERROR: readback mismatch\n");
        err = 1;
    }

    printf("AXI burst write (4 beats) to 0x00008040\n");
    axi_burst_write(0x00008040ULL, 0x1122334455667788ULL, 4);

    printf("AXI burst read (4 beats) from 0x00008040\n");
    axi_burst_read(0x00008040ULL, &rdata, 4);
    printf("  first beat: 0x%016llX\n", (unsigned long long)rdata);
    if (rdata != 0x1122334455667788ULL) {
        printf("  ERROR: burst readback mismatch\n");
        err = 1;
    }

    printf("AXI write_check with 64-bit pattern\n");
    if (axi_write_check(0x10000ULL, 0xDEADBEEFCAFEBABEULL) != 0) {
        printf("  ERROR: write_check failed\n");
        err = 1;
    }
    printf("  write_check PASSED\n");

    printf("%s\n", err ? "=== AXI TEST FAILED ===" : "=== AXI TEST PASSED ===");

    axi_set_tb_scope();

    endSim();
}