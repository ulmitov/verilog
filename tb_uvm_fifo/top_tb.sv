`include "fifo_config.sv"
`include "fifo_transaction.sv"
`include "sequencer.sv"
`include "fifo_sequence.sv"
`include "fifo_interface.sv"
`include "driver.sv"
`include "monitor.sv"
`include "agent.sv"
`include "scoreboard.sv"
`include "environment.sv"
`include "fifo_test.sv"
`include "test_wr.sv"
`include "test_wr_rd.sv"
`include "test_rand.sv"

`include "uvm_macros.svh"
import uvm_pkg::*;
/*
dvlcom -uvm 1.2 top_tb.sv 
dsim -top work.top_tb -genimage image -uvm 1.2 +acc+b
dsim -image image -uvm 1.2 -waves waves.mxd +UVM_NO_RELNOTES +UVM_TESTNAME=fifo_test
*/
module top_tb;
    timeunit 1ns;
    timeprecision 1ns;
    bit clk = 0;
    bit res = 1;

    fifo_interface IF(.clk(clk), .res(res));

    fifo #(.ADDR_WIDTH(fifo_config::ADDR_WIDTH), .DATA_WIDTH(fifo_config::DATA_WIDTH)) DUT (
        .res(IF.res),
        .clk(IF.clk),
        .push(IF.push),
        .pull(IF.pull),
        .din(IF.din),
        .dout(IF.dout),
        .empty(IF.empty),
        .full(IF.full)
    );

    always  #fifo_config::T_CLK clk = ~clk;
    initial #(fifo_config::T_CLK*2) res = 0;
    initial begin
        uvm_config_db #(virtual fifo_interface)::set(null, "*", "vif", IF);
        run_test("fifo_test");
    end
endmodule
