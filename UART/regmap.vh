/*
References:
https://media.digikey.com/pdf/Data%20Sheets/Texas%20Instruments%20PDFs/PC16550D.pdf
https://www.ti.com/lit/ds/symlink/tl16c550c.pdf
*/

`define UART_DIV_WIDTH 16    // Divider range bits: 1 to 2**16
`define UART_TICKS_NUM 16
`define UART_FIFO_ADDR_W 4   // 16 byte FIFO

// Choose 8 or 32 bus width:
`define DATA_BUS_WIDTH_8 
`ifdef DATA_BUS_WIDTH_8
    `define UART_ADDR_WIDTH 3
    `define UART_DATA_WIDTH 8
`else
    `define UART_ADDR_WIDTH 5
    `define UART_DATA_WIDTH 32
`endif

// Register map
`define UART_REG_RBR `UART_ADDR_WIDTH'h0 // Receiver Buffer reg     (R only)
`define UART_REG_THR `UART_ADDR_WIDTH'h0 // Transmitter Holding reg (W only)
`define UART_REG_IER `UART_ADDR_WIDTH'h1 // Interrupt enable reg
`define UART_REG_IIR `UART_ADDR_WIDTH'h2 // Interrupt status reg    (R only)
`define UART_REG_FCR `UART_ADDR_WIDTH'h2 // Fifo control reg        (W only)
`define UART_REG_LCR `UART_ADDR_WIDTH'h3 // Line control reg
`define UART_REG_LSR `UART_ADDR_WIDTH'h5 // Line status reg
`define UART_REG_MCR `UART_ADDR_WIDTH'h4 // Modem control reg           /* Unimplemented */
`define UART_REG_MSR `UART_ADDR_WIDTH'h6 // Modem status reg            /* Unimplemented */
`define UART_REG_SPR `UART_ADDR_WIDTH'h7 // Scratch Pad                 /* Unimplemented */
`define UART_REG_DLL `UART_ADDR_WIDTH'h0 // Divisor latch LSB
`define UART_REG_DLM `UART_ADDR_WIDTH'h1 // Divisor latch MSB

// Interrupt Enable register bits (IER)
`define UART_IER_ERBFI  0   // Enable Received Data Available Interrupt (ERBI)
`define UART_IER_ETBEI  1   // Enable Transmitter Holding Register Empty Interrupt (ETBEI)
`define UART_IER_ELSI   2   // Enable Receiver Line Status Interrupt
`define UART_IER_EDSSI  3   // Enable Modem Status Interrupt (EDSSI)    /* Unimplemented */
`define UART_IER_UNUSED 7:4

// Interrupt Identification (status) Register bits (IIR, ISR): R only
`define UART_IIR_IPEND  0	    // Interrupt pending when 0
`define UART_IIR_INTID  3:1	    // Interrupt identification
`define UART_IIR_UNUSED 5:4
`define UART_IIR_FIOEN  7:6	    // FIFO enable. 0 disable, 3 enable

// Interrupt identification values for bits 3:1
`define UART_IIR_RLS	3'b011	// Receiver Line Status
`define UART_IIR_RDA	3'b010	// Receiver Data available
`define UART_IIR_TI	    3'b110	// Char Timeout Indication
`define UART_IIR_THRE	3'b001	// Transmitter Holding Register empty
`define UART_IIR_MS	    3'b000	// Modem Status                         /* Unimplemented */

// Line Status Register bits
`define UART_LSR_DR	    0	    // Data ready
`define UART_LSR_OE	    1	    // Overrun Error
`define UART_LSR_PE	    2	    // Parity Error
`define UART_LSR_FE	    3	    // Framing Error
`define UART_LSR_BI	    4	    // Break interrupt                      /* Unimplemented */
`define UART_LSR_TF     5	    // Transmit FIFO is empty THRE
`define UART_LSR_TE	    6	    // Transmitter Empty indicator TEMT
`define UART_LSR_EI	    7	    // Error in Rx Fifo RXFIFOE

// Line Control register bits
`define UART_LCR_WLS    1:0     // Word length select bit 0 (WLS1:WLS0)
`define UART_LCR_STB    2	    // stop bits
`define UART_LCR_PEN    3	    // parity enable
`define UART_LCR_EPS    4	    // even parity select
`define UART_LCR_SP	    5	    // stick parity
`define UART_LCR_PS	    5:3	    // parity bits 5:3
`define UART_LCR_BC	    6	    // Break control                        /* Unimplemented */
`define UART_LCR_DL	    7	    // Divisor Latch access bit (DLAB)

// Fifo Control register bits (FCR): W only
`define UART_FCR_FIFOEN     0   // FIFO Enable                          /* Unimplemented */ fifo always on
`define UART_FCR_RXCLR      1   // Receiver FIFO Reset
`define UART_FCR_TXCLR      2   // Transmitter FIFO Reset
`define UART_FCR_DMAMODE1   3   // DMA Mode select                      /* Unimplemented */
`define UART_FCR_RXFIFTL    7:6 // Receiver fifo threshold levels       /* Unimplemented */ always 01

// FIFO threshold trigger level RXFIFTL (RXFIFTM:RXFIFTL) values
`define UART_FCR_TL_1	2'b00
`define UART_FCR_TL_4	2'b01
`define UART_FCR_TL_8	2'b10
`define UART_FCR_TL_14	2'b11

// Modem Control register bits
`define UART_MCR_DTR	0   // Data terminal ready
`define UART_MCR_RTS	1   // Request to send
`define UART_MCR_OUT1	2
`define UART_MCR_OUT2	3
`define UART_MCR_LOOP   4	// Loopback mode enable
`define UART_MCR_AFE    5	// Autoflow control mode enable

// Modem Status Register bits
`define UART_MSR_DCTS	0	// Delta Clear to Send
`define UART_MSR_DDSR	1   // Delta Data Set Ready
`define UART_MSR_TERI	2   // Trailing Edge Ring Indicator
`define UART_MSR_DDCD	3   // Delta Data Carrier Detect
`define UART_MSR_CCTS	4	// Complement Clear to Send
`define UART_MSR_CDSR	5   // Complement Data Set Ready
`define UART_MSR_CRI	6   // Complement Ring indicator
`define UART_MSR_CDCD	7   // Complement Data Carrier Detect
