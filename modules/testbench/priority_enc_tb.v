/*
tb="priority_enc_tb"
verilator --lint-only -Wall mux.v
iverilog -Wall -g2005 -gspecify -o ./vcd/${tb}.vvp -s ${tb} testbench/${tb}.v mux.v
vvp ./vcd/${tb}.vvp
*/
`timescale 1ns / 1ns
`define T_CLK 10
`define VCD "vcd/priority_enc_tb.vcd"


module priority_enc_tb;
    reg [7:0] din;
    wire [2:0] out;
    wire valid;
    reg exp_v;
    integer i, j, br;

    priority_enc_8to3 DUT ( .in(din), .out(out), .valid(valid) );

    // scoreboard
    always begin
        #`T_CLK exp_v = din ? 1 : 0;
        #1 if (exp_v !== 1'bX && valid !== exp_v) $error("valid %0b is not as expected %0b", valid, exp_v);
        br = 0;
        for (j = 7; j >= 0; j = j - 1) begin
            if (!br && din[j] === 1) begin
                br = 1;
                #1 if (out !== j) $error("out is not as expected %3b", j);
            end
        end
    end

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%4d: din=%b, out=%b, valid=%b", $time, din, out, valid);
        for (i = 0; i < 2**8 ; i = i + 1) #`T_CLK din = i;
        #`T_CLK $display("End of testbench: %s", `VCD);
        $finish;
    end
endmodule
