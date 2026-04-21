#include <stdint.h>

#ifdef DEBUG_MODE
#include <stdio.h>
#endif

#define CLK_FREQ_MHZ 4
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
#define UART_FCR_RXCLR 1
#define UART_FCR_TXCLR 2

typedef enum {
        PARITY_DISABLED = 0,
        PARITY_ODD = 1,
        PARITY_EVEN = 3,
        PARITY_STICK_0 = 7,
        PARITY_STICK_1 = 5
} PARITY_ENUM;


/**
 * uart driver
 */
class UartDriver {
    public:
        unsigned short freq_divisor;
        unsigned short ticks_per_word;

        /**
        * constructor
        */
        UartDriver();

        /**
        * destructor
        */
        ~UartDriver();

        /**
        * set fifo mode to enable or disable
        *
        * @param enable 1 or 0
        */
        void set_fifo_mode(short enable);

        /**
        * flush or reset fifo
        */
        void flush_fifo();

        /**
        * set baud rate and uart settings (LCR)
        *
        * @param baud baud rate
        * @param stop_bits stop bits value according to spec
        * @param parity parity bits value according to spec
        * @param word_len word length value according to spec, default is 3 (8 bits)
        */
        void set_baud_rate(unsigned int baud, unsigned char stop_bits, unsigned char parity, unsigned char word_len = 3);

        /**
        * check if uart rx fifo is empty
        *
        * @return 1: if empty; 0: otherwise
        */
        unsigned char rx_fifo_empty();

        /**
        * check if uart tx fifo is empty
        *
        * @return 1: if full; 0: otherwise
        */
        unsigned char tx_fifo_empty();

        /**
        * transmit a byte with tx fifo status polling
        *
        * @param data data byte to be transmitted
        * @param timeout how much clock ticks to attempt to send
        * @return 1 if data was accepted by uart, 0 otherwise
        */
        int tx_byte(uint8_t data, unsigned short timeout = 1000);

        /**
        * raw receive byte from RBR, without polling
        *
        * @return byte
        */
        unsigned char rx_byte();

        /**
        * receive bytes with polling
        *
        * @param arr uint8 uint8_t pointer
        */
        void recv(uint8_t *arr);

        /**
        * receive a char with polling
        *
        * @param timeout max clocks to wait for char
        * @return null if no data received; char otherwise
        */
        char recv_ch();

        /**
        * send (print) a char via uart
        *
        * @param ch char to send
        */
        void send_ch(char ch);

        /**
        * send an array of bytes
        *
        * @param arr pointer to the bytes array
        * @param length data length
        */
        void send(const uint8_t *arr, int length);

        /**
        * send (print) a string via uart
        *
        * @param str pointer to the string to be sent
        */
        void send_str(const char *str);

        /**
        * check if Overrun flag was raised
        *
        * @return 1: if OE; 0: otherwise
        */
        unsigned char is_overrun();

        /**
        * get line status bits
        *
        * @return LSR value
        */
        int get_line_status();

        /**
        * poll for rx fifo to be empty
        *
        * @return 1: if fifo empty; 0: otherwise
        */
        short poll_rx(unsigned short timeout = 1000);

        /**
        * poll for tx fifo to be empty
        *
        * @return 1: if fifo empty; 0: otherwise
        */
        short poll_tx(unsigned short timeout = 1000);

        /**
         * read an io register.
         * This actually should be an external function
         * @param addr register word address
         * @return 32-bit data of the register
         */
        virtual uint32_t io_read(uint32_t addr);

        /**
        * write an io register
        * This actually should be an external function
        * @param addr register word address
        * @param data 32-bit data
        */
        virtual void io_write(uint32_t addr, uint32_t data);
    protected:
        uint32_t line_status = 0;   // LSR is saved here each read
};
