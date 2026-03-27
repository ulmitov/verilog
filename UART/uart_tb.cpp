/*
    Simple simulation using uart driver

vsrc="uart_top.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv ../fifo.v ../shift_reg.v"

verilator -I../ -Wno-lint --pins-inout-enables --trace-vcd --timing --top uart_top --cc --public-flat-rw --coverage --build --exe uart_tb.cpp uart_verilated.cpp uart_driver.cpp ${vsrc}

./obj_dir/Vuart_top
*/
#include <iostream>

#define VERILATOR_SIM
#ifdef VERILATOR_SIM
#include "uart_verilated.h"
#else
#include "uart_driver.h"
#endif


int main (int argc, char **argv, char **env) {
    #ifdef VERILATOR_SIM
        UartVerilated* dut = new UartVerilated("uart_core_tb.vcd", argc, argv);
    #else
        UartDriver* dut = new UartDriver;
    #endif
    char ch;

    dut->reset();
    // Settings: 2 stop bits, even parity, 8 bit word len
    dut->set_baud_rate(115200, 1, 3, 3);
    std::cout << "Frequency Divisor = " << dut->freq_divisor << std::endl;
    std::cout << "clock ticks_per_word = " << dut->ticks_per_word << std::endl;
    std::cout << "UART_REG_LCR = " << std::hex << dut->io_read(UART_REG_LCR) << std::endl;
    dut->set_fifo_mode(false);

    std::cout << "************ Send a single char (fifo is off) ************" << std::endl;
    dut->send_ch('Z');
    dut->io_write(UART_REG_IER, 0x00);
    dut->wait_ticks(dut->ticks_per_word);
    ch = dut->recv_ch();
    std::cout << "Rx: " << ch << std::endl;

    std::cout << "************ Send a string (fifo is on) ************" << std::endl;
    char str[16];
    dut->set_fifo_mode(true);
    dut->send_str("0: 16 chars str\n");
    dut->wait_ticks(dut->ticks_per_word * 17);
    std::cout << "RxFifoEmpty = " << dut->rx_fifo_empty() << std::endl;
    dut->recv_str(str, 16);
    std::cout << "Rx: " << str << std::endl;
    std::cout << "RxFifoEmpty = " << dut->rx_fifo_empty() << std::endl;

    std::cout << "****** END SIM on " << std::dec << dut->timestamp << " ******" << std::endl;
    delete dut;
    return 0;
}

