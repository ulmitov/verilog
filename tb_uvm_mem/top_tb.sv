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
    int i;
    string str;
    uvm_event ev_init, ev_dump;

    mem_interface mif(.clk(wclk));

    memory #(
        .MEM_FILE(""),
        .DEPTH(mem_config::DEPTH),
        .ADDR_WIDTH(mem_config::ADDR_WIDTH),
        .DATA_WIDTH(mem_config::DATA_WIDTH),
        .ENDIANESS(mem_config::ENDIANESS)
    ) dut (
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
    initial run_test("test_regression");
    initial begin
        $dumpfile("top_tb_mem.vcd");
        $dumpvars(0, top_tb);
        uvm_config_db #(virtual mem_interface)::set(null, "*", "vif", mif);
        // Wait for memory init task event
        ev_init = uvm_event_pool::get_global_pool().get("EV_INIT");
        ev_dump = uvm_event_pool::get_global_pool().get("EV_DUMP");
        forever begin
            fork
                ev_init.wait_trigger();
                ev_dump.wait_trigger();
            join_any
            if (ev_init.is_on()) begin
                dut.initmem(mem_config::MEM_FILE);
                ev_init.reset();
            end
            if (ev_dump.is_on()) begin
                str = "";
                foreach (dut.MEMX[i]) str = { str, $sformatf("[0x%0h]%2h ", i, dut.MEMX[i]) };
                $display("DUMP: [%s]", str);
                ev_dump.reset();
            end
        end
    end
endmodule
