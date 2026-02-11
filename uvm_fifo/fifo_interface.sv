interface fifo_interface #(
    parameter ADDR_WIDTH = 3,
    parameter WORD_WIDTH = 8
) (
    input logic clk,
    input logic res
);
    logic push;
    logic pull;
    logic [WORD_WIDTH-1:0] din;
    logic [WORD_WIDTH-1:0] dout;
    logic empty;
    logic full;

    clocking cb_drv @(posedge clk);
        default input #1 output #2;
        output push;
        output pull;
        output din;
        /*input dout;
        input empty;
        input full;*/
    endclocking

    clocking cb_mon @(posedge clk);
        default input #1;
        input push;
        input pull;
        input din;
        input dout;
        input empty;
        input full;
    endclocking
    
    modport DRIVER_MP(clocking cb_drv, input clk, input res);
    modport MONITOR_MP(clocking cb_mon, input clk, input res);
endinterface