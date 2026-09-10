#include "vc_hdrs.h"
#include <stdio.h>
#include "apb_access.h"

extern void endSim();

void something() {
    uint32_t rdata;

    printf("=== APB Access Test ===\n");

    printf("Testing APB3 (UMCTL2) read at 0x0000601c\n");
    apb3_read(0x601c, &rdata);
    printf("  APB3 read from 0x0000: 0x%08X\n", rdata);

    printf("Testing APB3 (UMCTL2) read at 0x00006000\n");
    apb3_read(0x6000, &rdata);
    printf("  APB3 read from 0x0000: 0x%08X\n", rdata);

    printf("Testing APB3 write/read at 0x00006000\n");
    apb3_write(0x6000, 0x1);
    apb3_read(0x6000, &rdata);
    printf("  APB3 write 0x1, readback: 0x%08X\n", rdata);


    printf("Reset PHY\n");
    apb3_write(0x6000, 0x1);
    apb3_write(0x6004, 0x1);
    apb3_write(0x6000, 0x0);

    printf("Testing APB4 (PHY) read at 0x0000...\n");
    apb4_read(0x0000, &rdata);
    printf("  APB4 read from 0x0000: 0x%08X\n", rdata);

    printf("Testing APB4 write/read at 0x0000...\n");
    apb4_write(0x0000, 0xEF01);
    apb4_read(0x0000, &rdata);
    printf("  APB4 write 0xEF01, readback: 0x%08X\n", rdata);

    printf("=== APB Access Test Complete ===\n");

    apb_set_tb_scope();

    endSim();
}