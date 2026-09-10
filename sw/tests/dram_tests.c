#include "vc_hdrs.h"
#include <stdio.h>
#include "apb_access.h"

extern void endSim();
extern void phyinit();
void something() {

    phyinit();
    printf("PHYINIT COMPLETE\n");
    apb_set_tb_scope();
    endSim();
}