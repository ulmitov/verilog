import risc_pkg::*;
`timescale 1ns / 1ns

`ifdef CONST_DELAYS_OFF
`define TPD 80
`else
`define TPD (`T_DELAY_PD*(3*32))
`endif

`include "consts.vh"
`include "environment.sv"


module top_tb;
    logic clk = 0;
    intf itf(clk);
    // TBD: remove the clock when threading issues fixed
    always #`TPD clk = ~clk;

    alu DUT (
        .alu_a(itf.alu_a),
        .alu_b(itf.alu_b),
        .alu_op(itf.alu_op),
        .alu_res(itf.alu_res)
    );

    alu_dataflow REF (
        .alu_a(itf.alu_a),
        .alu_b(itf.alu_b),
        .alu_op(itf.alu_op),
        .alu_res(itf.res_exp)
    );

    main_test TEST(itf);

    initial begin
        $dumpfile("top_tb_alu.vcd");
        $dumpvars();
    end
endmodule


program main_test(intf itf);
    environment env;
    initial begin
        env = new(itf);
        env.pre_test();
        env.test_manual_val();
        env.test_bit_by_bit(32);
        env.test_random_bit(10*32);
        env.test_random_val(1000);
        env.post_test();
        $display("End of testbench: top_tb_alu.vcd");
        $finish;
    end
endprogram
