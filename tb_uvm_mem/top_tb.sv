`include "mem_config.sv"
`include "mem_interface.sv"
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
`include "tests.sv"
`include "uvm_macros.svh"
import uvm_pkg::*;


module top_tb;
    bit wclk = 0;
    bit res;
    bit req;

    mem_interface mif(.clk(wclk), .req(req));

    memory #(
        .MEM_FILE(""),
        .DEPTH(mem_config::DEPTH),
        .ADDR_WIDTH(mem_config::ADDR_WIDTH),
        .DATA_WIDTH((mem_config::DATA_WIDTH)),
        .ENDIANESS(0)
    ) ram (
        .rclk(mif.clk),
        .wclk(mif.clk),
        .res(mif.res),
        .ren(mif.ren),
        .wen(mif.wen),
        .req(mif.req),
        .addr(mif.addr),
        .blsize(mif.blsize),
        .wr_data(mif.wr_data),
        .rd_data(mif.rd_data)
    );

    always  #(mem_config::T_CLK) wclk = ~wclk;
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
        //res = 1'b1;
        req = 1'b1;
        //#(mem_config::T_CLK*2) res = 1'b0;
    end
    initial begin
        uvm_config_db #(virtual mem_interface)::set(null, "*", "vif", mif);
        run_test("test_regression");
    end
endmodule
