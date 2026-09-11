#include "vc_hdrs.h"
#include <stdio.h>
#include <stdint.h>
#include "apb_access.h"


void dwc_ddrphy_apb_wr(unsigned int addr, unsigned int data){
    apb4_write(addr<<2, data);
    return;
}

void dwc_ddrphy_stage_print(int a){
  	if(a==3){
  	  printf("**STEP C**\n");
  	} 
  	else if (a==4) {
  	  printf("**STEP D**\n");
  	} 
  	else if (a==5) {
  	  printf("**STEP E**\n");
  	} 
  	else if (a==6) {
  	  printf("**STEP F**\n");
  	} 
  	else if (a==7) {
  	  printf("**STEP G**\n");
  	} 
  	return;
}

void dwc_ddrphy_phyinit_userCustom_overrideUserInput (){
  	return;
}

void dwc_ddrphy_phyinit_userCustom_A_bringupPower (){
  	return;
}

void dwc_ddrphy_phyinit_userCustom_B_startClockResetPhy (){
    printf("Reset PHY\n");
	for(int i=0;i<32;i++){apb3_write(0x6000, 0x1);}
	for(int i=0;i<32;i++){apb3_write(0x6004, 0x1);}
    apb3_write(0x6000, 0x0);
    return;
}
void dwc_ddrphy_phyinit_userCustom_E_setDfiClk(int a){
  return;
}
void dwc_ddrphy_phyinit_userCustom_G_waitFwDone(){
  	uint32_t tmp;
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

  	return;
}
void dwc_ddrphy_phyinit_userCustom_H_readMsgBlock(int a){

  	return;
}
void dwc_ddrphy_phyinit_userCustom_customPostTrain(){
  	return;
}
void dwc_ddrphy_phyinit_userCustom_J_enterMissionMode(){
  	return;

}
void phyinit(){
// Leave empty brace to allow for cat of generated phyinit function