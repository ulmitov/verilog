/*
    Simulation tests with uart driver
*/
#include <iostream>
#include <string.h>

#ifdef VERILATOR
#include "uart_verilated.h"
#else
#include "uart_driver.h"
#endif

uint8_t buffer[1024];
const PARITY_ENUM parity_vals[5] = {PARITY_DISABLED, PARITY_ODD, PARITY_EVEN, PARITY_STICK_0, PARITY_STICK_1};


void print_header(const char *header) {
    std::cout << "************ " << header << " ************" << std::endl;
}


void setup(UartDriver *obj, int baud, int stop_bits, int parity, int word_len) {
    std::string result = "";
    std::cout << "################### SETUP ######################" << std::endl;
    obj->set_baud_rate(baud, stop_bits, parity, word_len);
    word_len += 5;
    std::cout << "Frequency Divisor = " << obj->freq_divisor << std::endl;
    std::cout << "clock ticks_per_word = " << obj->ticks_per_word << std::endl;
    std::cout << "Baud rate = " << baud << std::endl;
    result += "Word len " + std::to_string(word_len);
    result += ", Parity ";

    if (!(parity & 1)) {
        result += "DISABLED";
    } else {
        switch(parity) {
            case 1:
                result += "ODD";
                break;
            case 3:
                result += "EVEN";
                break;
            case 5:
                result += "stick 1";
                break;
            case 7:
                result += "stick 0";
                break;
        }
    }

    switch(stop_bits) {
        case 0:
            result += ", Stop bits = 1";
            break;
        default:
            if (word_len == 5) {
                result += ", Stop bits = 1.5";
            } else {
                result += ", Stop bits = 2";
            }
            break;
    }
    std::cout << "UART_REG_LCR = " << std::hex << obj->io_read(UART_REG_LCR) << std::endl;
    std::cout << "************ " << result << " ************" << std::endl;
}


int test_single_char(UartDriver *dut, char ch) {
    char rcv;
    print_header("Send single char (fifo is off)");
    dut->send_ch(ch);
    dut->poll_rx();
    if (dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is empty" << std::endl;
        return 1;
    }
    rcv = dut->recv_ch();
    std::cout << "Rx: " << rcv << std::endl;
    if (rcv != ch) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved char is incorrect" << std::endl;
        return 1;
    }
    if (dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was raised" << std::endl;
        return 1;
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        return 1;
    }
    return 0;
}


int test_send_data(UartDriver *dut, uint8_t *arr, int expected_len, int word_len) {
    uint8_t temp;
    uint8_t *ptr = buffer;
    uint8_t bdata;
    int mask = (1 << (word_len + 5)) - 1;

    print_header("Send data bytes (fifo mode is on)");
    dut->send(arr, expected_len);
    dut->recv(&buffer[0]);
    std::cout << "Rx str: " << buffer << std::endl;
    
    while (bdata = *ptr++) {
        temp = *arr++;
        if (bdata != (temp & mask)) {
            std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect data: 0x" << std::hex << (int) temp << ", but buffer holds " << std::hex << (int) bdata << std::endl;
            return 1;
        } else std::cout << std::hex << (int) temp << " ";
        if (expected_len) expected_len--;
    }
    std::cout << std::endl;
    if (expected_len) {
        std::cout << "[uart_tb.cpp] ERROR: recieved length differs with expected by " << expected_len << std::endl;
        return 1;
    }
    if (dut->is_overrun()) { // TODO why no overrun i forgot!
        std::cout << "[uart_tb.cpp] ERROR: OE flag was raised" << std::endl;
        return 1;
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        return 1;
    }
    return 0;
}


int test_send_string_truncated(UartDriver *dut, const char *arr, const char *exp) {
    uint8_t *ptr = buffer;
    std::string result = "";

    print_header("Send a long string (fifo is on, truncating)");
    dut->send_str(arr);
    dut->recv(&buffer[0]);
    while(*ptr) result += (char) *ptr++;
    std::cout << "Rx str: " << result << std::endl;
    if (result != exp) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved string is incorrect" << std::endl;
        return 1;
    }
    if (dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was raised" << std::endl;
        return 1;
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        return 1;
    }
    return 0;
}


int test_single_byte(UartDriver *dut, char ch, char exp = '\0') {
    char rcv;
    print_header("Send-receive single byte (in polling mode)");
    dut->tx_byte(ch);
    dut->poll_rx();
    rcv = dut->recv_ch();
    std::cout << "Rx byte: " << std::hex << (int)(unsigned char) rcv << std::endl;
    if (!exp) exp = ch;
    if (rcv != exp) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved byte is incorrect" << std::endl;
        return 1;
    }
    if (dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was raised" << std::endl;
        return 1;
    }
    if (!dut->rx_fifo_empty()) {
        std::cout << "[uart_tb.cpp] ERROR: RX fifo is not empty" << std::endl;
        return 1;
    }
    return 0;
}



