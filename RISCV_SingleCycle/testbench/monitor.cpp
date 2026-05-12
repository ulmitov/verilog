#ifndef COMMON_H
#include "common.h"
#endif

extern Scoreboard *scb;


class Monitor {
private:
    Interface *inf;
    Scoreboard *scb;
    struct Transaction req;
public:
    Monitor(Interface *intef, Scoreboard *scb_ptr): inf(intef), scb(scb_ptr) {}

    ~Monitor() {}

    void main();
};


void Monitor::main() {
    if (inf->top->clk) {
        if (VERBOSITY) {
            printf("[%ld] MON: waiting to sample on SETUP_TIME before posedge\n", inf->timestamp);
        }
        while (inf->top->clk) inf->wait(1);
        inf->wait(CLK_PHASE - SETUP_TIME - 1);
    }
    inf->dump();
    if (!inf->req()) return;

    req.req = inf->req();
    req.wr = inf->wr();
    req.addr = inf->addr();
    req.wr_data = inf->wr_data();
    req.rd_data = inf->rd_data();

    scb->write(&req);
}
