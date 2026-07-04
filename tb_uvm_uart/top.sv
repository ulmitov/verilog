`timescale 1ns / 1ns
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "config.sv"
`include "interface_apb.sv"
`include "interface_pin.sv"
`include "transaction.sv"
`include "sequencer.sv"
`include "scoreboard.sv"
`include "driver_apb.sv"
`include "monitor_apb.sv"
`include "agent_apb.sv"
`include "driver_pin.sv"
`include "monitor_pin.sv"
`include "agent_pin.sv"
`include "ral_env.sv"
`include "environment.sv"
`include "sequences.sv"
`include "test_base.sv"
import config_pkg::*;


module top;
    logic clk = 1'b1;

    interface_apb vif_apb(clk);
    interface_pin vif_pin(clk, vif_apb.presetn);

    uart_apb #(.APB_DATA_WIDTH(APB_DATA_WIDTH)) dut(
        .pclk(vif_apb.pclk),
        .presetn(vif_apb.presetn),
        .psel(vif_apb.psel),
        .penable(vif_apb.penable),
        .pwrite(vif_apb.pwrite),
        .paddr(vif_apb.paddr),
        .pwdata(vif_apb.pwdata),
        .prdata(vif_apb.prdata),
        .pready(vif_apb.pready),
        .pslverr(vif_apb.pslverr),
        .rclk(vif_pin.rclk),
        .sin(vif_pin.sin),
        .sout(vif_pin.sout),
        .baudout(vif_pin.baudout),
        .intr(vif_pin.intr)
    );

    always #TCLK clk = ~clk;

    // later can set it to external uart clock according to test
    assign vif_pin.rclk = vif_pin.baudout;

    initial begin
        $dumpfile("vcd/top_uart_uvm.vcd");
        $dumpvars();
        uvm_config_db#(virtual interface_apb)::set(null, "*", "vif_apb", vif_apb);
        uvm_config_db#(virtual interface_pin)::set(null, "*", "vif_pin", vif_pin);
    end
    initial run_test("test");
endmodule
