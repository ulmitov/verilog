#include <stdio.h>
#include "uart_verilated.h"
#include "verilated_cov.h"


UartVerilated::UartVerilated(const char * vcd_path, int argc, char **argv): 
    vcd(new VerilatedVcdC()),
    top(new Vuart_top()),
    timestamp(0)
{
        Verilated::commandArgs(argc, argv);
        Verilated::traceEverOn(true);
        top->trace(vcd, 99);
        vcd->open(vcd_path);
        top->clk = 0;
 }

UartVerilated::~UartVerilated() {
    wait_ticks(10);
    printf("End time: %ld\n", timestamp);
    top->eval();
    vcd->close();
    top->final();
    VerilatedCov::write("coverage.dat");
    delete vcd;
    delete top;
}

void UartVerilated::wait_ticks(int repeat) {
    while(repeat--) tick();
}

void UartVerilated::tick() {
    /* UART uses posedge clk, so should drive on negedge and monitor on posedge */
    for (int j = 0; j < 2; j++) {
        half_tick();
    }
}

void UartVerilated::half_tick() {
    /* UART uses posedge clk, so should drive on negedge and monitor on posedge */
    if (Verilated::gotFinish()) return;
    top->eval();
    if (vcd) vcd->dump(timestamp);
    timestamp += half_cycle;
    top->clk ^= 1;
}

void UartVerilated::reset() {
    top->res = 1;
    tick();
    top->res = 0;
}

uint32_t UartVerilated::io_read(uint32_t addr) {
    uint32_t res;
    top->addr = addr;
    top->ddis = 0;
    top->wr = 0;
    top->rd = 1;
    top->cs = 1;
    half_tick();
    // capture data before edge
    res = top->data_bus__out;
    half_tick();
    top->rd = 0;
    //printf("%ld ns: io_read addr %x data_bus=%x data_bus__out=%x\n", timestamp, addr, top->data_bus, top->data_bus__out);
    return res;
}

void UartVerilated::io_write(uint32_t addr, uint32_t data) {
    printf("%ld ns: io_write addr %x val 0x%x\n", timestamp, addr, data);
    top->ddis = 1;
    top->cs = 1;
    top->wr = 1;
    top->rd = 0;
    top->addr = addr;
    top->data_bus = data;
    tick();
    top->wr = 0;
}
