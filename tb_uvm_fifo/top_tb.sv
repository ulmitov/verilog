`include "uvm_macros.svh"
import uvm_pkg::*;

`include "fifo_config.sv"
`include "fifo_interface.sv"
`include "transaction.sv"
`include "sequences.sv"
`include "driver.sv"
`include "monitor.sv"
`include "agent.sv"
`ifndef VERILATOR
`include "coverage.sv"
`endif
`include "scoreboard.sv"
`include "environment.sv"
`include "test_base.sv"



module top_tb;
    bit res;
    bit clk = 0;

    fifo_interface IF(.clk(clk));

    fifo #(
        .ADDR_WIDTH(fifo_config::ADDR_WIDTH),
        .DATA_WIDTH(fifo_config::DATA_WIDTH)
    ) DUT (
        .res(IF.res),
        .clk(IF.clk),
        .push(IF.push),
        .pull(IF.pull),
        .din(IF.din),
        .dout(IF.dout),
        .empty(IF.empty),
        .full(IF.full),
        .count(IF.counter)
    );

    always  #(fifo_config::TCLK) clk = ~clk;
    initial run_test("test_regression");
    initial begin
        //$dumpfile("fifo_top_tb.vcd");
        //$dumpvars(0);
        uvm_config_db#(virtual fifo_interface)::set(null, "*", "vif", IF);
    end
endmodule
