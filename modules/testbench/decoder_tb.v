/*
tb="decoder_tb"; verilator --lint-only -Wall mux.v
iverilog -Wall -g2005 -gspecify -o ./vcd/${tb}.vvp -s ${tb} testbench/${tb}.v mux.v && vvp ./vcd/${tb}.vvp
*/
`timescale 1ns / 1ns
`define T_CLK 10
`define VCD "vcd/decoder_tb.vcd"

module decoder_tb;
    reg [15:0] exp;
    wire [15:0] out;
    reg [3:0] din;
    reg en;
    integer i;

    decoder4to16 DUT ( .en(en), .w(din), .y(out) );

    always
        #`T_CLK if (out !== exp) $display("%4d: ERROR: exp=%16b, out=%16b", $time, exp, out);

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%4d: en=%0d, din=%4b, out=%16b", $time, en, din, out);
        $display("Test stuck at 1");
        en = 0;
        exp = 0;
        for (i = 0; i < 16; i = i + 1) #`T_CLK din = i;
        $display("Test stuck at 0 and functionality");
        en = 1;
        din = 0;
        exp = 1;
        for (i = 0; i < 16; i = i + 1) begin
            #`T_CLK din = i;
            exp = 2 ** i;
        end
        $display("End of testbench: %s", `VCD);
        #`T_CLK $finish;
    end
endmodule
