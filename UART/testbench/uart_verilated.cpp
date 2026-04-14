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
        if (Verilated::gotFinish()) break;
        top->eval();
        if (vcd) vcd->dump(timestamp);
        timestamp += half_cycle;
        top->clk ^= 1;
    }
}

void UartVerilated::reset() {
    top->res = 1;
    tick();
    top->res = 0;
}

uint32_t UartVerilated::io_read(uint32_t addr) {
    top->addr = addr;
    top->ddis = 0;
    top->wr = 0;
    top->rd = 1;
    top->cs = 1;
    tick();
    top->rd = 0;
    //printf("%ld ns: io_read addr %x data_bus=%x data_bus__out=%x\n", timestamp, addr, top->data_bus, top->data_bus__out);
    return (uint32_t) top->data_bus__out;
}

void UartVerilated::io_write(uint32_t addr, uint32_t data) {
    printf("%ld ns: io_write addr %x val 0x%x (%c)\n", timestamp, addr, data, data);
    top->ddis = 1;
    top->cs = 1;
    top->wr = 1;
    top->rd = 0;
    top->addr = addr;
    top->data_bus = data;
    tick();
    top->wr = 0;
}
