#include "uart_driver.h"


UartDriver::UartDriver() {}
UartDriver::~UartDriver() {}

// not implemented for now, should be external
void UartDriver::io_write(int addr, int data) {}
int UartDriver::io_read(int addr) {return 0;}


void UartDriver::set_baud_rate(int baud, unsigned char stop_bits, unsigned char parity, unsigned char word_len) {
    int par_bit = parity != 0;
    int total_bits = word_len + 5 + stop_bits + 1 + par_bit;
    int div = BAUD_OSRATE * baud * total_bits;
    freq_divisor = (1000000 * CLK_FREQ_MHZ * (word_len + 5) + (div - 1))/ div;  // round up
    ticks_per_word = freq_divisor * BAUD_OSRATE * total_bits;
    io_write(UART_REG_LCR, MASK_LCR_DLAB);
    io_write(UART_REG_DLL, (uint8_t) freq_divisor);
    io_write(UART_REG_DLM, (uint8_t) (freq_divisor >> 8));
    io_write(UART_REG_LCR, (word_len << UART_LCR_WLS) | (stop_bits << UART_LCR_STB) | (parity << UART_LCR_PEN));
}

unsigned char UartDriver::rx_fifo_empty() {
    // TODO: set UART_FCR_RXFIFTL then can check for full also
    uint8_t rd_word = io_read(UART_REG_LSR);
    return !(rd_word & MASK_RX_EMPTY);
}

unsigned char UartDriver::tx_fifo_empty() {
    uint8_t rd_word = io_read(UART_REG_LSR);
    return rd_word & MASK_TX_EMPTY;
}

unsigned char UartDriver::tx_fifo_full() {
    return !tx_fifo_empty();
}

void UartDriver::set_fifo_mode(short enable) {
    io_write(UART_REG_FCR, enable ? MASK_FIFO_EN : 0x00);
}

char UartDriver::rx_byte() {
    if (rx_fifo_empty()) {
        #ifdef DEBUG_MODE
        printf("rx fifo empty..");
        #endif
        return -1;
    }
    return io_read(UART_REG_RBR);
}

char UartDriver::recv_ch(unsigned short timeout) {
    int ch;
    while (timeout--) {
        ch = rx_byte();
        if (ch != -1) return ((char) ch);
    }
    return UART_EOM;
}

void UartDriver::recv_str(char *txt, unsigned short length) {
    char ch;
    while (length-- && (ch = recv_ch()) != UART_EOM) {
        #ifdef DEBUG_MODE
        if (ch != UART_EOM) printf("rx got char: %c (%x)\n", ((char)ch), ch);
        #endif
        *txt++ = ch;
    }
}

void UartDriver::tx_byte(uint8_t byte, unsigned short timeout) {
    while (timeout--) {
        if (tx_fifo_empty()) {
            io_write(UART_REG_THR, byte);
            break;
        }
        #ifdef DEBUG_MODE
        printf("t");
        #endif
    }
}

void UartDriver::send_ch(char ch) {
    tx_byte((int) ch);
}

void UartDriver::send_str(const char *str) {
    while (*str) tx_byte(*str++);
}
