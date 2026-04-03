#include <stdint.h>
#include <stdbool.h>

//#define LOGS_ENABLE 1
#ifdef LOGS_ENABLE
#include <stdio.h>
#endif

#define CLK_FREQ_MHZ 10     // Mhz
#define BASE_ADDRESS 0x00
#define UART_EOM '\0'       // End of message

#define BAUD_OSRATE  16
#define UART_REG_RBR 0x0
#define UART_REG_THR 0x0
#define UART_REG_IER 0x1
#define UART_REG_IIR 0x2
#define UART_REG_FCR 0x2
#define UART_REG_LCR 0x3
#define UART_REG_LSR 0x5
#define UART_REG_DLL 0x0
#define UART_REG_DLM 0x1

#define UART_LCR_WLS 0
#define UART_LCR_PEN 3
#define UART_LCR_STB 2

#define UART_LSR_DR	0
#define UART_LSR_OE 1
#define UART_LSR_TF 5
#define UART_LCR_DL 7
#define UART_LSR_TE	6
#define UART_FCR_FIFOEN 0

/**
 * uart driver
 */
class UartDriver {
    /**
     * mask fields
     */
    enum {
        MASK_LCR_DLAB   = 1 << UART_LCR_DL,
        MASK_TX_EMPTY   = 1 << UART_LSR_TF,
        MASK_RX_EMPTY   = 1 << UART_LSR_DR,
        MASK_FIFO_EN    = 1 << UART_FCR_FIFOEN,
    };
    public:
        short int freq_divisor;
        short int ticks_per_word;

        /**
        * constructor
        */
        UartDriver();

        /**
        * destructor
        */
        ~UartDriver();

        /**
         * read an io register.
         * This actually should be an external function
         * @param addr register word address
         * @return 32-bit data of the register
         */
        virtual int io_read(int addr);

        /**
        * write an io register
        * This actually should be an external function
        * @param addr register word address
        * @param data 32-bit data
        */
        virtual void io_write(int addr, int data);

        /**
        * set fifo mode to enable or disable
        *
        * @param enable true/false
        */
        void set_fifo_mode(bool enable);

        /**
        * set baud rate and uart settings (LCR)
        *
        * @param baud baud rate
        * @param stop_bits stop bits value according to spec
        * @param parity parity bits value according to spec
        * @param word_len word length value according to spec (default is 8 bits)
        */
        void set_baud_rate(int baud, short int stop_bits, short int parity, short int word_len = 3);

        /**
        * check if uart rx fifo is empty
        *
        * @return 1: if empty; 0: otherwise
        */
        bool rx_fifo_empty();

        /**
        * check if uart tx fifo is full.
        * No real full flag exist, can only check if not empty,
        * then sending more data might override
        *
        * @return 1: if full; 0: otherwise
        */
        bool tx_fifo_full();

        /**
        * check if uart tx fifo is empty
        *
        * @return 1: if full; 0: otherwise
        */
        bool tx_fifo_empty();

        /**
        * transmit a byte with tx fifo status polling
        *
        * @param byte data byte to be transmitted
        * @param timeout how much clock ticks to attempt to send
        */
        void tx_byte(uint8_t byte, short int timeout = 1000);

        /**
        * raw receive a byte, without polling
        *
        * @return -1 if rx fifo empty; byte data otherwise
        */
        int rx_byte();

        /**
        * receive a string, with polling
        *
        * @param txt preallocated string array pointer
        * @param length string length
        */
        void recv_str(char* txt, short int length);

        /**
        * receive a char, with polling
        *
        * @param timeout how much clock ticks to wait for char
        * @return null if no data received; char otherwise
        */
        char recv_ch(short int timeout = 1000);

        /**
        * send (print) a char via uart
        *
        * @param ch char to send
        */
        void send_ch(char ch);

        /**
        * send (print) a string via uart
        *
        * @param str pointer to the string to be sent
        */
        void send_str(const char *str);
};
/*
#ifdef __cplusplus
extern "C" {
#endif

#ifdef __cplusplus
}
#endif
*/
