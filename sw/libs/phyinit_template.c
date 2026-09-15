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
	// Need to wait 200us for power startup
	// But let's set tINIT1 to lower value in TB for now.

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
  printf("** STEP E **\n");
  printf("Set clock to Pstate %d\n",a);
  return;
}

uint32_t get_mail(int mode){
  	uint32_t tmp;
	uint32_t mail;
	uint32_t mail_top;
	// 9 Poll the PUB register
	//  APBONLY.UctShadowRegs[0]=1’b0 
	apb4_read(0x340010,&tmp);
	while((tmp&0x1)!=0){apb4_read(0x340010,&tmp);}
	// 10 Read the PUB Register
	//    APBONLY.UctWriteOnlyShadow for training status
	apb4_read(0x3400C8,&mail);
	printf("APBONLY.UctWriteOnlyShadow: 0x%08x\n",mail);

	if(mode==32){
        apb4_read(0x3400d0,&mail_top);
        printf("Upper byte of Streaming msg: 0x%08x\n",mail_top);
		mail = mail | (mail_top<<16);
	}

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
	// 13 Write the PUB Register
	//  APBONLY.DctWriteProt= 1 phy_init See PUB databook for details
	apb4_write(0x3400C4,1);
	printf("Wrote 1 to ABPONLY.DctWriteProt\n");

	return mail;
}

void dwc_ddrphy_phyinit_userCustom_G_waitFwDone(){
  	uint32_t tmp;
    uint32_t mail=0x100;
	uint32_t args;
	uint32_t stream;
    while(mail!=0x07){
		mail=get_mail(16);
		printf("Mail = 0x%08x\n",mail);
		if(mail==0xFF){
			printf("**!!! TRAINING FAILED !!!**\n");
			break;
		} else if (mail==0x08){
			// Streaming Message
			stream=get_mail(32);
			printf("Stream = 0x%08x\n",stream);
			if(stream==0x00e10001){
				args=get_mail(32);
				printf("Stream args = 0x%08x\n",args);
			}
		}
	}
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