#include "vc_hdrs.h"
#include "apb_access.h"
#include <stdio.h>

extern int sayHello();
extern void endSim();

void something() {
    printf("something\n");
    apb_set_tb_scope();
    sayHello();
    endSim();
}
