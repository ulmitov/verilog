`timescale 1ns / 1ns
`define CLK_DRIVE 10
`define CLK_MONITOR 12
`define VCD "vcd/decoder_tb.vcd"


module decoder_tb;
    reg [15:0] exp;
    wire [15:0] out;
    reg [3:0] din;
    reg en;
    integer i;

    decoder4to16 DUT ( .en(en), .w(din), .y(out) );

    always
        #(`CLK_MONITOR) if (out !== exp) $display("%4d: ERROR: exp=%16b, out=%16b", $time, exp, out);

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%4d: en=%0d, din=%4b, out=%16b", $time, en, din, out);
        $display("Test stuck at 1");
        en = 0;
        exp = 0;
        for (i = 0; i < 16; i = i + 1) #`CLK_DRIVE din = i;
        $display("Test stuck at 0 and functionality");
        en = 1;
        din = 0;
        exp = 1;
        for (i = 0; i < 16; i = i + 1) begin
            #`CLK_DRIVE din = i;
            exp = 2 ** i;
        end
        $display("End of testbench: %s", `VCD);
        #`CLK_DRIVE $finish;
    end
endmodule
