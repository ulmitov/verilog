`define SPICCR 'h7040
`define SPICTL 'h7401
`define SPIST 'h7042
`define SPIBRR 'h7044
`define SPIRXBUF 'h7047
`define SPITXBUF 'h7048
`define SPIDAT 'h7049

`define SPICCR_LOOPBACK 4
`define SPICCR_POL 6
`define SPICCR_SW_RES 7

`define SPICTL_SPI_EN 1
`define SPICTL_MASTER 2
`define SPICTL_PHASE 3

`define SPIST_TX_FULL 5
`define SPIST_SPI_INT 6
`define SPIST_RX_OVERRUN 7

`define FORCED_COMB_DELAY 4