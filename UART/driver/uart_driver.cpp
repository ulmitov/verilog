#include "uart_driver.h"


UartDriver::UartDriver() {}
UartDriver::~UartDriver() {}


// TBD: should be taken from cpu header
void UartDriver::io_write(uint32_t addr, uint32_t data) {
    (*((volatile uint32_t *)addr)) = (data);
}

uint32_t UartDriver::io_read(uint32_t addr) {
    return (*((volatile uint32_t *)addr));
}


void UartDriver::set_baud_rate(unsigned int baud, unsigned char stop_bits, unsigned char parity, unsigned char word_len) {
    float rate = CLK_FREQ_MHZ * (word_len + 5);
    rate = rate * 1000000 / baud / BAUD_OSRATE;
    short total_bits = word_len + 5 + stop_bits + 1 + (parity & 1);
    int freq_divisor = (rate + total_bits - 1) / total_bits;        // round up: (a + b - 1) / b
    io_write(UART_REG_LCR, 1 << UART_LCR_DL);
    io_write(UART_REG_DLL, (uint8_t) freq_divisor);
    io_write(UART_REG_DLM, (uint8_t) (freq_divisor >> 8));
    io_write(UART_REG_LCR, (word_len << UART_LCR_WLS) | (stop_bits << UART_LCR_STB) | (parity << UART_LCR_PEN));
}

unsigned short UartDriver::get_divisor() {
    int lcr = io_read(UART_REG_LCR);
    io_write(UART_REG_LCR, 1 << UART_LCR_DL);
    unsigned short freq_divisor = io_read(UART_REG_DLL) | (io_read(UART_REG_DLM) << 8);
    io_write(UART_REG_LCR, lcr);
    return freq_divisor;
}

int UartDriver::get_line_status() {
    line_status = io_read(UART_REG_LSR);
    return line_status;
}

unsigned char UartDriver::rx_fifo_empty() {
    return !(get_line_status() & (1 << UART_LSR_DR));
}

unsigned char UartDriver::tx_fifo_empty() {
    return get_line_status() & (1 << UART_LSR_TF);
}

unsigned char UartDriver::is_overrun() {
    return get_line_status() & (1 << UART_LSR_OE);
}

void UartDriver::set_fifo_mode(short enable) {
    io_write(UART_REG_FCR, enable ? (1 << UART_FCR_FIFOEN) : 0x00);
}

void UartDriver::flush_fifo() {
    io_write(UART_REG_FCR, 1 << UART_FCR_RXCLR | 1 << UART_FCR_TXCLR);
}

unsigned char UartDriver::rx_byte() {
    return io_read(UART_REG_RBR);
}

char UartDriver::recv_ch() {
    int ch;
    if (!rx_fifo_empty()) {
        ch = rx_byte();
        #ifdef DEBUG_MODE
        printf("rx got char: %c (0x%x)\n", ch, ch);
        #endif
        return (char) ch;
    } else {
        #ifdef DEBUG_MODE
        printf("rx fifo empty\n");
        #endif
    }
    return UART_EOM;
}

short UartDriver::poll_rx(unsigned short timeout) {
    short res;
    while (timeout-- && (res = rx_fifo_empty())) {
        #ifdef DEBUG_MODE
        printf("P");
        #endif
    }
    return !res;
}

short UartDriver::poll_tx(unsigned short timeout) {
    short res;
    while (timeout-- && !(res = tx_fifo_empty())) {
        #ifdef DEBUG_MODE
        printf("T");
        #endif
    }
    return res;
}

void UartDriver::recv(uint8_t *arr) {
    // in fifo mode can just poll for rx fifo empty.
    // in polling mode should check local flag.
    while (poll_rx() && (*arr++ = rx_byte()));
    *arr = UART_EOM;
}

int UartDriver::tx_byte(uint8_t data, unsigned short timeout) {
    if (!poll_tx(timeout)) return 0;
    io_write(UART_REG_THR, data);
    return 1;
}

void UartDriver::send_ch(char ch) {
    tx_byte((uint8_t) ch);
}

void UartDriver::send_str(const char *str) {
    while (*str) tx_byte(*str++);
}

void UartDriver::send(const uint8_t *arr, int length) {
    while (length--) tx_byte(*arr++);
}
