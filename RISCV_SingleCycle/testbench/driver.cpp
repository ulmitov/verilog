#ifndef COMMON_H
#include "common.h"
#endif

std::queue<Transaction> drv_fifo;


class Driver {
private:
    Interface *inf;
    struct Transaction req;
public:
    Driver(Interface *intef): inf(intef) {}

    ~Driver() {}

    void main();
};


void Driver::main() {
    if (!inf->top->clk) {
        if (VERBOSITY) {
            printf("[%ld] DRV: waiting to drive on HOLD_TIME after posedge\n", inf->timestamp);
        }
        while (!inf->top->clk) inf->wait(1);
        inf->wait(SETUP_TIME + 1);
    }
    if (drv_fifo.empty()) return;

    // skip if mem operation not requested
    if (!inf->req()) return;

    // skip if the address belongs to data memory
    if (inf->addr() >= DATA_MEMORY_BASE_ADDR && inf->addr() < DATA_MEMORY_LAST_ADDR) return;
    req = drv_fifo.front();

    // skip if bus not like in the transaction
    if (req.wr != inf->wr()) return;
    if (req.addr != inf->addr()) return;

    // drive
    inf->set_rd_data(req.rd_data);

    // post drive
    drv_fifo.pop();
    inf->wait(1);
    inf->dump();
}
