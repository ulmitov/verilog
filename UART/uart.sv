/*
uart_tb.cpp 

src="uart.sv uart_rx.sv uart_tx.sv clock_divider.sv ../shift_reg.v"
ignore="-Wno-SYNCASYNCNET -Wno-WIDTHTRUNC -Wno-LATCH -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-WIDTHEXPAND -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-MULTITOP -Wno-TIMESCALEMOD"
verilator -I../ -Wall ${ignore} --trace-vcd --timing --top uart --binary ${src}
*/
module uart #(
    parameter DATA_WIDTH = 8,
    parameter DIV_WIDTH = 12,
    parameter TICKS_NUM = 16,
    parameter FIFO_ADDR_W = 3
) (
    input clk,
    input res_n,
    input [DIV_WIDTH-1:0] divisor,
    input [DATA_WIDTH-1:0] wr_data,
    input rd_uart,          // cpu asks to read from uart
    input wr_uart,          // cpu asks to write to uart
    input rx_ext,           // from external device
    output logic tx_ext,    // to external device
    output logic rx_empty,  // uart to cpu: no rd_data to read
    output logic tx_full,   // uart to cpu: stop pushing wr_data
    output logic [DATA_WIDTH-1:0] rd_data
);
    logic tx_ready;
    logic rx_ready;
    logic rx_full;
    logic tx_empty;
    logic rx_baud;
    logic tx_baud;
    logic err_par;
    logic err_fr;
    logic [DATA_WIDTH-1:0] rx_out;
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] tx_fifo_out;
    logic [DATA_WIDTH-1:0] rx_fifo_out;

    // Rx: rx_ext -> RxUUT push rx_out to RxFifo when rx_ready and not full
    // -> RxFifo outputs rd_data -> CPU reads it when ~rx_empty
    clock_divider #(DIV_WIDTH) Rx_baud (.clk_in(clk), .res_n(res_n), .div(divisor), .clk_out(rx_baud));
    uart_rx #(.DATA_WIDTH(DATA_WIDTH), .TICKS_NUM(TICKS_NUM)) Rx_uut (
        .clk(clk),
        .res_n(res_n),
        .rx_baud(rx_baud),
        .rx_din(rx_ext),
        .rx_out(rx_out),
        .rx_ready(rx_ready),
        .err_par(err_par),
        .err_fr(err_fr)
    );
    fifo #(.ADDR_WIDTH(FIFO_ADDR_W), .DATA_WIDTH(DATA_WIDTH), .name("Rx_fifo")) Rx_fifo (
        .clk(clk),
        .res(~res_n),
        .push(rx_ready),
        .pull(rd_uart),
        .din(rx_out),
        .dout(rx_fifo_out),
        .empty(rx_empty),
        .full(rx_full)
    );

    // Tx: CPU push wr_data when ~tx_full -> TxFIFO outputs tx_data to TxUUT
    // -> TxUUT pulls it when ~tx_empty -> tx_ext
    clock_divider #(DIV_WIDTH) Tx_baud (.clk_in(clk), .res_n(res_n), .div(divisor), .clk_out(tx_baud));
    uart_tx #(.DATA_WIDTH(DATA_WIDTH), .STOP_BITS(1), .TICKS_NUM(TICKS_NUM)) Tx_uut (
        .clk(clk),
        .res_n(res_n),
        .tx_baud(tx_baud),
        .tx_start(~tx_empty),
        .tx_din(tx_data),
        .tx_dout(tx_ext),
        .tx_ready(tx_ready)
    );
    fifo #(.ADDR_WIDTH(FIFO_ADDR_W), .DATA_WIDTH(DATA_WIDTH), .name("Tx_fifo")) Tx_fifo (
        .clk(clk),
        .res(~res_n),
        .push(wr_uart),
        .pull(tx_ready),
        .din(wr_data),
        .dout(tx_fifo_out),
        .empty(tx_empty),
        .full(tx_full)
    );

    // Store fifo out, suppose we dont know if fifo dout can change on the next clock
    always_ff @(posedge clk) if (~rx_empty) rd_data <= rx_fifo_out;
    always_ff @(posedge clk) if (tx_ready)  tx_data <= tx_fifo_out;

    logic err_overrun;
    always_comb begin
        if (rx_full & rx_ready)
            err_overrun = 1'b1;
        else
            err_overrun = 1'b0;
    end
endmodule
