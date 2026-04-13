/*
    Simulation tests with uart driver
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
        UartVerilated* dut = new UartVerilated("dir/uart_cpp_tb.vcd", argc, argv);
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
    dut->io_write(UART_REG_IER, 0x00);

    std::cout << "************ Send a single char (fifo is off) ************" << std::endl;
    dut->send_ch('Z');
    dut->poll_rx();
    ch = dut->recv_ch();
    std::cout << "Rx: " << ch << std::endl;
    if (ch != 'Z') {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect char: " << ch << std::endl;
        goto finish;
    }


    std::cout << "************ Overriding chars (fifo is off) ************" << std::endl;
    std::cout << "Sending 1st char" << std::endl;
    dut->send_ch('A');
    dut->poll_rx();
    std::cout << "Sending 2nd char" << std::endl;
    dut->send_ch('B');
    dut->wait_ticks(dut->ticks_per_word);
    std::cout << "Sending 3rd char" << std::endl;
    dut->send_ch('C');
    dut->wait_ticks(dut->ticks_per_word);
    if (!dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was not raised" << std::endl;
        err = 1;
    }
    // check that A is received:
    // if not waiting at least two baud ticks then C will be pushed to RxFifo as soon as A is pulled
    dut->wait_ticks(dut->ticks_per_word);
    ch = dut->recv_ch();
    if (ch != 'A') {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect char: " << ch << std::endl;
        err = 1;
    }
    // check that C was not pushed:
    ch = dut->recv_ch();
    if (ch) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved a char: " << ch << std::endl;
        err = 1;
    }


    std::cout << "************ Send a string (fifo is on) ************" << std::endl;
    dut->set_fifo_mode(1);
    dut->send_str("0123456789ABCDE\n");
    dut->recv_str(&buffer[0]);
    std::cout << "Rx str: " << buffer << std::endl;
    if (strcmp(buffer, "0123456789ABCDE\n")) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect string: " << buffer << std::endl;
        err = 1;
    }
    if (dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was raised" << std::endl;
        err = 1;
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        err = 1;
    }
    

    std::cout << "************ Send a longer string (trancating) ************" << std::endl;
    dut->send_str("Should be 3x0: 0000000");
    dut->recv_str(&buffer[0]);
    std::cout << "Rx str: " << buffer << std::endl;
    if (strcmp(buffer, "Should be 3x0: 000")) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect string: " << buffer << std::endl;
        err = 1;
    }
    if (dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was raised" << std::endl;
        err = 1;
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        err = 1;
    }


    std::cout << "*** [uart_tb.cpp]: End of testbench time: " << std::dec << dut->timestamp << " ******" << std::endl;
    finish:
        delete dut;
        exit(err);
}
