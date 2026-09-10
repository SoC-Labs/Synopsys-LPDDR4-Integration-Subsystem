#include "vc_hdrs.h"
#include <stdio.h>
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
    apb3_write(0x6000, 0x1);
    apb3_write(0x6004, 0x1);
    apb3_write(0x6000, 0x0);

    return;
}
void dwc_ddrphy_phyinit_userCustom_E_setDfiClk(int a){
  return;
}
void dwc_ddrphy_phyinit_userCustom_G_waitFwDone(){

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