`include "environment.sv"
`timescale 1ns / 1ns

/* SEE README HOW TO RUN */
module top_tb;
    intf itf();

    alu DUT (
        .alu_a(itf.alu_a),
        .alu_b(itf.alu_b),
        .alu_op(itf.alu_op),
        .alu_res(itf.alu_res)
    );

    alu_dataflow REF (
        .alu_op(itf.alu_op),
        .alu_a(itf.alu_a),
        .alu_b(itf.alu_b),
        .alu_res(itf.res_exp)
    );

    test TEST(itf);

    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars();
    end
endmodule


program test(intf itf);
    environment env;

    initial begin
        env = new(itf);
        env.pre_test();
        env.test_manual_val();
        env.test_bit_by_bit(32);
        env.test_random_bit(10*32);
        env.test_random_val(100);
        env.post_test();
        $finish;
    end
endprogram
