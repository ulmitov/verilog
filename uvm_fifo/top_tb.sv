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
`include "uvm_macros.svh"
import uvm_pkg::*;

/*
dvlcom -uvm 2020.3.1 sequencer.sv fifo_interface.sv fifo_transaction.sv  fifo_sequence.sv driver.sv monitor.sv scoreboard.sv agent.sv environment.sv test.sv top_tb.sv 

dvlcom -uvm 2020.3.1 top_tb.sv 
dsim -top work.top_tb -genimage image -uvm 2020.3.1 ../filelist.txt +acc+b
dsim -top work.top_tb -genimage image -uvm 2020.3.1  +acc+b
dsim -image image -uvm 2020.3.1 -waves waves.mxd +UVM_NO_RELNOTES +UVM_TESTNAME=top_tb
*/
module top_tb;
    bit clk = 0;
    bit res = 1;

    always #5 clk = ~clk;
    initial #10 res = 0;

    fifo_interface IF(.clk(clk), .res(res));

    fifo #(.ADDR_WIDTH(3), .WORD_WIDTH(8)) DUT (.res(IF.res), .clk(IF.clk), .push(IF.push), .pull(IF.pull), .din(IF.din), .dout(IF.dout), .empty(IF.empty), .full(IF.full));

    initial uvm_config_db#(virtual fifo_interface)::set(null, "*", "vif", IF);

    initial begin
        run_test("test_wr_rd");
    end
endmodule
