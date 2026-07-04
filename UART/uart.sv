`include "regmap.vh"


module uart #(
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
    input baud_res,
    input loopback,
    input [7:0] wr_data,
    input [DIV_BITS-1:0] divisor,
    input [DWIDTH-1:0] lcreg,
    input [DWIDTH-1:0] fcreg,
    output logic tsr_empty,
    output logic [9:0] rd_data,
    output logic baudout,
    output logic tx_ext,    // to external device
    output logic rx_empty,
    output logic tx_full,
    output logic rx_ready,
    output logic rx_full,
    output logic tx_empty,
    output logic tx_ready
    //,output logic [FIFO_ADDR_W:0] rx_fifo_count
);
    logic [7:0] tx_fifo_out;
    logic [9:0] rx_out;
    logic rx_din;
    logic rx_sin;
    logic rx_clk;
    logic rx_sync;
    logic fifo_en;
    logic res_rxf;
    logic res_txf;
    logic tx_push;
    logic rx_push;
    logic rx_fifo_full;
    logic tx_fifo_full;
    logic rx_done;
    logic tx_pull;


    clock_divider #(DIV_BITS) baud_gen (
        .clk_in(clk),
        .res(~res_n | baud_res),
        .div(divisor),
        .clk_out(baudout)
    );

    // Rx: rx_ext -> RxUUT push rx_out to RxFifo when rx_ready and not full
    // -> RxFifo outputs rd_data -> CPU reads it when ~rx_empty
    uart_rx #(.TICKS_NUM(TICKS_NUM)) Rx_uut (
        .res_n(res_n),
        .rx_baud(rx_clk),
        .rx_din(rx_din),
        .lcreg(lcreg),
        .rx_out(rx_out),
        .rx_done(rx_done)
    );
    fifo #(.ADDR_WIDTH(FIFO_ADDR_W), .DATA_WIDTH(10), .name("Rx_fifo")) Rx_fifo (
        .clk(clk),
        .res(res_rxf),
        .push(rx_push),
        .pull(rd_uart),
        .din(rx_out),
        .dout(rd_data),
        .empty(rx_empty),
        .full(rx_fifo_full)
        //,.count(rx_fifo_count)
    );

    // Tx: CPU push wr_data when ~tx_full -> TxFIFO outputs tx_data to TxUUT
    // -> TxUUT pulls it when ~tx_empty -> tx_ext
    uart_tx #(.TICKS_NUM(TICKS_NUM)) Tx_uut (
        .res_n(res_n),
        .baudout(baudout),
        .tx_start(~tx_empty),
        .tx_din(tx_fifo_out),
        .tx_dout(tx_ext),
        .tx_ready(tx_pull),
        .lcreg(lcreg),
        .tsr_empty(tsr_empty)
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


    // 3-stage synchronizer to prevent metastability and glitches shorter than system clock
    // so clock divisor should be at least 3
    // if divisor < 4 then not syncing
    assign rx_din = ~|divisor[`UART_DATA_WIDTH:2] ? rx_sin : rx_sync;
    synchroniser #(.DATA_WIDTH(1), .STAGES(3)) synch_din (
        .clk(clk),
        .res(~res_n),
        .din(rx_sin),
        .dout(rx_sync)
    );
    /*
    logic [2:0] rx_sync_reg;
    assign rx_din = rx_sync_reg[2];
    always_ff @(posedge clk or negedge res_n) begin
        if (~res_n)
            rx_sync_reg <= 3'b111;
        else
            rx_sync_reg <= {rx_sync_reg[1:0], rx_sin};
    end
    */


    assign rx_sin = loopback ? tx_ext : rx_ext;
    assign rx_clk = loopback ? baudout : clk_rx;
    assign fifo_en = fcreg[`UART_FCR_FIFOEN];
    assign rx_full = (fifo_en & rx_fifo_full) | (~fifo_en & ~rx_empty);
    assign tx_full = (fifo_en & tx_fifo_full) | (~fifo_en & ~tx_empty);
    assign tx_push = wr_uart & ~tx_full;
    assign rx_push = rx_ready & ~rx_full; // The character in the shift register is overwritten, but it is not transferred to the FIFO
    assign res_rxf = ~res_n | fcreg[`UART_FCR_RXCLR];
    assign res_txf = ~res_n | fcreg[`UART_FCR_TXCLR];


    // rx_done width is 1 baud tick, but fifo needs clk width (posedge detector).
    logic rx_done_set;
    assign rx_ready = rx_done & ~rx_done_set;
    always_ff @(posedge clk) rx_done_set <= rx_done; // this will last for 1 baud tick

    //  (posedge detector) pull from TxFifo should be done
    // according to system clock. On first clock not pulled yet.
    logic tx_pulled;
    assign tx_ready = tx_pull & ~tx_pulled;
    always_ff @(posedge clk) tx_pulled <= tx_pull;
endmodule