int test_chars_override(UartDriver *dut) {
    char ch;
    std::cout << "************ Overriding chars (fifo is off) ************" << std::endl;
    std::cout << "Sending 1st char" << std::endl;
    dut->send_ch('A');
    dut->poll_rx();
    std::cout << "Sending 2nd char" << std::endl;
    dut->send_ch('B');
    dut->poll_tx();
    std::cout << "Sending 3rd char" << std::endl;
    dut->send_ch('C');
    dut->poll_tx();
    if (!dut->is_overrun()) {
        std::cout << "[uart_tb.cpp] ERROR: OE flag was not raised" << std::endl;
        return 1;
    }
    // check that A is received:
    // if not waiting at least two baud ticks then C will be pushed to RxFifo as soon as A is pulled
    dut->poll_tx();
    ch = dut->recv_ch();
    if (ch != 'A') {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved incorrect char: " << ch << std::endl;
        return 1;
    }
    // B was overriden by C which should be now in RSR. Check that C was not pushed to Rx fifo:
    ch = dut->recv_ch();
    if (ch) {
        std::cout << std::endl << "[uart_tb.cpp] ERROR: recieved a char: " << ch << std::endl;
        return 1;
    }
    return 0;
}


int main (int argc, char **argv, char **env) {
    #ifdef VERILATOR
        UartVerilated* dut = new UartVerilated("vcd/uart_cpp_tb.vcd", argc, argv);
    #else
        UartDriver* dut = new UartDriver;
    #endif
    uint8_t data_8bit[16] = {0xF0, 0xE1, 0xD2, 0xC3, 0xB4, 0xA5, 0xB6, 0xC7, 0xD8, 0xE9, 0xFA, 0xEB, 0xDC, 0xCD, 0xBE, 0xAF};
    /*
    uint8_t data_7bit[16] = {0x7F, 0x6E, 0x5D, 0x4C, 0x4B, 0x4A, 0x40, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78};
    uint8_t data_6bit[16] = {0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x30, 0x32, 0x35, 0x3A, 0x3B, 0x3E, 0x3F};
    uint8_t data_5bit[16] = {0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F};
    */
    dut->reset();

    dut->io_write(UART_REG_IER, 0x00);
    dut->set_fifo_mode(0);

    setup(dut, 115200, 1, 3, 3);
    test_single_char(dut, 'Z');

    for (int stop_bits = 0; stop_bits < 2; stop_bits++) {
        for (int par_bit = 0; par_bit < 5; par_bit++) {
            setup(dut, 115200, stop_bits, parity_vals[par_bit], 3);
            if (test_single_byte(dut, 0xFA)) goto finish;

            setup(dut, 115200, stop_bits, parity_vals[par_bit], 2);
            if (test_single_byte(dut, 0xFA, 0x7A)) goto finish;

            setup(dut, 115200, stop_bits, parity_vals[par_bit], 1);
            if (test_single_byte(dut, 0xFA, 0x3A)) goto finish;
            
            setup(dut, 115200, stop_bits, parity_vals[par_bit], 0);
            if (test_single_byte(dut, 0xFA, 0x1A)) goto finish;
        }
    }

    dut->set_fifo_mode(1);

    for (int stop_bits = 0; stop_bits < 2; stop_bits++) {
        for (int par_bit = 0; par_bit < 5; par_bit++) {
            setup(dut, 115200, 1, 3, 3);
            if (test_send_data(dut, data_8bit, 16, 3)) goto finish;

            setup(dut, 115200, 1, 3, 2);
            if (test_send_data(dut, data_8bit, 16, 2)) goto finish;

            setup(dut, 115200, 1, 3, 1);
            if (test_send_data(dut, data_8bit, 16, 1)) goto finish;

            setup(dut, 115200, 1, 3, 0);
            if (test_send_data(dut, data_8bit, 16, 0)) goto finish;

            setup(dut, 115200, 1, 1, 3);
            if (test_send_string_truncated(dut, "Expected 4xF: FFFFFF", "Expected 4xF: FFFF")) goto finish;
        }
    }

    dut->set_fifo_mode(0);
    setup(dut, 115200, 0, 0, 3);
    if (test_chars_override(dut)) goto finish;
    dut->flush_fifo();

    finish:
        std::cout << "[uart_tb.cpp] End of testbench" << std::endl;
        delete dut;
        exit(0);
}
