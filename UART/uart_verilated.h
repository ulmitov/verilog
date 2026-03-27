#include "uart_driver.h"
#include <Vuart_top.h>
#include <verilated.h>
#include <verilated_vcd_c.h>


class UartVerilated: public UartDriver {
public:
    vluint64_t timestamp;

    UartVerilated(const char * vcd_path, int argc, char **argv);

    ~UartVerilated();

    void reset();

    void tick();

    void wait_ticks(int repeat = 1);

    void io_write(int addr, int data) override;

    int io_read(int addr) override;

private:
    VerilatedVcdC* vcd;
    Vuart_top* top;
    int half_cycle = 500 / CLK_FREQ_MHZ;
};
