`include "regmap.vh"


module uart #(
    parameter LOOPBACK = 1,
    parameter DWIDTH = `UART_DATA_WIDTH,
    parameter DIV_BITS = `UART_DIV_WIDTH,
    parameter TICKS_NUM = `UART_TICKS_NUM,
    parameter FIFO_ADDR_W = `UART_FIFO_ADDR_W
) (
    input clk,
    input clk_rx,
    input res_n,
    input rd_uart,
    input wr_uart,
    input rx_ext,           // from external device
    input [7:0] wr_data,
    input baud_res,
    input [DIV_BITS-1:0] divisor,
    input [DWIDTH-1:0] lcreg,
    input [DWIDTH-1:0] fcreg,
    output logic [7:0] tsr_data,
    output logic [9:0] rd_data,
    output logic tx_baud,
    output logic tx_ext,    // to external device
    output logic rx_empty,
    output logic tx_full,
    output logic rx_ready,
    output logic rx_full,
    output logic tx_empty,
    output logic tx_ready
);
    logic [7:0] tx_data;
    logic [7:0] tx_fifo_out;
    logic [9:0] rx_fifo_out;
    logic [9:0] rx_out;
    logic rx_din;
    logic rx_clk;
    logic res_rxf;
    logic res_txf;
    logic fifo_en;
    logic rx_fifo_full;
    logic tx_fifo_full;
    logic tx_push;
    logic rx_push;

    clock_divider #(DIV_BITS) baud_gen (
        .clk_in(clk),
        .res(~res_n | baud_res),
        .div(divisor),
        .clk_out(tx_baud)
    );

    // Rx: rx_ext -> RxUUT push rx_out to RxFifo when rx_ready and not full
    // -> RxFifo outputs rd_data -> CPU reads it when ~rx_empty
    uart_rx #(.TICKS_NUM(TICKS_NUM)) Rx_uut (
        .clk(clk),
        .res_n(res_n),
        .rx_baud(rx_clk),
        .rx_din(rx_din),
        .lcreg(lcreg),
        .rx_out(rx_out),
        .rx_ready(rx_ready)
    );
    fifo #(.ADDR_WIDTH(FIFO_ADDR_W), .DATA_WIDTH(10), .name("Rx_fifo")) Rx_fifo (
        .clk(clk),
        .res(res_rxf),
        .push(rx_push),
        .pull(rd_uart),
        .din(rx_out),
        .dout(rx_fifo_out),
        .empty(rx_empty),
        .full(rx_fifo_full),
        .count(rx_fifo_count)
    );

    // Tx: CPU push wr_data when ~tx_full -> TxFIFO outputs tx_data to TxUUT
    // -> TxUUT pulls it when ~tx_empty -> tx_ext
    uart_tx #(.TICKS_NUM(TICKS_NUM)) Tx_uut (
        .clk(clk),
        .res_n(res_n),
        .tx_baud(tx_baud),
        .tx_start(~tx_empty),
        .tx_din(tx_data),
        .tx_dout(tx_ext),
        .tx_ready(tx_ready),
        .lcreg(lcreg),
        .tsr_data(tsr_data)
    );
    fifo #(.ADDR_WIDTH(FIFO_ADDR_W), .DATA_WIDTH(8), .name("Tx_fifo")) Tx_fifo (
        .clk(clk),
        .res(res_txf),
        .push(tx_push),
        .pull(tx_ready),
        .din(wr_data),
        .dout(tx_fifo_out),
        .empty(tx_empty),
        .full(tx_fifo_full)
    );

    assign rx_din = LOOPBACK ? tx_ext : rx_ext;
    assign rx_clk = LOOPBACK ? tx_baud : clk_rx;
    assign fifo_en = fcreg[`UART_FCR_FIFOEN];
    assign rx_full = (fifo_en & rx_fifo_full) | (~fifo_en & ~rx_empty);
    assign tx_full = (fifo_en & tx_fifo_full) | (~fifo_en & ~tx_empty);
    assign tx_push = wr_uart & ~tx_full;
    assign rx_push = rx_ready & ~rx_full; // The character in the shift register is overwritten, but it is not transferred to the FIFO
    assign res_rxf = ~res_n | fcreg[`UART_FCR_RXCLR];
    assign res_txf = ~res_n | fcreg[`UART_FCR_TXCLR];
    // buffer fifo out, since it will change after pull
    always_ff @(posedge clk) if (tx_ready) tx_data <= tx_fifo_out;
    always_ff @(posedge clk) if (rd_uart) rd_data <= rx_fifo_out;
endmodule
