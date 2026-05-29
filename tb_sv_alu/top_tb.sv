import risc_pkg::*;
`timescale 1ns / 1ns

`ifdef CONST_DELAYS_OFF
`define TPD 80
`else
`define TPD (`T_DELAY_PD*(3*32))
`endif
`define SV_TB   // TODO: remove after verilator bug

`include "consts.vh"
`include "environment.sv"


module top_tb;
    logic clk = 0;
    intf itf(clk);
    // TODO: remove the clock when verilator threading issues fixed
    always #`TPD clk = ~clk;

    alu #(.XLEN(RISCV_XLEN)) DUT (
        .alu_a(itf.alu_a),
        .alu_b(itf.alu_b),
        .alu_op(itf.alu_op),
        .alu_res(itf.alu_res)
    );

    alu_dataflow #(.XLEN(RISCV_XLEN)) REF (
        .alu_a(itf.alu_a),
        .alu_b(itf.alu_b),
        .alu_op(itf.alu_op),
        .alu_res(itf.res_exp)
    );

    main_test TEST(itf);

    initial begin
        $dumpfile("vcd/top_tb_sv_alu.vcd");
        $dumpvars();
    end
endmodule


program main_test(intf itf);
    // reducing for 64 bits, runs too much time
    parameter int SEQ_NUM = RISCV_XLEN > 32 ? RISCV_XLEN * 3 : RISCV_XLEN * 10;
    environment env;
    
    initial begin
        env = new(itf);
        env.pre_test();
        env.test_bit_by_bit();
        env.test_random_bit(SEQ_NUM);
        env.test_random_val(SEQ_NUM);
        env.test_manual_val();
        env.post_test();
        $display("End of testbench: top_tb_sv_alu.vcd");
        $finish;
    end
endprogram
