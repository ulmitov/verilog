/*
    Simple simulation using uart driver
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
    char buffer[1024];
    char *str = buffer;
    int err = 0;
    int i;

    dut->reset();
    // Settings: 2 stop bits, even parity, 8 bit word len
    dut->set_baud_rate(115200, 1, 3, 3);
    std::cout << "Frequency Divisor = " << dut->freq_divisor << std::endl;
    std::cout << "clock ticks_per_word = " << dut->ticks_per_word << std::endl;
    std::cout << "UART_REG_LCR = " << std::hex << dut->io_read(UART_REG_LCR) << std::endl;
    dut->set_fifo_mode(0);

    std::cout << "************ Send a single char (fifo is off) ************" << std::endl;
    dut->send_ch('Z');
    dut->io_write(UART_REG_IER, 0x00);
    dut->wait_ticks(dut->ticks_per_word);
    ch = dut->recv_ch();
    std::cout << "Rx: " << ch << std::endl;

    std::cout << "************ Send a string (fifo is on) ************" << std::endl;
    dut->set_fifo_mode(1);
    dut->send_str("0: 16 chars str\n");
    while (dut->rx_fifo_empty());
    dut->recv_str(str, 16);
    std::cout << "Rx str: ";
    for (i = 0; i < 16; i++) {
        std::cout << *str;
        if (*str++ != "0: 16 chars str\n"[i]) {
            std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect string: " << str[i] << std::endl;
            err = 1;
        }
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        err = 1;
    }
    std::cout << "****** END SIM on " << std::dec << dut->timestamp << " ******" << std::endl;
    delete dut;
    exit(err);
}
