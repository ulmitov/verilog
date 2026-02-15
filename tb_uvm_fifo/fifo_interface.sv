interface fifo_interface (
    input logic clk,
    input logic res
);
    logic push;
    logic pull;
    logic [fifo_config::DATA_WIDTH-1:0] din;
    logic [fifo_config::DATA_WIDTH-1:0] dout;
    logic empty;
    logic full;

    clocking cb_drv @(posedge clk);
        /*
        Input Skew: The input signals will be sampled 2 times unit before the clock edge.
        Output Skew: Delays the driving of output signals by a specified time relative to clk edge.
        default: input #1step output #0;
        */
        default input #fifo_config::SETUP_TIME output #fifo_config::HOLD_TIME;
        output push;
        output pull;
        output din;
        input dout;
        input empty;
        input full;
    endclocking

    clocking cb_mon @(posedge clk);
        default input #fifo_config::SETUP_TIME;
        input push;
        input pull;
        input din;
        input dout;
        input empty;
        input full;
    endclocking
    
    // actually if DUT is pure Verilog dont need those:
    modport DRIVER_MP(clocking cb_drv, input clk, input res);
    modport MONITOR_MP(clocking cb_mon, input clk, input res);
endinterface
