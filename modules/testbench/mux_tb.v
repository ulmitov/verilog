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
        $monitor("%d: din=%16b, sel=%d, out=%d, exp=%d", $time, din, sel, out, exp);

        #`T_CLK sel = 0; din = 0; exp = 0;
        for (i = 0; i < 16; i = i + 1) begin
            #`T_CLK sel = i; exp = 1; din = 2 ** i; 
            #`T_CLK sel = i; exp = 0; din = 'hFFFF - 2 ** i;
        end
        $display("End of mux testbench");
        #`T_CLK $finish;
    end
endmodule
