/*
    APB Slave UART interface wrapper
*/
`include "regmap.vh"
`include "clock_divider.sv"
`include "uart_rx.sv"
`include "uart_tx.sv"
`include "uart.sv"
`include "uart_top.sv"

`define REGS_ADDR_END 'h7

module uart_apb #(parameter APB_DATA_WIDTH = 32) (
    input logic rclk,   // rx baud pin
    input logic sin,    // serial input to rx
    input logic pclk,
    input logic presetn,
    input logic psel,
    input logic penable,
    input logic pwrite,
    input logic [`UART_ADDR_WIDTH-1:0] paddr,
    input logic [APB_DATA_WIDTH-1:0] pwdata,
    output logic [APB_DATA_WIDTH-1:0] prdata,
    output logic pready,
    output logic pslverr,
    output logic sout,      // serial output from tx
    output logic baudout,   // Tx baud
    output logic intr       // interrupt to cpu
);
    tri [`UART_DATA_WIDTH-1:0] data_bus;
    logic [`UART_DATA_WIDTH-1:0] wdata;
    logic rd;
    logic wr;
    
    generate
        if (`UART_DATA_WIDTH < APB_DATA_WIDTH)
            assign wdata = pwdata[`UART_DATA_WIDTH:0];
        else
            assign wdata = pwdata;
    endgenerate

    // invalid range. wr and rd will still work which is ok by spec
    assign pslverr = (pready & paddr > `REGS_ADDR_END) ? 1'b1 : 1'b0;
    assign pready = psel & penable;
    assign data_bus = pwrite & psel ? wdata : 'bZ;
    assign prdata = {{(APB_DATA_WIDTH - `UART_DATA_WIDTH){1'b0}}, data_bus};
    assign rd = ~pwrite & pready;
    assign wr = pwrite & pready;

    uart_top uart_apb (
        .clk(pclk),
        .res(~presetn),
        .cs(psel),
        .wr(wr),
        .rd(rd),
        .addr(paddr),
        .ddis(pwrite),
        .data_bus(data_bus),
        .rclk(rclk),
        .sin(sin),
    // outputs:
        .sout(sout),
        .baudout(baudout),
        .intr(intr)
    );
endmodule
