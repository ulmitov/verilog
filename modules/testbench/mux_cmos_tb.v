`timescale 1ns / 1ns
`define T_CLK 10       // not real clock, only test delays
`define VCD "vcd/mux_cmos_tb.vcd"

module mux_cmos_tb;
    reg a, b, s;
    reg clk, exp;
    wire out_c, out_p;

    pmos_mux pdut( .W0(a), .W1(b), .SEL(s), .Y(out_p) );
    cmos_mux cdut( .W0(a), .W1(b), .SEL(s), .Y(out_c) );

    always @(*) begin
        #(`T_CLK+1) exp = s ? b : a;
        if (out_c !== exp) $error("[%0d] out_c=%0b, exp=%0b", $time, out_c, exp);
        if (out_p !== exp) $error("[%0d] out_p=%0b, exp=%0b", $time, out_p, exp);
    end

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%d: a=%0b, b=%0b, s=%0b, out_c=%0b, out_p=%0b, exp=%0b", $time, a, b, s, out_c, out_p, exp);

        #`T_CLK a=0; b=0; s=0;
        #`T_CLK a=1;
        #`T_CLK s=1;
        #`T_CLK b=1;
        #`T_CLK b=0;
        #`T_CLK s=0;
        #`T_CLK a=0;
        #`T_CLK $display("End of testbench: %s", `VCD);
        $finish;
    end
endmodule
