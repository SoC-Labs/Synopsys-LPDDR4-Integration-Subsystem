#include "vc_hdrs.h"
#include <stdio.h>
#include <stdint.h>
#include "apb_access.h"

extern void endSim();
extern void phyinit();

int simulation=1;

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


void something() {
    printf("DRAM Tests\n");

    printf("** Start DDR CTRL Init **\n");
    uint32_t tmp;
    // Program DWC_ddr_umctl2 registers
        //Note 1: When running training with the PHY. The following controller registers must be programmed to
        //these values at this stage:
        //  INIT0.skip_dram_init=2’b11
        //  PWRCTL.selfref_sw=1’b1
        //Programming them as follows is only allowed for simulation purposes when skipping training:
        //  INIT0.skip_dram_init=0
        //  (that is, SDRAM INIT through the controller)
        //  PWRCTL.selfref_sw=0
    if(simulation){
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

    // Set DFIMISC.dfi_init_complete_en to ‘0' (mask transition in phy_dfi_init_complete)
    apb3_bit_clear(0x1b0, 0);
    
    // Set SWCTL.sw_done to ‘1' (poll swstat.sw_donw_ack)
    apb3_bit_set(0x320, 0);
    
    apb3_read(0x324,&tmp);
    while(tmp==0){
        apb3_read(0x324,&tmp);
    }

    // Start PHY initialization and training by
    // accessing relevant PUB registers
    printf("** Start DDR PHY Init **\n");
    phyinit();
    printf("** Finish DDR PHY Init **\n");
    // De-assert reset signal core_ddrc_rstn
    apb3_write(0x6008,0x1); //DDR_RESET_CTRL->CORE_RSTn=1;

    // 9 Poll the PUB register
    //  APBONLY.UctShadowRegs[0]=1’b0 
    apb4_read(0x340010,&tmp);
    while((tmp&0x1)!=0){apb4_read(0x340010,&tmp);}
    // 10 Read the PUB Register
    //    APBONLY.UctWriteOnlyShadow for training status
    apb4_read(0x3400C8,&tmp);
    printf("APBONLY.UctWriteOnlyShadow: 0x%08x\n",tmp);

    // Write the PUB Register
    //  APBONLY.DctWriteProt = 0 phy_init See PUB databook for details
    apb4_write(0x3400C4,0);
    printf("Wrote 0 to ABPONLY.DctWriteProt\n");
    // Poll the PUB register
    // APBONLY.UctShadowRegs[0]=1’b1 phy_init See PUB databook for details
    apb4_read(0x340010,&tmp);
    while((tmp&0x1)==0){
        apb4_read(0x340010,&tmp);
    }
    apb4_read(0x3400C8,&tmp);

    printf("APBONLY.UctWriteOnlyShadow: 0x%08x\n",tmp);

    // 13 Write the PUB Register
    //  APBONLY.DctWriteProt= 1 phy_init See PUB databook for details
    apb4_write(0x3400C4,1);
    printf("Wrote 1 to ABPONLY.DctWriteProt\n");

    // 14 Poll the PUB register MASTER.CalBusy=0 phy_init See PUB databook for details
    apb4_read(0x8025c,&tmp);
    while((tmp!=0)){apb4_read(0x8025c,&tmp);}

    // 15 Set SWCTL.sw_done to ‘0’
    //  If UMCTL2_OCCAP_EN=1 && OCCAPCCFG.occap_en=1, require polling
    // SWSTAT.sw_done_ack after setting SWCTL.sw_done to ‘0’
    apb3_bit_clear(0x320,0);
    printf("Wrote 0 to SWCTL.B.sw_done\n");

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

    // 25 Wait for DWC_ddr_umctl2 to move to normal
    // operating mode by monitoring STAT.operating_mode signal
    apb3_read(0x4,&tmp);
    while( (tmp&7)==0){apb3_read(0x4,&tmp);}
    printf("STAT.B.operating_mode != 0\n");

    // 26 Set back registers in step 4 to the original
    // values if desired

    //SNPS_MCTL2_DDRC->RFSHCTL3.B.dis_auto_refresh = 0;
    //SNPS_MCTL2_DDRC->PWRCTL.B.powerdown_en = 0;
    //SNPS_MCTL2_DDRC->PWRCTL.B.selfref_en=0;
    //SNPS_MCTL2_DDRC->PWRCTL.B.en_dfi_dram_clk_disable=0;

    //HW64_REG(DRAM_BASE)=0xA5A5A5A5A5A5A5A5;

    printf("Wrote over DDR\n");

    // if(HW64_REG(DRAM_BASE)!=0xA5A5A5A5A5A5A5A5){
    //     printf("TEST FAILED\n");
    // } else {
    //     printf("TEST PASSED\n");
    // }

    printf("PHYINIT COMPLETE\n");
    apb_set_tb_scope();
    endSim();
}