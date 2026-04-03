#include "uart_driver.h"


UartDriver::UartDriver() {}
UartDriver::~UartDriver() {}

// not implemented for now, should be external
void UartDriver::io_write(int addr, int data) {}
int UartDriver::io_read(int addr) {return 0;}


void UartDriver::set_baud_rate(int baud, short int stop_bits, short int parity, short int word_len) {
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

bool UartDriver::rx_fifo_empty() {
    // TODO: set UART_FCR_RXFIFTL then can check for full also
    uint8_t rd_word;
    int data_ready;
    rd_word = io_read(UART_REG_LSR);
    data_ready = (rd_word & MASK_RX_EMPTY);
    return bool(!data_ready);
}

bool UartDriver::tx_fifo_empty() {
    uint8_t rd_word;
    rd_word = io_read(UART_REG_LSR);
    return bool(rd_word & MASK_TX_EMPTY);
}

bool UartDriver::tx_fifo_full() {
    return !tx_fifo_empty();
}

void UartDriver::set_fifo_mode(bool enable) {
    io_write(UART_REG_FCR, enable ? MASK_FIFO_EN : 0x00);
}

int UartDriver::rx_byte() {
    if (rx_fifo_empty()) {
        #ifdef LOGS_ENABLE
        printf("rx fifo is empty");
        #endif
        return -1;
    }
    return ((int) io_read(UART_REG_RBR));
}

char UartDriver::recv_ch(short int timeout) {
    int ch;
    for (int i = 0; i < timeout; i++) {
        ch = rx_byte();
        if (ch != -1) break;
        #ifdef LOGS_ENABLE
        printf("rx got char: %c (%x)\n", ((char)ch), ch);
        #endif
    }
    return ch == -1 ? UART_EOM : ((char) ch);
}

void UartDriver::recv_str(char* txt, short int length) {
    char ch;
    int i = 0;
    while (i < length && (ch = recv_ch()) != UART_EOM) {
        txt[i++] = ch;
    }
}

void UartDriver::tx_byte(uint8_t byte, short int timeout) {
    for (int i = 0; i < timeout; i++) {
        if (tx_fifo_empty()) {
            io_write(UART_REG_THR, byte);
            break;
        }
        #ifdef LOGS_ENABLE
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
