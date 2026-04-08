`timescale 1ns / 1ns
`define TDELAY 10


module mux_tb;
    reg [15:0] din;
    reg [3:0] sel;
    wire out;
    reg exp;
    integer i;

    mux_16to1 DUT(.W(din), .SEL(sel), .Y(out));

    initial begin
        $dumpfile("vcd/mux_tb.vcd");
        $dumpvars(0);
        $monitor("%d: din=%16b  sel=%0b  out=%0b  exp=%0b", $time, din, sel, out, exp);

        #`TDELAY sel = 0; din = 0; exp = 0;
        #`TDELAY if (out != exp) $display("ERROR: mux out %0b is not as expected %0b", out, exp);
        for (i = 0; i < 16; i = i + 1) begin
            sel = i; din = 2 ** i; exp = din[i];
            #`TDELAY if (out != exp) $display("ERROR: mux out %0b with sel %0b is not as expected %0b", out, sel, exp);
            sel = i; din = 'hFFFF - 2 ** i; exp = din[i];
            #`TDELAY if (out != exp) $display("ERROR: mux out %0b with sel %0b is not as expected %0b", out, sel, exp);
        end
        $display("End testbench: vcd/mux_tb.vcd");
        $finish;
    end
endmodule
