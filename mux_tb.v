`timescale 1ns / 1ns
`define T_CLK 10       // not real clock, only test delays


module mux_tb;
    reg [15:0] din;
    reg [3:0] sel;
    wire out;
    reg exp;
    integer i;

    mux_16to1 DUT(.W(din), .SEL(sel), .Y(out));

    initial begin
        $dumpfile("vcd/mux_tb.vcd");
        $dumpvars(0, mux_tb);
        $display("Start test");
        $monitor("%d: din=%16b, sel=%d, out=%d, exp=%d", $time, din, sel, out, exp);

        #`T_CLK sel = 0; din = 0; exp = 0;
        for (i = 0; i < 16; i = i + 1) begin
            #`T_CLK sel = i; exp = 1; din = 2 ** i; 
            #`T_CLK sel = i; exp = 0; din = 'hFFFF - 2 ** i;
        end
        #`T_CLK $finish;
    end
endmodule


module cmos_mux_tb;
    reg a, b, s;
    reg clk, exp;
    wire out_c, out_p;

    pmos_mux pdut( .W0(a), .W1(b), .SEL(s), .Y(out_p) );
    cmos_mux cdut( .W0(a), .W1(b), .SEL(s), .Y(out_c) );

    always @(*) begin
        #`T_CLK exp = s ? b : a;
        if (out_c !== exp) $display("%0d：　ERROR: out_c=%0b, exp=%0b", $time, out_c, exp);
        if (out_p !== exp) $display("%0d：　ERROR: out_p=%0b, exp=%0b", $time, out_p, exp);
    end

    initial begin
        $dumpfile("vcd/cmos_mux_tb.vcd");
        $dumpvars(0, cmos_mux_tb);
        $monitor("%d: a=%0b, b=%0b, s=%0b, out_c=%0b, out_p=%0b, exp=%0b", $time, a, b, s, out_c, out_p, exp);

        #`T_CLK a=0; b=0; s=0;
        #`T_CLK a=1;
        #`T_CLK s=1;
        #`T_CLK b=1;
        #`T_CLK b=0;
        #`T_CLK s=0;
        #`T_CLK a=0;
        #`T_CLK $finish;
    end
endmodule


module decoder_tb;
    reg [15:0] exp, out;
    reg [3:0] din;
    reg en;
    integer i;

    decoder4to16 DUT ( .en(en), .w(din), .y(out) );

    always
        #`T_CLK if (out !== exp) $display("%4d: ERROR: exp=%16b, out=%16b", $time, exp, out);

    initial begin
        $dumpfile("vcd/decoder_tb.vcd");
        $dumpvars(0, decoder_tb);
        $monitor("%4d: en=%0d, din=%4b, out=%16b", $time, en, din, out);
        en = 0;
        exp = 0;
        for (i = 0; i < 16; i = i + 1) #`T_CLK din = i;
        en = 1;
        din = 0;
        exp = 1;
        for (i = 0; i < 16; i = i + 1) begin
            #`T_CLK din = i;
            exp = 2 ** i;
        end
        #`T_CLK $finish;
    end
endmodule


module priority_enc_tb;
    reg [7:0] din;
    wire [2:0] out;
    wire valid;
    reg exp_v;
    integer i, j, br;

    priority_enc_8to3 DUT ( .in(din), .out(out), .valid(valid) );

    // expected results
    always begin
        #`T_CLK exp_v = din ? 1 : 0;
        if (valid !== exp_v) $display("ERROR: valid is not as expected");
        br = 0;
        for (j = 7; j >= 0; j = j - 1) begin
            if (!br && din[j] === 1) begin
                br = 1;
                if (out !== j) $display("ERROR: out is not as expected %3b", j);
            end
        end
    end

    // stimulus
    initial begin
        $dumpfile("vcd/priority_enc_tb.vcd");
        $dumpvars(0, priority_enc_tb);
        $monitor("%4d: din=%b, out=%b, valid=%b", $time, din, out, valid);

        for (i = 0; i < 2**8 ; i = i + 1) #`T_CLK din = i;
        #`T_CLK $finish;
    end
endmodule
