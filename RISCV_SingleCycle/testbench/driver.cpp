#ifndef COMMON_H
#include "common.h"
#endif

std::queue<Transaction> drv_fifo;


class Driver {
private:
    Interface *inf;
    struct Transaction req;
public:
    int drv_count;

    Driver(Interface *intef): drv_count(0), inf(intef) {}

    ~Driver() {}

    void main();

    void forward_to_set(int set_num);
};


void Driver::main() {
    if (!inf->top->clk) {
        if (VERBOSITY) {
            //printf("[%ld] DRV: waiting to drive on HOLD_TIME after posedge\n", inf->timestamp);
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

    drv_count++;
    if (VERBOSITY) {
        printf("DRV: Tr(%d) setting rd_data to 0x%0lx\n", drv_count, req.rd_data);
        printf("%s\n", req.str);
    }

    // drive
    inf->set_rd_data(req.rd_data);

    // post drive
    drv_fifo.pop();
    inf->wait(1);
    inf->dump();
}


void Driver::forward_to_set(int set_num) {
    while (!drv_fifo.empty()) {
        if (drv_fifo.front().test_id != set_num) {
            drv_fifo.pop();
            drv_count++;
        } else {
            break;
        }
    }
}
