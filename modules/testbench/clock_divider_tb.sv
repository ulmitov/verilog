`timescale 1ns / 1ns
`define TCLK 5  // 100Mhz


module clock_divider_tb;
    logic clk;
    logic res;
    logic clk_out2, clk_out3, clk_out4, clk_out5, clk_out6, clk_out7, clk_out8, clk_out9, clk_out10;
    int cnt2 = 0, cnt3 = 0, cnt4 = 0, cnt5 = 0, cnt6 = 0, cnt7 = 0, cnt8 = 0, cnt9 = 0, cnt10 = 0;
    logic [15:0] div;
    logic pol = 1'b1;

    clock_divider uut2 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd2), .clk_out(clk_out2));
    clock_divider uut3 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd3), .clk_out(clk_out3));
    clock_divider uut4 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd4), .clk_out(clk_out4));
    clock_divider uut5 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd5), .clk_out(clk_out5));
    clock_divider uut6 (.clk_in(clk), .res(res), .polarity(pol), .div(div), .clk_out(clk_out6));
    clock_divider uut7 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd7), .clk_out(clk_out7));
    clock_divider uut8 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd8), .clk_out(clk_out8));
    clock_divider uut9 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd9), .clk_out(clk_out9));
    clock_divider uut10 (.clk_in(clk), .res(res), .polarity(pol), .div(16'd10), .clk_out(clk_out10));

    always #`TCLK clk = ~clk;
    always @(posedge clk_out2) cnt2 = cnt2 + 1;
    always @(posedge clk_out3) cnt3 = cnt3 + 1;
    always @(posedge clk_out4) cnt4 = cnt4 + 1;
    always @(posedge clk_out5) cnt5 = cnt5 + 1;
    always @(posedge clk_out6) cnt6 = cnt6 + 1;
    always @(posedge clk_out7) cnt7 = cnt7 + 1;
    always @(posedge clk_out8) cnt8 = cnt8 + 1;
    always @(posedge clk_out9) cnt9 = cnt9 + 1;
    always @(posedge clk_out10) cnt10 = cnt10 + 1;

    initial begin
        $dumpfile("vcd/clock_divider_tb.vcd");
        $dumpvars(0);
        clk = 1'b1;
        res = 1'b0;

        @(negedge clk);
        assert(clk_out2 === pol) else
        $error("%t Initial value before reset of Baud clock %0b is not %0b", $time, clk_out2, pol);

        @(posedge clk) res = 1'b1;
        assert(clk_out3 === pol) else
        $error("Initial value while reset of Baud clock %0b is not %0b", clk_out2, pol);
        @(posedge clk) res = 1'b0;

        @(negedge clk);
        assert(clk_out6 === pol) else
        $error("Initial value before div is set of Baud clock %0b is not %0b", clk_out2, pol);
        div = 16'd6;

        repeat(24) @(posedge clk);
        // on time 0 it is also posedge, so adding 1 to counters
        if (cnt2 != 13) $error("cnt2 %0d is not 13", cnt2);
        if (cnt3 != 9) $error("cnt3 %0d is not 9", cnt3);
        if (cnt4 != 7) $error("cnt4 %0d is not 7", cnt4);
        if (cnt5 != 5) $error("cnt5 %0d is not 5", cnt5);
        if (cnt6 != 5) $error("cnt6 %0d is not 5", cnt6);
        if (cnt7 != 4) $error("cnt7 %0d is not 4", cnt7);
        if (cnt8 != 4) $error("cnt8 %0d is not 4", cnt8);
        if (cnt9 != 3) $error("cnt9 %0d is not 3", cnt9);
        if (cnt10 != 3) $error("cnt10 %0d is not 3", cnt10);
        $display("End of testbench: clock_divider_tb.vcd");
        $finish;
    end
endmodule
